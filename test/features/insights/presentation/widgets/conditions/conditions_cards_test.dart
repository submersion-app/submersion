import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_stats.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_band_card.dart';
import 'package:submersion/features/insights/presentation/widgets/conditions/conditions_category_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #3118: the reusable condition cards hide when nothing is recorded
/// and say how many dives each chart is based on.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  const bands = BandStat(
    bands: [
      (lower: null, upper: 10.0, count: 1),
      (lower: 10.0, upper: null, count: 2),
    ],
    recorded: 3,
  );

  testWidgets('band card shows its bars and coverage line', (tester) async {
    await pump(
      tester,
      const ConditionsBandCard(
        title: 'Wind Speed',
        subtitle: 'sub',
        stat: bands,
        totalDives: 10,
        unitSymbol: 'km/h',
        barColor: Colors.blue,
      ),
    );
    expect(find.text('Wind Speed'), findsOneWidget);
    expect(find.text('<10'), findsOneWidget);
    expect(find.text('10+'), findsOneWidget);
    expect(find.text('Based on 3 of 10 dives'), findsOneWidget);
  });

  testWidgets('band card is hidden when nothing is recorded', (tester) async {
    await pump(
      tester,
      const ConditionsBandCard(
        title: 'Wind Speed',
        subtitle: 'sub',
        stat: BandStat(bands: [], recorded: 0),
        totalDives: 10,
        unitSymbol: 'km/h',
        barColor: Colors.blue,
      ),
    );
    expect(find.text('Wind Speed'), findsNothing);
  });

  testWidgets('coverage line uses the singular for one dive', (tester) async {
    await pump(
      tester,
      const ConditionsBandCard(
        title: 'Humidity',
        subtitle: 'sub',
        stat: BandStat(
          bands: [
            (lower: null, upper: 40.0, count: 1),
            (lower: 40.0, upper: null, count: 0),
          ],
          recorded: 1,
        ),
        totalDives: 1,
        unitSymbol: '%',
        barColor: Colors.blue,
      ),
    );
    expect(find.text('Based on 1 of 1 dive'), findsOneWidget);
  });

  testWidgets('category pie labels values and colors by value', (tester) async {
    await pump(
      tester,
      ConditionsCategoryCard<CloudCover>(
        title: 'Cloud Cover',
        subtitle: 'sub',
        stat: const CategoryStat(
          counts: [
            (value: CloudCover.clear, count: 3),
            (value: CloudCover.overcast, count: 1),
          ],
          recorded: 4,
        ),
        totalDives: 8,
        labelOf: (v) => v.name,
        kind: ConditionsChartKind.pie,
        colorOf: (v) => v == CloudCover.clear ? Colors.amber : Colors.grey,
      ),
    );
    final chart = tester.widget<PieChart>(find.byType(PieChart));
    expect(chart.data.sections.map((s) => s.title), ['75%', '25%']);
    expect(chart.data.sections.map((s) => s.color), [
      Colors.amber,
      Colors.grey,
    ]);
    expect(find.text('clear'), findsOneWidget);
    expect(find.text('Based on 4 of 8 dives'), findsOneWidget);
  });

  testWidgets('category bar card is hidden when nothing is recorded', (
    tester,
  ) async {
    await pump(
      tester,
      ConditionsCategoryCard<Precipitation>(
        title: 'Precipitation',
        subtitle: 'sub',
        stat: const CategoryStat(counts: [], recorded: 0),
        totalDives: 8,
        labelOf: (v) => v.name,
        kind: ConditionsChartKind.bar,
      ),
    );
    expect(find.text('Precipitation'), findsNothing);
  });

  testWidgets('category bar lists categories in the given order', (
    tester,
  ) async {
    await pump(
      tester,
      ConditionsCategoryCard<Precipitation>(
        title: 'Precipitation',
        subtitle: 'sub',
        stat: const CategoryStat(
          counts: [
            (value: Precipitation.none, count: 1),
            (value: Precipitation.rain, count: 3),
          ],
          recorded: 4,
        ),
        totalDives: 4,
        labelOf: (v) => v.name,
        kind: ConditionsChartKind.bar,
      ),
    );
    final none = tester.getTopLeft(find.text('none'));
    final rain = tester.getTopLeft(find.text('rain'));
    expect(none.dy, lessThan(rain.dy));
    expect(find.text('Based on 4 of 4 dives'), findsOneWidget);
  });
}
