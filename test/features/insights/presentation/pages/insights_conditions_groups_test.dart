import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/domain/conditions/conditions_row.dart';
import 'package:submersion/features/insights/domain/trend_aggregation.dart';
import 'package:submersion/features/insights/presentation/pages/insights_conditions_page.dart';
import 'package:submersion/features/insights/presentation/providers/conditions_stats_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/providers/trend_chart_settings_provider.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_chart_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Issue #3118: the Conditions tab is grouped, the new weather groups sit
/// between Water and Site & Access, and a temperature trend's per-year rate
/// is a difference.
void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    List<ConditionsRow> rows = const [],
    bool rowsFail = false,
    MockSettingsNotifier? settings,
  }) async {
    tester.view.physicalSize = const Size(1200, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final base = await getBaseOverrides(settingsNotifier: settings);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          visibilityDistributionProvider.overrideWith((ref) async => const []),
          waterTypeDistributionProvider.overrideWith((ref) async => const []),
          siteTypeDistributionProvider.overrideWith((ref) async => const []),
          entryMethodDistributionProvider.overrideWith((ref) async => const []),
          waterTempTrendProvider.overrideWith(
            (ref) async => [
              TrendDataPoint(date: DateTime.utc(2024), value: 20, diveId: 'a'),
              TrendDataPoint(date: DateTime.utc(2026), value: 21, diveId: 'b'),
            ],
          ),
          temperatureByMonthProvider.overrideWith((ref) async => const []),
          waterTempBandDistributionProvider.overrideWith(
            (ref) async => const [],
          ),
          waterTempBandMetricsProvider.overrideWith((ref) async => const []),
          conditionsRowsProvider.overrideWith(
            (ref) async => rowsFail ? throw StateError('boom') : rows,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: InsightsConditionsPage(embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double topOf(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  testWidgets('existing cards sit under the Water and Site & Access headers', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Site & Access'), findsOneWidget);
    expect(
      topOf(tester, 'Water'),
      lessThan(topOf(tester, 'Visibility Distribution')),
    );
    expect(
      topOf(tester, 'Site & Access'),
      lessThan(topOf(tester, 'Entry Method')),
    );
    expect(
      topOf(tester, 'Dives by Water Temperature'),
      lessThan(topOf(tester, 'Site & Access')),
    );
  });

  testWidgets('weather groups sit between Water and Site & Access', (
    tester,
  ) async {
    await pumpPage(
      tester,
      rows: [
        ConditionsRow(
          diveId: 'a',
          dateTime: DateTime.utc(2026, 1, 1),
          cloudCover: CloudCover.clear,
          currentStrength: CurrentStrength.none,
        ),
      ],
    );
    final weather = topOf(tester, 'Surface & Weather');
    final movement = topOf(tester, 'Water Movement');
    expect(topOf(tester, 'Dives by Water Temperature'), lessThan(weather));
    expect(weather, lessThan(movement));
    expect(movement, lessThan(topOf(tester, 'Site & Access')));
  });

  testWidgets('water temperature rate in F is a difference, not a reading', (
    tester,
  ) async {
    final settings = MockSettingsNotifier();
    await settings.setTemperatureUnit(TemperatureUnit.fahrenheit);
    await pumpPage(tester, settings: settings);
    final section = tester.widget<TrendChartSection>(
      find.byWidgetPredicate(
        (w) => w is TrendChartSection && w.chartId == TrendChartIds.waterTemp,
      ),
    );
    // 1 C per year is 1.8 F per year, never 33.8 F.
    expect(section.rateFormatter!(1), '1.8°F');
  });

  testWidgets('a failed conditions query leaves the existing cards alone', (
    tester,
  ) async {
    await pumpPage(tester, rowsFail: true);
    expect(find.text('Visibility Distribution'), findsOneWidget);
    expect(find.text('Dives by Water Temperature'), findsOneWidget);
    expect(find.text('Entry Method'), findsOneWidget);
    expect(
      find.text('Failed to load weather and conditions data'),
      findsNWidgets(2),
    );
  });
}
