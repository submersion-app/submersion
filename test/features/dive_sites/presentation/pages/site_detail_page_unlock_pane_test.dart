import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_routes.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_pane_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_pane_row.dart';

import 'site_detail_page_unlock_harness.dart';

/// The site list's pane holds the site's sitting as the full page does
/// (issue #4527, phase 2): its own lock, the shared pane header while
/// unlocked, and `&mode=edit` opening the site unlocked, not the form.
void main() {
  final l = AppLocalizationsEn();

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  testWidgets('the pane unlocks under the shared pane header', (tester) async {
    await pumpSitePage(tester, embedded: true);
    await unlock(tester);

    expect(find.byType(RecordEditPaneHeader), findsOneWidget);
    expect(find.text(l.recordEdit_editingTitle('Blue Hole')), findsOneWidget);
    // Laid over the locked row, which keeps its place.
    expect(find.byType(RecordPaneRow), findsOneWidget);
  });

  testWidgets("the pane's Save writes one sitting and locks", (tester) async {
    final page = await pumpSitePage(tester, embedded: true);
    await unlock(tester);
    await tester.ensureVisible(find.text(l.diveSites_detail_section_notes));
    await tester.tap(find.text(l.diveSites_detail_section_notes));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Choppy');
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();

    expect(page.save.calls, hasLength(1));
    expect(page.save.calls.single.apply(page.stored).notes, 'Choppy');
    expect(find.byType(RecordEditPaneHeader), findsNothing);
  });

  testWidgets('opened by mode=edit, Cancel returns the pane to view mode', (
    tester,
  ) async {
    var ended = 0;
    await pumpSitePage(
      tester,
      embedded: true,
      openUnlocked: true,
      onSittingEnded: () => ended++,
    );
    expect(find.byType(RecordEditPaneHeader), findsOneWidget);

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();

    expect(ended, 1);
    expect(find.byType(RecordEditPaneHeader), findsNothing);
  });

  testWidgets('a locked pane offers no way to change the site', (tester) async {
    final page = await pumpSitePage(tester, embedded: true);

    expect(find.byType(RecordPencilIcon), findsNothing);
    // The strip is there, keeping the layout, but offers nothing.
    expect(tester.widget<AddStrip>(find.byType(AddStrip)).entries, isEmpty);
    expect(find.byTooltip(l.media_diveMediaSection_addTooltip), findsNothing);
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text(l.recordEdit_unlockToUseThese), findsOneWidget);
    expect(page.save.calls, isEmpty);
  });

  // The lock is the one way in (issue #4527, phase 2, plan 7): no Edit
  // pencil beside it on the pane's row.
  testWidgets('the locked pane row has the lock and no Edit pencil', (
    tester,
  ) async {
    await pumpSitePage(tester, embedded: true);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.edit), findsNothing);
  });

  // The locked row stays laid out, unseen, under the unlocked one: each has
  // its own display-options anchor, so the menu in view opens its panel,
  // unlocked and locked again alike.
  testWidgets('Display options opens from the pane menu in view, unlocked '
      'and locked again', (tester) async {
    await pumpSitePage(tester, embedded: true);

    Future<void> openDisplayOptions() async {
      await tester.tap(find.byIcon(Icons.more_vert).hitTestable().first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.diveLog_detail_displayOptions_tooltip));
      await tester.pumpAndSettle();
      expect(find.byType(ReorderableListView), findsOneWidget);
      // A tap outside the panel closes it.
      await tester.tapAt(const Offset(4, 1396));
      await tester.pumpAndSettle();
      expect(find.byType(ReorderableListView), findsNothing);
    }

    await openDisplayOptions();
    await unlock(tester);
    await openDisplayOptions();
    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();
    await openDisplayOptions();
  });

  // On a device that attaches media the locked pane's Media card still
  // offers no Add: the pane holds the sitting's scope, which makes the
  // card read only until it is unlocked and opened.
  group('on a device that attaches media', () {
    final attaches = [
      deviceCapabilitiesProvider.overrideWithValue(
        currentDeviceCapabilities().copyWith(mediaAttach: true),
      ),
    ];
    final addMedia = find.byTooltip(l.media_diveMediaSection_addTooltip);

    testWidgets('a locked pane offers no media Add', (tester) async {
      await pumpSitePage(tester, embedded: true, extra: attaches);
      await tester.scrollUntilVisible(
        find.text(l.diveSites_detail_section_notes),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(addMedia, findsNothing);
    });
  });

  group('the list\'s edit pane', () {
    var cancelled = 0;
    Widget pane(BuildContext context) =>
        siteEditPane(context, 's1', (_) {}, () => cancelled++);

    testWidgets('is the site page opened unlocked', (tester) async {
      late Widget built;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            built = pane(context);
            return const SizedBox();
          },
        ),
      );

      expect(built, isA<SiteDetailPage>());
      final page = built as SiteDetailPage;
      expect(page.embedded, isTrue);
      expect(page.openUnlocked, isTrue);
      // The end of its sitting returns the pane to view mode.
      page.onSittingEnded!();
      expect(cancelled, 1);
    });
  });

  // Inside the dive list's pane the site's back arrow returns to the dive.
  // While unlocked the pane header lies over it, so leaving an open sitting
  // goes through Cancel, which asks first with unsaved changes (issue
  // #4527).
  group("the back arrow in the dive list's pane", () {
    final backArrow = find.byTooltip(l.common_action_back);

    testWidgets('is under the pane header while unlocked', (tester) async {
      var closed = 0;
      await pumpSitePage(
        tester,
        embedded: true,
        onClose: () => closed++,
        openUnlocked: true,
      );

      expect(backArrow.hitTestable(), findsNothing);
      expect(closed, 0);
    });

    testWidgets('with unsaved changes, Cancel asks before the arrow shows', (
      tester,
    ) async {
      var closed = 0;
      final page = await pumpSitePage(
        tester,
        embedded: true,
        onClose: () => closed++,
        openUnlocked: true,
      );
      await tester.ensureVisible(find.text(l.diveSites_detail_section_notes));
      await tester.tap(find.text(l.diveSites_detail_section_notes));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, 'Choppy');
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.forms_cancel));
      await tester.pumpAndSettle();
      expect(find.text(l.forms_discard_title), findsOneWidget);
      await tester.tap(find.text(l.forms_discard_discard));
      await tester.pumpAndSettle();

      await tester.tap(backArrow.hitTestable());
      await tester.pumpAndSettle();
      expect(closed, 1);
      expect(page.save.calls, isEmpty);
    });

    testWidgets('locked goes straight back', (tester) async {
      var closed = 0;
      await pumpSitePage(tester, embedded: true, onClose: () => closed++);

      await tester.tap(backArrow.hitTestable());
      await tester.pumpAndSettle();

      expect(find.text(l.forms_discard_title), findsNothing);
      expect(closed, 1);
    });
  });

  group("the dive list's site pane", () {
    var cancelled = 0;
    var closed = 0;
    Widget pane(BuildContext context) => siteInDivesPane(
      context,
      's1',
      onCancel: () => cancelled++,
      onClose: () => closed++,
      onDeleted: () {},
    );

    Future<Widget> build(WidgetTester tester) async {
      late Widget built;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            built = pane(context);
            return const SizedBox();
          },
        ),
      );
      return built;
    }

    testWidgets('is the site opened unlocked, its back '
        'arrow to the dive', (tester) async {
      final built = await build(tester);

      expect(built, isA<SiteDetailPage>());
      final page = built as SiteDetailPage;
      expect(page.embedded, isTrue);
      expect(page.openUnlocked, isTrue);
      // Its back arrow returns to the dive; its sitting's end, to the site
      // in view mode.
      page.onClose!();
      page.onSittingEnded!();
      expect(closed, 1);
      expect(cancelled, 1);
    });
  });
}
