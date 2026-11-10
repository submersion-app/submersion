import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/repairs/duplicate_cylinder_rules.dart';
import 'package:submersion/features/dive_log/data/repositories/duplicate_cylinder_repository.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';

const _log = LoggerService('DuplicateCylinderService');

/// One cylinder of a merge, as the confirmation shows it.
class CylinderSummary {
  const CylinderSummary({
    required this.id,
    required this.order,
    required this.name,
    required this.o2,
    required this.he,
  });

  final String id;

  /// Its place on the dive (0-based), for "Cylinder 2" when it has no name.
  final int order;
  final String? name;
  final double o2;
  final double he;
}

/// What removing one dive's duplicate rows of one cylinder would do.
class CylinderMergePreview {
  const CylinderMergePreview({
    required this.diveId,
    required this.survivorId,
    required this.duplicateIds,
    required this.cylinders,
    required this.findingIds,
  });

  final String diveId;
  final String survivorId;
  final List<String> duplicateIds;

  /// Every row of the group, survivor included, in dive order.
  final List<CylinderSummary> cylinders;

  /// The findings this merge answers; resolved when it lands.
  final List<String> findingIds;

  /// Whether the rows disagree on gas, so the diver must say which it held.
  bool get mixesDiffer {
    final first = cylinders.first;
    return cylinders.any(
      (c) => (c.o2 - first.o2).abs() > 0.05 || (c.he - first.he).abs() > 0.05,
    );
  }

  CylinderSummary get survivor =>
      cylinders.firstWhere((c) => c.id == survivorId);
}

/// What a removal did, for its summary and its Undo.
class DuplicateRemovalResult {
  const DuplicateRemovalResult({
    required this.merged,
    required this.skippedMixes,
    required this.failed,
    required this.operationId,
    this.diveIds = const [],
  });

  final int merged;
  final int skippedMixes;
  final int failed;

  /// The change log operation the whole run filed under; reverting it undoes
  /// every merge. Null with no database to log to.
  final String? operationId;

  /// The dives a merge changed, to rescan after an Undo.
  final List<String> diveIds;
}

/// Removes duplicate cylinders for one twin finding or for every
/// serial-proven one (issue #4393).
///
/// Each run is one change log operation labelled
/// [ChangeLogLabels.removeDuplicateCylinders], which also records the
/// pressure series a merge moves, so one revert restores everything. It
/// always opens its own operation, even inside another scope.
class DuplicateCylinderService {
  DuplicateCylinderService({
    DuplicateCylinderRepository? repository,
    QualityFindingsRepository? findings,
  }) : _repository = repository ?? DuplicateCylinderRepository(),
       _findings = findings ?? QualityFindingsRepository();

  final DuplicateCylinderRepository _repository;
  final QualityFindingsRepository _findings;

  AppDatabase get _db => DatabaseService.instance.database;

  static bool _isTwin(QualityFinding f) =>
      f.detectorId == 'tank_assignment' &&
      f.params['tankIdA'] is String &&
      f.params['tankIdB'] is String;

  /// The open twin findings the bulk action may act on: those whose rows
  /// share a transmitter serial. A match by pressure curve alone could be a
  /// real twinset, so it stays with the per-card action.
  List<QualityFinding> bulkCandidates(Iterable<QualityFinding> open) =>
      candidatesIn(open);

  /// [bulkCandidates] without a service, for the toolbar's count.
  static List<QualityFinding> candidatesIn(Iterable<QualityFinding> open) => [
    for (final f in open)
      if (_isTwin(f) && f.params['sameTransmitter'] == true) f,
  ];

  /// The merge [twin] asks for, or null when fewer than two of its rows are
  /// still on the dive.
  Future<CylinderMergePreview?> previewFor(QualityFinding twin) async {
    final previews = await _previewDive(twin.diveId, [twin]);
    return previews.firstOrNull;
  }

  /// One merge per dive and serial group among [candidates].
  Future<List<CylinderMergePreview>> previewAll(
    List<QualityFinding> candidates,
  ) async {
    final byDive = <String, List<QualityFinding>>{};
    for (final f in candidates) {
      (byDive[f.diveId] ??= []).add(f);
    }
    return [
      for (final entry in byDive.entries)
        ...await _previewDive(entry.key, entry.value),
    ];
  }

  Future<List<CylinderMergePreview>> _previewDive(
    String diveId,
    List<QualityFinding> twins,
  ) async {
    final tanks =
        await (_db.select(_db.diveTanks)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([(t) => OrderingTerm.asc(t.tankOrder)]))
            .get();
    final primary =
        await (_db.select(_db.diveDataSources)
              ..where((s) => s.diveId.equals(diveId) & s.isPrimary.equals(true))
              ..limit(1))
            .getSingleOrNull();
    final byGroup = <String, ({List<String> ids, List<String> findings})>{};
    for (final f in twins) {
      final ids = duplicateGroupFor(
        tankIdA: f.params['tankIdA']! as String,
        tankIdB: f.params['tankIdB']! as String,
        sameTransmitter: f.params['sameTransmitter'] == true,
        tanks: tanks,
      );
      if (ids.isEmpty) continue;
      final entry = byGroup[ids.join('|')] ??= (ids: ids, findings: []);
      entry.findings.add(f.id);
    }
    return [
      for (final group in byGroup.values)
        _preview(diveId, tanks, group.ids, group.findings, primary?.id),
    ];
  }

  CylinderMergePreview _preview(
    String diveId,
    List<DiveTank> tanks,
    List<String> ids,
    List<String> findingIds,
    String? primarySourceId,
  ) {
    final rows = [
      for (final t in tanks)
        if (ids.contains(t.id)) t,
    ];
    final survivorId = pickSurvivor(rows, primarySourceId: primarySourceId);
    return CylinderMergePreview(
      diveId: diveId,
      survivorId: survivorId,
      duplicateIds: [
        for (final id in ids)
          if (id != survivorId) id,
      ],
      cylinders: [
        for (final t in rows)
          CylinderSummary(
            id: t.id,
            order: t.tankOrder,
            name: t.tankName ?? t.presetName,
            o2: t.o2Percent,
            he: t.hePercent,
          ),
      ],
      findingIds: findingIds,
    );
  }

  /// Merges one group. [mix] is the diver's choice when the rows disagree.
  Future<DuplicateRemovalResult> removeOne(
    CylinderMergePreview preview, {
    ({double o2, double he})? mix,
  }) => _run([preview], mix: mix, skipMixClashes: false);

  /// Merges every group whose rows agree on gas; the others are counted in
  /// [DuplicateRemovalResult.skippedMixes] and their findings stay open. A
  /// group whose rows have gone is skipped silently, and one that fails is
  /// counted without stopping the rest.
  Future<DuplicateRemovalResult> removeAll(
    List<CylinderMergePreview> previews, {
    void Function(int done, int total)? onProgress,
  }) => _run(previews, skipMixClashes: true, onProgress: onProgress);

  Future<DuplicateRemovalResult> _run(
    List<CylinderMergePreview> previews, {
    ({double o2, double he})? mix,
    required bool skipMixClashes,
    void Function(int done, int total)? onProgress,
  }) async {
    var merged = 0;
    var skippedMixes = 0;
    var failed = 0;
    String? operationId;
    final resolved = <String>[];
    final touched = <String>{};

    // run, not bulk: its own operation even inside another scope, so the
    // label that records the moved pressure series is never lost.
    await ChangeLogScope.run(
      DatabaseService.instance.databaseOrNull,
      source: ChangeLogSource.manual,
      label: ChangeLogLabels.removeDuplicateCylinders,
      body: () async {
        operationId = ChangeLogScope.currentOperationId;
        final now = DateTime.now().millisecondsSinceEpoch;
        for (var i = 0; i < previews.length; i++) {
          final p = previews[i];
          onProgress?.call(i, previews.length);
          if (skipMixClashes && p.mixesDiffer) {
            skippedMixes++;
            continue;
          }
          try {
            final done = await _db.transaction(
              () => _repository.mergeInto(
                diveId: p.diveId,
                survivorId: p.survivorId,
                duplicateIds: p.duplicateIds,
                mix: mix,
                now: now,
              ),
            );
            if (!done) continue;
            merged++;
            resolved.addAll(p.findingIds);
            touched.add(p.diveId);
          } catch (error, stackTrace) {
            failed++;
            _log.warning(
              'Could not merge duplicate cylinders on dive ${p.diveId}',
              error: error,
              stackTrace: stackTrace,
            );
          }
        }
        onProgress?.call(previews.length, previews.length);
      },
    );

    if (touched.isNotEmpty) {
      SyncEventBus.notifyLocalChange();
      for (final id in resolved) {
        await _findings.setStatus(id, QualityStatus.resolved);
      }
      final dives = touched.toList();
      scheduleQualityScan(dives);
      scheduleSensorSummaryRefresh(dives, force: true);
      scheduleDerivedMetricsRefresh(dives, force: true);
    }
    return DuplicateRemovalResult(
      merged: merged,
      skippedMixes: skippedMixes,
      failed: failed,
      operationId: operationId,
      diveIds: touched.toList(),
    );
  }
}
