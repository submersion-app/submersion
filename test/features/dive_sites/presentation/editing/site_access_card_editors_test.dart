import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/models/entry_exit_suggestion.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_access_card_editors.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

import 'site_editor_harness.dart';

/// The site's Hazards and Access cards edited in place (issue #4527,
/// phase 2, plan 2).
void main() {
  final l = AppLocalizationsEn();
  const site = DiveSite(id: 's1', name: 'Hole');

  Future<SiteEditorHarness> pumpAccess(
    WidgetTester tester, {
    DiveSite s = site,
    EntryExitSuggestion? suggestion,
  }) => pumpSiteEditor(
    tester,
    s,
    (session) => SiteAccessCardEditor(session: session),
    overrides: [
      siteEntryExitSuggestionProvider(
        s.id,
      ).overrideWith((_) async => suggestion),
    ],
  );

  testWidgets('hazards write through', (tester) async {
    final h = await pumpSiteEditor(
      tester,
      site,
      (session) => SiteHazardsCardEditor(session: session),
    );

    await tester.enterText(find.byType(EditableText), 'Strong current');
    await tester.pump();

    expect(h.session.valueOf(siteHazardsField), 'Strong current');
    await tester.enterText(find.byType(EditableText), '  ');
    await tester.pump();
    expect(h.session.valueOf(siteHazardsField), isNull);
  });

  testWidgets('access notes edit as Markdown', (tester) async {
    await pumpAccess(tester);

    final notes = tester
        .widgetList<SuggestionFormRow>(find.byType(SuggestionFormRow))
        .where((row) => row.markdown);
    expect(notes, hasLength(1));
  });

  testWidgets('the entry suggestion fills both methods on a tap', (
    tester,
  ) async {
    final h = await pumpAccess(
      tester,
      suggestion: const EntryExitSuggestion(
        entry: EntryMethod.shore,
        exit: EntryMethod.ladder,
        count: 3,
      ),
    );

    await tester.tap(find.byType(ActionChip));
    await tester.pump();

    expect(h.session.valueOf(siteEntryMethodsField), [EntryMethod.shore]);
    expect(h.session.valueOf(siteExitMethodsField), [EntryMethod.ladder]);
    // Gone once either method is set.
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('no entry suggestion once a method is set', (tester) async {
    await pumpAccess(
      tester,
      s: site.copyWith(entryMethods: const [EntryMethod.boat]),
      suggestion: const EntryExitSuggestion(
        entry: EntryMethod.shore,
        exit: null,
        count: 3,
      ),
    );

    expect(find.byType(ActionChip), findsNothing);
  });

  // The entry and exit method rows, as the site form had them (plan 7).
  testWidgets('the card shows the entry and exit method rows', (tester) async {
    await pumpAccess(tester);

    expect(find.text(l.diveSites_edit_access_entryMethod_label), findsOne);
    expect(find.text(l.diveSites_edit_access_exitMethod_label), findsOne);
  });

  testWidgets("a site's every entry and exit method shows on its row", (
    tester,
  ) async {
    await pumpAccess(
      tester,
      s: const DiveSite(
        id: 's1',
        name: 'Hole',
        entryMethods: [EntryMethod.backRoll, EntryMethod.giantStride],
        exitMethods: [EntryMethod.ladder, EntryMethod.platform],
      ),
    );

    expect(find.text('Back Roll, Giant Stride'), findsOneWidget);
    expect(find.text('Ladder, Platform'), findsOneWidget);
  });

  testWidgets("ticking methods holds every one, in the list's order", (
    tester,
  ) async {
    final h = await pumpAccess(tester);

    Future<void> tick(String row, List<String> methods) async {
      await tester.tap(find.text(row));
      await tester.pumpAndSettle();
      for (final method in methods) {
        await tester.tap(find.widgetWithText(CheckboxListTile, method));
        await tester.pumpAndSettle();
      }
      Navigator.of(tester.element(find.byType(CheckboxListTile).first)).pop();
      await tester.pumpAndSettle();
    }

    await tick(l.diveSites_edit_access_entryMethod_label, [
      'Giant Stride',
      'Back Roll',
    ]);
    await tick(l.diveSites_edit_access_exitMethod_label, ['Shore']);

    expect(h.session.valueOf(siteEntryMethodsField), [
      EntryMethod.backRoll,
      EntryMethod.giantStride,
    ]);
    expect(h.session.valueOf(siteExitMethodsField), [EntryMethod.shore]);
    expect(h.session.changedCardIds, contains('access'));
  });

  // The null branch of the suggestion: an empty site with no dives to
  // suggest from shows its method rows and no chip.
  testWidgets('no suggestion offers no chip', (tester) async {
    await pumpAccess(tester);
    await tester.pumpAndSettle();

    expect(find.text(l.diveSites_edit_access_entryMethod_label), findsOne);
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('a suggestion with no exit names the entry alone', (
    tester,
  ) async {
    await pumpAccess(
      tester,
      suggestion: const EntryExitSuggestion(
        entry: EntryMethod.shore,
        exit: null,
        count: 3,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(l.diveSites_edit_access_entrySuggestionEntryOnly(3, 'Shore')),
      findsOneWidget,
    );
  });
}
