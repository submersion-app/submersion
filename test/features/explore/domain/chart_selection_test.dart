import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/explore/domain/chart_selection.dart';
import 'package:submersion/features/explore/domain/dive_field_catalog.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

void main() {
  test('always starts with dives over time', () {
    final charts = selectCharts(
      numericFields: const [],
      resolvedEntityCounts: const {},
    );
    expect(charts.map((c) => c.kind), [ChartKind.divesOverTime]);
  });

  test(
    'adds one trend per numeric field in catalog order, capped at three',
    () {
      final charts = selectCharts(
        numericFields: const [
          ExploreDiveField.bottomTime,
          ExploreDiveField.depth,
          ExploreDiveField.waterTemp,
          ExploreDiveField.rating,
        ],
        resolvedEntityCounts: const {MentionKind.place: 3},
      );
      expect(charts.map((c) => c.kind), [
        ChartKind.divesOverTime,
        ChartKind.depthTrend,
        ChartKind.waterTempTrend,
      ]);
    },
  );

  test('entity counts appear only for kinds with several ids', () {
    final charts = selectCharts(
      numericFields: const [],
      resolvedEntityCounts: const {
        MentionKind.place: 3,
        MentionKind.species: 1,
      },
    );
    expect(charts, hasLength(2));
    expect(charts[1].kind, ChartKind.entityCounts);
    expect(charts[1].entityKind, MentionKind.place);
  });
}
