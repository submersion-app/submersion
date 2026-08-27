import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_position.dart';

/// Raw (metric, unformatted) instrument values at one review position.
class InstrumentSample {
  final int runtimeSeconds;
  final double? depthMeters;
  final double? temperatureCelsius;
  final int? ndlSeconds;
  final double? ceilingMeters;
  final int? ttsSeconds;
  final Map<String, double> tankPressuresBar;
  final double? ppO2Bar;
  final double? gfPercent;
  final double? cnsPercent;
  final double? sacRate;
  final int? heartRateBpm;
  final double? ascentRateMetersPerMin;
  final bool inDeco;

  const InstrumentSample({
    required this.runtimeSeconds,
    this.depthMeters,
    this.temperatureCelsius,
    this.ndlSeconds,
    this.ceilingMeters,
    this.ttsSeconds,
    this.tankPressuresBar = const {},
    this.ppO2Bar,
    this.gfPercent,
    this.cnsPercent,
    this.sacRate,
    this.heartRateBpm,
    this.ascentRateMetersPerMin,
    this.inDeco = false,
  });
}

/// Resolves instrument values at [timestamp] (dive-seconds).
///
/// Consumed by the fullscreen profile readout and by the Perdix media
/// overlay, which resolves a sample per video frame.
InstrumentSample resolveSample({
  /// The profile the analysis curves were computed over (the active source's
  /// rendered profile). Curve values are read by INDEX, so passing any other
  /// array (e.g. dive.profile when a different source is active, or when the
  /// sources sample at different rates) reads wrong values where the arrays
  /// diverge and null past the shorter one's end.
  required List<DiveProfilePoint> profile,
  ProfileAnalysis? analysis,
  Map<String, List<TankPressurePoint>>? tankPressures,
  required int timestamp,
}) {
  final index = indexForTimestamp(profile, timestamp);
  if (index == null) {
    return InstrumentSample(runtimeSeconds: timestamp);
  }
  final point = profile[index];

  T? curveAt<T>(List<T>? curve) =>
      (curve != null && index < curve.length) ? curve[index] : null;

  return InstrumentSample(
    runtimeSeconds: point.timestamp,
    depthMeters: point.depth,
    temperatureCelsius: point.temperature,
    ndlSeconds: curveAt(analysis?.ndlCurve) ?? point.ndl,
    ceilingMeters: curveAt(analysis?.ceilingCurve) ?? point.ceiling,
    ttsSeconds: curveAt(analysis?.ttsCurve) ?? point.tts,
    tankPressuresBar: {
      if (tankPressures != null)
        for (final entry in tankPressures.entries)
          entry.key: ?pressureAtTimestamp(entry.value, timestamp),
    },
    ppO2Bar: curveAt(analysis?.ppO2Curve) ?? point.ppO2,
    gfPercent: curveAt(analysis?.gfCurve),
    cnsPercent: curveAt(analysis?.cnsCurve) ?? point.cns,
    sacRate: curveAt(analysis?.smoothedSacCurve),
    heartRateBpm: point.heartRate,
    ascentRateMetersPerMin:
        curveAt(analysis?.ascentRates)?.rateMetersPerMin ?? point.ascentRate,
    inDeco: point.decoType == 2,
  );
}
