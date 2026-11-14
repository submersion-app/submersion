import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_text_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_notes_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tags_card_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_form_block.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

Tag _tag(String id, String name) => Tag(
  id: id,
  diverId: 'diver-1',
  name: name,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  final l = AppLocalizationsEn();
  final dive = createTestDiveWithBottomTime();
  final wreck = _tag('wreck', 'Wreck');
  final night = _tag('night', 'Night');

  group('the dive cards', () {
    test('are Notes and Tags, with ids equal to the section names', () {
      expect(diveEditCards.keys, {
        DiveDetailSectionId.notes,
        DiveDetailSectionId.tags,
      });
      expect(diveEditCards[DiveDetailSectionId.notes]!.id, 'notes');
      expect(diveEditCards[DiveDetailSectionId.tags]!.id, 'tags');
      expect(diveNotesField.cardId, 'notes');
      expect(diveTagsField.cardId, 'tags');
    });

    test('Notes is never left out; Tags is left out with no tags', () {
      final notes = diveEditCards[DiveDetailSectionId.notes]!;
      final tags = diveEditCards[DiveDetailSectionId.tags]!;

      expect(notes.isEmpty(dive), isFalse);
      expect(tags.isEmpty(dive), isTrue);
      expect(tags.isEmpty(dive.copyWith(tags: [wreck])), isFalse);
    });

    test('the same tags in another order are not a change', () {
      expect(diveTagsField.same([wreck, night], [night, wreck]), isTrue);
      expect(diveTagsField.same([wreck, night], [wreck]), isFalse);
      expect(diveTagsField.same([wreck], [night]), isFalse);
      expect(diveTagsField.same(const [], const []), isTrue);
    });

    test('writing a field changes only that field', () {
      final stored = dive.copyWith(notes: 'a', tags: [wreck]);

      expect(diveNotesField.write(stored, 'b'), stored.copyWith(notes: 'b'));
      expect(
        diveTagsField.write(stored, [night]),
        stored.copyWith(tags: [night]),
      );
    });
  });

  group('the editors', () {
    late MockCurrentDiverIdNotifier diverIdNotifier;

    setUp(() async {
      await setUpTestDatabase();
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO divers (id, name, created_at, updated_at) "
        "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
      );
      diverIdNotifier = MockCurrentDiverIdNotifier();
      await diverIdNotifier.setCurrentDiver('diver-1');
    });

    tearDown(() async => tearDownTestDatabase());

    Widget harness(Widget child) => ProviderScope(
      overrides: [
        currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

    EditSession<Dive> sessionOver(Dive stored) {
      final session = EditSession<Dive>(stored);
      addTearDown(session.dispose);
      return session;
    }

    testWidgets('typing in the Notes editor changes the session', (
      tester,
    ) async {
      final session = sessionOver(dive.copyWith(notes: 'Calm'));
      await tester.pumpWidget(harness(DiveNotesCardEditor(session: session)));
      await tester.pump();
      expect(find.text('Calm'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Calm, then current');

      expect(session.valueOf(diveNotesField), 'Calm, then current');
      expect(session.changedCardIds, {'notes'});
    });

    testWidgets('untouched Notes text follows the stored dive', (tester) async {
      final session = sessionOver(dive.copyWith(notes: 'Calm'));
      await tester.pumpWidget(harness(DiveNotesCardEditor(session: session)));
      await tester.pump();

      session.rebase(dive.copyWith(notes: 'From another device'));
      await tester.pump();

      expect(find.text('From another device'), findsOneWidget);
      expect(session.isDirty, isFalse);
    });

    testWidgets('edited Notes text is kept when the stored dive changes', (
      tester,
    ) async {
      final session = sessionOver(dive.copyWith(notes: 'Calm'));
      await tester.pumpWidget(harness(DiveNotesCardEditor(session: session)));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Mine');

      session.rebase(dive.copyWith(notes: 'Theirs'));
      await tester.pump();

      expect(find.text('Mine'), findsOneWidget);
      expect(find.text('Theirs'), findsNothing);
      expect(session.valueOf(diveNotesField), 'Mine');
    });

    testWidgets('the Tags editor shows the tags and reports a change', (
      tester,
    ) async {
      final session = sessionOver(dive.copyWith(tags: [wreck, night]));
      await tester.pumpWidget(harness(DiveTagsCardEditor(session: session)));
      await tester.pumpAndSettle();
      expect(find.text('Wreck'), findsOneWidget);
      expect(find.text('Night'), findsOneWidget);

      tester.widget<TagFormBlock>(find.byType(TagFormBlock)).onTagsChanged([
        night,
      ]);
      await tester.pumpAndSettle();

      expect(session.valueOf(diveTagsField), [night]);
      expect(session.changedCardIds, {'tags'});
      expect(find.text('Wreck'), findsNothing);
    });

    testWidgets('the locked Notes and Tags cards read as they did', (
      tester,
    ) async {
      final shown = dive.copyWith(notes: 'Calm', tags: [wreck, night]);
      await tester.pumpWidget(
        harness(
          Column(
            children: [
              DiveTagsSection(dive: shown),
              DiveNotesSection(dive: shown),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleStyle = Theme.of(
        tester.element(find.byType(DiveNotesSection)),
      ).textTheme.titleMedium;
      for (final title in [
        l.diveLog_detail_section_notes,
        l.diveLog_detail_section_tags,
      ]) {
        expect(tester.widget<Text>(find.text(title)).style, titleStyle);
      }
      expect(find.text(l.diveLog_detail_tagCount(2)), findsOneWidget);
      expect(find.text('Calm'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });
  });
}
