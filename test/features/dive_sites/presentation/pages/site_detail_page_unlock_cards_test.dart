import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/presentation/editing/site_access_card_editors.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import 'site_detail_page_unlock_harness.dart';

/// The site page frames every card it can edit, offers the empty ones in
/// the Add strip, and fades the calculated ones while unlocked (issue
/// #4527, phase 2, plan 2).
void main() {
  final l = AppLocalizationsEn();
  final hazards = l.diveSites_detail_section_hazards;

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  Finder chip(String label) =>
      find.descendant(of: find.byType(AddStrip), matching: find.text(label));

  Future<void> openCard(WidgetTester tester, String title) async {
    final pencil = find.byTooltip(l.recordEdit_editCardTooltip(title));
    await tester.ensureVisible(pencil);
    await tester.tap(pencil);
    await tester.pumpAndSettle();
  }

  Future<void> done(WidgetTester tester, String title) async {
    // The open card is the innermost card holding the title.
    final doneButton = find.descendant(
      of: find.widgetWithText(Card, title).last,
      matching: find.text(l.common_action_done),
    );
    await tester.ensureVisible(doneButton);
    await tester.tap(doneButton);
    await tester.pumpAndSettle();
  }

  testWidgets('an empty card is offered in the strip and opens in place', (
    tester,
  ) async {
    await pumpSitePage(tester);
    await unlock(tester);

    expect(chip(hazards), findsOneWidget);
    await tester.ensureVisible(chip(hazards));
    await tester.pumpAndSettle();
    await tester.tap(chip(hazards));
    await tester.pumpAndSettle();

    expect(find.byType(SiteHazardsCardEditor), findsOneWidget);
    expect(chip(hazards), findsNothing);
  });

  testWidgets('a card emptied and closed returns to the strip and Save '
      'writes the clear', (tester) async {
    final page = await pumpSitePage(
      tester,
      site: harnessSite.copyWith(hazards: 'Current'),
    );
    await unlock(tester);
    expect(chip(hazards), findsNothing);

    await openCard(tester, hazards);
    await tester.enterText(
      find.descendant(
        of: find.byType(SiteHazardsCardEditor),
        matching: find.byType(EditableText),
      ),
      '',
    );
    await tester.pumpAndSettle();
    await done(tester, hazards);

    expect(find.byType(SiteHazardsCardEditor), findsNothing);
    expect(chip(hazards), findsOneWidget);

    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
    expect(page.save.calls.single.apply(page.stored).hazards, isNull);
  });

  testWidgets('a name emptied outside its editor refuses Save', (tester) async {
    final page = await pumpSitePage(tester);
    await unlock(tester);
    // Any route that empties the name with the header block closed: the
    // card's own check is asked at Save, as every card's is.
    final controller = RecordEditScope.maybeOf<DiveSite>(
      tester.element(find.byType(RecordCardFrame<DiveSite>).first),
    )!;
    controller.session!.set(siteNameField, '');
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();

    expect(page.save.calls, isEmpty);
  });

  testWidgets('calculated cards fade while unlocked', (tester) async {
    await pumpSitePage(tester);
    expect(find.text(l.recordEdit_calculated), findsNothing);

    await unlock(tester);

    expect(find.text(l.recordEdit_calculated), findsWidgets);
  });

  testWidgets('no card comes or goes above an open editor', (tester) async {
    await pumpSitePage(tester, site: harnessSite.copyWith(hazards: 'Current'));
    await unlock(tester);
    // Notes stays open below while the hazards are cleared above it.
    await openCard(tester, l.diveSites_detail_section_notes);
    await openCard(tester, hazards);
    await tester.enterText(
      find.descendant(
        of: find.byType(SiteHazardsCardEditor),
        matching: find.byType(EditableText),
      ),
      '',
    );
    await tester.pumpAndSettle();
    await done(tester, hazards);

    // Held in place while Notes is open.
    expect(find.text(hazards), findsWidgets);
    expect(chip(hazards), findsNothing);

    await done(tester, l.diveSites_detail_section_notes);
    expect(chip(hazards), findsOneWidget);
  });
}
