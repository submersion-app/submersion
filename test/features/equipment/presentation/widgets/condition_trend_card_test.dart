import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/condition_trend.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/condition_trend_providers.dart';
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
}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
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

  testWidgets('the selected finding shades its window', (tester) async {
    final evidence = FindingEvidence(
      n: 2,
      windowStart: DateTime.utc(2026, 1, 2),
      windowEnd: DateTime.utc(2026, 1, 3),
    );
    final finding = EquipmentFinding(
      id: 'cf_r1_cellOutputDeclining_1',
      equipmentId: 'r1',
      ruleId: ConditionRuleId.cellOutputDeclining,
      severity: ConditionSeverity.caution,
      evidence: evidence,
      evidenceFingerprint: evidenceFingerprint(evidence),
      engineVersion: 1,
      createdAt: DateTime.utc(2026),
    );
    await tester.pumpWidget(
      host(
        cellTrend,
        extra: [
          selectedConditionFindingProvider('r1').overrideWith((ref) => finding),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final chart = tester.widget<DiveTrendChart>(find.byType(DiveTrendChart));
    expect(chart.highlightRange, (
      start: DateTime.utc(2026, 1, 2),
      end: DateTime.utc(2026, 1, 3),
    ));
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
