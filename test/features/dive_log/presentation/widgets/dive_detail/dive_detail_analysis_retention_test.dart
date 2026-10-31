import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_analysis_retention.dart';

void main() {
  const sourceA = (diveId: 'dive-1', sourceId: 'source-a');
  const sourceB = (diveId: 'dive-1', sourceId: 'source-b');
  const primary = (diveId: 'dive-1', sourceId: null);
  const otherDive = (diveId: 'dive-2', sourceId: 'source-a');

  final analysis = ProfileAnalysis.empty();

  test('the deco panel answers only for the dive and source it came from', () {
    final retention = DiveDetailAnalysisRetention()
      ..retainDecoPanel(sourceA, analysis);

    expect(retention.decoPanelFor(sourceA), same(analysis));
    expect(retention.decoPanelFor(sourceB), isNull);
    expect(retention.decoPanelFor(primary), isNull);
    expect(retention.decoPanelFor(otherDive), isNull);
  });

  test('SAC segments answer only for the dive and source they came from', () {
    final retention = DiveDetailAnalysisRetention()
      ..retainSacSegments(sourceA, analysis);

    expect(retention.sacSegmentsFor(sourceA), same(analysis));
    expect(retention.sacSegmentsFor(sourceB), isNull);
    expect(retention.sacSegmentsFor(primary), isNull);
    expect(retention.sacSegmentsFor(otherDive), isNull);
  });

  test('the two kinds of analysis are kept apart', () {
    final retention = DiveDetailAnalysisRetention()
      ..retainDecoPanel(sourceA, analysis);

    expect(retention.sacSegmentsFor(sourceA), isNull);
  });
}
