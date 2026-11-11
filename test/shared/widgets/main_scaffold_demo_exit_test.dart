import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/main_scaffold.dart';

import '../../helpers/main_scaffold_stubs.dart';

Future<void> _pumpShell(
  WidgetTester tester, {
  required Size size,
  required bool demo,
  Future<void> Function()? exit,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const Scaffold(body: Text('Page')),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        updateServiceProvider.overrideWith((ref) async => null),
        updateStatusProvider.overrideWith((ref) => StubUpdateStatusNotifier()),
        downloadNotifierProvider.overrideWith((ref) => StubDownloadNotifier()),
        settingsProvider.overrideWith(
          (ref) => StubSettingsNotifier(const AppSettings()),
        ),
        demoModeActiveProvider.overrideWithValue(demo),
        if (exit != null) demoExitActionProvider.overrideWithValue(exit),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const wide = Size(1400, 900);
  const phone = Size(390, 844);

  group('a way out of demo mode in the shell (#4428)', () {
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
