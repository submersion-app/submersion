import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/settings/presentation/pages/site_detail_sections_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier([super.initial = const AppSettings()]);

  @override
  Future<void> setSiteDetailSections(
    List<SiteDetailSectionConfig> sections,
  ) async => state = state.copyWith(siteDetailSections: sections);

  @override
  Future<void> resetSiteDetailSections() async =>
      state = state.copyWith(clearSiteDetailSections: true);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, _FakeSettingsNotifier notifier) async {
  await tester.binding.setSurfaceSize(const Size(400, 4000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [settingsProvider.overrideWith((ref) => notifier)],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SiteDetailSectionsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<SiteDetailSectionId> _order(AppSettings settings) => [
  for (final s in settings.siteDetailSections) s.id,
];

void main() {
  testWidgets('shows its title and every card with its description', (
    tester,
  ) async {
    await _pump(tester, _FakeSettingsNotifier());

    expect(find.text('Site Detail Sections'), findsOneWidget);
    expect(find.text('Dives at this Site'), findsOneWidget);
    expect(find.text('Map preview of the site location'), findsOneWidget);
    expect(
      find.byType(Switch),
      findsNWidgets(SiteDetailSectionId.values.length),
    );
    expect(
      find.byIcon(Icons.drag_handle),
      findsNWidgets(SiteDetailSectionId.values.length),
    );
  });

  testWidgets('switching a card off hides only that card', (tester) async {
    final notifier = _FakeSettingsNotifier();
    await _pump(tester, notifier);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    final sections = notifier.state.siteDetailSections;
    expect(sections.first.id, SiteDetailSectionId.map);
    expect(sections.first.visible, isFalse);
    expect(sections.skip(1).every((s) => s.visible), isTrue);
  });

  testWidgets('a drop writes the new order', (tester) async {
    final notifier = _FakeSettingsNotifier();
    await _pump(tester, notifier);

    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorderItem!(0, 2);
    await tester.pumpAndSettle();

    expect(_order(notifier.state).take(3), [
      SiteDetailSectionId.diveStatistics,
      SiteDetailSectionId.description,
      SiteDetailSectionId.map,
    ]);
  });

  testWidgets('reset to default restores the order and visibility', (
    tester,
  ) async {
    final notifier = _FakeSettingsNotifier(
      AppSettings(
        siteDetailSections: [
          for (final id in SiteDetailSectionId.values.reversed)
            SiteDetailSectionConfig(id: id, visible: false),
        ],
      ),
    );
    await _pump(tester, notifier);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset to Default'));
    await tester.pumpAndSettle();

    expect(_order(notifier.state), SiteDetailSectionId.values);
    expect(notifier.state.siteDetailSections.every((s) => s.visible), isTrue);
  });
}
