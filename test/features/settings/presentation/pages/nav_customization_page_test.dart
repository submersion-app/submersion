import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/pages/nav_customization_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/nav_order_editor.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

import '../../../../support/fake_app_settings_repository.dart';

void main() {
  group('applyReorderPreservingDivider', () {
    // Movable items: [a, b, c, d, e, f]; divider sits at dividerIndex=3.
    // Flat list shown to user: [a, b, c, DIVIDER, d, e, f].

    test('drop above divider stays above divider', () {
      // Move 'e' (flat index 5) to position 1 (before 'b')
      final result = applyReorderPreservingDivider(
        movable: const ['a', 'b', 'c', 'd', 'e', 'f'],
        dividerIndex: 3,
        oldIndex: 5,
        newIndex: 1,
      );
      expect(result, ['a', 'e', 'b', 'c', 'd', 'f']);
    });

    test('drop below divider stays below divider', () {
      // onReorderItem reports the post-removal flat index, so moving 'a' (flat 0)
      // to between 'd' and 'e' below the divider is newIndex 4 (not 5).
      final result = applyReorderPreservingDivider(
        movable: const ['a', 'b', 'c', 'd', 'e', 'f'],
        dividerIndex: 3,
        oldIndex: 0,
        newIndex: 4,
      );
      expect(result, ['b', 'c', 'd', 'a', 'e', 'f']);
    });

    test('attempting to drag the divider itself is a no-op', () {
      final result = applyReorderPreservingDivider(
        movable: const ['a', 'b', 'c', 'd', 'e', 'f'],
        dividerIndex: 3,
        oldIndex: 3, // divider's position
        newIndex: 1,
      );
      expect(result, ['a', 'b', 'c', 'd', 'e', 'f']);
    });

    test('newIndex is treated as the post-removal index (no internal shift)', () {
      // onReorderItem already adjusts for the removed item, so dragging 'a' (0)
      // to the bottom reports newIndex 6 (end of the 6-item post-removal flat
      // list); the helper must not subtract again.
      final result = applyReorderPreservingDivider(
        movable: const ['a', 'b', 'c', 'd', 'e', 'f'],
        dividerIndex: 3,
        oldIndex: 0,
        newIndex: 6,
      );
      expect(result, ['b', 'c', 'd', 'e', 'f', 'a']);
    });

    test(
      'same-position reorder returns content-equal but non-identical list',
      () {
        // Drop-on-self (or any drag that results in no position change) still
        // produces a fresh list. _commitReorder therefore uses listEquals, not
        // identical, to detect a no-op and skip the repository write.
        const input = ['a', 'b', 'c', 'd', 'e', 'f'];
        final result = applyReorderPreservingDivider(
          movable: input,
          dividerIndex: 3,
          oldIndex: 4,
          newIndex: 4,
        );
        expect(result, input);
        expect(identical(result, input), isFalse);
      },
    );

    group('with no divider (desktop rail)', () {
      test('flat indices map straight through', () {
        final result = applyReorderPreservingDivider(
          movable: const ['a', 'b', 'c', 'd'],
          dividerIndex: null,
          oldIndex: 3,
          newIndex: 0,
        );
        expect(result, ['d', 'a', 'b', 'c']);
      });

      test('a drop at the end lands last', () {
        final result = applyReorderPreservingDivider(
          movable: const ['a', 'b', 'c', 'd'],
          dividerIndex: null,
          oldIndex: 0,
          newIndex: 3,
        );
        expect(result, ['b', 'c', 'd', 'a']);
      });

      test('an out-of-range source index is a no-op', () {
        const input = ['a', 'b', 'c'];
        expect(
          applyReorderPreservingDivider(
            movable: input,
            dividerIndex: null,
            oldIndex: 7,
            newIndex: 0,
          ),
          input,
        );
      });
    });
  });

  group('NavCustomizationPage widget', () {
    /// Sizes the surface so the page opens on the requested scope and the
    /// whole list renders without scrolling; the page uses a
    /// ReorderableListView.builder, which only builds visible rows.
    void useSurface(WidgetTester tester, {required bool wide}) {
      tester.view.physicalSize = Size(wide ? 1200 : 500, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Widget buildHarness(AppSettingsRepository repo) {
      return ProviderScope(
        overrides: [appSettingsRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NavCustomizationPage(),
        ),
      );
    }

    Future<FakeAppSettingsRepository> pumpPage(
      WidgetTester tester, {
      bool wide = false,
      FakeAppSettingsRepository? repo,
    }) async {
      useSurface(tester, wide: wide);
      final resolved = repo ?? FakeAppSettingsRepository();
      await tester.pumpWidget(buildHarness(resolved));
      await tester.pumpAndSettle();
      return resolved;
    }

    testWidgets('opens on the scope matching the current surface', (
      tester,
    ) async {
      await pumpPage(tester);

      // The divider row only exists on the phone surface, so its presence is
      // the tell that the page opened on the phone scope.
      expect(find.text('Items below appear in the More menu'), findsOneWidget);
    });

    testWidgets('opens on Desktop when the window is rail-width', (
      tester,
    ) async {
      await pumpPage(tester, wide: true);

      // The divider only exists on the phone surface.
      expect(find.byKey(const ValueKey('nav-divider')), findsNothing);
      expect(find.text('Items below appear in the More menu'), findsNothing);
    });

    testWidgets('shows pinned Home and More rows on the phone scope', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      // Lock icons render for pinned rows.
      expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
    });

    testWidgets('desktop scope pins Home only, with no More row', (
      tester,
    ) async {
      await pumpPage(tester, wide: true);

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('More'), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('every movable destination gets a reorderable row', (
      tester,
    ) async {
      await pumpPage(tester);

      // A destination that is not listed here cannot be moved between the
      // phone bottom bar and the More menu, so adding one to kNavDestinations
      // without it appearing here would silently strand it in overflow.
      for (final id in movableNavIds) {
        expect(
          find.byKey(ValueKey('nav-item-$id')),
          findsOneWidget,
          reason: '$id has no row in the navigation customizer',
        );
      }
      expect(find.byKey(const ValueKey('nav-item-species')), findsOneWidget);
      expect(find.text('Species'), findsOneWidget);
    });

    testWidgets('the desktop scope lists every movable destination too', (
      tester,
    ) async {
      await pumpPage(tester, wide: true);

      for (final id in movableNavIds) {
        expect(
          find.byKey(ValueKey('nav-item-$id')),
          findsOneWidget,
          reason: '$id has no row in the rail customizer',
        );
      }
    });

    testWidgets('switching scope swaps which order is shown', (tester) async {
      final repo = FakeAppSettingsRepository()
        ..navPrimaryIds = ['equipment', 'buddies', 'statistics']
        ..navRailIds = ['gps-log', 'planning'];
      await pumpPage(tester, repo: repo);

      // Phone scope first: the divider is present and the top row is Equipment.
      expect(find.byKey(const ValueKey('nav-divider')), findsOneWidget);
      expect(_firstRowId(tester), 'equipment');

      await tester.tap(find.text('Desktop'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('nav-divider')), findsNothing);
      expect(_firstRowId(tester), 'gps-log');

      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('nav-divider')), findsOneWidget);
      expect(_firstRowId(tester), 'equipment');
    });

    testWidgets('Reset button is disabled when the order matches defaults', (
      tester,
    ) async {
      await pumpPage(tester); // empty store -> defaults after load

      final resetButton = find.widgetWithText(TextButton, 'Reset to defaults');
      expect(resetButton, findsOneWidget);
      expect(tester.widget<TextButton>(resetButton).onPressed, isNull);
    });

    testWidgets('Reset button is enabled after customization', (tester) async {
      final repo = FakeAppSettingsRepository()
        ..navPrimaryIds = ['equipment', 'buddies', 'statistics'];
      await pumpPage(tester, repo: repo);

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Reset to defaults'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('tapping Reset restores defaults via the repository', (
      tester,
    ) async {
      final repo = FakeAppSettingsRepository()
        ..navPrimaryIds = ['equipment', 'buddies', 'statistics'];
      await pumpPage(tester, repo: repo);

      await tester.tap(find.widgetWithText(TextButton, 'Reset to defaults'));
      await tester.pumpAndSettle();

      expect(repo.navPrimaryIds, movableNavIds);
    });

    testWidgets('move-up on first overflow row promotes it to primary', (
      tester,
    ) async {
      // Default primary: [dives, sites, trips]; first overflow = media.
      final repo = await pumpPage(tester);

      await tester.tap(find.byTooltip('Move Media up'));
      await tester.pumpAndSettle();

      // Media should now be primary; trips (the last default primary)
      // should drop to overflow.
      expect(repo.navPrimaryIds!.take(3), contains('media'));
      expect(repo.navPrimaryIds!.take(3), isNot(contains('trips')));
    });

    testWidgets('move-down on last primary row demotes it to overflow', (
      tester,
    ) async {
      // Default primary: [dives, sites, trips]; last primary = trips.
      final repo = await pumpPage(tester);

      await tester.tap(find.byTooltip('Move Trips down'));
      await tester.pumpAndSettle();

      expect(repo.navPrimaryIds!.take(3), contains('media'));
      expect(repo.navPrimaryIds!.take(3), isNot(contains('trips')));
    });

    testWidgets('move-down moves a row down by exactly one slot (not two)', (
      tester,
    ) async {
      // Default primary order is [dives, sites, trips]. Moving the first row
      // down by one must swap it with the second -> [sites, dives, trips], and
      // must NOT overshoot to [sites, trips, dives]. The move buttons feed
      // _commitReorder/applyReorderPreservingDivider, which expect
      // onReorderItem-style (already-adjusted) indices; this guards against the
      // old onReorder off-by-one in _moveDown.
      final repo = await pumpPage(tester);

      // The first arrow_downward belongs to the first movable row (dives).
      await tester.tap(find.byIcon(Icons.arrow_downward).first);
      await tester.pumpAndSettle();

      expect(repo.navPrimaryIds!.take(3).toList(), ['sites', 'dives', 'trips']);
    });

    testWidgets('a phone reorder persists the whole order, not just 3 slots', (
      tester,
    ) async {
      // Reordering inside the More menu is the case the old 3-id storage
      // dropped on the floor: the write must carry every id.
      final repo = await pumpPage(tester);

      await tester.tap(find.byTooltip('Move GPS Log up'));
      await tester.pumpAndSettle();

      expect(repo.navPrimaryIds, isNotNull);
      expect(repo.navPrimaryIds!.length, movableNavIds.length);
      // 'gps-log' sits second-to-last canonically; moving it up must move it
      // ahead of 'transfer' while both stay in the overflow tail.
      final order = repo.navPrimaryIds!;
      expect(order.indexOf('gps-log'), lessThan(order.indexOf('transfer')));
      expect(order.take(3).toList(), kDefaultPrimaryIds);
    });

    testWidgets('a desktop reorder writes the rail key only', (tester) async {
      final repo = await pumpPage(tester, wide: true);

      await tester.tap(find.byIcon(Icons.arrow_downward).first);
      await tester.pumpAndSettle();

      expect(repo.navRailIds, isNotNull);
      expect(repo.navRailIds!.take(2).toList(), ['sites', 'dives']);
      expect(repo.navRailIds!.length, movableNavIds.length);
      // The phone order must not have been touched.
      expect(repo.navPrimaryIds, isNull);
    });

    testWidgets('a failed save rolls the row back and reports it', (
      tester,
    ) async {
      final repo = _WriteFailsRepo();
      await pumpPage(tester, repo: repo);

      await tester.tap(find.byIcon(Icons.arrow_downward).first);
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save navigation layout. Please try again.'),
        findsOneWidget,
      );
      // Rolled back: the default order is still on screen.
      expect(_firstRowId(tester), 'dives');
    });
  });
}

/// Id of the topmost reorderable row, read off its ValueKey.
String _firstRowId(WidgetTester tester) {
  final key = tester
      .widgetList<ListTile>(find.byType(ListTile))
      .map((tile) => tile.key)
      .whereType<ValueKey<String>>()
      .firstWhere((k) => k.value.startsWith('nav-item-'));
  return key.value.substring('nav-item-'.length);
}

/// Fake whose nav writes always fail, so the editor's rollback path runs.
class _WriteFailsRepo extends FakeAppSettingsRepository {
  @override
  Future<void> setNavPrimaryIds(List<String> ids) async =>
      throw StateError('write failed');

  @override
  Future<void> setNavRailIds(List<String> ids) async =>
      throw StateError('write failed');
}
