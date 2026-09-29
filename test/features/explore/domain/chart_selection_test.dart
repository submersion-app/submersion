import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/explore/domain/chart_selection.dart';
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
        numericFields: const ['bottomTime', 'depth', 'waterTemp', 'rating'],
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

  test('no count chart for a kind without a ranking query', () {
    // Tags, trips and computers have no ranking behind them; a chart titled
    // for them would be filled with site counts.
    for (final kind in [
      MentionKind.tag,
      MentionKind.trip,
      MentionKind.computer,
    ]) {
      final charts = selectCharts(
        numericFields: const [],
        resolvedEntityCounts: {kind: 3},
      );
      expect(charts.map((c) => c.kind), [
        ChartKind.divesOverTime,
      ], reason: kind.name);
    }
  });

  test('sites and places share one site-count chart', () {
    final charts = selectCharts(
      numericFields: const [],
      resolvedEntityCounts: const {MentionKind.site: 2, MentionKind.place: 3},
    );
    expect(charts.where((c) => c.kind == ChartKind.entityCounts), hasLength(1));
  });

  test('every ranked kind still gets its chart', () {
    for (final kind in [
      MentionKind.species,
      MentionKind.buddy,
      MentionKind.center,
      MentionKind.gear,
    ]) {
      final charts = selectCharts(
        numericFields: const [],
        resolvedEntityCounts: {kind: 2},
      );
      expect(charts.last.entityKind, kind, reason: kind.name);
    }
  });

  test('a SAC clause draws a SAC chart', () {
    expect(
      selectCharts(
        numericFields: const ['sac'],
        resolvedEntityCounts: const {},
      ),
      contains(const ChartRequest(ChartKind.sacTrend)),
    );
  });
}
