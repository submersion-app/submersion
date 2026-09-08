import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail_properties_menu.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Settings notifier that keeps state in memory, so the menu's writes are
/// visible to the next pump without a database.
class _FakeSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier(super.initial);

  @override
  Future<void> setDiveDetailSections(
    List<DiveDetailSectionConfig> sections,
  ) async => state = state.copyWith(diveDetailSections: sections);

  @override
  Future<void> setDiveDetailLayout(DiveDetailLayout layout) async =>
      state = state.copyWith(diveDetailLayout: layout);

  @override
  Future<void> setDiveDetailSectionExpanded(
    DiveDetailSectionId id,
    bool expanded,
  ) async {
    state = state.copyWith(
      diveDetailSections: [
        for (final section in state.diveDetailSections)
          section.id == id ? section.copyWith(expanded: expanded) : section,
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness(_FakeSettingsNotifier notifier, {bool isGauge = false}) {
  return ProviderScope(
    overrides: [settingsProvider.overrideWith((ref) => notifier)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(actions: [DiveDetailPropertiesMenu(isGauge: isGauge)]),
      ),
    ),
  );
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.tune));
  await tester.pumpAndSettle();
}

/// The section list's own scrollable, inside the menu.
Finder _sectionList() => find.descendant(
  of: find.byType(ReorderableListView),
  matching: find.byType(Scrollable),
);

/// Taps a menu entry, scrolling to it first.
///
/// The section list shows a handful of rows and builds the rest lazily, so
/// an entry further down has to be scrolled into existence before it can be
/// found; the fixed entries around the list only need to be scrolled into
/// view.
Future<void> _tapMenuItem(WidgetTester tester, String label) async {
  final item = find.text(label);
  if (item.evaluate().isEmpty) {
    await tester.scrollUntilVisible(item, 48, scrollable: _sectionList());
  } else {
    await tester.ensureVisible(item);
  }
  await tester.pumpAndSettle();
  await tester.tap(item);
  await tester.pumpAndSettle();
}

List<DiveDetailSectionId> _order(AppSettings settings) => [
  for (final section in settings.diveDetailSections) section.id,
];

void main() {
  group('DiveDetailPropertiesMenu', () {
    testWidgets('opens from the tune button and lists every layout', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _FakeSettingsNotifier(const AppSettings());
      await tester.pumpWidget(_harness(notifier));
      await _openMenu(tester);

      expect(find.text('Detailed'), findsOneWidget);
      expect(find.text('List'), findsOneWidget);
    });

    testWidgets('choosing a layout writes it to settings', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _FakeSettingsNotifier(const AppSettings());
      await tester.pumpWidget(_harness(notifier));
      await _openMenu(tester);

      await _tapMenuItem(tester, 'List');

      expect(notifier.state.diveDetailLayout, DiveDetailLayout.list);
    });

    testWidgets('the current layout is the checked one', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _FakeSettingsNotifier(
        const AppSettings(diveDetailLayout: DiveDetailLayout.list),
      );
      await tester.pumpWidget(_harness(notifier));
      await _openMenu(tester);

      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      final checked = tester.widget<MenuItemButton>(
        find.ancestor(
          of: find.text('List'),
          matching: find.byType(MenuItemButton),
        ),
      );
      expect(
        ((checked.leadingIcon as Icon?)!).icon,
        Icons.radio_button_checked,
      );
    });

    testWidgets('toggling a section flips only that section', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _FakeSettingsNotifier(const AppSettings());
      await tester.pumpWidget(_harness(notifier));
      await _openMenu(tester);

      await _tapMenuItem(tester, 'Notes');

      final sections = notifier.state.diveDetailSections;
      expect(
        sections.firstWhere((s) => s.id == DiveDetailSectionId.notes).visible,
        isFalse,
      );
      expect(
        sections
            .where((s) => s.id != DiveDetailSectionId.notes)
            .every((s) => s.visible),
        isTrue,
      );
    });

    testWidgets('the menu stays open while sections are toggled', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _FakeSettingsNotifier(const AppSettings());
      await tester.pumpWidget(_harness(notifier));
      await _openMenu(tester);

      await _tapMenuItem(tester, 'Notes');
      await _tapMenuItem(tester, 'Tags');

      final hidden = notifier.state.diveDetailSections
          .where((s) => !s.visible)
          .map((s) => s.id)
          .toSet();
      expect(hidden, {DiveDetailSectionId.notes, DiveDetailSectionId.tags});
    });

    testWidgets('"show all sections" restores visibility, keeping the order', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // A custom order with two sections switched off.
      final custom = [
        for (final id in DiveDetailSectionId.values.reversed)
          DiveDetailSectionConfig(
            id: id,
            visible:
                id != DiveDetailSectionId.notes &&
                id != DiveDetailSectionId.tags,
          ),
      ];
      final notifier = _FakeSettingsNotifier(
        AppSettings(diveDetailSections: custom),
      );
      await tester.pumpWidget(_harness(notifier));
      await _openMenu(tester);

      await _tapMenuItem(tester, 'Show all sections');

      expect(notifier.state.diveDetailSections.every((s) => s.visible), isTrue);
      expect(_order(notifier.state), DiveDetailSectionId.values.reversed);
    });

    testWidgets('gauge dives are not offered the gas and deco sections', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final notifier = _FakeSettingsNotifier(const AppSettings());
      await tester.pumpWidget(_harness(notifier, isGauge: true));
      await _openMenu(tester);

      expect(find.text('Deco Status'), findsNothing);
      expect(find.text('Tissue Loading'), findsNothing);
      expect(find.text('Cylinders'), findsNothing);
      // The profile chart is exactly what a gauge does record.
      expect(find.text('Dive Profile'), findsOneWidget);
    });

    // The gauge menu never lists the gas and deco sections, so "show all"
    // there must not switch them on behind the diver's back: they would only
    // surface on the next non-gauge dive, as a change nobody asked for.
    testWidgets('on a gauge dive, "show all" leaves the unlisted sections be', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final custom = [
        for (final id in DiveDetailSectionId.values)
          DiveDetailSectionConfig(
            id: id,
            visible: !id.hiddenInGaugeMode && id != DiveDetailSectionId.notes,
          ),
      ];
      final notifier = _FakeSettingsNotifier(
        AppSettings(diveDetailSections: custom),
      );
      await tester.pumpWidget(_harness(notifier, isGauge: true));
      await _openMenu(tester);

      await _tapMenuItem(tester, 'Show all sections');

      final sections = notifier.state.diveDetailSections;
      expect(
        sections.firstWhere((s) => s.id == DiveDetailSectionId.notes).visible,
        isTrue,
      );
      expect(
        sections.where((s) => s.id.hiddenInGaugeMode).every((s) => !s.visible),
        isTrue,
      );
    });

    group('reordering', () {
      testWidgets('the sections sit in a reorderable list with handles', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(600, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final notifier = _FakeSettingsNotifier(const AppSettings());
        await tester.pumpWidget(_harness(notifier));
        await _openMenu(tester);

        expect(find.byType(ReorderableListView), findsOneWidget);
        expect(find.byIcon(Icons.drag_handle), findsWidgets);
      });

      testWidgets('a drop writes the new order to settings', (tester) async {
        await tester.binding.setSurfaceSize(const Size(600, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final notifier = _FakeSettingsNotifier(const AppSettings());
        await tester.pumpWidget(_harness(notifier));
        await _openMenu(tester);

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

      // On a gauge dive the list is a subset of the saved order, so a drop
      // index is not a saved-list index; the sections the menu does not list
      // must keep their places.
      testWidgets('sections the menu does not list keep their place', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(600, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final notifier = _FakeSettingsNotifier(const AppSettings());
        await tester.pumpWidget(_harness(notifier, isGauge: true));
        await _openMenu(tester);

        final before = _order(notifier.state);
        final listed = [
          for (final id in before)
            if (!id.hiddenInGaugeMode) id,
        ];
        tester
            .widget<ReorderableListView>(find.byType(ReorderableListView))
            .onReorderItem!(0, listed.length - 1);
        await tester.pumpAndSettle();

        final after = _order(notifier.state);
        expect(after.toSet(), before.toSet());
        // The moved section now trails every other listed one.
        final listedAfter = [
          for (final id in after)
            if (!id.hiddenInGaugeMode) id,
        ];
        expect(listedAfter.last, listed.first);
        expect(listedAfter.sublist(0, listed.length - 1), listed.sublist(1));
        // The unlisted ones sit where they did relative to their neighbours.
        expect(
          [
            for (final id in after)
              if (id.hiddenInGaugeMode) id,
          ],
          [
            for (final id in before)
              if (id.hiddenInGaugeMode) id,
          ],
        );
      });
    });
  });
}
