import 'package:flutter/foundation.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/deco/gas_switch/gas_segment_lookup.dart';

/// Replays a recorded depth trace on fresh engines so two gas schedules can be
/// compared without touching the analysis engine.
///
/// Interval loading mirrors BuhlmannAlgorithm.processProfileWithGasSegments
/// (split at every switch inside an interval, linear depth, average depth per
/// sub-interval); a parity test pins the two together. The replay restarts
/// from the dive start because DecoStatus does not store the GF-low anchor.
class TissueReplay {
  TissueReplay({
    required this.newEngine,
    required this.depths,
    required this.timestamps,
    required this.ascentPlan,
    this.startCompartments,
  });

  /// TTS is compared every this many seconds of dive time.
  static const int evaluationStrideSeconds = 30;

  final BuhlmannAlgorithm Function() newEngine;
  final List<double> depths;
  final List<int> timestamps;
  final AscentGasPlan ascentPlan;
  final List<TissueCompartment>? startCompartments;

  /// The engine after loading samples 1..[index] with [segments].
  @visibleForTesting
  BuhlmannAlgorithm replayThrough(List<ProfileGasSegment> segments, int index) {
    final engine = _seeded();
    for (var i = 1; i <= index; i++) {
      _loadInterval(engine, i, segments);
    }
    return engine;
  }

  /// Largest `TTS(actual) - TTS(counterfactual)` from [fromIndex] to the end
  /// of the dive, evaluated every [evaluationStrideSeconds] and at
  /// [mustEvaluateIndex]; floored at zero.
  ///
  /// The as-dived side comes either from [actualTts], the TTS the analysis
  /// already computed for every sample (the cheap path, used by the analyzer,
  /// and the very curve the diver sees), or by replaying [actual]. Pass
  /// exactly one.
  int peakTtsGap({
    List<ProfileGasSegment>? actual,
    List<int>? actualTts,
    required List<ProfileGasSegment> counterfactual,
    required int fromIndex,
    int? mustEvaluateIndex,
  }) {
    assert(
      (actual == null) != (actualTts == null),
      'pass exactly one of actual and actualTts',
    );
    assert(actualTts == null || actualTts.length == depths.length);
    final a = actual == null ? null : _seeded();
    final c = _seeded();
    var peak = 0;
    int? lastEvaluated;
    for (var i = 0; i < depths.length; i++) {
      if (i > 0) {
        if (a != null) _loadInterval(a, i, actual!);
        _loadInterval(c, i, counterfactual);
      }
      if (i < fromIndex) continue;
      final due =
          lastEvaluated == null ||
          timestamps[i] - lastEvaluated >= evaluationStrideSeconds ||
          i == mustEvaluateIndex;
      if (!due) continue;
      lastEvaluated = timestamps[i];
      final asDived = a == null ? actualTts![i] : _tts(a, i, actual!);
      final gap = asDived - _tts(c, i, counterfactual);
      if (gap > peak) peak = gap;
    }
    return peak;
  }

  BuhlmannAlgorithm _seeded() {
    final engine = newEngine();
    final start = startCompartments;
    if (start != null) engine.setCompartments(start);
    return engine;
  }

  int _tts(BuhlmannAlgorithm engine, int i, List<ProfileGasSegment> segments) {
    final gas = activeSegmentAt(segments, timestamps[i]);
    final scratch = newEngine()
      ..restoreState(
        engine.compartments,
        gfLowCeilingAnchor: engine.gfLowCeilingAnchor,
      );
    return scratch
        .getDecoStatus(
          currentDepth: depths[i],
          fN2: gas.fN2,
          fHe: gas.fHe,
          ascentGas: ascentPlan,
        )
        .ttsSeconds;
  }

  void _loadInterval(
    BuhlmannAlgorithm engine,
    int i,
    List<ProfileGasSegment> segments,
  ) {
    final start = timestamps[i - 1];
    final end = timestamps[i];
    final boundaries = <int>[
      start,
      for (final s in segments)
        if (s.startTimestamp > start && s.startTimestamp < end)
          s.startTimestamp,
      end,
    ];
    for (var b = 1; b < boundaries.length; b++) {
      final subStart = boundaries[b - 1];
      final subEnd = boundaries[b];
      final avgDepth = (_depthAt(i, subStart) + _depthAt(i, subEnd)) / 2.0;
      final gas = activeSegmentAt(segments, subStart);
      engine.calculateSegment(
        depthMeters: avgDepth,
        durationSeconds: subEnd - subStart,
        fN2: gas.fN2,
        fHe: gas.fHe,
      );
    }
  }

  double _depthAt(int i, int t) {
    final t0 = timestamps[i - 1];
    final t1 = timestamps[i];
    if (t1 == t0) return depths[i];
    return depths[i - 1] + (depths[i] - depths[i - 1]) * ((t - t0) / (t1 - t0));
  }
}
