import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/condition_trend.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/condition_trend_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/condition_trend_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/domain/trend_aggregation.dart';
import 'package:submersion/features/statistics/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const rebreather = EquipmentItem(
  id: 'r1',
  name: 'CCR',
  type: EquipmentType.rebreather,
);

List<TrendDataPoint> slotPoints(double base) => [
  for (var i = 0; i < 4; i++)
    TrendDataPoint(
      date: DateTime.utc(2026, 1, 1 + i),
      value: base - i,
      diveId: 'd$i',
    ),
];

final cellTrend = ConditionTrend(
  kind: ConditionTrendKind.cellGain,
  series: [
    ConditionTrendSeries(key: 'slot1', slot: 1, points: slotPoints(50)),
    ConditionTrendSeries(key: 'slot2', slot: 2, points: slotPoints(48)),
  ],
);

Widget host(
  ConditionTrend? trend, {
  ConditionTrendKind? kind,
  List<Override> extra = const [],
  MockSettingsNotifier? settings,
}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith((ref) => settings ?? MockSettingsNotifier()),
    conditionTrendProvider((
      equipmentId: 'r1',
      kind: kind,
    )).overrideWith((ref) async => trend),
    ...extra,
  ],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ConditionTrendCard(equipment: rebreather, kind: kind),
    ),
  ),
);

void main() {
  testWidgets('draws one secondary series per slot with a legend', (
    tester,
  ) async {
    await tester.pumpWidget(host(cellTrend));
    await tester.pumpAndSettle();
    expect(find.text('Cell output per dive'), findsOneWidget);
    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.points, isEmpty);
    expect(chart.secondarySeries, hasLength(2));
    expect(chart.highlightRange, isNull);
    expect(find.text('Cell 1'), findsOneWidget);
    expect(find.text('Cell 2'), findsOneWidget);
  });

  testWidgets('the cell axis stays in mV/bar for a psi diver', (tester) async {
    // Cell gain is read against oxygen partial pressure, which the app
    // shows in bar whatever the tank pressure unit.
    await tester.pumpWidget(
      host(
        cellTrend,
        settings: MockSettingsNotifier(
          const AppSettings(pressureUnit: PressureUnit.psi),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.yAxisLabel, 'mV/bar');
    expect(chart.secondarySeries.first.points.first.value, 50);
  });

  testWidgets('a cell keeps its slot colour whatever else is drawn', (
    tester,
  ) async {
    // The colour follows the slot, not the list position: a standalone
    // slot-2 cell, or a rebreather missing slot 1, must not borrow slot
    // 1's colour, and the legend must not reshuffle as series come and go.
    Future<Map<String, Color>> colours(ConditionTrend trend) async {
      // Unmount first: a ProviderScope cannot change its overrides in place.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(host(trend));
      await tester.pumpAndSettle();
      final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
      return {for (final s in chart.secondarySeries) s.label: s.color};
    }

    final both = await colours(cellTrend);
    final slot2Only = await colours(
      ConditionTrend(
        kind: ConditionTrendKind.cellGain,
        series: [
          ConditionTrendSeries(key: 'slot2', slot: 2, points: slotPoints(48)),
        ],
      ),
    );
    expect(slot2Only['Cell 2'], both['Cell 2']);
    expect(slot2Only['Cell 2'], isNot(both['Cell 1']));
  });

  testWidgets('a cell series with no slot is named by its position', (
    tester,
  ) async {
    // A legacy series without a slot must not read "Cell 0".
    await tester.pumpWidget(
      host(
        ConditionTrend(
          kind: ConditionTrendKind.cellGain,
          series: [ConditionTrendSeries(key: 'legacy', points: slotPoints(50))],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cell 1'), findsOneWidget);
    expect(find.text('Cell 0'), findsNothing);
  });

  EquipmentFinding declining({required int fromDay}) {
    final evidence = FindingEvidence(
      n: 2,
      windowStart: DateTime.utc(2026, 1, fromDay),
      windowEnd: DateTime.utc(2026, 1, fromDay + 1),
    );
    return EquipmentFinding(
      id: 'cf_r1_cellOutputDeclining_1',
      equipmentId: 'r1',
      ruleId: ConditionRuleId.cellOutputDeclining,
      severity: ConditionSeverity.caution,
      evidence: evidence,
      evidenceFingerprint: evidenceFingerprint(evidence),
      engineVersion: 1,
      createdAt: DateTime.utc(2026),
    );
  }

  List<Override> selecting(
    EquipmentFinding selected, {
    List<EquipmentFinding>? current,
  }) => [
    selectedConditionFindingProvider('r1').overrideWith((ref) => selected),
    equipmentConditionProvider(
      'r1',
    ).overrideWith((ref) async => current ?? [selected]),
  ];

  testWidgets('the selected finding shades its window', (tester) async {
    final finding = declining(fromDay: 2);
    await tester.pumpWidget(host(cellTrend, extra: selecting(finding)));
    await tester.pumpAndSettle();
    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.highlightRange, (
      start: DateTime.utc(2026, 1, 2),
      end: DateTime.utc(2026, 1, 3),
    ));
  });

  testWidgets('a hidden finding shades nothing', (tester) async {
    // With the engine switched off the findings card hides it, so the
    // chart must not keep shading its window.
    final settings = MockSettingsNotifier();
    await settings.setConditionEngineEnabled(false);
    await tester.pumpWidget(
      host(
        cellTrend,
        settings: settings,
        extra: selecting(declining(fromDay: 2)),
      ),
    );
    await tester.pumpAndSettle();
    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.highlightRange, isNull);
  });

  testWidgets('a recomputed finding shades its current window', (tester) async {
    // The selection holds a snapshot; the chart follows the finding as
    // it is now.
    await tester.pumpWidget(
      host(
        cellTrend,
        extra: selecting(
          declining(fromDay: 2),
          current: [declining(fromDay: 3)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.highlightRange?.start, DateTime.utc(2026, 1, 3));
  });

  testWidgets('a scrubber card titles and labels its series', (tester) async {
    await tester.pumpWidget(
      host(
        ConditionTrend(
          kind: ConditionTrendKind.scrubberMinutes,
          series: [
            ConditionTrendSeries(key: 'scrubber', points: slotPoints(120)),
          ],
        ),
        kind: ConditionTrendKind.scrubberMinutes,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Scrubber use per dive'), findsOneWidget);
    expect(find.text('Scrubber minutes'), findsOneWidget);
  });

  testWidgets('no trend renders no card', (tester) async {
    await tester.pumpWidget(host(null));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('an empty trend renders no card', (tester) async {
    await tester.pumpWidget(
      host(
        const ConditionTrend(
          kind: ConditionTrendKind.cellGain,
          series: [ConditionTrendSeries(key: 'slot1', slot: 1, points: [])],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
  });
}
