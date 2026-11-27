import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_3d_page.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_align_page.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_detail_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_preview_provider.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_detail_cards.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_marker_layer.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import 'nav_track_detail_page_unlock_harness.dart';

/// The underwater track page edits in place behind the phase 3 switch
/// (issue #4527, plan 5): it opens locked, a sitting holds its name, dive,
/// site, device and correction, and one Save writes them.
void main() {
  final l = AppLocalizationsEn();

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  Future<void> openCard(WidgetTester tester, String title) async {
    await tester.tap(find.byTooltip(l.recordEdit_editCardTooltip(title)));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  Future<void> pickNewSite(WidgetTester tester) async {
    await openCard(tester, l.navTrack_editCard_site);
    await tester.tap(find.byKey(const ValueKey('nav-track-edit-change-site')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(newSite.name));
    await tester.pumpAndSettle();
  }

  Future<void> pickCandidateDive(WidgetTester tester) async {
    await openCard(tester, l.navTrack_editCard_dive);
    await tester.tap(find.byKey(const ValueKey('nav-track-edit-choose-dive')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('#9'));
    await tester.pumpAndSettle();
  }

  /// Unlocked, the 3D views are in the menu (the bar keeps room for the
  /// editing title).
  Future<void> openPreviewFromMenu(WidgetTester tester) async {
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-track-menu-3d-preview')));
  }

  GeoPoint? drawnAnchor(WidgetTester tester) => tester
      .widget<NavTrackMarkerLayer>(find.byType(NavTrackMarkerLayer))
      .route
      .anchor;

  testWidgets('locked, no tap writes and no card offers an action', (
    tester,
  ) async {
    final harness = await pumpNavTrackPage(
      tester,
      route: navRoute(diveId: null),
    );

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byType(RecordPencilIcon), findsNothing);
    expect(find.text(l.navTrack_detail_chooseDive), findsNothing);
    expect(find.text(l.navTrack_detail_menuChangeSite), findsNothing);
    expect(find.text(l.navTrack_detail_chooseDevice), findsNothing);
    await tester.tap(find.text('Morning'));
    await tester.pumpAndSettle();

    expect(harness.repository.writes, isEmpty);
    expect(harness.save.calls, isEmpty);
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets('a rename and a site in one sitting save as one entry and '
      'lock', (tester) async {
    final harness = await pumpNavTrackPage(tester);
    await unlock(tester);
    await openCard(tester, l.changeLog_table_navTrack);
    await tester.enterText(
      find.byKey(const ValueKey('nav-track-name-field')),
      'Evening',
    );
    await tester.pumpAndSettle();
    await pickNewSite(tester);

    await save(tester);

    expect(harness.save.calls, hasLength(1));
    final call = harness.save.calls.single;
    // The anchor followed the old pin, so it follows the new site's pin.
    expect(call.cards, {'header', 'site', 'correction'});
    expect(call.after.name, 'Evening');
    expect(call.after.siteId, 'site-2');
    expect(call.after.anchor, newSite.location);
    expect(harness.repository.writes, isEmpty);
    expect(find.byType(RecordEditBar), findsNothing);
    expect(find.text('Evening'), findsOneWidget);
  });

  testWidgets('the dive changed in a sitting, then Cancel, writes nothing', (
    tester,
  ) async {
    final harness = await pumpNavTrackPage(tester);
    await unlock(tester);
    await pickCandidateDive(tester);
    expect(find.textContaining('#9'), findsWidgets);

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(harness.save.calls, isEmpty);
    expect(harness.repository.writes, isEmpty);
    expect(harness.stored.state!.diveId, 'dive-1');
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets('a dive chosen in a sitting is saved as a change of Dive', (
    tester,
  ) async {
    final harness = await pumpNavTrackPage(tester);
    await unlock(tester);
    await pickCandidateDive(tester);

    await save(tester);

    expect(harness.save.calls.single.cards, {'dive'});
    expect(harness.save.calls.single.after.diveId, 'dive-9');
  });

  testWidgets('unlinking in a sitting is a change of Dive', (tester) async {
    final harness = await pumpNavTrackPage(tester);
    await unlock(tester);
    await openCard(tester, l.navTrack_editCard_dive);
    await tester.tap(find.byKey(const ValueKey('nav-track-edit-unlink')));
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls.single.after.diveId, isNull);
  });

  testWidgets('the map follows a held anchor', (tester) async {
    await pumpNavTrackPage(tester);
    expect(drawnAnchor(tester), oldSite.location);
    await unlock(tester);

    await pickNewSite(tester);

    expect(drawnAnchor(tester), newSite.location);
  });

  testWidgets('the stats and recorder cards fade as calculated', (
    tester,
  ) async {
    await pumpNavTrackPage(tester);
    await unlock(tester);

    expect(find.text(l.recordEdit_calculated), findsWidgets);
  });

  testWidgets('Align in a sitting opens the align page joined to it', (
    tester,
  ) async {
    await pumpNavTrackPage(tester);
    await unlock(tester);

    await tester.tap(find.byKey(const ValueKey('nav-track-align')));
    await tester.pumpAndSettle();

    final page = tester.widget<NavTrackAlignPage>(
      find.byType(NavTrackAlignPage),
    );
    expect(page.joinedSitting, isNotNull);
    expect(find.byKey(const ValueKey('nav-track-align-done')), findsOneWidget);
  });

  testWidgets('Align while locked opens the align page reading only', (
    tester,
  ) async {
    final harness = await pumpNavTrackPage(tester);

    await tester.tap(find.byKey(const ValueKey('nav-track-align')));
    await tester.pumpAndSettle();

    final page = tester.widget<NavTrackAlignPage>(
      find.byType(NavTrackAlignPage),
    );
    expect(page.joinedSitting, isNull);
    expect(find.byKey(const ValueKey('nav-track-align-save')), findsNothing);
    expect(find.byKey(const ValueKey('nav-track-align-done')), findsNothing);
    expect(harness.repository.writes, isEmpty);
  });

  testWidgets("the align page's Done is a change of Correction", (
    tester,
  ) async {
    final harness = await pumpNavTrackPage(tester);
    await unlock(tester);
    await tester.tap(find.byKey(const ValueKey('nav-track-align')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('nav-track-align-trust-slider')),
      const Offset(80, 0),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('nav-track-align-done')));
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.save.calls.single.cards, {'correction'});
    expect(harness.save.calls.single.after.trustFraction, greaterThan(0));
    expect(harness.repository.writes, isEmpty);
  });

  testWidgets('Cancel with changes asks first', (tester) async {
    await pumpNavTrackPage(tester);
    await unlock(tester);
    await openCard(tester, l.changeLog_table_navTrack);
    await tester.enterText(
      find.byKey(const ValueKey('nav-track-name-field')),
      'Evening',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  group('the menu and its whole-record operations', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
    }

    PopupMenuItem<String> item(WidgetTester tester, String key) =>
        tester.widget<PopupMenuItem<String>>(find.byKey(ValueKey(key)));

    testWidgets('the menu offers no Unlink', (tester) async {
      await pumpNavTrackPage(tester);
      await openMenu(tester);

      expect(find.text(l.navTrack_common_unlink), findsNothing);
    });

    testWidgets('locked, Update from file and Delete are off under "Unlock '
        'to use these"', (tester) async {
      await pumpNavTrackPage(tester);
      await openMenu(tester);

      expect(find.text(l.recordEdit_unlockToUseThese), findsOneWidget);
      expect(item(tester, 'nav-track-update-from-file').enabled, isFalse);
      expect(item(tester, 'nav-track-delete').enabled, isFalse);
      expect(item(tester, 'nav-track-export-csv').enabled, isTrue);
    });

    testWidgets('with unsaved changes they are off', (tester) async {
      await pumpNavTrackPage(tester);
      await unlock(tester);
      await openCard(tester, l.changeLog_table_navTrack);
      await tester.enterText(
        find.byKey(const ValueKey('nav-track-name-field')),
        'Evening',
      );
      await tester.pumpAndSettle();
      await openMenu(tester);

      expect(find.text(l.recordEdit_saveOrCancelFirst), findsOneWidget);
      expect(item(tester, 'nav-track-update-from-file').enabled, isFalse);
      expect(item(tester, 'nav-track-delete').enabled, isFalse);
    });

    testWidgets('unlocked and clean, Delete asks, deletes and pops', (
      tester,
    ) async {
      final harness = await pumpNavTrackPage(tester);
      await unlock(tester);
      await openMenu(tester);
      await tester.tap(find.byKey(const ValueKey('nav-track-delete')));
      await tester.pumpAndSettle();
      expect(find.text(l.navTrack_detail_deleteTrackTitle), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();

      expect(harness.repository.writes, ['delete']);
      expect(find.text('first route'), findsOneWidget);
    });

    testWidgets('unlocked and clean, Update from file replaces the points and '
        'keeps the rest', (tester) async {
      final harness = await pumpNavTrackPage(tester);
      await unlock(tester);
      await openMenu(tester);
      await tester.tap(
        find.byKey(const ValueKey('nav-track-update-from-file')),
      );
      await tester.pumpAndSettle();

      expect(harness.import.updates, ['r1']);
      final route = harness.stored.state!;
      expect(route.points, hasLength(12));
      expect(route.name, 'Morning');
      expect(route.diveId, 'dive-1');
      expect(route.siteId, 'site-1');
      // The sitting carries on, on the route as now stored.
      expect(find.byType(RecordEditBar), findsOneWidget);
      expect(find.text('Morning'), findsOneWidget);
    });
  });

  testWidgets('with a held correction the 3D preview draws it and nothing is '
      'written', (tester) async {
    final harness = await pumpNavTrackPage(tester);
    await unlock(tester);
    await pickNewSite(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NavTrackDetailPage)),
    );

    await openPreviewFromMenu(tester);
    await tester.pumpAndSettle();

    expect(find.byType(NavTrack3dPage), findsOneWidget);
    expect(
      container.read(navTrackPreviewProvider('r1'))?.anchor,
      newSite.location,
    );
    expect(harness.repository.writes, isEmpty);
    expect(harness.save.calls, isEmpty);

    Navigator.of(tester.element(find.byType(NavTrack3dPage))).pop();
    await tester.pumpAndSettle();

    expect(container.read(navTrackPreviewProvider('r1')), isNull);
    expect(find.byType(RecordEditBar), findsOneWidget);
  });

  testWidgets('without a held change the 3D preview previews nothing', (
    tester,
  ) async {
    await pumpNavTrackPage(tester);
    await unlock(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NavTrackDetailPage)),
    );

    await openPreviewFromMenu(tester);
    await tester.pumpAndSettle();

    expect(container.read(navTrackPreviewProvider('r1')), isNull);
  });

  testWidgets('a preview left behind goes when the sitting ends', (
    tester,
  ) async {
    await pumpNavTrackPage(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NavTrackDetailPage)),
    );
    await unlock(tester);
    container.read(navTrackPreviewProvider('r1').notifier).state = navRoute();

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();

    expect(find.byType(RecordEditBar), findsNothing);
    expect(container.read(navTrackPreviewProvider('r1')), isNull);
  });

  testWidgets('a preview left behind goes when the page closes', (
    tester,
  ) async {
    await pumpNavTrackPage(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NavTrackDetailPage)),
    );
    await unlock(tester);
    container.read(navTrackPreviewProvider('r1').notifier).state = navRoute();

    Navigator.of(tester.element(find.byType(NavTrackDetailPage))).pop();
    await tester.pumpAndSettle();

    expect(find.text('first route'), findsOneWidget);
    expect(container.read(navTrackPreviewProvider('r1')), isNull);
  });

  testWidgets('locked, the bar keeps its two 3D buttons', (tester) async {
    await pumpNavTrackPage(tester);

    expect(
      find.byKey(const ValueKey('nav-track-open-3d-preview')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('nav-track-open-3d')), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('nav-track-menu-3d-preview')),
      findsNothing,
    );
  });

  testWidgets('unlocked, the 3D views move from the bar into the menu', (
    tester,
  ) async {
    await pumpNavTrackPage(tester);
    await unlock(tester);

    expect(
      find.byKey(const ValueKey('nav-track-open-3d-preview')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('nav-track-open-3d')), findsNothing);
    expect(find.byKey(const ValueKey('nav-track-align')), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('nav-track-menu-3d-preview')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('nav-track-menu-3d')), findsOneWidget);
  });

  testWidgets("the menu's 3D view opens it", (tester) async {
    await pumpNavTrackPage(tester);
    await unlock(tester);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-track-menu-3d-preview')));
    await tester.pumpAndSettle();

    expect(find.byType(NavTrack3dPage), findsOneWidget);
  });

  testWidgets("the menu's 3D views carry the bar buttons' icons", (
    tester,
  ) async {
    await pumpNavTrackPage(tester);
    await unlock(tester);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('nav-track-menu-3d-preview')),
        matching: find.byIcon(Icons.view_in_ar),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('nav-track-menu-3d')),
        matching: find.byIcon(Icons.terrain),
      ),
      findsOneWidget,
    );
  });

  testWidgets('typing a name does not recompute the statistics', (
    tester,
  ) async {
    await pumpNavTrackPage(tester);
    await unlock(tester);
    final before = tester
        .widget<NavTrackStatsCard>(find.byType(NavTrackStatsCard))
        .stats;

    await openCard(tester, l.changeLog_table_navTrack);
    await tester.enterText(
      find.byKey(const ValueKey('nav-track-name-field')),
      'Evening',
    );
    await tester.pumpAndSettle();

    final after = tester
        .widget<NavTrackStatsCard>(find.byType(NavTrackStatsCard))
        .stats;
    expect(after, same(before));
  });

  testWidgets('a failed delete says so and keeps the page', (tester) async {
    final harness = await pumpNavTrackPage(tester);
    harness.repository.deleteFails = true;
    await unlock(tester);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-track-delete')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(harness.repository.writes, isEmpty);
    expect(find.text(l.common_error_tryAgain), findsOneWidget);
    expect(find.text('first route'), findsNothing);
    expect(find.byType(RecordEditBar), findsOneWidget);
  });
}
