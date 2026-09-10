import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';

/// The device-local marker that the engine has run over an item's current
/// inputs. An unchanged item costs one row read.
class EquipmentConditionReview {
  final String equipmentId;
  final int engineVersion;
  final String inputFingerprint;
  final DateTime reviewedAt;

  const EquipmentConditionReview({
    required this.equipmentId,
    required this.engineVersion,
    required this.inputFingerprint,
    required this.reviewedAt,
  });
}

/// Persistence for condition findings and their review markers.
///
/// `equipment_findings` is synced the way `dive_safety_findings` is: no HLC
/// of its own, so every write marks the row pending and bumps the parent
/// equipment row's clock, and every delete logs a tombstone.
/// `equipment_condition_reviews` is device-local and never marked.
class EquipmentFindingsRepository {
  static const String entityType = 'equipmentFindings';

  /// New dives that must have joined a finding's evidence before a
  /// dismissal clears (the spec's "three new dives").
  static const int dismissalClearsAfterNewDives = 3;

  final AppDatabase? _dbOverride;
  final SyncRepository _syncRepository;

  EquipmentFindingsRepository({AppDatabase? db, SyncRepository? syncRepository})
    : _dbOverride = db,
      _syncRepository = syncRepository ?? SyncRepository();

  AppDatabase get _db => _dbOverride ?? DatabaseService.instance.database;

  Stream<void> watchChanges() => _db
      .tableUpdates(
        TableUpdateQuery.allOf([
          TableUpdateQuery.onTable(_db.equipmentFindings),
          TableUpdateQuery.onTable(_db.equipmentConditionReviews),
        ]),
      )
      .map((_) {});

  Future<EquipmentConditionReview?> getReview(String equipmentId) async {
    final row = await (_db.select(
      _db.equipmentConditionReviews,
    )..where((t) => t.equipmentId.equals(equipmentId))).getSingleOrNull();
    if (row == null) return null;
    return EquipmentConditionReview(
      equipmentId: row.equipmentId,
      engineVersion: row.engineVersion,
      inputFingerprint: row.inputFingerprint,
      reviewedAt: DateTime.fromMillisecondsSinceEpoch(
        row.reviewedAt,
        isUtc: true,
      ),
    );
  }

  /// The item's findings, undismissed first, then in rule order. Rows whose
  /// rule this build does not know (a newer peer) are dropped, never
  /// coerced.
  Future<List<EquipmentFinding>> getFindings(String equipmentId) async {
    final rows = await (_db.select(
      _db.equipmentFindings,
    )..where((t) => t.equipmentId.equals(equipmentId))).get();
    return _sorted([for (final row in rows) ?_toDomain(row)]);
  }

  /// Every undismissed finding across items, for badges.
  Future<List<EquipmentFinding>> getAllUndismissed() async {
    final rows = await (_db.select(
      _db.equipmentFindings,
    )..where((t) => t.dismissedAt.isNull())).get();
    return _sorted([for (final row in rows) ?_toDomain(row)]);
  }

  /// Replaces the item's findings with [findings] in one transaction.
  ///
  /// A finding the engine re-emits keeps its `created_at`, and keeps its
  /// dismissal unless at least [dismissalClearsAfterNewDives] dive ids in
  /// the new evidence were absent from the old. A finding the engine no
  /// longer emits is deleted with a tombstone. The review marker is
  /// upserted without sync marks (device-local).
  Future<void> saveReview({
    required String equipmentId,
    required String inputFingerprint,
    required List<EquipmentFinding> findings,
    required int engineVersion,
    Map<String, DateTime> diveDates = const {},
    required DateTime now,
  }) async {
    final nowMs = now.millisecondsSinceEpoch;
    await _db.transaction(() async {
      final existingRows = await (_db.select(
        _db.equipmentFindings,
      )..where((t) => t.equipmentId.equals(equipmentId))).get();
      final existingById = {for (final r in existingRows) r.id: r};
      final keep = <String>{};

      for (final finding in findings) {
        keep.add(finding.id);
        final old = existingById[finding.id];
        int? dismissedAt;
        int createdAt = finding.createdAt.millisecondsSinceEpoch;
        if (old != null) {
          createdAt = old.createdAt;
          dismissedAt = old.dismissedAt;
          if (dismissedAt != null) {
            // A dismissed row keeps the evidence it was dismissed with, so
            // "new dives" is always measured from the dismissal, not from
            // the last recompute. Once enough arrive, the row updates and
            // clears in one step.
            //
            // The dive must also have HAPPENED after the dismissal, per
            // the spec. Counting any unseen id would let an imported
            // logbook or a restore clear every dismissal at once, which is
            // the opposite of what dismissing one asked for. A dive whose
            // date the caller did not supply cannot be shown to be newer,
            // so it does not count.
            final dismissedMs = dismissedAt;
            final oldIds =
                FindingEvidence.decode(old.evidence)?.diveIds.toSet() ??
                const <String>{};
            final newIds = finding.evidence.diveIds.where((id) {
              if (oldIds.contains(id)) return false;
              final date = diveDates[id];
              return date != null && date.millisecondsSinceEpoch > dismissedMs;
            }).length;
            if (newIds < dismissalClearsAfterNewDives) continue;
            dismissedAt = null;
          }
        }
        await _db
            .into(_db.equipmentFindings)
            .insertOnConflictUpdate(
              EquipmentFindingsCompanion.insert(
                id: finding.id,
                equipmentId: finding.equipmentId,
                ruleId: finding.ruleId.dbValue,
                severity: finding.severity.dbValue,
                value: Value(finding.value),
                evidence: Value(finding.evidence.encode()),
                evidenceFingerprint: finding.evidenceFingerprint,
                engineVersion: finding.engineVersion,
                dismissedAt: Value(dismissedAt),
                createdAt: createdAt,
              ),
            );
        await _syncRepository.markRecordPending(
          entityType: entityType,
          recordId: finding.id,
          localUpdatedAt: nowMs,
        );
      }

      for (final old in existingRows) {
        if (keep.contains(old.id)) continue;
        await (_db.delete(
          _db.equipmentFindings,
        )..where((t) => t.id.equals(old.id))).go();
        await _syncRepository.logDeletion(
          entityType: entityType,
          recordId: old.id,
        );
      }

      await _db
          .into(_db.equipmentConditionReviews)
          .insertOnConflictUpdate(
            EquipmentConditionReviewsCompanion.insert(
              equipmentId: equipmentId,
              // The version of the engine that produced this review, from
              // the caller. Reading it off the findings breaks on the most
              // common case of all: an item the engine cleared has no
              // finding to read it from, and the marker then recorded a
              // version older than any engine, so every read recomputed.
              engineVersion: engineVersion,
              inputFingerprint: inputFingerprint,
              reviewedAt: nowMs,
            ),
          );

      // The findings carry no HLC; the incremental exporter picks them up
      // for equipment whose clock advanced, so bump the parent (the safety
      // review does the same with dives).
      await _syncRepository.markRecordPending(
        entityType: 'equipment',
        recordId: equipmentId,
        localUpdatedAt: nowMs,
      );
    });
    SyncEventBus.notifyLocalChange();
  }

  Future<void> setDismissed({
    required String findingId,
    required bool dismissed,
    required DateTime now,
  }) async {
    final nowMs = now.millisecondsSinceEpoch;
    await _db.transaction(() async {
      final row = await (_db.select(
        _db.equipmentFindings,
      )..where((t) => t.id.equals(findingId))).getSingleOrNull();
      if (row == null) return;
      await (_db.update(
        _db.equipmentFindings,
      )..where((t) => t.id.equals(findingId))).write(
        EquipmentFindingsCompanion(
          dismissedAt: Value(dismissed ? nowMs : null),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: findingId,
        localUpdatedAt: nowMs,
      );
      await _syncRepository.markRecordPending(
        entityType: 'equipment',
        recordId: row.equipmentId,
        localUpdatedAt: nowMs,
      );
    });
    SyncEventBus.notifyLocalChange();
  }

  List<EquipmentFinding> _sorted(List<EquipmentFinding> findings) =>
      findings..sort((a, b) {
        if (a.isDismissed != b.isDismissed) return a.isDismissed ? 1 : -1;
        final byRule = a.ruleId.index.compareTo(b.ruleId.index);
        return byRule != 0 ? byRule : a.id.compareTo(b.id);
      });

  EquipmentFinding? _toDomain(EquipmentFindingRow row) {
    final rule = ConditionRuleId.fromDbValue(row.ruleId);
    final evidence = FindingEvidence.decode(row.evidence);
    if (rule == null || evidence == null) return null;
    return EquipmentFinding(
      id: row.id,
      equipmentId: row.equipmentId,
      ruleId: rule,
      severity: ConditionSeverity.fromDbValue(row.severity),
      value: row.value,
      evidence: evidence,
      evidenceFingerprint: row.evidenceFingerprint,
      engineVersion: row.engineVersion,
      dismissedAt: row.dismissedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.dismissedAt!, isUtc: true),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAt,
        isUtc: true,
      ),
    );
  }
}
