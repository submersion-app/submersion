import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/domain/water_temp_bands.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_conditions_page.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_charts.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #1827: the Conditions page shows dives per water-temperature band,
/// labelled in the diver's temperature unit.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  const title = 'Dives by Water Temperature';

  Future<void> pumpPage(
    WidgetTester tester, {
    required TemperatureUnit unit,
    required List<WaterTempBandCount> bands,
  }) async {
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(
        AppSettings(temperatureUnit: unit),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          waterTempTrendProvider.overrideWith((ref) async => const []),
          temperatureByMonthProvider.overrideWith((ref) async => const []),
          waterTempBandDistributionProvider.overrideWith((ref) async => bands),
        ].cast(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatisticsConditionsPage(embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder bandCard() => find.ancestor(
    of: find.text(title),
    matching: find.byType(StatSectionCard),
  );

  CategoryBarChart bandChart(WidgetTester tester) => tester.widget(
    find.descendant(of: bandCard(), matching: find.byType(CategoryBarChart)),
  );

  testWidgets('labels Celsius bands with the Celsius symbol', (tester) async {
    await pumpPage(
      tester,
      unit: TemperatureUnit.celsius,
      bands: const [
        (lower: null, upper: 10, count: 2),
        (lower: 10, upper: 18, count: 0),
        (lower: 18, upper: 24, count: 3),
        (lower: 24, upper: null, count: 1),
      ],
    );

    final chart = bandChart(tester);
    expect(chart.data, [
      (label: '<10', count: 2),
      (label: '10-18', count: 0),
      (label: '18-24', count: 3),
      (label: '24+', count: 1),
    ]);
    expect(chart.xAxisLabel, '°C');
  });

  testWidgets('labels Fahrenheit bands with the Fahrenheit symbol', (
    tester,
  ) async {
    await pumpPage(
      tester,
      unit: TemperatureUnit.fahrenheit,
      bands: const [
        (lower: null, upper: 50, count: 1),
        (lower: 50, upper: 65, count: 4),
        (lower: 65, upper: 75, count: 0),
        (lower: 75, upper: null, count: 2),
      ],
    );

    final chart = bandChart(tester);
    expect(chart.data.map((d) => d.label), ['<50', '50-65', '65-75', '75+']);
    expect(chart.xAxisLabel, '°F');
  });

  testWidgets('shows an empty state when no dive has a temperature', (
    tester,
  ) async {
    await pumpPage(tester, unit: TemperatureUnit.celsius, bands: const []);

    expect(
      find.descendant(
        of: bandCard(),
        matching: find.text('No water temperature data available'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bandCard(), matching: find.byType(CategoryBarChart)),
      findsNothing,
    );
  });
}
