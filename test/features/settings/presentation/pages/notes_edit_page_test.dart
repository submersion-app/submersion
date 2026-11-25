import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/features/settings/presentation/pages/notes_edit_page.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import '../../../../helpers/test_database.dart';
import 'diver_profile_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  Future<void> pump(WidgetTester tester, {String notes = ''}) async {
    await seedDiver(profileDiver(notes: notes));
    await pumpProfilePage(tester, path: 'notes', page: const NotesEditPage());
  }

  Future<void> typeNotes(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
  }

  Future<String> savedNotes() async => (await storedDiver('diver-1'))!.notes;

  testWidgets('populates the notes field from the existing diver', (
    tester,
  ) async {
    await pump(tester, notes: 'Prefers early morning boat dives');

    expect(find.text('Notes'), findsWidgets);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Prefers early morning boat dives'), findsOneWidget);
    expect(await sittings(db), isEmpty);
  });

  testWidgets('saving persists the trimmed notes onto the diver', (
    tester,
  ) async {
    await pump(tester);

    await typeNotes(tester, '  Nitrox refresher due in spring  ');
    await tapBar(tester, 'Save');

    expect(await savedNotes(), 'Nitrox refresher due in spring');
  });

  testWidgets('clearing existing notes persists an empty string', (
    tester,
  ) async {
    await pump(tester, notes: 'Old note');

    await typeNotes(tester, '');
    await tapBar(tester, 'Save');

    expect(await savedNotes(), isEmpty);
  });

  testWidgets('the bar is the tinted Cancel and Save bar, with no back arrow', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('an untouched page has Save disabled and Back asks nothing', (
    tester,
  ) async {
    await pump(tester, notes: 'Old note');

    expect(barAction(tester, 'Save').onPressed, isNull);
    await back(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Hub'), findsOneWidget);
  });

  testWidgets('Back after a change asks; Discard returns to the hub', (
    tester,
  ) async {
    await pump(tester);
    await typeNotes(tester, 'New note');

    await back(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Hub'), findsOneWidget);
    expect(await savedNotes(), isEmpty);
  });

  testWidgets('Save writes one change log operation labelled with the diver', (
    tester,
  ) async {
    await pump(tester);
    await typeNotes(tester, 'New note');
    await tapBar(tester, 'Save');

    final written = await sittings(db);
    expect(written, hasLength(1));
    expect(written.single.table, 'divers');
    expect(written.single.id, 'diver-1');
  });

  testWidgets('notes typed back to the stored text are no change', (
    tester,
  ) async {
    await pump(tester, notes: 'Old note');

    await typeNotes(tester, 'Old notes');
    expect(barAction(tester, 'Save').onPressed, isNotNull);
    await typeNotes(tester, 'Old note');
    expect(barAction(tester, 'Save').onPressed, isNull);
  });
}
