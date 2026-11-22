import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/home_panels.dart';
import 'package:submersion/features/dashboard/presentation/home_presets.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/settings/presentation/pages/home_appearance_page.dart';
import 'package:submersion/features/settings/presentation/pages/home_key_numbers_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

AppSettings _custom() {
  final layout = homeLayoutForPreset(
    HomeLayoutPreset.balanced,
  ).withPanelEnabled(HomePanelType.recentDives, false);
  return AppSettings(
    homePanelOrder: layout.orderNames,
    hiddenHomePanels: layout.hiddenNames,
  );
}

Future<MockSettingsNotifier> _pump(
  WidgetTester tester, {
  AppSettings? initial,
  Widget page = const HomeAppearancePage(),
  double width = 800,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final notifier = MockSettingsNotifier(initial);
  final overrides = await getBaseOverrides(settingsNotifier: notifier);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return notifier;
}

bool _selected(WidgetTester tester, HomeLayoutPreset p) => tester
    .widget<HomePresetTile>(find.byKey(Key('homePreset_${p.name}')))
    .selected;

void main() {
  testWidgets('a fresh install highlights Balanced', (tester) async {
    await _pump(tester);
    expect(_selected(tester, HomeLayoutPreset.balanced), isTrue);
    expect(_selected(tester, HomeLayoutPreset.trends), isFalse);
  });

  testWidgets('switching a panel off makes the layout Custom', (tester) async {
    final notifier = await _pump(tester);
    final toggle = find.byKey(const Key('homePanelToggle_recentDives'));
    await tester.scrollUntilVisible(toggle, 100);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(notifier.state.hiddenHomePanels, contains('recentDives'));
    expect(notifier.state.homePanelOrder, isNotNull);
    await tester.scrollUntilVisible(
      find.byKey(const Key('homePreset_balanced')),
      -100,
    );
    expect(_selected(tester, HomeLayoutPreset.balanced), isFalse);
  });

  testWidgets('picking a preset from a preset applies it at once', (
    tester,
  ) async {
    final notifier = await _pump(tester);
    await tester.tap(find.byKey(const Key('homePreset_trends')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      notifier.state.homePanelOrder,
      homeLayoutForPreset(HomeLayoutPreset.trends).orderNames,
    );
  });

  testWidgets('picking a preset over a Custom layout asks first', (
    tester,
  ) async {
    final notifier = await _pump(tester, initial: _custom());
    await tester.tap(find.byKey(const Key('homePreset_trends')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(notifier.state.hiddenHomePanels, contains('recentDives'));

    await tester.tap(find.byKey(const Key('homePreset_trends')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(
      notifier.state.homePanelOrder,
      homeLayoutForPreset(HomeLayoutPreset.trends).orderNames,
    );
  });

  testWidgets('every panel has a row', (tester) async {
    await _pump(tester);
    // In list order: the test only scrolls down.
    final order = homeLayoutForPreset(HomeLayoutPreset.balanced).order;
    expect(order.length, HomePanelType.values.length);
    for (final p in order) {
      final tile = find.byKey(Key('homePanelTile_${p.name}'));
      await tester.scrollUntilVisible(tile, 100);
      expect(tile, findsOneWidget, reason: p.name);
    }
  });

  testWidgets('reset returns to Balanced after confirming', (tester) async {
    final notifier = await _pump(tester, initial: _custom());
    final reset = find.byKey(const Key('homePanelsReset'));
    await tester.scrollUntilVisible(reset, 100);
    // Fully on screen: the list can stop with the button at its edge.
    await tester.ensureVisible(reset);
    await tester.pumpAndSettle();
    await tester.tap(reset);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(
      notifier.state.homePanelOrder,
      homeLayoutForPreset(HomeLayoutPreset.balanced).orderNames,
    );
  });

  testWidgets('status light switches still hide lights', (tester) async {
    final notifier = await _pump(tester);
    final toggle = find.byKey(const Key('homeChipToggle_noFly'));
    await tester.scrollUntilVisible(toggle, 200);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(notifier.state.hiddenHomeChips, contains('noFly'));
    for (final type in HomeChipType.values) {
      final t = find.byKey(Key('homeChipToggle_${type.name}'));
      await tester.scrollUntilVisible(t, 200);
      expect(t, findsOneWidget);
    }
  });

  testWidgets('each preset thumbnail draws its rows', (tester) async {
    await _pump(tester);
    final bars = find.descendant(
      of: find.byKey(const Key('homePreset_balanced')),
      matching: find.byType(DecoratedBox),
    );
    expect(bars, findsWidgets);
    for (final e in bars.evaluate()) {
      final size = (e.renderObject! as RenderBox).size;
      expect(size.height, greaterThan(2));
      expect(size.width, greaterThan(2));
    }
  });

  // Right to left, the first bar of each row sits at the right edge, so the
  // gap between bars must follow the reading direction too.
  testWidgets('a right-to-left thumbnail reaches its right edge', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('he'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: SizedBox(
            width: 200,
            child: HomePresetTile(
              preset: HomeLayoutPreset.balanced,
              selected: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    final tile = tester.getRect(find.byType(HomePresetTile));
    final bars = find.descendant(
      of: find.byType(HomePresetTile),
      matching: find.byType(DecoratedBox),
    );
    final rights = [
      for (final e in bars.evaluate())
        tester.getRect(find.byWidget(e.widget)).right,
    ];
    // The tile's inner padding is 8 on every side.
    expect(rights.reduce((a, b) => a > b ? a : b), tile.right - 8);
  });

  testWidgets('a narrow page puts the presets two by two', (tester) async {
    await _pump(tester, width: 340);
    final a = tester.getRect(find.byKey(const Key('homePreset_balanced')));
    final c = tester.getRect(find.byKey(const Key('homePreset_trends')));
    expect(c.top, greaterThan(a.top));
    expect(tester.takeException(), isNull);
  });

  group('the gas panel and tile take the name Home shows them by', () {
    Future<void> expectNames(
      WidgetTester tester,
      AppSettings settings, {
      required String trend,
      required String tile,
    }) async {
      await _pump(tester, initial: settings);
      final row = find.byKey(const Key('homePanelTile_sacTrend'));
      await tester.scrollUntilVisible(row, 100);
      expect(
        find.descendant(of: row, matching: find.text(trend)),
        findsOneWidget,
      );
      await _pump(tester, initial: settings, page: const HomeKeyNumbersPage());
      expect(
        find.descendant(
          of: find.byKey(const Key('homeKeyNumberToggle_avgSac')),
          matching: find.text(tile),
        ),
        findsOneWidget,
      );
    }

    testWidgets('RMV for a diver who reads RMV', (tester) async {
      await expectNames(
        tester,
        const AppSettings(),
        trend: 'RMV trend',
        tile: 'Avg RMV',
      );
    });

    testWidgets('SAC for a diver who reads only SAC', (tester) async {
      await expectNames(
        tester,
        const AppSettings(gasConsumptionDisplay: GasConsumptionDisplay.sac),
        trend: 'SAC trend',
        tile: 'Avg SAC',
      );
    });
  });

  testWidgets('the key numbers page toggles a tile', (tester) async {
    final notifier = await _pump(tester, page: const HomeKeyNumbersPage());
    // Deepest this year starts off; switching it on keeps the other
    // default-off tile, average depth, off.
    final deepest = find.byKey(
      const Key('homeKeyNumberToggle_deepestThisYear'),
    );
    await tester.scrollUntilVisible(deepest, 100);
    expect(tester.widget<SwitchListTile>(deepest).value, isFalse);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('homeKeyNumberToggle_species')),
          )
          .value,
      isTrue,
    );
    await tester.tap(deepest);
    await tester.pumpAndSettle();
    expect(
      notifier.state.hiddenHomeKeyNumbers,
      isNot(contains('deepestThisYear')),
    );
    expect(notifier.state.hiddenHomeKeyNumbers, contains('avgDepth'));
  });
}
