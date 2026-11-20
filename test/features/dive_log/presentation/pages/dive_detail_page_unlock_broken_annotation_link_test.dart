import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/data/repositories/annotation_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// A link in Notes whose markup the diver broke would read at Save as its
/// annotation removed, and the annotation went without a word (#4815). The
/// Notes card says so and holds Save until the link is mended or deleted.
void main() {
  final l = AppLocalizationsEn();
  late Dive linked;

  setUp(() async {
    await setUpTestDatabase();
    await DiveRepository().createDive(dive.copyWith(notes: 'Calm'));
    await AnnotationRepository().addAnnotation(
      diveId: dive.id,
      timestamp: 120,
      words: 'Vomit',
    );
    linked = (await DiveRepository().getDiveById(dive.id))!;
  });
  tearDown(tearDownTestDatabase);

  final field = find.descendant(
    of: find.byType(MarkdownNotesField),
    matching: find.byType(TextFormField),
  );

  Future<FakeSave> breakTheLink(WidgetTester tester) async {
    final page = await pumpPage(
      tester,
      stored: linked,
      visible: const {DiveDetailSectionId.notes},
    );
    await unlock(tester);
    await openNotes(tester);
    // The link's closing parenthesis deleted.
    await tester.enterText(
      field,
      linked.notes.substring(0, linked.notes.length - 1),
    );
    await settle(tester);
    return page.save;
  }

  testWidgets('the Notes card says the link is broken as it breaks', (
    tester,
  ) async {
    await breakTheLink(tester);

    expect(find.text(l.diveLog_annotation_brokenLink), findsOneWidget);
  });

  testWidgets('Save is held, and nothing is written', (tester) async {
    final save = await breakTheLink(tester);

    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(save.calls, isEmpty);
    expect(find.byType(MarkdownNotesField), findsOneWidget);
    expect(find.text(l.diveLog_annotation_brokenLink), findsOneWidget);
    expect(
      (await tester.runAsync(
        () => AnnotationRepository().annotationsForDive(dive.id),
      ))!.single.description,
      'Vomit',
    );
  });

  testWidgets('Done keeps the card open while the link is broken', (
    tester,
  ) async {
    await breakTheLink(tester);

    await tester.tap(find.text('Done'));
    await settle(tester);

    expect(find.byType(MarkdownNotesField), findsOneWidget);
    expect(find.text(l.diveLog_annotation_brokenLink), findsOneWidget);
  });

  testWidgets('the link mended, the message goes and Save goes through', (
    tester,
  ) async {
    final save = await breakTheLink(tester);

    await tester.enterText(field, '${linked.notes} Choppy');
    await settle(tester);
    expect(find.text(l.diveLog_annotation_brokenLink), findsNothing);

    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(save.calls, hasLength(1));
  });
}
