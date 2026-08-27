import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/home_cards.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/settings/presentation/pages/home_appearance_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  Future<MockSettingsNotifier> pumpPage(
    WidgetTester tester, {
    AppSettings? initial,
  }) async {
    final notifier = MockSettingsNotifier(initial);
    final overrides = await getBaseOverrides(settingsNotifier: notifier);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeAppearancePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  testWidgets('shows one enabled toggle per chip type', (tester) async {
    await pumpPage(tester);
    for (final type in HomeChipType.values) {
      final toggle = find.byKey(Key('homeChipToggle_${type.name}'));
      await tester.scrollUntilVisible(toggle, 100);
      expect(toggle, findsOneWidget);
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    }
  });

  testWidgets('toggling a chip records it as hidden', (tester) async {
    final notifier = await pumpPage(tester);
    final toggle = find.byKey(const Key('homeChipToggle_noFly'));
    await tester.scrollUntilVisible(toggle, 100);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(notifier.state.hiddenHomeChips, contains('noFly'));
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
  });

  testWidgets('renders one card tile per card type in effective order', (
    tester,
  ) async {
    await pumpPage(tester);
    for (final card in HomeCardType.values) {
      final tile = find.byKey(Key('homeCardTile_${card.name}'));
      await tester.scrollUntilVisible(tile, 100);
      expect(tile, findsOneWidget);
    }
  });

  testWidgets('toggle off calls setHomeCardEnabled and persists in state', (
    tester,
  ) async {
    final notifier = await pumpPage(tester);
    final toggle = find.byKey(Key('homeCardToggle_${HomeCardType.hero.name}'));
    await tester.scrollUntilVisible(toggle, 100);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(notifier.state.hiddenHomeCards, {HomeCardType.hero.name});
  });

  testWidgets('hidden card row is switched off', (tester) async {
    await pumpPage(
      tester,
      initial: AppSettings(hiddenHomeCards: {HomeCardType.milestones.name}),
    );
    final toggle = find.byKey(
      Key('homeCardToggle_${HomeCardType.milestones.name}'),
    );
    await tester.scrollUntilVisible(toggle, 100);
    expect(tester.widget<Switch>(toggle).value, isFalse);
  });

  testWidgets('reset asks for confirmation then clears customization', (
    tester,
  ) async {
    final notifier = await pumpPage(
      tester,
      initial: AppSettings(hiddenHomeCards: {HomeCardType.hero.name}),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('homeCardsReset')),
      100,
    );
    await tester.tap(find.byKey(const Key('homeCardsReset')));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      find.text(l10n.settings_homeCards_resetDialog_title),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.settings_homeCards_resetDialog_confirm));
    await tester.pumpAndSettle();
    expect(notifier.state.hiddenHomeCards, isEmpty);
    expect(notifier.state.homeCardOrder, isEmpty);
  });

  testWidgets('chips section header says Status chips, not the page title', (
    tester,
  ) async {
    await pumpPage(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.scrollUntilVisible(
      find.text(l10n.settings_homeChips_sectionTitle),
      100,
    );
    expect(find.text(l10n.settings_homeChips_sectionTitle), findsOneWidget);
    // The page title ("Home screen") must not double as the section header.
    expect(find.text(l10n.settings_homeChips_pageTitle), findsOneWidget);
  });

  testWidgets('stored order drives the card tile order', (tester) async {
    await pumpPage(
      tester,
      initial: AppSettings(
        homeCardOrder: [
          HomeCardType.recentDives.name,
          for (final c in HomeCardType.values)
            if (c != HomeCardType.recentDives) c.name,
        ],
      ),
    );
    final firstTileY = tester
        .getTopLeft(
          find.byKey(Key('homeCardTile_${HomeCardType.recentDives.name}')),
        )
        .dy;
    final heroTileY = tester
        .getTopLeft(find.byKey(Key('homeCardTile_${HomeCardType.hero.name}')))
        .dy;
    expect(firstTileY, lessThan(heroTileY));
  });
}
