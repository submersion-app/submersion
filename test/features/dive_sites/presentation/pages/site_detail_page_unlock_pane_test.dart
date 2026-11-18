import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
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

  group('the list\'s edit pane', () {
    Widget pane(BuildContext context, {required bool unlockEditing}) =>
        siteEditPane(
          context,
          's1',
          (_) {},
          () {},
          unlockEditing: unlockEditing,
        );

    testWidgets('with the switch on is the site page opened unlocked', (
      tester,
    ) async {
      late Widget built;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            built = pane(context, unlockEditing: true);
            return const SizedBox();
          },
        ),
      );

      expect(built, isA<SiteDetailPage>());
      final page = built as SiteDetailPage;
      expect(page.embedded, isTrue);
      expect(page.openUnlocked, isTrue);
      expect(page.onSittingEnded, isNotNull);
    });

    testWidgets('with the switch off is the form', (tester) async {
      late Widget built;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            built = pane(context, unlockEditing: false);
            return const SizedBox();
          },
        ),
      );

      expect(built, isA<SiteEditPage>());
    });
  });
}
