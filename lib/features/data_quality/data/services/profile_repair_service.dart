import 'dart:math' as math;

import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/data_quality/domain/repairs/repair_predicates.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

/// Profile-sample surgery. The math is pure and static (unit-tested with
/// vectors); persistence delegates to the EXISTING edited-profile pattern:
/// saveEditedProfile demotes originals to isPrimary=false and inserts the
/// corrected series as the new primary -- computer data is never destroyed,
/// and restoreOriginalProfile is the ready-made undo.
class ProfileRepairService {
  ProfileRepairService({DiveRepository? diveRepository})
    : _diveRepo = diveRepository ?? DiveRepository();

  final DiveRepository _diveRepo;

  /// Replace single-sample spikes (QualityThresholds.spikeRateMetersPerSecond
  /// exceeded in both directions with opposite signs) by linear interpolation
  /// of the two neighbors.
  ///
  /// Neighbors are read from the INPUT, not from the partially rewritten
  /// output, so this fires on exactly the samples DepthSpikeDetector flags.
  static List<domain.DiveProfilePoint> despike(
    List<domain.DiveProfilePoint> points,
  ) {
    if (points.length < 3) return List.of(points);
    final out = List.of(points);
    for (var i = 1; i + 1 < points.length; i++) {
      final dt1 = points[i].timestamp - points[i - 1].timestamp;
      final dt2 = points[i + 1].timestamp - points[i].timestamp;
      if (!RepairPredicates.isDepthSpike(
        dt1: dt1,
        dt2: dt2,
        d0: points[i - 1].depth,
        d1: points[i].depth,
        d2: points[i + 1].depth,
      )) {
        continue;
      }
      final span = points[i + 1].timestamp - points[i - 1].timestamp;
      final frac = span > 0 ? dt1 / span : 0.5;
      out[i] = out[i].copyWith(
        depth:
            points[i - 1].depth +
            (points[i + 1].depth - points[i - 1].depth) * frac,
      );
    }
    return out;
  }

  /// Redraw the interior of every sustained impossible-rate run as a straight
  /// line between the run's endpoints. Runs whose endpoints are themselves far
  /// apart -- a genuine, if aggressive, descent -- are left untouched rather
  /// than rewritten into something the detector would flag again.
  static List<domain.DiveProfilePoint> smoothImpossibleRates(
    List<domain.DiveProfilePoint> points,
  ) {
    if (points.length < 3) return List.of(points);
    final out = List.of(points);
    int? runStart;
    var lastIndex = 0;

    void closeRun() {
      final start = runStart;
      if (start != null) {
        final from = points[start];
        final to = points[lastIndex];
        final span = to.timestamp - from.timestamp;
        if (span >= QualityThresholds.impossibleRateMinSeconds &&
            RepairPredicates.impossibleRunIsInterpolatable(
              sampleCount: lastIndex - start + 1,
              startSeconds: from.timestamp,
              endSeconds: to.timestamp,
              startDepth: from.depth,
              endDepth: to.depth,
            )) {
          for (var j = start + 1; j < lastIndex; j++) {
            final frac = (points[j].timestamp - from.timestamp) / span;
            out[j] = out[j].copyWith(
              depth: from.depth + (to.depth - from.depth) * frac,
            );
          }
        }
      }
      runStart = null;
    }

    // Mirrors ImpossibleRateDetector's run bookkeeping exactly, including the
    // way a non-increasing timestamp is skipped without closing the run.
    for (var i = 1; i < points.length; i++) {
      final dt = points[i].timestamp - points[i - 1].timestamp;
      if (dt <= 0) continue;
      final ratePerMin = ((points[i].depth - points[i - 1].depth) / dt * 60)
          .abs();
      if (ratePerMin > QualityThresholds.impossibleRateMetersPerMinute) {
        runStart ??= i - 1;
        lastIndex = i;
      } else {
        closeRun();
      }
    }
    closeRun();
    return out;
  }

  /// Raise above-surface samples back to the surface. A negative depth is not
  /// a measurement, so clamping it destroys no information.
  static List<domain.DiveProfilePoint> clampNegativeDepths(
    List<domain.DiveProfilePoint> points,
  ) => [
    for (final p in points)
      if (p.depth < 0) p.copyWith(depth: 0) else p,
  ];

  /// Fill holes up to QualityThresholds.gapFillMaxSeconds with linearly
  /// interpolated samples at the profile's median interval. Longer holes are
  /// honest data loss and stay.
  static List<domain.DiveProfilePoint> fillGaps(
    List<domain.DiveProfilePoint> points,
  ) {
    if (points.length < 3) return List.of(points);
    final intervals = <int>[
      for (var i = 1; i < points.length; i++)
        if (points[i].timestamp > points[i - 1].timestamp)
          points[i].timestamp - points[i - 1].timestamp,
    ];
    if (intervals.isEmpty) return List.of(points);
    final sorted = [...intervals]..sort();
    final median = sorted[sorted.length ~/ 2];
    final threshold = math.max(
      median * QualityThresholds.gapMedianFactor,
      QualityThresholds.gapMinSeconds.toDouble(),
    );
    final out = <domain.DiveProfilePoint>[];
    for (var i = 0; i < points.length; i++) {
      out.add(points[i]);
      if (i + 1 >= points.length) break;
      final gap = points[i + 1].timestamp - points[i].timestamp;
      if (!RepairPredicates.gapIsFillable(gap, threshold)) continue;
      for (
        var t = points[i].timestamp + median;
        t < points[i + 1].timestamp;
        t += median
      ) {
        final frac = (t - points[i].timestamp) / gap;
        out.add(
          domain.DiveProfilePoint(
            timestamp: t,
            depth:
                points[i].depth +
                (points[i + 1].depth - points[i].depth) * frac,
            temperature: _lerpNullable(
              points[i].temperature,
              points[i + 1].temperature,
              frac,
            ),
          ),
        );
      }
    }
    return out;
  }

  /// Clamp isolated temperature outliers by neighbor interpolation.
  /// Touches ONLY the temperature channel.
  ///
  /// Neighbors are the adjacent samples that CARRY a reading, matching how
  /// TempAnomalyDetector walks the channel: a sample without a temperature
  /// must not hide the outlier next to it.
  static List<domain.DiveProfilePoint> smoothTemperature(
    List<domain.DiveProfilePoint> points,
  ) {
    final out = List.of(points);
    final withTemp = [
      for (var i = 0; i < points.length; i++)
        if (points[i].temperature != null) i,
    ];
    if (withTemp.length < 3) return out;
    for (var k = 1; k + 1 < withTemp.length; k++) {
      final a = points[withTemp[k - 1]].temperature;
      final c = points[withTemp[k + 1]].temperature;
      if (!RepairPredicates.isTemperatureSpike(
        a,
        points[withTemp[k]].temperature,
        c,
      )) {
        continue;
      }
      out[withTemp[k]] = out[withTemp[k]].copyWith(temperature: (a! + c!) / 2);
    }
    return out;
  }

  /// Repair wrong-unit temperature channels (e.g. the Fahrenheit-as-Kelvin
  /// firmware bug): kelvinScale converts K -> C, otherwise F -> C.
  static List<domain.DiveProfilePoint> convertTemperature(
    List<domain.DiveProfilePoint> points, {
    required bool kelvinScale,
  }) => [
    for (final p in points)
      p.temperature == null
          ? p
          : p.copyWith(
              temperature: RepairPredicates.convertToCelsius(
                p.temperature!,
                kelvinScale: kelvinScale,
              ),
            ),
  ];

  static double? _lerpNullable(double? a, double? b, double frac) =>
      (a == null || b == null) ? null : a + (b - a) * frac;

  Future<List<domain.DiveProfilePoint>> currentPrimaryProfile(String diveId) =>
      _diveRepo.getDiveProfile(diveId);

  Future<void> applyEdited(
    String diveId,
    List<domain.DiveProfilePoint> edited,
  ) => _diveRepo.saveEditedProfile(diveId, edited);

  Future<void> undo(String diveId) => _diveRepo.restoreOriginalProfile(diveId);

  /// Fix stored maxDepth/avgDepth from the primary profile (the maxdepth
  /// mismatch repair) without touching samples.
  Future<void> recomputeMetrics(String diveId) async {
    final dive = await _diveRepo.getDiveById(diveId);
    if (dive == null) return;
    final maxDepth = dive.calculateMaxDepthFromProfile();
    final avgDepth = dive.calculateAvgDepthFromProfile();
    if (maxDepth == null && avgDepth == null) return;
    await _diveRepo.bulkUpdateFields(
      [diveId],
      DivesCompanion(
        maxDepth: maxDepth != null ? Value(maxDepth) : const Value.absent(),
        avgDepth: avgDepth != null ? Value(avgDepth) : const Value.absent(),
      ),
    );
  }
}
