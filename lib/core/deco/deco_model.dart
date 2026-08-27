import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/deco/schedule_policy.dart';

/// Model-opaque tissue state. Each [DecoModel] defines its own concrete
/// state (Buhlmann: compartment tensions; a future VPM-B: bubble
/// parameters). Callers treat it as a token: obtain it from the model,
/// hand it back to the model.
abstract class TissueState {
  const TissueState();
}

/// Buhlmann ZH-L16C state: 16 compartments plus the GF-low ceiling anchor.
class BuhlmannState extends TissueState {
  const BuhlmannState({
    required this.compartments,
    this.gfLowCeilingAnchor = 0.0,
  });

  final List<TissueCompartment> compartments;
  final double gfLowCeilingAnchor;
}

/// One constant-or-linear depth leg of a dive.
class DecoSegment {
  const DecoSegment({
    required this.startDepth,
    required this.endDepth,
    required this.durationSeconds,
  });

  final double startDepth;
  final double endDepth;
  final int durationSeconds;
}

/// A computed decompression schedule.
class DecoSchedule {
  const DecoSchedule({required this.stops, required this.ttsSeconds});

  final List<DecoStop> stops;
  final int ttsSeconds;
}

/// A decompression model: the seam where VPM-B slots in beside Buhlmann.
///
/// Implementations are PURE with respect to [TissueState]: methods never
/// mutate the state passed in; [applySegment] returns a new state.
abstract class DecoModel {
  /// Surface-equilibrated state for this model's environment.
  TissueState initial();

  /// State after breathing [breathing] over [segment].
  TissueState applySegment(
    TissueState state,
    DecoSegment segment,
    BreathingConfig breathing,
  );

  /// Current ceiling in meters (0 = clear to surface).
  double ceilingMeters(TissueState state, {double currentDepth = 0});

  /// No-deco limit in seconds at [depthMeters] on [breathing];
  /// -1 when already in deco.
  int ndlSeconds(
    TissueState state, {
    required double depthMeters,
    required BreathingConfig breathing,
  });

  /// Full deco schedule from [currentDepth] ascending on [gases].
  DecoSchedule schedule(
    TissueState state, {
    required double currentDepth,
    required AscentGasPlan gases,
  });
}

/// Buhlmann ZH-L16C with gradient factors, wrapping [BuhlmannAlgorithm].
class BuhlmannGf implements DecoModel {
  BuhlmannGf({
    double gfLow = 0.30,
    double gfHigh = 0.70,
    DiveEnvironment environment = DiveEnvironment.standard,
    this.policy = const SchedulePolicy(),
  }) : _algorithm = BuhlmannAlgorithm(
         gfLow: gfLow,
         gfHigh: gfHigh,
         lastStopDepth: policy.lastStopDepth,
         stopIncrement: policy.stopIncrement,
         ascentRate: policy.ascentRate,
         environment: environment,
       );

  final SchedulePolicy policy;
  final BuhlmannAlgorithm _algorithm;

  void _restore(TissueState state) {
    final s = state as BuhlmannState;
    _algorithm.restoreState(
      s.compartments,
      gfLowCeilingAnchor: s.gfLowCeilingAnchor,
    );
  }

  BuhlmannState _capture() => BuhlmannState(
    compartments: _algorithm.compartments,
    gfLowCeilingAnchor: _algorithm.gfLowCeilingAnchor,
  );

  @override
  TissueState initial() {
    _algorithm.reset();
    return _capture();
  }

  @override
  TissueState applySegment(
    TissueState state,
    DecoSegment segment,
    BreathingConfig breathing,
  ) {
    _restore(state);
    final avgDepth = (segment.startDepth + segment.endDepth) / 2.0;
    _algorithm.calculateSegment(
      depthMeters: avgDepth,
      durationSeconds: segment.durationSeconds,
      breathing: breathing,
    );
    return _capture();
  }

  @override
  double ceilingMeters(TissueState state, {double currentDepth = 0}) {
    _restore(state);
    return _algorithm.calculateCeiling(currentDepth: currentDepth);
  }

  @override
  int ndlSeconds(
    TissueState state, {
    required double depthMeters,
    required BreathingConfig breathing,
  }) {
    _restore(state);
    return _algorithm.calculateNdl(
      depthMeters: depthMeters,
      breathing: breathing,
    );
  }

  @override
  DecoSchedule schedule(
    TissueState state, {
    required double currentDepth,
    required AscentGasPlan gases,
  }) {
    _restore(state);
    final stops = _algorithm.calculateDecoSchedule(
      currentDepth: currentDepth,
      ascentGas: gases,
      policy: policy,
    );
    _restore(state);
    final tts = _algorithm.calculateTts(
      currentDepth: currentDepth,
      ascentGas: gases,
      policy: policy,
    );
    return DecoSchedule(stops: stops, ttsSeconds: tts);
  }
}
