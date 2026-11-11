import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/main_scaffold_stubs.dart';

Future<void> _pumpShell(
  WidgetTester tester, {
  required Size size,
  required bool demo,
  Future<void> Function()? exit,
}) => pumpMainScaffoldShell(
  tester,
  size: size,
  page: const Scaffold(body: Text('Page')),
  overrides: [
    demoModeActiveProvider.overrideWithValue(demo),
    if (exit != null) demoExitActionProvider.overrideWithValue(exit),
  ],
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const wide = Size(1400, 900);
  const phone = Size(390, 844);

  group('a way out of demo mode in the shell (#4436)', () {
    testWidgets('the rail has none while demo mode is off', (tester) async {
      await _pumpShell(tester, size: wide, demo: false);

      expect(find.text(l10n.demo_exit_button), findsNothing);
      expect(find.byTooltip(l10n.demo_exit_button), findsNothing);
    });

    testWidgets('the rail offers it in demo mode', (tester) async {
      var exits = 0;
      await _pumpShell(
        tester,
        size: wide,
        demo: true,
        exit: () async => exits++,
      );

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.demo_exit_confirm_action).last);
      await tester.pumpAndSettle();
      expect(exits, 1);
    });

    testWidgets('the More sheet leads with it in demo mode', (tester) async {
      var exits = 0;
      await _pumpShell(
        tester,
        size: phone,
        demo: true,
        exit: () async => exits++,
      );

      await tester.tap(find.text(l10n.nav_more));
      await tester.pumpAndSettle();
      final tiles = find.descendant(
        of: find.byKey(const ValueKey('navOverflowSheetBody')),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(
          of: tiles.first,
          matching: find.text(l10n.demo_exit_button),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.demo_exit_button));
      await tester.pumpAndSettle();
      // The sheet closes before the question opens.
      expect(find.byKey(const ValueKey('navOverflowSheetBody')), findsNothing);
      await tester.tap(find.text(l10n.demo_exit_confirm_action).last);
      await tester.pumpAndSettle();
      expect(exits, 1);
    });

    testWidgets('the More sheet has none while demo mode is off', (
      tester,
    ) async {
      await _pumpShell(tester, size: phone, demo: false);

      await tester.tap(find.text(l10n.nav_more));
      await tester.pumpAndSettle();
      expect(find.text(l10n.demo_exit_button), findsNothing);
    });
  });
}
