import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/planner_gas_defaults_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Widget _app(MockSettingsNotifier notifier) => ProviderScope(
  overrides: [settingsProvider.overrideWith((ref) => notifier)],
  child: const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: PlannerGasDefaultsSection()),
  ),
);

/// Global defaults for the planner Setup accordion's Gas options (issue
/// #3552).
void main() {
  testWidgets('shows the current gas defaults', (tester) async {
    final notifier = MockSettingsNotifier(
      const AppSettings(
        plannerSacBottom: 18.0,
        plannerSacStressedFactor: 3.0,
        plannerProblemSolvingMinutes: 3,
      ),
    );
    await tester.pumpWidget(_app(notifier));
    await tester.pumpAndSettle();

    expect(find.text('18.0 L/min'), findsOneWidget);
    expect(find.text('3.0×'), findsOneWidget);
    expect(find.text('3 min'), findsOneWidget);
  });

  testWidgets('editing the bottom SAC writes through the notifier', (
    tester,
  ) async {
    final notifier = MockSettingsNotifier(
      const AppSettings(plannerSacBottom: 15.0),
    );
    await tester.pumpWidget(_app(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bottom RMV'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '17.5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.state.plannerSacBottom, 17.5);
  });

  testWidgets('editing the buddy/RMV factor writes through the notifier', (
    tester,
  ) async {
    final notifier = MockSettingsNotifier(
      const AppSettings(plannerBuddyFactor: 2.0),
    );
    await tester.pumpWidget(_app(notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('RMV factor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '2.5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(notifier.state.plannerBuddyFactor, 2.5);
  });

  testWidgets(
    'the "Per-O2-band deco limits" tile opens the dialog seeded with the '
    'current settings (issue #3580)',
    (tester) async {
      final notifier = MockSettingsNotifier(
        const AppSettings(
          ppO2DecoBandsEnabled: true,
          ppO2DecoBand1: 1.3,
          ppO2DecoBand2: 1.4,
          ppO2DecoBand3: 1.5,
          maxO2DepthEnabled: true,
          maxO2DepthMeters: 7.0,
        ),
      );
      await tester.pumpWidget(_app(notifier));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Per-O2-band deco limits'));
      await tester.pumpAndSettle();

      expect(find.text('1.3 bar'), findsOneWidget);
      expect(find.text('1.4 bar'), findsOneWidget);
      expect(find.text('1.5 bar'), findsOneWidget);
      expect(find.text('7.0m'), findsOneWidget);
    },
  );

  testWidgets(
    'saving the dialog writes every value through setPpO2DecoBandsConfig '
    '(issue #3580)',
    (tester) async {
      final notifier = MockSettingsNotifier(const AppSettings());
      await tester.pumpWidget(_app(notifier));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Per-O2-band deco limits'));
      await tester.pumpAndSettle();

      final bandsSwitch = find.byType(SwitchListTile).first;
      await tester.tap(bandsSwitch);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(notifier.state.ppO2DecoBandsEnabled, isTrue);
      // The three bands and the explicit depth keep their (unedited)
      // defaults, snapped onto the grid.
      expect(notifier.state.ppO2DecoBand1, const AppSettings().ppO2DecoBand1);
      expect(
        notifier.state.maxO2DepthMeters,
        const AppSettings().maxO2DepthMeters,
      );
    },
  );
}
