import 'package:drift/drift.dart' show Variable;
import 'package:flutter/foundation.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/utils/root_zone_future.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector_registry.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector_toggles.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/quality_context_builder.dart';
import 'package:submersion/features/data_quality/data/services/quality_neighbor_sql.dart';
import 'package:submersion/features/data_quality/data/services/quality_prefilters.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';

class QualityScanSummary {
  const QualityScanSummary({
    required this.divesScanned,
    required this.findingsProduced,
    required this.detectorErrors,
    this.cancelled = false,
  });
  final int divesScanned;
  final int findingsProduced;
  final int detectorErrors;

  /// The scan stopped before reaching every dive, so it does not count as a
  /// full scan. Only [QualityScanService.scanLibrary] can be cancelled.
  final bool cancelled;
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
  ///
  /// Contexts are built [batchSize] dives at a time, since an import can send
  /// a whole logbook here, but the findings are written once for the whole
  /// scope. A pair can be reported from one member alone, and a later batch
  /// holding only the other member would delete what an earlier one wrote.
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
    final expanded = (await _expandNeighbors(diveIds)).toList();
    // Resolved here so every batch of one scan reads the same clock.
    final scanNow = now ?? DateTime.now();
    final produced = <QualityFinding>[];
    var errors = 0;
    for (final batch in seriesIdChunks(expanded, size: batchSize)) {
      final detected = await _detect(
        batch,
        detectorsFor: (_) => enabled,
        now: scanNow,
      );
      produced.addAll(detected.produced);
      errors += detected.errors;
    }
    return _apply(
      expanded,
      enabled: enabled,
      produced: produced,
      errors: errors,
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
    // Resolved here so the dives the prefilters pick are judged by the clock
    // that picked them, however long the batches take.
    final scanNow = now ?? DateTime.now();
    final candidates = await QualityPrefilters().candidatesByDetector(
      now: scanNow,
    );
    final allDiveIds = [
      for (final r in await _db.customSelect('SELECT id FROM dives').get())
        r.read<String>('id'),
    ];
    var done = 0;
    var produced = 0;
    var errors = 0;
    var cancelled = false;
    for (final batch in seriesIdChunks(allDiveIds, size: batchSize)) {
      if (isCancelled?.call() ?? false) {
        cancelled = true;
        break;
      }
      final summary = await _scanBatch(
        batch,
        enabled: enabled,
        // A detector the prefilters do not know runs on every dive. It
        // counts as run either way, so skipping it would retire all of its
        // findings (#2870): a slower scan beats lost findings.
        detectorsFor: (diveId) => [
          for (final d in enabled)
            if (candidates[d.id]?.contains(diveId) ?? true) d,
        ],
        now: scanNow,
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
      cancelled: cancelled,
    );
  }

  Future<QualityScanSummary> _scanBatch(
    List<String> diveIds, {
    required List<QualityDetector> enabled,
    required List<QualityDetector> Function(String diveId) detectorsFor,
    DateTime? now,
  }) async {
    final detected = await _detect(
      diveIds,
      detectorsFor: detectorsFor,
      now: now,
    );
    return _apply(
      diveIds,
      enabled: enabled,
      produced: detected.produced,
      errors: detected.errors,
    );
  }

  Future<({List<QualityFinding> produced, int errors})> _detect(
    List<String> diveIds, {
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
    return (produced: produced, errors: errors);
  }

  Future<QualityScanSummary> _apply(
    List<String> diveIds, {
    required List<QualityDetector> enabled,
    required List<QualityFinding> produced,
    required int errors,
  }) async {
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
    final windowMs = QualityThresholds.neighborWindow.inMilliseconds;
    final expanded = {...diveIds};
    for (final chunk in seriesIdChunks(diveIds.toList())) {
      final rows = await _db
          .customSelect(
            qualityExpandNeighborsSql(chunk.length, windowMs),
            variables: [for (final id in chunk) Variable.withString(id)],
          )
          .get();
      expanded.addAll(rows.map((r) => r.read<String>('id')));
    }
    return expanded;
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

  Future<void> _tail = rootZoneFuture();
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
