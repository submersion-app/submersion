import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/data/repositories/sync_repository.dart';
import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/sync/sync_event_bus.dart';
import '../../domain/entities/quality_finding.dart';

class ScanApplyResult {
  const ScanApplyResult({
    required this.inserted,
    required this.updated,
    required this.removed,
  });
  final int inserted;
  final int updated;
  final int removed;
}

class QualityFindingsRepository {
  QualityFindingsRepository();

  AppDatabase get _db => DatabaseService.instance.database;
  final _sync = SyncRepository();

  /// Applies one scan's results for a scope of dives and detectors.
  ///
  /// Semantics (spec "Write discipline"):
  /// - re-produced findings refresh facts but preserve `dismissed`;
  /// - `resolved` findings still produced reopen (the repair did not stick);
  /// - findings in scope not re-produced are deleted with tombstones;
  /// - detectors outside [ranDetectorIds] are never touched.
  ///
  /// Runs in one transaction and does NOT notify; the scan service emits one
  /// SyncEventBus.notifyLocalChange() per batch.
  Future<ScanApplyResult> applyScanResults({
    required Set<String> scopeDiveIds,
    required Set<String> ranDetectorIds,
    required List<QualityFinding> produced,
  }) async {
    if (scopeDiveIds.isEmpty || ranDetectorIds.isEmpty) {
      return const ScanApplyResult(inserted: 0, updated: 0, removed: 0);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    // Same id produced twice in a batch (both members of a pair scanned)
    // collapses here.
    final producedById = {for (final f in produced) f.id: f};

    return _db.transaction(() async {
      final existingRows =
          await (_db.select(_db.qualityFindings)..where(
                (t) =>
                    t.detectorId.isIn(ranDetectorIds) &
                    (t.diveId.isIn(scopeDiveIds) |
                        t.relatedDiveId.isIn(scopeDiveIds)),
              ))
              .get();
      final existingById = {for (final r in existingRows) r.id: r};

      var removed = 0;
      for (final row in existingRows) {
        if (producedById.containsKey(row.id)) continue;
        await (_db.delete(
          _db.qualityFindings,
        )..where((t) => t.id.equals(row.id))).go();
        await _sync.logDeletion(
          entityType: 'qualityFindings',
          recordId: row.id,
        );
        removed++;
      }

      var inserted = 0;
      var updated = 0;
      for (final f in producedById.values) {
        final existing =
            existingById[f.id] ??
            await (_db.select(
              _db.qualityFindings,
            )..where((t) => t.id.equals(f.id))).getSingleOrNull();
        final paramsJson = jsonEncode(f.params);
        if (existing == null) {
          await _db
              .into(_db.qualityFindings)
              .insert(
                QualityFindingsCompanion.insert(
                  id: f.id,
                  diveId: f.diveId,
                  relatedDiveId: Value(f.relatedDiveId),
                  computerId: Value(f.computerId),
                  detectorId: f.detectorId,
                  detectorVersion: f.detectorVersion,
                  category: f.category.name,
                  severity: f.severity.name,
                  status: const Value('open'),
                  params: Value(paramsJson),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          inserted++;
        } else {
          final newStatus = existing.status == QualityStatus.resolved.name
              ? QualityStatus.open.name
              : existing.status;
          final unchanged =
              existing.params == paramsJson &&
              existing.severity == f.severity.name &&
              existing.detectorVersion == f.detectorVersion &&
              existing.status == newStatus;
          if (unchanged) continue; // avoid sync churn on repeat scans
          await (_db.update(
            _db.qualityFindings,
          )..where((t) => t.id.equals(f.id))).write(
            QualityFindingsCompanion(
              detectorVersion: Value(f.detectorVersion),
              severity: Value(f.severity.name),
              params: Value(paramsJson),
              status: Value(newStatus),
              updatedAt: Value(now),
            ),
          );
          updated++;
        }
        await _sync.markRecordPending(
          entityType: 'qualityFindings',
          recordId: f.id,
          localUpdatedAt: now,
        );
      }
      return ScanApplyResult(
        inserted: inserted,
        updated: updated,
        removed: removed,
      );
    });
  }

  Future<void> setStatus(String id, QualityStatus status) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.qualityFindings,
    )..where((t) => t.id.equals(id))).write(
      QualityFindingsCompanion(
        status: Value(status.name),
        updatedAt: Value(now),
      ),
    );
    await _sync.markRecordPending(
      entityType: 'qualityFindings',
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<List<QualityFinding>> getFindings({
    QualityStatus? status,
    String? diveId,
  }) async {
    final query = _db.select(_db.qualityFindings)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (status != null) {
      query.where((t) => t.status.equals(status.name));
    }
    if (diveId != null) {
      query.where(
        (t) => t.diveId.equals(diveId) | t.relatedDiveId.equals(diveId),
      );
    }
    final rows = await query.get();
    return [for (final r in rows) _fromRow(r)];
  }

  Stream<int> watchOpenCount() {
    final count = _db.qualityFindings.id.count();
    final query = _db.selectOnly(_db.qualityFindings)
      ..addColumns([count])
      ..where(_db.qualityFindings.status.equals(QualityStatus.open.name));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  QualityFinding _fromRow(QualityFindingRow row) => QualityFinding(
    id: row.id,
    diveId: row.diveId,
    relatedDiveId: row.relatedDiveId,
    computerId: row.computerId,
    detectorId: row.detectorId,
    detectorVersion: row.detectorVersion,
    category: QualityCategory.values.byName(row.category),
    severity: QualitySeverity.values.byName(row.severity),
    status: QualityStatus.values.byName(row.status),
    params: (jsonDecode(row.params) as Map<String, dynamic>),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );
}
