import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

/// An analysis keeps the times its per-sample curves were computed at, so a
/// view pairing them with a clock reads this analysis's times and never a
/// profile that has changed since (issue #4503, PR 4506 review).
void main() {
  final service = ProfileAnalysisService();
  const timestamps = [0, 30, 90, 150, 630];
  const depths = [0.0, 5.0, 20.0, 20.0, 0.0];

  test('an open-circuit analysis keeps one time per deco status', () {
    final analysis = service.analyze(
      diveId: 'd',
      timestamps: timestamps,
      depths: depths,
      diveMode: DiveMode.oc,
    );

    expect(analysis.sampleTimestamps, timestamps);
    expect(analysis.sampleTimestamps, hasLength(analysis.decoStatuses.length));
  });

  test('a gauge analysis keeps its times too', () {
    final analysis = service.analyze(
      diveId: 'd',
      timestamps: timestamps,
      depths: depths,
      diveMode: DiveMode.gauge,
    );

    expect(analysis.sampleTimestamps, timestamps);
  });

  test('an empty analysis has no times', () {
    expect(ProfileAnalysis.empty().sampleTimestamps, isEmpty);
  });
}
