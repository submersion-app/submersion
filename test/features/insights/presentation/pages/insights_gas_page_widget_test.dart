import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/presentation/providers/insights_focus_providers.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/insights/presentation/pages/insights_gas_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_gas_lane_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Under Both the gas page carries a SAC | RMV control that drives every
/// section; a single-lane preference shows no control (spec D9).
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<void> pumpPage(WidgetTester tester, AppSettings settings) async {
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: InsightsGasPage(embedded: true)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  final chip = find.byType(SegmentedButton<GasConsumptionLane>);

  testWidgets('both shows the lane control seeded on SAC', (tester) async {
    await pumpPage(tester, const AppSettings());

    expect(chip, findsOneWidget);
    expect(find.text('Gas consumption trend'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(InsightsGasPage)),
    );
    expect(container.read(insightsGasLaneProvider), GasConsumptionLane.sac);

    await tester.tap(find.descendant(of: chip, matching: find.text('RMV')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(container.read(insightsGasLaneProvider), GasConsumptionLane.rmv);
  });

  testWidgets('a single-lane preference shows no control', (tester) async {
    await pumpPage(
      tester,
      const AppSettings(gasConsumptionDisplay: GasConsumptionDisplay.rmv),
    );
    expect(chip, findsNothing);
  });

  testWidgets('the consumption trend renders as a per-dive chart', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          sacTrendProvider.overrideWith(
            (ref) async => List.generate(
              20,
              (i) => TrendDataPoint(
                date: DateTime.utc(2024, 1, 1).add(Duration(days: i * 7)),
                value: 15.0 + i,
              ),
            ),
          ),
        ].cast(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: InsightsGasPage(embedded: true)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(DiveTrendChart), findsOneWidget);
    expect(find.byKey(const ValueKey('trend-aggregation-sac')), findsOneWidget);
  });

  testWidgets('See top 10 presets Dive focus to the gas lane', (tester) async {
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const Scaffold(body: InsightsGasPage(embedded: true)),
        ),
        GoRoute(
          path: '/insights/focus',
          builder: (_, _) => const Scaffold(body: Text('focus page')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          sacRecordsProvider.overrideWith(
            (ref) async => (
              best: RankingItem(
                id: 'd1',
                name: 'Best',
                count: 1,
                value: 12,
                date: DateTime.utc(2025),
              ),
              worst: null,
            ),
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(InsightsGasPage)),
    );
    final lane = container.read(insightsGasLaneProvider);
    await tester.ensureVisible(
      find.byKey(const ValueKey('gas-records-see-top')),
    );
    await tester.tap(find.byKey(const ValueKey('gas-records-see-top')));
    await tester.pumpAndSettle();

    expect(find.text('focus page'), findsOneWidget);
    expect(
      container.read(focusSelectionProvider),
      FocusSelection(
        metric: lane == GasConsumptionLane.rmv
            ? FocusMetric.rmv
            : FocusMetric.sac,
      ),
    );
  });

  testWidgets('no See top 10 link without consumption records', (tester) async {
    await pumpPage(tester, const AppSettings());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('gas-records-see-top')), findsNothing);
  });
}
