import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/models/entry_exit_suggestion.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_access_card_editors.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

import 'site_editor_harness.dart';

/// The site's Hazards and Access cards edited in place (issue #4527,
/// phase 2, plan 2).
void main() {
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
}
