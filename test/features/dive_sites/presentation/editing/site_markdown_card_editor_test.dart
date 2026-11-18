import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_edit_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_markdown_card_editor.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// A site's Markdown card (Notes, Description) edited in place, bound to
/// the sitting (issue #4527, phase 2).
void main() {
  const site = DiveSite(id: 's1', name: 'Blue Hole', notes: 'Calm');
  late EditSession<DiveSite> session;

  setUp(() => session = EditSession<DiveSite>(site));
  tearDown(() => session.dispose());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SiteMarkdownCardEditor(session: session, field: siteNotesField),
        ),
      ),
    ),
  );

  Finder field() => find.byType(TextFormField);

  String text(WidgetTester tester) =>
      tester.widget<TextFormField>(field()).controller!.text;

  testWidgets("shows the sitting's value", (tester) async {
    await pump(tester);

    expect(text(tester), 'Calm');
  });

  testWidgets('typing writes through to the sitting', (tester) async {
    await pump(tester);

    await tester.enterText(field(), 'Calm sea');

    expect(session.valueOf(siteNotesField), 'Calm sea');
    expect(session.changedCardIds, {'notes'});
  });

  testWidgets('typing it back leaves the sitting clean', (tester) async {
    await pump(tester);

    await tester.enterText(field(), 'Calm sea');
    await tester.enterText(field(), 'Calm');

    expect(session.isDirty, isFalse);
  });

  testWidgets('follows a stored change it has not touched', (tester) async {
    await pump(tester);

    session.rebase(site.copyWith(notes: 'Flat'));
    await tester.pump();

    expect(text(tester), 'Flat');
  });
}
