import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/planner_dpv_team_defaults_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Widget _app(MockSettingsNotifier notifier) => ProviderScope(
  overrides: [settingsProvider.overrideWith((ref) => notifier)],
  child: const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: PlannerDpvTeamDefaultsSection()),
  ),
);

/// Global defaults for the DPV Team Setup-accordion policy fields (issue
/// #3552).
void main() {
  testWidgets('shows the current DPV team defaults', (tester) async {
    final notifier = MockSettingsNotifier(
      const AppSettings(
        plannerBatteryReserveFraction: 0.4,
        // Walking speed is stored in m/s but shown as a depth-rate (m/min,
        // same unit the planner Rates section uses): 0.8 m/s -> 48 m/min.
        plannerWalkSpeedMps: 0.8,
      ),
    );
    await tester.pumpWidget(_app(notifier));
    await tester.pumpAndSettle();

    expect(find.text('40%'), findsOneWidget);
    expect(find.text('48 m/min'), findsOneWidget);
  });

  testWidgets('editing the battery reserve writes through the notifier', (
    tester,
  ) async {
    final notifier = MockSettingsNotifier(
      const AppSettings(plannerBatteryReserveFraction: 1 / 3),
    );
    await tester.pumpWidget(_app(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Battery reserve'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.state.plannerBatteryReserveFraction, 0.5);
  });

  testWidgets('editing the walk speed writes through the notifier', (
    tester,
  ) async {
    final notifier = MockSettingsNotifier(
      const AppSettings(plannerWalkSpeedMps: 0.8),
    );
    await tester.pumpWidget(_app(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Walking speed'));
    await tester.pumpAndSettle();
    // Entered in m/min (60 m/min = 1.0 m/s stored).
    await tester.enterText(find.byType(TextFormField), '60');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.state.plannerWalkSpeedMps, 1.0);
  });
}
