import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/planner_contingency_defaults_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Widget _app(MockSettingsNotifier notifier) => ProviderScope(
  overrides: [settingsProvider.overrideWith((ref) => notifier)],
  child: const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: PlannerContingencyDefaultsSection()),
  ),
);

/// Global defaults for the planner Setup accordion's Contingency fields
/// (issue #3552).
void main() {
  testWidgets('shows the current contingency defaults', (tester) async {
    final notifier = MockSettingsNotifier(
      const AppSettings(
        plannerDeviationDepthDelta: 6.0,
        plannerDeviationTimeMinutes: 7,
      ),
    );
    await tester.pumpWidget(_app(notifier));
    await tester.pumpAndSettle();

    expect(find.text('6.0m'), findsOneWidget);
    expect(find.text('7 min'), findsOneWidget);
  });

  testWidgets('editing the depth delta writes through the notifier', (
    tester,
  ) async {
    final notifier = MockSettingsNotifier(
      const AppSettings(plannerDeviationDepthDelta: 5.0),
    );
    await tester.pumpWidget(_app(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Extra depth'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '8');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.state.plannerDeviationDepthDelta, 8.0);
  });

  testWidgets('editing the time delta writes through the notifier', (
    tester,
  ) async {
    final notifier = MockSettingsNotifier(
      const AppSettings(plannerDeviationTimeMinutes: 5),
    );
    await tester.pumpWidget(_app(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Extra minutes'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '9');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.state.plannerDeviationTimeMinutes, 9);
  });
}
