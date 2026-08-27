import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/core/deco/vpm_b_algorithm.dart';

/// VPM-B tissue state: gas loadings plus the crushing-pressure history the
/// ascent's Critical Volume Algorithm depends on.
///
/// Unlike Buhlmann (where the ceiling is a pure function of current tensions),
/// VPM-B's allowable gradients depend on the maximum crushing pressure each
/// compartment saw during descent. That history, the current He/N2 tensions,
/// and the accumulated run time (for nucleus regeneration) are the complete,
/// restorable state. Adjusted critical radii are constant for a single dive
/// (no repetitive-dive adjustment), so they are re-derived from settings.
class VpmBState extends TissueState {
  const VpmBState({
    required this.heliumPressure,
    required this.nitrogenPressure,
    required this.maxCrushingPressureHe,
    required this.maxCrushingPressureN2,
    required this.runTime,
  });

  final List<double> heliumPressure;
  final List<double> nitrogenPressure;
  final List<double> maxCrushingPressureHe;
  final List<double> maxCrushingPressureN2;

  /// Accumulated run time in minutes (drives nucleus regeneration).
  final double runTime;
}

/// Varying-Permeability Model (VPM-B): the second [DecoModel], slotting in
/// beside [BuhlmannGf].
///
/// Wraps the golden-validated [VpmBAlgorithm]. Conservatism +0..+4 maps to the
/// critical nucleus radii (Subsurface-equivalent). Internally the algorithm
/// works in the reference's sea-level msw convention; this wrapper treats depth
/// in meters as msw (matching the golden vectors). Altitude/water-density
/// variation is not yet modeled for VPM-B (a separate altitude algorithm in the
/// reference); the [DiveEnvironment] seam that Buhlmann uses is intentionally
/// absent here rather than accepted-and-ignored.
class VpmB implements DecoModel {
  VpmB({
    int conservatism = 3,
    this.policy = const SchedulePolicy(),
    VpmBSettings? settings,
  }) : _algo = VpmBAlgorithm(
         settings ?? VpmBSettings.forConservatism(conservatism),
       );

  final SchedulePolicy policy;
  final VpmBAlgorithm _algo;

  /// Surface NDL sentinel (seconds); mirrors Buhlmann's "effectively
  /// unlimited" surface value.
  static const int _surfaceNdl = 999 * 60;

  VpmBState _capture() => VpmBState(
    heliumPressure: List<double>.of(_algo.heliumPressure),
    nitrogenPressure: List<double>.of(_algo.nitrogenPressure),
    maxCrushingPressureHe: List<double>.of(_algo.maxCrushingPressureHe),
    maxCrushingPressureN2: List<double>.of(_algo.maxCrushingPressureN2),
    runTime: _algo.runTime,
  );

  void _load(VpmBState state) {
    _algo.loadState(
      heliumPressure: state.heliumPressure,
      nitrogenPressure: state.nitrogenPressure,
      maxCrushingPressureHe: state.maxCrushingPressureHe,
      maxCrushingPressureN2: state.maxCrushingPressureN2,
      runTime: state.runTime,
    );
  }

  /// Open-circuit mix -> VPM gas is exact. CCR/SCR are approximated by the
  /// loop's effective inert fractions at [meanDepthMeters]: VPM-B is formulated
  /// for open circuit, so loop support is mean-depth-anchored and approximate.
  VpmGasMix _gasFromBreathing(BreathingConfig breathing, double meanDepth) {
    if (breathing is OpenCircuit) {
      return VpmGasMix(fN2: breathing.fN2, fHe: breathing.fHe);
    }
    // msw ambient (baro = 10 msw), then bar for the config (1 bar per 10 msw).
    final ambientMsw = meanDepth + VpmBAlgorithm.barometricPressure;
    final ambientBar = ambientMsw / 10.0;
    final inspired = breathing.inspiredAt(ambientBar);
    final alvMsw = ambientMsw - VpmBAlgorithm.waterVaporPressure;
    if (alvMsw <= 0) return const VpmGasMix(fN2: 0.0, fHe: 0.0);
    // Partial pressures are in bar; * 10 converts to the msw the algorithm
    // uses so mean-depth inert loading is consistent.
    final fN2 = (inspired.pN2 * 10.0) / alvMsw;
    final fHe = (inspired.pHe * 10.0) / alvMsw;
    return VpmGasMix(fN2: fN2, fHe: fHe);
  }

  /// Build the algorithm's gas-mix table and deep-to-shallow ascent-change
  /// list from an [AscentGasPlan]. Change 0 is the deepest (at [currentDepth]);
  /// each gas switch depth from the plan becomes a shallower change.
  (List<VpmGasMix>, List<VpmAscentChange>) _buildAscent(
    double currentDepth,
    AscentGasPlan gases,
  ) {
    final rate = -policy.ascentRate; // negative msw/min for ascent
    final step = policy.stopIncrement;
    final mixes = <VpmGasMix>[];
    final mixIndex = <String, int>{};

    int mixNumberFor(AscentGas g) {
      final key = '${g.fN2}/${g.fHe}';
      final existing = mixIndex[key];
      if (existing != null) return existing;
      mixes.add(VpmGasMix(fN2: g.fN2, fHe: g.fHe));
      final n = mixes.length; // 1-based
      mixIndex[key] = n;
      return n;
    }

    final changes = <VpmAscentChange>[
      VpmAscentChange(
        startingDepth: currentDepth,
        mixNumber: mixNumberFor(gases.gasForDepth(currentDepth)),
        rate: rate,
        stepSize: step,
      ),
    ];
    for (final s in gases.switchDepthsBetween(currentDepth, 0)) {
      changes.add(
        VpmAscentChange(
          startingDepth: s,
          mixNumber: mixNumberFor(gases.gasForDepth(s)),
          rate: rate,
          stepSize: step,
        ),
      );
    }
    return (mixes, changes);
  }

  bool _hasDecoObligation(VpmBState state, double depth, VpmGasMix gas) {
    _load(state);
    final stops = _algo.runAscent(
      [gas],
      [
        VpmAscentChange(
          startingDepth: depth,
          mixNumber: 1,
          rate: -policy.ascentRate,
          stepSize: policy.stopIncrement,
        ),
      ],
    );
    return stops.isNotEmpty;
  }

  VpmBState _applyConstantMinutes(
    VpmBState state,
    double depth,
    int minutes,
    VpmGasMix gas,
  ) {
    _load(state);
    _algo.applyConstantDepth(depth, _algo.runTime + minutes, gas);
    return _capture();
  }

  @override
  TissueState initial() {
    _algo.initializeToSurface();
    return _capture();
  }

  @override
  TissueState applySegment(
    TissueState state,
    DecoSegment segment,
    BreathingConfig breathing,
  ) {
    _load(state as VpmBState);
    final meanDepth = (segment.startDepth + segment.endDepth) / 2.0;
    final gas = _gasFromBreathing(breathing, meanDepth);
    final durationMin = segment.durationSeconds / 60.0;
    if (segment.startDepth == segment.endDepth) {
      _algo.applyConstantDepth(
        segment.startDepth,
        _algo.runTime + durationMin,
        gas,
      );
    } else {
      final rate = (segment.endDepth - segment.startDepth) / durationMin;
      _algo.applyDepthChange(segment.startDepth, segment.endDepth, rate, gas);
    }
    return _capture();
  }

  @override
  double ceilingMeters(TissueState state, {double currentDepth = 0}) {
    _load(state as VpmBState);
    return _algo.ascentCeilingDepthMeters();
  }

  @override
  int ndlSeconds(
    TissueState state, {
    required double depthMeters,
    required BreathingConfig breathing,
  }) {
    if (depthMeters <= 0) return _surfaceNdl;
    final gas = _gasFromBreathing(breathing, depthMeters);
    if (_hasDecoObligation(state as VpmBState, depthMeters, gas)) return -1;

    // Search the longest additional bottom time that still clears to the
    // surface. VPM-B has no closed-form NDL, so this scans at 1-minute
    // resolution (bounded); it is the expensive path and is not part of the
    // golden-validated contract (only schedule() is).
    const stepMin = 1;
    const capMin = 300;
    var current = state;
    for (var t = stepMin; t <= capMin; t += stepMin) {
      current = _applyConstantMinutes(current, depthMeters, stepMin, gas);
      if (_hasDecoObligation(current, depthMeters, gas)) {
        return (t - stepMin) * 60;
      }
    }
    return capMin * 60;
  }

  @override
  DecoSchedule schedule(
    TissueState state, {
    required double currentDepth,
    required AscentGasPlan gases,
  }) {
    if (currentDepth <= 0) {
      return const DecoSchedule(stops: [], ttsSeconds: 0);
    }
    _load(state as VpmBState);
    final (mixes, changes) = _buildAscent(currentDepth, gases);
    final vpmStops = _algo.runAscent(mixes, changes);

    final stops = <DecoStop>[
      for (final s in vpmStops)
        DecoStop(
          depthMeters: s.depth.toDouble(),
          durationSeconds: s.time * 60,
          isDeepStop: s.depth > 9,
        ),
    ];

    // TTS: ascent travel (currentDepth at the ascent rate) plus total stop
    // time. VPM-B's reference does not emit a TTS; this is the standard
    // travel-plus-stops estimate used for display.
    final travelMin = currentDepth / policy.ascentRate;
    final stopMin = vpmStops.fold<int>(0, (a, s) => a + s.time);
    final tts = ((travelMin + stopMin) * 60).round();
    return DecoSchedule(stops: stops, ttsSeconds: tts);
  }
}
