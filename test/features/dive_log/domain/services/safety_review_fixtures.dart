import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

/// Runs the real profile analysis over a synthetic profile.
/// Default settings: air, GF 30/70, sea level.
///
/// [ascentRateWarning] / [ascentRateCritical] mirror the diver's configurable
/// ascent-rate alarm thresholds; they let tests prove the safety rule ignores
/// them in favour of its own fixed design thresholds.
ProfileAnalysis analyzeFixture({
  required List<double> depths,
  required List<int> timestamps,
  double ascentRateWarning = 9.0,
  double ascentRateCritical = 12.0,
}) {
  final service = ProfileAnalysisService(
    ascentRateWarning: ascentRateWarning,
    ascentRateCritical: ascentRateCritical,
  );
  return service.analyze(
    diveId: 'fixture-dive',
    depths: depths,
    timestamps: timestamps,
  );
}

/// Builds (depths, timestamps) by concatenating linear segments.
/// Each segment is (targetDepth, durationSeconds); sampling every 10 s.
({List<double> depths, List<int> timestamps}) buildProfile(
  List<(double, int)> segments,
) {
  final depths = <double>[0];
  final timestamps = <int>[0];
  var t = 0;
  var d = 0.0;
  for (final (target, duration) in segments) {
    final steps = duration ~/ 10;
    for (var i = 1; i <= steps; i++) {
      t += 10;
      depths.add(d + (target - d) * i / steps);
      timestamps.add(t);
    }
    d = target;
  }
  return (depths: depths, timestamps: timestamps);
}

/// 18 m for 20 min, slow ascent with a 3-min stop at 5 m. No findings expected.
({List<double> depths, List<int> timestamps}) cleanDiveProfile() =>
    buildProfile([
      (18, 120), // descend to 18 m over 2 min
      (18, 1200), // 20 min bottom
      (5, 160), // ascend to 5 m at ~4.9 m/min
      (5, 180), // 3-min safety stop
      (0, 90), // slow final ascent (~3.3 m/min)
    ]);

/// Same dive but the ascent from 18 m runs at 18 m/min (rapid, critical).
({List<double> depths, List<int> timestamps}) rapidAscentProfile() =>
    buildProfile([
      (18, 120),
      (18, 1200),
      (0, 60), // 18 m in 60 s = 18 m/min, straight to surface
    ]);

/// 45 m for 25 min builds a real deco obligation, then a direct 9 m/min
/// ascent to the surface blows through every required stop.
({List<double> depths, List<int> timestamps}) missedDecoStopProfile() =>
    buildProfile([
      (45, 180), // descend to 45 m over 3 min
      (45, 1500), // 25 min bottom time on air
      (0, 300), // straight up at 9 m/min, no stops
    ]);

/// 18 m for 20 min (no-deco even at GF 30/70), then a steady ~7.7 m/min
/// ascent straight to the surface with no safety stop. The rate stays under
/// the 9 m/min warning threshold so only the omitted stop should flag.
/// (25 m for 15 min was tried first but enters deco at GF 30/70.)
({List<double> depths, List<int> timestamps}) omittedSafetyStopProfile() =>
    buildProfile([
      (18, 120),
      (18, 1200),
      (0, 140), // ~7.7 m/min direct ascent
    ]);

/// 20 m bottom with three 6 m up-and-back excursions (20 -> 14 -> 20),
/// then a normal slow ascent with safety stop.
({List<double> depths, List<int> timestamps}) sawtoothProfile() =>
    buildProfile([
      (20, 120),
      (20, 300),
      (14, 90), (20, 90), // tooth 1
      (20, 120),
      (14, 90), (20, 90), // tooth 2
      (20, 120),
      (14, 90), (20, 90), // tooth 3
      (20, 120),
      (5, 190), // slow ascent
      (5, 180), // safety stop
      (0, 90),
    ]);
