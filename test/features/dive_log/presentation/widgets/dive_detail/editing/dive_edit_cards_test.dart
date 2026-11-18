import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/annotation_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/presentation/providers/annotation_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_annotations_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_text_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_notes_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tags_card_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_form_block.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

/// Answers the annotation read when the test says.
class _GatedAnnotations extends AnnotationRepository {
  _GatedAnnotations(this.answer);
  final Future<List<ProfileEvent>> answer;

  @override
  Future<List<ProfileEvent>> annotationsForDive(String diveId) => answer;
}

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
    // A card registered here gains a pencil on the dive page. Naming them
    // makes adding one a deliberate change to this test.
    test('are the cards with something to edit', () {
      expect(diveEditCards.keys, {
        DiveDetailSectionId.profile,
        DiveDetailSectionId.safetyReview,
        DiveDetailSectionId.notes,
        DiveDetailSectionId.tags,
        DiveDetailSectionId.altitude,
        DiveDetailSectionId.environment,
        DiveDetailSectionId.details,
        DiveDetailSectionId.tanks,
        DiveDetailSectionId.weights,
        DiveDetailSectionId.equipment,
        DiveDetailSectionId.navTrack,
        DiveDetailSectionId.buddies,
        DiveDetailSectionId.signatures,
        DiveDetailSectionId.sightings,
        DiveDetailSectionId.media,
        DiveDetailSectionId.documents,
        DiveDetailSectionId.diveLab,
        DiveDetailSectionId.customFields,
      });
    });

    test('Equipment is left out of a dive with no gear', () {
      final equipment = diveEditCards[DiveDetailSectionId.equipment]!;
      expect(equipment.isEmpty(dive.copyWith(gear: const [])), isTrue);
    });

    test('Weight is left out of a dive with no weight', () {
      final weights = diveEditCards[DiveDetailSectionId.weights]!;
      expect(weights.isEmpty(dive.copyWith(weights: const [])), isTrue);
      expect(weights.isEmpty(dive.copyWith(weightAmount: 4)), isFalse);
    });

    test('Cylinders is left out of a gauge dive and of one with none', () {
      final tanks = diveEditCards[DiveDetailSectionId.tanks]!;
      const tank = DiveTank(id: 't');
      expect(tanks.isEmpty(dive.copyWith(tanks: const [])), isTrue);
      expect(tanks.isEmpty(dive.copyWith(tanks: const [tank])), isFalse);
      expect(
        tanks.isEmpty(
          dive.copyWith(tanks: const [tank], diveMode: DiveMode.gauge),
        ),
        isTrue,
      );
      expect(tanks.isValid, isNotNull);
    });

    test('Details is never left out: the page always shows it', () {
      final details = diveEditCards[DiveDetailSectionId.details]!;
      expect(details.id, 'details');
      expect(details.isEmpty(dive), isFalse);
      expect(
        details.isEmpty(Dive(id: 'bare', dateTime: DateTime(2024))),
        isFalse,
      );
    });

    test('every card id is its section name', () {
      for (final MapEntry(key: section, value: card) in diveEditCards.entries) {
        expect(card.id, section.name);
      }
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

    // Assigning the controller's text would throw the caret out of a field
    // the diver is in.
    testWidgets('Notes text that follows the stored dive keeps its caret', (
      tester,
    ) async {
      final session = sessionOver(dive.copyWith(notes: 'Calm'));
      await tester.pumpWidget(harness(DiveNotesCardEditor(session: session)));
      await tester.pump();
      final text = tester.widget<TextField>(find.byType(TextField)).controller!;
      text.selection = const TextSelection.collapsed(offset: 2);

      session.rebase(dive.copyWith(notes: 'From another device'));
      await tester.pump();
      expect(text.text, 'From another device');
      expect(text.selection, const TextSelection.collapsed(offset: 2));

      // Shorter than where the caret was: it goes to the end.
      session.rebase(dive.copyWith(notes: 'C'));
      await tester.pump();
      expect(text.selection, const TextSelection.collapsed(offset: 1));
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

    testWidgets('the Notes editor offers annotate once the sitting holds '
        'the annotations, not before', (tester) async {
      final reading = Completer<List<ProfileEvent>>();
      final container = ProviderContainer(
        overrides: [
          annotationRepositoryProvider.overrideWithValue(
            _GatedAnnotations(reading.future),
          ),
        ],
      );
      addTearDown(container.dispose);
      final session = sessionOver(dive.copyWith(notes: 'Calm'));
      loadDiveAnnotations(session, container.read);
      await tester.pumpWidget(harness(DiveNotesCardEditor(session: session)));
      await tester.pump();
      MarkdownNotesField field() =>
          tester.widget<MarkdownNotesField>(find.byType(MarkdownNotesField));
      expect(field().onAnnotate, isNull);

      reading.complete(const []);
      await tester.pump();
      await tester.pump();
      expect(field().onAnnotate, isNotNull);
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
