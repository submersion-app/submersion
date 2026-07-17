import 'dart:math' as math;

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/foundation.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector_registry.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector_toggles.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/quality_context_builder.dart';
import 'package:submersion/features/data_quality/data/services/quality_prefilters.dart';

class QualityScanSummary {
  const QualityScanSummary({
    required this.divesScanned,
    required this.findingsProduced,
    required this.detectorErrors,
  });
  final int divesScanned;
  final int findingsProduced;
  final int detectorErrors;
}

class QualityScanService {
  QualityScanService({
    QualityContextBuilder? contextBuilder,
    QualityFindingsRepository? findingsRepository,
    List<QualityDetector>? detectors,
  }) : _builder = contextBuilder ?? QualityContextBuilder(),
       _findings = findingsRepository ?? QualityFindingsRepository(),
       _detectors = detectors ?? kQualityDetectors;

  static const _log = LoggerService('QualityScanService');
  static const batchSize = 200;

  AppDatabase get _db => DatabaseService.instance.database;
  final QualityContextBuilder _builder;
  final QualityFindingsRepository _findings;
  final List<QualityDetector> _detectors;

  List<QualityDetector> _enabled(Set<String>? enabledIds) {
    if (enabledIds != null) {
      return [
        for (final d in _detectors)
          if (enabledIds.contains(d.id)) d,
      ];
    }
    return [
      for (final d in _detectors)
        if (!QualityDetectorToggles.disabled.contains(d.id)) d,
    ];
  }

  /// Targeted scan: the given dives plus their chronological neighbors (so
  /// cross-dive pair findings can be retired from either side).
  Future<QualityScanSummary> scanDives(
    Set<String> diveIds, {
    Set<String>? enabledDetectorIds,
    DateTime? now,
  }) async {
    if (diveIds.isEmpty) {
      return const QualityScanSummary(
        divesScanned: 0,
        findingsProduced: 0,
        detectorErrors: 0,
      );
    }
    final enabled = _enabled(enabledDetectorIds);
    final expanded = await _expandNeighbors(diveIds);
    return _scanBatch(
      expanded.toList(),
      enabled: enabled,
      detectorsFor: (_) => enabled,
      now: now,
    );
  }

  /// Full-library scan, pre-filtered, batched, cancellable at batch
  /// boundaries. Never triggered automatically at startup.
  Future<QualityScanSummary> scanLibrary({
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
    Set<String>? enabledDetectorIds,
    DateTime? now,
  }) async {
    final enabled = _enabled(enabledDetectorIds);
    final candidates = await QualityPrefilters().candidatesByDetector(now: now);
    final allDiveIds = [
      for (final r in await _db.customSelect('SELECT id FROM dives').get())
        r.read<String>('id'),
    ];
    var done = 0;
    var produced = 0;
    var errors = 0;
    for (var i = 0; i < allDiveIds.length; i += batchSize) {
      if (isCancelled?.call() ?? false) break;
      final batch = allDiveIds.sublist(
        i,
        math.min(i + batchSize, allDiveIds.length),
      );
      final summary = await _scanBatch(
        batch,
        enabled: enabled,
        detectorsFor: (diveId) => [
          for (final d in enabled)
            if (candidates[d.id]?.contains(diveId) ?? false) d,
        ],
        now: now,
      );
      produced += summary.findingsProduced;
      errors += summary.detectorErrors;
      done += batch.length;
      onProgress?.call(done, allDiveIds.length);
    }
    return QualityScanSummary(
      divesScanned: done,
      findingsProduced: produced,
      detectorErrors: errors,
    );
  }

  Future<QualityScanSummary> _scanBatch(
    List<String> diveIds, {
    required List<QualityDetector> enabled,
    required List<QualityDetector> Function(String diveId) detectorsFor,
    DateTime? now,
  }) async {
    final toBuild = [
      for (final id in diveIds)
        if (detectorsFor(id).isNotEmpty) id,
    ];
    final contexts = await _builder.buildAll(toBuild, now: now);
    final produced = <QualityFinding>[];
    var errors = 0;
    for (final ctx in contexts) {
      for (final det in detectorsFor(ctx.dive.id)) {
        try {
          produced.addAll(det.detect(ctx));
        } catch (e, st) {
          errors++;
          _log.error(
            'Detector ${det.id} failed for dive ${ctx.dive.id}',
            error: e,
            stackTrace: st,
          );
        }
      }
    }
    await _findings.applyScanResults(
      scopeDiveIds: diveIds.toSet(),
      ranDetectorIds: {for (final d in enabled) d.id},
      produced: produced,
    );
    SyncEventBus.notifyLocalChange();
    return QualityScanSummary(
      divesScanned: diveIds.length,
      findingsProduced: produced.length,
      detectorErrors: errors,
    );
  }

  Future<Set<String>> _expandNeighbors(Set<String> diveIds) async {
    final placeholders = List.filled(diveIds.length, '?').join(',');
    final windowMs = QualityThresholds.neighborWindow.inMilliseconds;
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT b.id AS id FROM dives a JOIN dives b '
          'ON b.id != a.id AND a.diver_id IS b.diver_id '
          'AND ABS(COALESCE(a.entry_time, a.dive_date_time) - '
          'COALESCE(b.entry_time, b.dive_date_time)) <= $windowMs '
          'WHERE a.id IN ($placeholders)',
          variables: [for (final id in diveIds) Variable.withString(id)],
        )
        .get();
    return {...diveIds, for (final r in rows) r.read<String>('id')};
  }
}

/// Fire-and-forget entry point for import/save hooks. Serializes scans
/// (single-flight) and merges bursts of requests.
class QualityScanScheduler {
  QualityScanScheduler._();
  static final QualityScanScheduler instance = QualityScanScheduler._();

  /// Widget tests that drive save flows against a fake-async zone can set
  /// this to false to keep Drift work out of the test zone.
  static bool enabled = true;

  static const _log = LoggerService('QualityScanScheduler');

  Future<void> _tail = Future.value();
  final Set<String> _pending = {};

  @visibleForTesting
  Future<void> get idle => _tail;

  void schedule(Set<String> diveIds) {
    if (!enabled || diveIds.isEmpty) return;
    _pending.addAll(diveIds);
    _tail = _tail.then((_) async {
      final ids = Set.of(_pending);
      _pending.clear();
      if (ids.isEmpty) return;
      try {
        await QualityScanService().scanDives(ids);
      } catch (e, st) {
        _log.error('Scheduled quality scan failed', error: e, stackTrace: st);
      }
    });
  }
}

void scheduleQualityScan(Iterable<String> diveIds) =>
    QualityScanScheduler.instance.schedule(diveIds.toSet());
