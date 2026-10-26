import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/planner_rates_defaults_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Widget _app(MockSettingsNotifier notifier) => ProviderScope(
  overrides: [settingsProvider.overrideWith((ref) => notifier)],
  child: const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: PlannerRatesDefaultsSection()),
  ),
);

/// Global defaults for the planner Setup accordion's Deco/Rates fields
/// (issue #3552).
void main() {
  testWidgets('shows the current rate defaults', (tester) async {
    final notifier = MockSettingsNotifier(
      const AppSettings(plannerDescentRate: 20.0, plannerAscentRate: 10.0),
    );
    await tester.pumpWidget(_app(notifier));
    await tester.pumpAndSettle();

    expect(find.text('20m/min'), findsOneWidget);
    expect(find.text('10m/min'), findsOneWidget);
  });

  testWidgets('editing the descent rate writes through the notifier', (
    tester,
  ) async {
    final notifier = MockSettingsNotifier(
      const AppSettings(plannerDescentRate: 18.0),
    );
    await tester.pumpWidget(_app(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Descent rate'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '22');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.state.plannerDescentRate, 22.0);
  });
}
