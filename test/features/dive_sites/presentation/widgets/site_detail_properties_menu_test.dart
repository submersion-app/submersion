import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_detail_properties_menu.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Keeps settings in memory so the menu's writes show on the next pump.
class _FakeSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier(super.initial);

  @override
  Future<void> setSiteDetailSections(
    List<SiteDetailSectionConfig> sections,
  ) async => state = state.copyWith(siteDetailSections: sections);

  @override
  Future<void> setSiteDetailLayout(DiveDetailLayout layout) async =>
      state = state.copyWith(siteDetailLayout: layout);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness(_FakeSettingsNotifier notifier) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          appBar: AppBar(actions: const [SiteDetailPropertiesMenu()]),
        ),
      ),
      GoRoute(
        path: '/settings/site-detail-sections',
        name: 'siteDetailSections',
        builder: (context, state) =>
            const Scaffold(body: Text('SITE_SECTIONS_PAGE')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [settingsProvider.overrideWith((ref) => notifier)],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(600, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.tap(find.byIcon(Icons.tune));
  await tester.pumpAndSettle();
}

List<SiteDetailSectionId> _order(AppSettings settings) => [
  for (final section in settings.siteDetailSections) section.id,
];

void main() {
  testWidgets('offers every site card', (tester) async {
    await tester.pumpWidget(
      _harness(_FakeSettingsNotifier(const AppSettings())),
    );
    await _open(tester);

    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    expect(list.itemCount, SiteDetailSectionId.values.length);
    expect(find.text('Dives at this Site'), findsOneWidget);
  });

  testWidgets('choosing a layout writes the site layout only', (tester) async {
    final notifier = _FakeSettingsNotifier(const AppSettings());
    await tester.pumpWidget(_harness(notifier));
    await _open(tester);

    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    expect(notifier.state.siteDetailLayout, DiveDetailLayout.list);
    expect(notifier.state.diveDetailLayout, DiveDetailLayout.detailed);
  });

  testWidgets('toggling a card flips only that card', (tester) async {
    final notifier = _FakeSettingsNotifier(const AppSettings());
    await tester.pumpWidget(_harness(notifier));
    await _open(tester);

    await tester.tap(find.text('Description'));
    await tester.pumpAndSettle();

    final sections = notifier.state.siteDetailSections;
    expect(
      sections
          .firstWhere((s) => s.id == SiteDetailSectionId.description)
          .visible,
      isFalse,
    );
    expect(
      sections
          .where((s) => s.id != SiteDetailSectionId.description)
          .every((s) => s.visible),
      isTrue,
    );
    expect(
      notifier.state.diveDetailSections,
      DiveDetailSectionConfig.defaultSections,
    );
  });

  testWidgets('show all restores every card and keeps the order', (
    tester,
  ) async {
    final custom = [
      for (final id in SiteDetailSectionId.values.reversed)
        SiteDetailSectionConfig(
          id: id,
          visible:
              id != SiteDetailSectionId.map && id != SiteDetailSectionId.tide,
        ),
    ];
    final notifier = _FakeSettingsNotifier(
      AppSettings(siteDetailSections: custom),
    );
    await tester.pumpWidget(_harness(notifier));
    await _open(tester);

    await tester.tap(find.text('Show all sections'));
    await tester.pumpAndSettle();

    expect(notifier.state.siteDetailSections.every((s) => s.visible), isTrue);
    expect(_order(notifier.state), SiteDetailSectionId.values.reversed);
  });

  testWidgets('a drop writes the new order', (tester) async {
    final notifier = _FakeSettingsNotifier(const AppSettings());
    await tester.pumpWidget(_harness(notifier));
    await _open(tester);

    final before = _order(notifier.state);
    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorderItem!(0, 1);
    await tester.pumpAndSettle();

    final after = _order(notifier.state);
    expect(after[0], before[1]);
    expect(after[1], before[0]);
    expect(after.sublist(2), before.sublist(2));
  });

  testWidgets('Reorder sections opens the site settings page', (tester) async {
    await tester.pumpWidget(
      _harness(_FakeSettingsNotifier(const AppSettings())),
    );
    await _open(tester);

    await tester.tap(find.text('Reorder sections...'));
    await tester.pumpAndSettle();

    expect(find.text('SITE_SECTIONS_PAGE'), findsOneWidget);
  });
}
