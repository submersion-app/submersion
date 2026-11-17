import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/planner_rebreather_defaults_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Widget _app(MockSettingsNotifier notifier) => ProviderScope(
  overrides: [settingsProvider.overrideWith((ref) => notifier)],
  child: const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: PlannerRebreatherDefaultsSection()),
  ),
);

/// The diver's semi-closed loop defaults (issue #4660): SCR injection rate,
/// SCR VO2 and pSCR VO2, in the diver's volume unit per minute.
void main() {
  testWidgets('shows the defaults in L/min', (tester) async {
    await tester.pumpWidget(_app(MockSettingsNotifier()));
    await tester.pumpAndSettle();

    expect(find.text('12.0 L/min'), findsOneWidget);
    expect(find.text('1.30 L/min'), findsOneWidget);
    expect(find.text('0.72 L/min'), findsOneWidget);
  });

  testWidgets('an imperial diver sees cuft/min', (tester) async {
    await tester.pumpWidget(
      _app(
        MockSettingsNotifier(
          const AppSettings(volumeUnit: VolumeUnit.cubicFeet),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0.42 cuft/min'), findsOneWidget);
    expect(find.text('0.046 cuft/min'), findsOneWidget);
    expect(find.text('0.025 cuft/min'), findsOneWidget);
  });

  testWidgets('editing the injection rate writes litres through the notifier', (
    tester,
  ) async {
    final notifier = MockSettingsNotifier();
    await tester.pumpWidget(_app(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Injection rate'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '7.5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.state.plannerScrInjectionRate, 7.5);
  });

  testWidgets('editing the pSCR VO2 writes through the notifier', (
    tester,
  ) async {
    final notifier = MockSettingsNotifier();
    await tester.pumpWidget(_app(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('VO₂ (pSCR)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0.9');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.state.plannerPscrVo2, 0.9);
  });
}
