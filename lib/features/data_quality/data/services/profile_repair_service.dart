import 'dart:math' as math;

import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
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
  static List<domain.DiveProfilePoint> despike(
    List<domain.DiveProfilePoint> points,
  ) {
    if (points.length < 3) return List.of(points);
    final out = List.of(points);
    for (var i = 1; i + 1 < out.length; i++) {
      final dt1 = out[i].timestamp - out[i - 1].timestamp;
      final dt2 = out[i + 1].timestamp - out[i].timestamp;
      if (dt1 <= 0 || dt2 <= 0) continue;
      final r1 = (out[i].depth - out[i - 1].depth) / dt1;
      final r2 = (out[i + 1].depth - out[i].depth) / dt2;
      if (r1.abs() > QualityThresholds.spikeRateMetersPerSecond &&
          r2.abs() > QualityThresholds.spikeRateMetersPerSecond &&
          r1.sign != r2.sign) {
        final span = out[i + 1].timestamp - out[i - 1].timestamp;
        final frac = span > 0
            ? (out[i].timestamp - out[i - 1].timestamp) / span
            : 0.5;
        out[i] = out[i].copyWith(
          depth:
              out[i - 1].depth + (out[i + 1].depth - out[i - 1].depth) * frac,
        );
      }
    }
    return out;
  }

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
      if (gap <= threshold || gap > QualityThresholds.gapFillMaxSeconds) {
        continue;
      }
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

  /// Clamp single-sample temperature jumps beyond
  /// QualityThresholds.tempJumpPerSampleC by neighbor interpolation.
  /// Touches ONLY the temperature channel.
  static List<domain.DiveProfilePoint> smoothTemperature(
    List<domain.DiveProfilePoint> points,
  ) {
    if (points.length < 3) return List.of(points);
    final out = List.of(points);
    for (var i = 1; i + 1 < out.length; i++) {
      final a = out[i - 1].temperature;
      final b = out[i].temperature;
      final c = out[i + 1].temperature;
      if (a == null || b == null || c == null) continue;
      if ((b - a).abs() > QualityThresholds.tempJumpPerSampleC &&
          (c - b).abs() > QualityThresholds.tempJumpPerSampleC &&
          (b - a).sign != (c - b).sign) {
        out[i] = out[i].copyWith(temperature: (a + c) / 2);
      }
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
              temperature: kelvinScale
                  ? p.temperature! - 273.15
                  : (p.temperature! - 32) * 5 / 9,
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
