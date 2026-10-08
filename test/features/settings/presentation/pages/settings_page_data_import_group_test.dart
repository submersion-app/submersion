// Issue #2779: the two import preferences (auto site matching and tank
// pressure at surfacing) live in their own "Import" group on Settings > Data,
// between Storage and Data Tools, instead of as loose cards above the first
// header.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  Widget buildDataSection(List<Override> overrides) {
    final router = GoRouter(
      initialLocation: '/settings?selected=data',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    );

    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        locale: const Locale('en'),
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  Future<void> pumpDataSection(
    WidgetTester tester, {
    MockSettingsNotifier? settings,
  }) async {
    // Tall enough that the whole Data page lays out without scrolling, so
    // every header and row has a real position to compare.
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      buildDataSection(await getBaseOverrides(settingsNotifier: settings)),
    );
    await tester.pumpAndSettle();
  }

  double topOf(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  Element cardOf(WidgetTester tester, String text) => tester.element(
    find.ancestor(of: find.text(text), matching: find.byType(Card)).first,
  );

  testWidgets('an Import header sits between Storage and Data Tools', (
    tester,
  ) async {
    await pumpDataSection(tester);

    expect(find.text('Import'), findsOneWidget);
    expect(topOf(tester, 'Storage'), lessThan(topOf(tester, 'Import')));
    expect(topOf(tester, 'Import'), lessThan(topOf(tester, 'Data Tools')));
  });

  testWidgets('both import options sit inside the Import group', (
    tester,
  ) async {
    await pumpDataSection(tester);

    final importTop = topOf(tester, 'Import');
    final dataToolsTop = topOf(tester, 'Data Tools');
    for (final option in ['Auto site matching', 'Tank pressure at surfacing']) {
      expect(topOf(tester, option), greaterThan(importTop), reason: option);
      expect(topOf(tester, option), lessThan(dataToolsTop), reason: option);
    }
  });

  testWidgets('nothing sits above the Backup & Sync header', (tester) async {
    await pumpDataSection(tester);

    // Every text on the Data page, not just cards: a bare tile or label
    // reintroduced above the first header must fail this too.
    final page = find
        .ancestor(
          of: find.text('Backup & Sync'),
          matching: find.byType(SingleChildScrollView),
        )
        .first;
    final texts = find.descendant(of: page, matching: find.byType(Text));
    final firstHeaderTop = topOf(tester, 'Backup & Sync');
    for (final element in texts.evaluate()) {
      final text = (element.widget as Text).data;
      if (text == 'Backup & Sync') continue;
      // Read the element's own box: a widget-based lookup would throw on a
      // widget instance mounted in more than one place.
      final box = element.renderObject! as RenderBox;
      expect(
        box.localToGlobal(Offset.zero).dy,
        greaterThan(firstHeaderTop),
        reason: '"$text" sits above the first header',
      );
    }
  });

  testWidgets('the two options share one card', (tester) async {
    await pumpDataSection(tester);

    expect(
      cardOf(tester, 'Auto site matching'),
      same(cardOf(tester, 'Tank pressure at surfacing')),
    );
  });

  testWidgets('choosing a site matching level records the preference', (
    tester,
  ) async {
    final settings = MockSettingsNotifier();
    await pumpDataSection(tester, settings: settings);
    expect(settings.state.siteMatchSensitivity, SiteMatchSensitivity.balanced);

    await tester.tap(find.text('Balanced'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strict').last);
    await tester.pumpAndSettle();

    expect(settings.state.siteMatchSensitivity, SiteMatchSensitivity.strict);
  });
}
