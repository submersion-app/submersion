import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_gas_page.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_gas_lane_provider.dart';
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
          home: Scaffold(body: StatisticsGasPage(embedded: true)),
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
      tester.element(find.byType(StatisticsGasPage)),
    );
    expect(container.read(statisticsGasLaneProvider), GasConsumptionLane.sac);

    await tester.tap(find.descendant(of: chip, matching: find.text('RMV')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(container.read(statisticsGasLaneProvider), GasConsumptionLane.rmv);
  });

  testWidgets('a single-lane preference shows no control', (tester) async {
    await pumpPage(
      tester,
      const AppSettings(gasConsumptionDisplay: GasConsumptionDisplay.rmv),
    );
    expect(chip, findsNothing);
  });
}
