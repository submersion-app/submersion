import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/domain/water_temp_band_metrics.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_conditions_page.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/statistics/presentation/widgets/stat_charts.dart';
import 'package:submersion/features/statistics/presentation/widgets/water_temp_band_metrics_table.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #1873: the water-temperature band card lists average SAC and
/// bottom time per band, each with the number of dives behind it.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  const celsiusBands = <WaterTempBandMetrics>[
    (
      lower: null,
      upper: 10,
      diveCount: 4,
      avgSac: null,
      sacDiveCount: 0,
      avgBottomMinutes: 38.2,
      bottomTimeDiveCount: 4,
    ),
    (
      lower: 10,
      upper: 18,
      diveCount: 0,
      avgSac: null,
      sacDiveCount: 0,
      avgBottomMinutes: null,
      bottomTimeDiveCount: 0,
    ),
    (
      lower: 18,
      upper: 24,
      diveCount: 20,
      avgSac: 1.14,
      sacDiveCount: 17,
      avgBottomMinutes: 51.6,
      bottomTimeDiveCount: 20,
    ),
    (
      lower: 24,
      upper: null,
      diveCount: 1,
      avgSac: 0.9,
      sacDiveCount: 1,
      avgBottomMinutes: 55.0,
      bottomTimeDiveCount: 1,
    ),
  ];

  Future<void> pumpPage(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
    required Future<List<WaterTempBandMetrics>> Function() metrics,
  }) async {
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          waterTempTrendProvider.overrideWith((ref) async => const []),
          temperatureByMonthProvider.overrideWith((ref) async => const []),
          waterTempBandDistributionProvider.overrideWith(
            (ref) async => const [
              (lower: null, upper: 10, count: 4),
              (lower: 10, upper: 18, count: 0),
              (lower: 18, upper: 24, count: 20),
              (lower: 24, upper: null, count: 1),
            ],
          ),
          waterTempBandMetricsProvider.overrideWith((ref) => metrics()),
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

  Finder table() => find.byType(WaterTempBandMetricsTable);

  Finder inTable(String text) =>
      find.descendant(of: table(), matching: find.text(text));

  testWidgets('lists every band with its dives and averages', (tester) async {
    await pumpPage(tester, metrics: () async => celsiusBands);

    for (final header in ['Band', 'Dives', 'Avg SAC', 'Avg bottom time']) {
      expect(inTable(header), findsOneWidget, reason: header);
    }
    for (final band in ['<10°C', '10-18°C', '18-24°C', '24+°C']) {
      expect(inTable(band), findsOneWidget, reason: band);
    }
    expect(inTable('1.1 bar/min'), findsOneWidget);
    expect(inTable('17 dives'), findsOneWidget);
    expect(inTable('52 min'), findsOneWidget);
    expect(inTable('38 min'), findsOneWidget);
  });

  testWidgets('shows a placeholder, not 0, for a band without data', (
    tester,
  ) async {
    await pumpPage(tester, metrics: () async => celsiusBands);

    // <10: no SAC. 10-18: no dives at all, so neither average.
    expect(inTable('--'), findsNWidgets(3));
    expect(inTable('0 bar/min'), findsNothing);
    expect(inTable('0 min'), findsNothing);
  });

  testWidgets('keeps the chart above the table', (tester) async {
    await pumpPage(tester, metrics: () async => celsiusBands);

    final chartTop = tester.getTopLeft(find.byType(CategoryBarChart)).dy;
    final tableTop = tester.getTopLeft(table()).dy;
    expect(tableTop, greaterThan(chartTop));
  });

  testWidgets('follows the RMV lane and the volume unit', (tester) async {
    await pumpPage(
      tester,
      settings: const AppSettings(
        gasConsumptionDisplay: GasConsumptionDisplay.rmv,
      ),
      metrics: () async => [
        (
          lower: 24,
          upper: null,
          diveCount: 3,
          avgSac: 14.26,
          sacDiveCount: 3,
          avgBottomMinutes: 45.0,
          bottomTimeDiveCount: 3,
        ),
      ],
    );

    expect(inTable('Avg RMV'), findsOneWidget);
    expect(inTable('Avg SAC'), findsNothing);
    expect(inTable('14.3 L/min'), findsOneWidget);
  });

  testWidgets('uses the imperial pressure and temperature units', (
    tester,
  ) async {
    await pumpPage(
      tester,
      settings: const AppSettings(
        pressureUnit: PressureUnit.psi,
        temperatureUnit: TemperatureUnit.fahrenheit,
        gasConsumptionDisplay: GasConsumptionDisplay.sac,
      ),
      metrics: () async => [
        (
          lower: 65,
          upper: 75,
          diveCount: 2,
          avgSac: 1.0,
          sacDiveCount: 2,
          avgBottomMinutes: 45.0,
          bottomTimeDiveCount: 2,
        ),
      ],
    );

    expect(inTable('65-75°F'), findsOneWidget);
    expect(inTable('15 psi/min'), findsOneWidget);
  });

  testWidgets('reads each row as one sentence to a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpPage(tester, metrics: () async => celsiusBands);

    expect(
      find.bySemanticsLabel(
        '18-24°C: 20 dives. Average SAC: 1.1 bar/min over 17 dives. '
        'Average bottom time: 52 min over 20 dives.',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        '10-18°C: 0 dives. Average SAC: no data. '
        'Average bottom time: no data.',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('an error in the averages leaves the chart in place', (
    tester,
  ) async {
    await pumpPage(tester, metrics: () async => throw StateError('boom'));

    expect(find.byType(CategoryBarChart), findsOneWidget);
    expect(find.text('Failed to load band averages'), findsOneWidget);
  });

  testWidgets('shows no table when no dive has a temperature', (tester) async {
    await pumpPage(tester, metrics: () async => const []);

    expect(find.text('Avg bottom time'), findsNothing);
  });
}
