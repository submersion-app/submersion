import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';

/// Persistence for post-dive safety reviews.
///
/// dive_safety_reviews is the "analyzed" marker (one row per analyzed dive);
/// dive_safety_findings holds the observations. Both are write-once children
/// of dives (no HLC columns): sync integrity comes from markRecordPending on
/// writes and per-row logDeletion on deletes, mirroring DiveProfileEvents.
class SafetyFindingsRepository {
  // Lazy getter (not a captured instance) so a restore that swaps the
  // DatabaseService database is picked up, matching DiveRepository.
  final AppDatabase? _dbOverride;
  final SyncRepository _syncRepository;

  SafetyFindingsRepository({AppDatabase? db, SyncRepository? syncRepository})
    : _dbOverride = db,
      _syncRepository = syncRepository ?? SyncRepository();

  AppDatabase get _db => _dbOverride ?? DatabaseService.instance.database;

  Future<SafetyReview?> getReview(String diveId) async {
    final marker = await (_db.select(
      _db.diveSafetyReviews,
    )..where((t) => t.diveId.equals(diveId))).getSingleOrNull();
    if (marker == null) return null;
    final rows =
        await (_db.select(_db.diveSafetyFindings)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([(t) => OrderingTerm.asc(t.startTimestamp)]))
            .get();
    return SafetyReview(
      diveId: diveId,
      engineVersion: marker.engineVersion,
      reviewedAt: DateTime.fromMillisecondsSinceEpoch(marker.reviewedAt),
      // Skip rows whose rule_id does not round-trip to a known SafetyRuleId:
      // an unknown value can only come from a newer app/sync payload, and
      // coercing it to a default rule would surface misleading UI text
      // (_toDomain returns null for such rows).
      findings: [for (final row in rows) ?_toDomain(row)],
    );
  }

  Future<void> saveReview(SafetyReview review) async {
    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.diveSafetyFindings,
      )..where((t) => t.diveId.equals(review.diveId))).get();
      await (_db.delete(
        _db.diveSafetyFindings,
      )..where((t) => t.diveId.equals(review.diveId))).go();
      for (final row in existing) {
        await _syncRepository.logDeletion(
          entityType: 'diveSafetyFindings',
          recordId: row.id,
        );
      }
      final reviewedAtMs = review.reviewedAt.millisecondsSinceEpoch;
      await _db
          .into(_db.diveSafetyReviews)
          .insertOnConflictUpdate(
            DiveSafetyReviewsCompanion.insert(
              diveId: review.diveId,
              engineVersion: review.engineVersion,
              reviewedAt: reviewedAtMs,
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'diveSafetyReviews',
        recordId: review.diveId,
        localUpdatedAt: reviewedAtMs,
      );
      // Both safety exporters gate incremental export on the parent dive's
      // HLC (dives.hlc > hlcSince). A review computed lazily on first view
      // never touches the dive, so its rows (and their device-local random
      // ids) would never sync; a later dismiss/restore on another device
      // would then reference finding ids it never received. Bump the parent
      // dive's HLC so the freshly computed review propagates and all devices
      // converge on one set of finding ids, mirroring setDismissed.
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: review.diveId,
        localUpdatedAt: reviewedAtMs,
      );
      for (final finding in review.findings) {
        await _db
            .into(_db.diveSafetyFindings)
            .insert(
              DiveSafetyFindingsCompanion.insert(
                id: finding.id,
                diveId: finding.diveId,
                ruleId: finding.ruleId.dbValue,
                severity: finding.severity.dbValue,
                startTimestamp: Value(finding.startTimestamp),
                endTimestamp: Value(finding.endTimestamp),
                value: Value(finding.value),
                engineVersion: finding.engineVersion,
                dismissedAt: Value(finding.dismissedAt?.millisecondsSinceEpoch),
                createdAt: finding.createdAt.millisecondsSinceEpoch,
              ),
            );
        await _syncRepository.markRecordPending(
          entityType: 'diveSafetyFindings',
          recordId: finding.id,
          localUpdatedAt: finding.createdAt.millisecondsSinceEpoch,
        );
      }
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
      final finding = await (_db.select(
        _db.diveSafetyFindings,
      )..where((t) => t.id.equals(findingId))).getSingleOrNull();
      if (finding == null) return;
      await (_db.update(
        _db.diveSafetyFindings,
      )..where((t) => t.id.equals(findingId))).write(
        DiveSafetyFindingsCompanion(
          dismissedAt: Value(dismissed ? nowMs : null),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'diveSafetyFindings',
        recordId: findingId,
        localUpdatedAt: nowMs,
      );
      // dive_safety_findings has no HLC of its own; the incremental exporter
      // pulls findings for dives whose parent HLC advanced. A standalone
      // dismiss/restore never touches the dive, so bump the parent dive's HLC
      // here too or the change is stranded and never reaches other devices.
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: finding.diveId,
        localUpdatedAt: nowMs,
      );
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Invalidation hook for profile writes: drops the review so the next view
  /// recomputes against the new profile. Static so both dive repositories
  /// can call it without holding a SafetyFindingsRepository.
  static Future<void> clearReviewForDive(
    AppDatabase db,
    SyncRepository sync,
    String diveId,
  ) async {
    final existing = await (db.select(
      db.diveSafetyFindings,
    )..where((t) => t.diveId.equals(diveId))).get();
    await (db.delete(
      db.diveSafetyFindings,
    )..where((t) => t.diveId.equals(diveId))).go();
    for (final row in existing) {
      await sync.logDeletion(
        entityType: 'diveSafetyFindings',
        recordId: row.id,
      );
    }
    final deletedMarker = await (db.delete(
      db.diveSafetyReviews,
    )..where((t) => t.diveId.equals(diveId))).go();
    if (deletedMarker > 0) {
      await sync.logDeletion(entityType: 'diveSafetyReviews', recordId: diveId);
    }
  }

  /// Maps a stored finding row to its domain entity, or null when the row's
  /// rule_id does not correspond to a known [SafetyRuleId]. Callers drop null
  /// rows rather than surface a coerced (misleading) rule.
  SafetyFinding? _toDomain(DiveSafetyFinding row) {
    final ruleId = SafetyRuleId.fromDbValue(row.ruleId);
    if (ruleId == null) return null;
    return SafetyFinding(
      id: row.id,
      diveId: row.diveId,
      ruleId: ruleId,
      severity: SafetySeverity.fromDbValue(row.severity),
      startTimestamp: row.startTimestamp,
      endTimestamp: row.endTimestamp,
      value: row.value,
      engineVersion: row.engineVersion,
      dismissedAt: row.dismissedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.dismissedAt!),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    );
  }
}
