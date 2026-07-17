import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

/// Runs the real profile analysis over a synthetic profile.
/// Default settings: air, GF 30/70, sea level.
ProfileAnalysis analyzeFixture({
  required List<double> depths,
  required List<int> timestamps,
}) {
  final service = ProfileAnalysisService();
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
