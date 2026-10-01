import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/utils/sac_segments_availability.dart';

import '../../../../helpers/mock_providers.dart';

/// A dive whose cylinder was logged with only a start and an end pressure has
/// a whole-dive SAC but no per-segment one. The segment card vanished for it
/// while its section toggle stayed on (issue #2505); this predicate decides
/// when the card explains why instead.
void main() {
  const startEndOnly = DiveTank(
    id: 'tank',
    startPressure: 200.0,
    endPressure: 50.0,
    gasMix: GasMix(),
  );
  const noPressures = DiveTank(id: 'tank', gasMix: GasMix());
  const startOnly = DiveTank(
    id: 'tank',
    startPressure: 200.0,
    gasMix: GasMix(),
  );
  const noDrop = DiveTank(
    id: 'tank',
    startPressure: 200.0,
    endPressure: 200.0,
    gasMix: GasMix(),
  );

  Dive diveWith(List<DiveTank> tanks) =>
      createTestDiveWithBottomTime().copyWith(tanks: tanks);

  final noPressureAnalysis = ProfileAnalysis.empty();

  const segment = SacSegment(
    startTimestamp: 0,
    endTimestamp: 300,
    avgDepth: 18.0,
    minDepth: 0.0,
    maxDepth: 24.0,
    sacRate: 0.8,
    gasConsumed: 4.0,
    segmentationType: SacSegmentationType.timeInterval,
  );

  test('true when only start and end pressures were logged', () {
    expect(
      sacSegmentsLackRecordedPressure(
        noPressureAnalysis,
        diveWith(const [startEndOnly]),
      ),
      isTrue,
    );
  });

  test('true when any one cylinder has a usable start and end', () {
    expect(
      sacSegmentsLackRecordedPressure(
        noPressureAnalysis,
        diveWith(const [noPressures, startEndOnly]),
      ),
      isTrue,
    );
  });

  test('false while the analysis is still loading', () {
    expect(
      sacSegmentsLackRecordedPressure(null, diveWith(const [startEndOnly])),
      isFalse,
    );
  });

  test('false when the dive has segments to show', () {
    expect(
      sacSegmentsLackRecordedPressure(
        noPressureAnalysis.copyWith(sacSegments: const [segment]),
        diveWith(const [startEndOnly]),
      ),
      isFalse,
    );
  });

  test('false when pressure was recorded but produced no segment', () {
    // A SAC curve means a pressure series reached the analysis, so "only
    // start and end pressures" would be untrue.
    expect(
      sacSegmentsLackRecordedPressure(
        noPressureAnalysis.copyWith(sacCurve: const [0.0, 0.0]),
        diveWith(const [startEndOnly]),
      ),
      isFalse,
    );
  });

  test('false when no cylinder has any gas use to report', () {
    for (final tanks in const [
      <DiveTank>[],
      [noPressures],
      [startOnly],
      [noDrop],
    ]) {
      expect(
        sacSegmentsLackRecordedPressure(noPressureAnalysis, diveWith(tanks)),
        isFalse,
        reason: 'tanks: $tanks',
      );
    }
  });
}
