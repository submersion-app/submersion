import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/pages/nav_customization_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/nav_order_editor.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';
import 'package:submersion/shared/widgets/nav/nav_id_aliases.dart';

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
    /// Sizes the surface so the page opens on the requested scope and, at the
    /// default [height], the whole list renders without scrolling; the page
    /// uses a ReorderableListView.builder, which only builds visible rows.
    void useSurface(
      WidgetTester tester, {
      required bool wide,
      double height = 3000,
    }) {
      tester.view.physicalSize = Size(wide ? 1200 : 500, height);
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
      double height = 3000,
      FakeAppSettingsRepository? repo,
    }) async {
      useSurface(tester, wide: wide, height: height);
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
      expect(
        find.text(
          'Items below go to the More menu when they do not fit in the bar',
        ),
        findsOneWidget,
      );
    });

    testWidgets('opens on Desktop when the window is rail-width', (
      tester,
    ) async {
      await pumpPage(tester, wide: true);

      // The divider only exists on the phone surface.
      expect(find.byKey(const ValueKey('nav-divider')), findsNothing);
      expect(
        find.text(
          'Items below go to the More menu when they do not fit in the bar',
        ),
        findsNothing,
      );
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
        ..navPrimaryIds = ['equipment', 'buddies', 'insights']
        ..navRailIds = ['tracks', 'planning'];
      await pumpPage(tester, repo: repo);

      // Phone scope first: the divider is present and the top row is Equipment.
      expect(find.byKey(const ValueKey('nav-divider')), findsOneWidget);
      expect(_firstRowId(tester), 'equipment');

      await tester.tap(find.text('Desktop'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('nav-divider')), findsNothing);
      expect(_firstRowId(tester), 'tracks');

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
        ..navPrimaryIds = ['equipment', 'buddies', 'insights'];
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
        ..navPrimaryIds = ['equipment', 'buddies', 'insights'];
      await pumpPage(tester, repo: repo);

      await tester.tap(find.widgetWithText(TextButton, 'Reset to defaults'));
      await tester.pumpAndSettle();

      expect(repo.navPrimaryIds, withLegacyNavIds(movableNavIds));
    });

    testWidgets('move-up on first overflow row promotes it to primary', (
      tester,
    ) async {
      // Default primary: [dives, sites, trips]; first overflow = equipment.
      final repo = await pumpPage(tester);

      await tester.tap(find.byTooltip('Move Equipment up'));
      await tester.pumpAndSettle();

      // Equipment should now be primary; trips (the last default primary)
      // should drop to overflow.
      expect(repo.navPrimaryIds!.take(3), contains('equipment'));
      expect(repo.navPrimaryIds!.take(3), isNot(contains('trips')));
    });

    testWidgets('move-down on last primary row demotes it to overflow', (
      tester,
    ) async {
      // Default primary: [dives, sites, trips]; last primary = trips.
      final repo = await pumpPage(tester);

      await tester.tap(find.byTooltip('Move Trips down'));
      await tester.pumpAndSettle();

      expect(repo.navPrimaryIds!.take(3), contains('equipment'));
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

      await tester.tap(find.byTooltip('Move Tracks up'));
      await tester.pumpAndSettle();

      expect(repo.navPrimaryIds, isNotNull);
      expect(
        repo.navPrimaryIds!.length,
        withLegacyNavIds(movableNavIds).length,
      );
      // 'tracks' sits second-to-last canonically; moving it up must move it
      // ahead of 'transfer' while both stay in the overflow tail.
      final order = repo.navPrimaryIds!;
      expect(order.indexOf('tracks'), lessThan(order.indexOf('transfer')));
      expect(order.take(3).toList(), kDefaultPrimaryIds);
    });

    testWidgets('a desktop reorder writes the rail key only', (tester) async {
      final repo = await pumpPage(tester, wide: true);

      await tester.tap(find.byIcon(Icons.arrow_downward).first);
      await tester.pumpAndSettle();

      expect(repo.navRailIds, isNotNull);
      expect(repo.navRailIds!.take(2).toList(), ['sites', 'dives']);
      expect(repo.navRailIds!.length, withLegacyNavIds(movableNavIds).length);
      // The phone order must not have been touched.
      expect(repo.navPrimaryIds, isNull);
    });

    testWidgets('a late failure does not undo a newer saved edit', (
      tester,
    ) async {
      final repo = _FirstWriteFailsLateRepo();
      await pumpPage(tester, repo: repo);

      // Edit A: Dives down. Its save hangs, then fails.
      await tester.tap(find.byIcon(Icons.arrow_downward).at(0));
      await tester.pump();
      // Edit B: Trips down, from A's order. Its save succeeds.
      await tester.tap(find.byIcon(Icons.arrow_downward).at(2));
      await tester.pumpAndSettle();
      final saved = List<String>.from(repo.navPrimaryIds!);

      repo.gate.complete();
      await tester.pumpAndSettle();

      expect(
        find.text('Could not save navigation layout. Please try again.'),
        findsOneWidget,
      );
      // The screen shows what is saved (B), not the order before A.
      expect(_firstRowId(tester), saved.first);
      expect(saved.first, 'sites');
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

    group('always-hide-labels switch (#1424)', () {
      testWidgets('defaults to off', (tester) async {
        await pumpPage(tester);

        final tile = tester.widget<SwitchListTile>(
          find.byKey(const ValueKey('navAlwaysHideLabelsSwitch')),
        );
        expect(tile.value, isFalse);
      });

      testWidgets('reflects a stored on value', (tester) async {
        final repo = FakeAppSettingsRepository();
        await repo.setNavAlwaysHideLabelsPhone(true);
        await pumpPage(tester, repo: repo);

        final tile = tester.widget<SwitchListTile>(
          find.byKey(const ValueKey('navAlwaysHideLabelsSwitch')),
        );
        expect(tile.value, isTrue);
      });

      testWidgets('tapping it persists the new value', (tester) async {
        final repo = await pumpPage(tester);

        await tester.tap(
          find.byKey(const ValueKey('navAlwaysHideLabelsSwitch')),
        );
        await tester.pumpAndSettle();

        expect(await repo.getNavAlwaysHideLabelsPhone(), isTrue);
        final tile = tester.widget<SwitchListTile>(
          find.byKey(const ValueKey('navAlwaysHideLabelsSwitch')),
        );
        expect(tile.value, isTrue);
      });

      testWidgets('a failed save reports the error and keeps the old value', (
        tester,
      ) async {
        final repo = _AlwaysHideLabelsWriteFailsRepo();
        await pumpPage(tester, repo: repo);

        await tester.tap(
          find.byKey(const ValueKey('navAlwaysHideLabelsSwitch')),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Something went wrong. Please try again.'),
          findsOneWidget,
        );
        final tile = tester.widget<SwitchListTile>(
          find.byKey(const ValueKey('navAlwaysHideLabelsSwitch')),
        );
        expect(tile.value, isFalse);
      });

      testWidgets('a failed read hides the switch but the rest of the page '
          'still renders', (tester) async {
        final repo = FakeAppSettingsRepository()
          ..throwOnRead = StateError('read failed');
        await pumpPage(tester, repo: repo);

        // The switch's AsyncValue.when has no data to build a tile from, and
        // this shows the error branch renders nothing rather than crashing.
        expect(
          find.byKey(const ValueKey('navAlwaysHideLabelsSwitch')),
          findsNothing,
        );
        // The rest of the page is unaffected by the failed read.
        expect(find.byKey(const ValueKey('navScopeSegments')), findsOneWidget);
      });

      group('phone and desktop are independent (#3222)', () {
        testWidgets('each tab shows its own stored value', (tester) async {
          final repo = FakeAppSettingsRepository();
          await repo.setNavAlwaysHideLabelsPhone(true);
          await repo.setNavAlwaysHideLabelsDesktop(false);
          await pumpPage(tester, repo: repo);

          expect(
            tester
                .widget<SwitchListTile>(
                  find.byKey(const ValueKey('navAlwaysHideLabelsSwitch')),
                )
                .value,
            isTrue,
          );

          await tester.tap(find.text('Desktop'));
          await tester.pumpAndSettle();

          expect(
            tester
                .widget<SwitchListTile>(
                  find.byKey(const ValueKey('navAlwaysHideLabelsSwitch')),
                )
                .value,
            isFalse,
          );
        });

        testWidgets('toggling on the phone tab leaves desktop untouched', (
          tester,
        ) async {
          final repo = await pumpPage(tester);

          await tester.tap(
            find.byKey(const ValueKey('navAlwaysHideLabelsSwitch')),
          );
          await tester.pumpAndSettle();

          expect(await repo.getNavAlwaysHideLabelsPhone(), isTrue);
          expect(await repo.getNavAlwaysHideLabelsDesktop(), isFalse);
        });

        testWidgets('toggling on the desktop tab leaves phone untouched', (
          tester,
        ) async {
          final repo = await pumpPage(tester, wide: true);

          await tester.tap(
            find.byKey(const ValueKey('navAlwaysHideLabelsSwitch')),
          );
          await tester.pumpAndSettle();

          expect(await repo.getNavAlwaysHideLabelsDesktop(), isTrue);
          expect(await repo.getNavAlwaysHideLabelsPhone(), isFalse);
        });

        testWidgets('the subtitle differs between phone and desktop', (
          tester,
        ) async {
          await pumpPage(tester);
          expect(
            find.text('Icons only, even where labels would normally fit'),
            findsOneWidget,
          );

          await tester.tap(find.text('Desktop'));
          await tester.pumpAndSettle();

          expect(
            find.text(
              'Starting state of the sidebar; the collapse arrow can still '
              'expand or collapse it for this session',
            ),
            findsOneWidget,
          );
        });
      });
    });

    group('nav shortcuts (#2936)', () {
      Future<void> addBlender(WidgetTester tester) async {
        await tester.tap(find.text('Add shortcut'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'blender');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Trimix blender'));
        await tester.pumpAndSettle();
      }

      testWidgets('Add shortcut inserts it right after Home', (tester) async {
        final repo = await pumpPage(tester);
        await addBlender(tester);

        expect(repo.navPrimaryIds!.first, 'shortcut:gas-blender');
        expect(
          find.byKey(const ValueKey('nav-item-shortcut:gas-blender')),
          findsOneWidget,
        );
        // Its parent is its subtitle, as in the More sheet.
        expect(find.text('Gas Calculators'), findsOneWidget);
      });

      testWidgets('adding on Phone leaves the Desktop order alone', (
        tester,
      ) async {
        final repo = await pumpPage(tester);
        await addBlender(tester);

        expect(repo.navRailIds, isNull);
      });

      testWidgets('adding on Desktop writes the rail order', (tester) async {
        final repo = await pumpPage(tester, wide: true);
        await addBlender(tester);

        expect(repo.navRailIds!.first, 'shortcut:gas-blender');
        expect(repo.navPrimaryIds, isNull);
      });

      testWidgets('a shortcut row can be removed', (tester) async {
        final repo = FakeAppSettingsRepository()
          ..navPrimaryIds = ['shortcut:gas-blender'];
        await pumpPage(tester, repo: repo);
        // The row previews the nav, so it names the short nav label.
        await tester.tap(find.byTooltip('Remove Blender'));
        await tester.pumpAndSettle();

        expect(repo.navPrimaryIds, isNot(contains('shortcut:gas-blender')));
        expect(
          find.byKey(const ValueKey('nav-item-shortcut:gas-blender')),
          findsNothing,
        );
      });

      testWidgets('built-in rows have no remove button', (tester) async {
        await pumpPage(tester);
        expect(find.byTooltip('Remove Dives'), findsNothing);
      });

      testWidgets('a failed add rolls back and reports it', (tester) async {
        await pumpPage(tester, repo: _WriteFailsRepo());
        await addBlender(tester);

        expect(
          find.text('Could not save navigation layout. Please try again.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('nav-item-shortcut:gas-blender')),
          findsNothing,
        );
      });

      testWidgets('Reset clears shortcuts', (tester) async {
        final repo = FakeAppSettingsRepository()
          ..navPrimaryIds = ['shortcut:gas-blender'];
        await pumpPage(tester, repo: repo);
        await tester.tap(find.text('Reset to defaults'));
        await tester.pumpAndSettle();

        expect(repo.navPrimaryIds, isNot(contains('shortcut:gas-blender')));
      });
    });

    group('short screens (#3370)', () {
      // A phone-sized window: too short to show every row at once.
      const shortHeight = 640.0;

      testWidgets('dragging the list scrolls the settings above it too', (
        tester,
      ) async {
        await pumpPage(tester, height: shortHeight);

        final switchTile = find.byKey(
          const ValueKey('navAlwaysHideLabelsSwitch'),
        );
        final switchTopBefore = tester.getTopLeft(switchTile).dy;

        // Start on the row's leading icon, well clear of its drag handle, so
        // this is a scroll and not a reorder.
        final row = find.byKey(ValueKey('nav-item-${_firstRowId(tester)}'));
        await tester.dragFrom(
          tester.getTopLeft(row) + const Offset(24, 24),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();

        // Page and list share one scroll axis, so the rows can use the whole
        // screen height instead of the gap between fixed blocks.
        expect(
          tester.getTopLeft(switchTile).dy,
          lessThan(switchTopBefore - 150),
        );
      });

      testWidgets('a shortcut added from the bottom scrolls into view', (
        tester,
      ) async {
        await pumpPage(tester, height: shortHeight);

        // The button is past the last row, so reaching it scrolls Home and
        // the top of the list off screen.
        final add = find.widgetWithText(TextButton, 'Add shortcut');
        await tester.scrollUntilVisible(
          add.hitTestable(),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(add);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'blender');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Trimix blender'));
        await tester.pumpAndSettle();

        // The new row lands right after Home; without scrolling back up the
        // diver would see nothing change.
        expect(
          find
              .byKey(const ValueKey('nav-item-shortcut:gas-blender'))
              .hitTestable(),
          findsOneWidget,
        );
      });

      testWidgets('holding a drag at the bottom edge auto-scrolls the page', (
        tester,
      ) async {
        final repo = await pumpPage(tester, height: shortHeight);

        final firstId = _firstRowId(tester);
        final handle = find.descendant(
          of: find.byKey(ValueKey('nav-item-$firstId')),
          matching: find.byIcon(Icons.drag_handle),
        );
        final start = tester.getCenter(handle);

        // Carry the row to the bottom edge of the screen in small steps, then
        // hold it there so the edge auto-scroller runs.
        final gesture = await tester.startGesture(start);
        await tester.pump();
        const steps = 30;
        final stepY = (shortHeight - 8 - start.dy) / steps;
        for (var i = 0; i < steps; i++) {
          await gesture.moveBy(Offset(0, stepY));
          await tester.pump(const Duration(milliseconds: 16));
        }
        for (var i = 0; i < 200; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pumpAndSettle();

        // The row travels past everything that was on screen at the start:
        // only an auto-scrolling drag can drop it at the end of the list.
        expect(repo.navPrimaryIds!.last, firstId);
      });

      testWidgets('a drag on the handle still reorders below the header', (
        tester,
      ) async {
        final repo = await pumpPage(tester, height: shortHeight);

        // The header now sits in the same scroll view as the rows, so check
        // the drag handle still maps to the right item.
        final firstId = _firstRowId(tester);
        final firstRow = find.byKey(ValueKey('nav-item-$firstId'));
        final handle = find.descendant(
          of: firstRow,
          matching: find.byIcon(Icons.drag_handle),
        );
        final rowHeight = tester.getSize(firstRow).height;

        final gesture = await tester.startGesture(tester.getCenter(handle));
        await tester.pump();
        // Small steps, so the drag passes touch slop before it travels.
        for (var i = 0; i < 15; i++) {
          await gesture.moveBy(Offset(0, rowHeight / 10));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pumpAndSettle();

        // The dragged row, not a neighbour, is the one that moved down.
        expect(_firstRowId(tester), isNot(firstId));
        expect(repo.navPrimaryIds!.indexOf(firstId), greaterThan(0));
      });

      testWidgets(
        'the actions scroll with the rows instead of staying pinned',
        (tester) async {
          await pumpPage(tester, height: shortHeight);

          final reset = find.widgetWithText(TextButton, 'Reset to defaults');
          // Not pinned to the bottom of the screen at the start ...
          expect(reset.hitTestable(), findsNothing);

          // ... but reached by scrolling past the last row and the More row.
          await tester.scrollUntilVisible(
            reset.hitTestable(),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(reset.hitTestable(), findsOneWidget);
          expect(
            tester.getTopLeft(reset).dy,
            greaterThan(tester.getTopLeft(find.text('More')).dy),
          );
        },
      );
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

/// Fake whose always-hide-labels writes always fail, so the switch's error
/// path runs on either tab.
class _AlwaysHideLabelsWriteFailsRepo extends FakeAppSettingsRepository {
  @override
  Future<void> setNavAlwaysHideLabelsPhone(bool value) async =>
      throw StateError('write failed');

  @override
  Future<void> setNavAlwaysHideLabelsDesktop(bool value) async =>
      throw StateError('write failed');
}

/// Holds the first nav write open until [gate] completes, then fails it;
/// every later write succeeds.
class _FirstWriteFailsLateRepo extends FakeAppSettingsRepository {
  final gate = Completer<void>();
  int _writes = 0;

  @override
  Future<void> setNavPrimaryIds(List<String> ids) async {
    _writes++;
    if (_writes == 1) {
      await gate.future;
      throw StateError('write failed');
    }
    navPrimaryIds = List<String>.from(ids);
  }
}
