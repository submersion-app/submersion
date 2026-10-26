import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

/// Issue #3673: a rebreather's cylinders do not drain with the diver's
/// breathing, so a CCR or SCR dive has no SAC curve and no SAC segments,
/// matching the dive overview, which shows no SAC for it.
void main() {
  late ProfileAnalysisService service;

  setUp(() {
    service = ProfileAnalysisService(gfLow: 1.0, gfHigh: 1.0);
  });

  /// 15 minutes at 20 m, sampled every 10 s, draining 3 bar/min.
  final timestamps = List<int>.generate(15 * 6 + 1, (i) => i * 10);
  final depths = List<double>.filled(timestamps.length, 20.0);
  final pressures = timestamps.map((t) => 230.0 - 3.0 * t / 60).toList();

  ProfileAnalysis analyze(DiveMode mode) => service.analyze(
    diveId: 'd',
    depths: depths,
    timestamps: timestamps,
    pressures: pressures,
    diveMode: mode,
  );

  test('an open-circuit dive gets a SAC curve and segments', () {
    final result = analyze(DiveMode.oc);
    expect(result.sacCurve, isNotNull);
    expect(result.smoothedSacCurve, isNotNull);
    expect(result.sacSegments, isNotEmpty);
  });

  for (final mode in [DiveMode.ccr, DiveMode.scr]) {
    test('a ${mode.name} dive gets no SAC curve and no segments', () {
      final result = analyze(mode);
      expect(result.sacCurve, isNull);
      expect(result.smoothedSacCurve, isNull);
      expect(result.sacSegments, isNull);
    });
  }
}
