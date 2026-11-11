import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/demo_mode/presentation/widgets/demo_exit_entries.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    required bool active,
    Future<void> Function()? exit,
    Size size = const Size(800, 600),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoModeActiveProvider.overrideWithValue(active),
          if (exit != null) demoExitActionProvider.overrideWithValue(exit),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Confirms the exit question the card or rail opened.
  Future<void> confirmExit(WidgetTester tester) async {
    expect(find.text(l10n.demo_exit_confirm_title), findsOneWidget);
    await tester.tap(find.text(l10n.demo_exit_confirm_action).last);
    await tester.pumpAndSettle();
  }

  Widget rail({required bool extended}) => Row(
    children: [
      NavigationRail(
        extended: extended,
        selectedIndex: 0,
        trailingAtBottom: true,
        trailing: const DemoExitRailButton(),
        destinations: const [
          NavigationRailDestination(icon: Icon(Icons.home), label: Text('A')),
          NavigationRailDestination(icon: Icon(Icons.list), label: Text('B')),
        ],
      ),
    ],
  );

  group('dashboard card', () {
    testWidgets('is absent while demo mode is off', (tester) async {
      await pump(tester, const DemoModeDashboardCard(), active: false);

      expect(find.text(l10n.demo_active_label), findsNothing);
      expect(find.text(l10n.demo_exit_button), findsNothing);
    });

    testWidgets('says demo mode is on and exits after confirming', (
      tester,
    ) async {
      var exits = 0;
      await pump(
        tester,
        const DemoModeDashboardCard(),
        active: true,
        exit: () async => exits++,
      );

      expect(find.text(l10n.demo_active_label), findsOneWidget);
      expect(find.text(l10n.demo_card_body), findsOneWidget);
      await tester.tap(find.text(l10n.demo_exit_button));
      await tester.pumpAndSettle();
      await confirmExit(tester);
      expect(exits, 1);
    });

    testWidgets('fits a narrow phone at text scale 2', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(
        tester,
        const SingleChildScrollView(child: DemoModeDashboardCard()),
        active: true,
        size: const Size(320, 640),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.demo_exit_button), findsOneWidget);
    });
  });

  group('rail button', () {
    testWidgets('is absent while demo mode is off', (tester) async {
      await pump(tester, rail(extended: true), active: false);

      expect(find.byIcon(Icons.logout), findsNothing);
    });

    testWidgets('is an icon with a tooltip on a collapsed rail', (
      tester,
    ) async {
      await pump(tester, rail(extended: false), active: true);

      expect(find.byTooltip(l10n.demo_exit_button), findsOneWidget);
      expect(find.text(l10n.demo_exit_button), findsNothing);
    });

    testWidgets('shows its label on an extended rail and exits', (
      tester,
    ) async {
      var exits = 0;
      await pump(
        tester,
        rail(extended: true),
        active: true,
        exit: () async => exits++,
      );

      await tester.tap(find.text(l10n.demo_exit_button));
      await tester.pumpAndSettle();
      await confirmExit(tester);
      expect(exits, 1);
    });

    testWidgets('sits at the bottom of the rail', (tester) async {
      await pump(tester, rail(extended: false), active: true);

      final button = tester.getRect(find.byIcon(Icons.logout));
      final lastDestination = tester.getRect(find.byIcon(Icons.list));
      expect(button.top, greaterThan(lastDestination.bottom + 200));
    });

    testWidgets('does not overflow while the rail animates open', (
      tester,
    ) async {
      await pump(tester, rail(extended: false), active: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [demoModeActiveProvider.overrideWithValue(true)],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: rail(extended: true)),
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('More sheet tile', () {
    testWidgets('is absent while demo mode is off', (tester) async {
      await pump(tester, DemoExitSheetTile(onTap: () {}), active: false);

      expect(find.text(l10n.demo_exit_button), findsNothing);
    });

    testWidgets('hands its tap to the sheet', (tester) async {
      var taps = 0;
      await pump(tester, DemoExitSheetTile(onTap: () => taps++), active: true);

      await tester.tap(find.text(l10n.demo_exit_button));
      expect(taps, 1);
    });
  });
}
