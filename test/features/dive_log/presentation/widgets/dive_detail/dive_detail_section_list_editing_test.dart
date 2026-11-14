import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_actions.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_analysis_retention.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_form_block.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

/// A settings notifier that records what the section list asks it to save.
class _RecordingSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _RecordingSettings(super.initial);

  final expandedCalls = <(DiveDetailSectionId, bool)>[];
  int sectionsCalls = 0;

  @override
  Future<void> setDiveDetailSections(
    List<DiveDetailSectionConfig> sections,
  ) async {
    sectionsCalls++;
    state = state.copyWith(diveDetailSections: sections);
  }

  @override
  Future<void> setDiveDetailSectionExpanded(
    DiveDetailSectionId id,
    bool expanded,
  ) async {
    expandedCalls.add((id, expanded));
    state = state.copyWith(
      diveDetailSections: [
        for (final section in state.diveDetailSections)
          section.id == id ? section.copyWith(expanded: expanded) : section,
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AppSettings _settings(
  List<DiveDetailSectionId> visible, {
  DiveDetailLayout layout = DiveDetailLayout.detailed,
}) => AppSettings(
  diveDetailSections: [
    for (final id in DiveDetailSectionId.values)
      DiveDetailSectionConfig(id: id, visible: visible.contains(id)),
  ],
  diveDetailLayout: layout,
);

Finder _section(DiveDetailSectionId id) =>
    find.byKey(ValueKey('diveSection_${id.name}'));

void main() {
  late MockCurrentDiverIdNotifier diverIdNotifier;
  final wreck = Tag(
    id: 'wreck',
    diverId: 'diver-1',
    name: 'Wreck',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final dive = createTestDiveWithBottomTime().copyWith(
    notes: 'Calm',
    tags: [wreck],
    customFields: const [
      DiveCustomField(id: 'c1', key: 'Boat', value: 'Aggressor'),
    ],
  );
  const shown = [
    DiveDetailSectionId.tags,
    DiveDetailSectionId.notes,
    DiveDetailSectionId.customFields,
  ];

  setUp(() async {
    await setUpTestDatabase();
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
    );
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
  });

  tearDown(() async => tearDownTestDatabase());

  RecordEditController<Dive> controllerOver(Dive stored) {
    final controller = RecordEditController<Dive>(onSave: (_) async {})
      ..unlock(stored);
    addTearDown(controller.dispose);
    return controller;
  }

  Widget harness({
    required Dive dive,
    required _RecordingSettings settings,
    RecordEditController<Dive>? controller,
  }) {
    final list = DiveDetailSectionList(
      dive: dive,
      profileSection: const SizedBox.shrink(),
      safetyReviewKey: GlobalKey(),
      notesKey: GlobalKey(),
      retention: DiveDetailAnalysisRetention(),
      actions: DiveDetailActions(
        setPrimarySource: (_) {},
        splitSource: (_, _) {},
        removeSource: (_, _, _) {},
        separateSegments: (_, _) {},
        scanGallery: (_) {},
        addPhotos: (_) {},
        addDocument: (_) {},
        openDocument: (_) {},
      ),
    );
    return ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => settings),
        currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: controller == null
                ? list
                : RecordEditScope<Dive>(controller: controller, child: list),
          ),
        ),
      ),
    );
  }

  testWidgets('with no controller the cards carry no pencil', (tester) async {
    await tester.pumpWidget(
      harness(dive: dive, settings: _RecordingSettings(_settings(shown))),
    );
    await tester.pumpAndSettle();

    expect(_section(DiveDetailSectionId.notes), findsOneWidget);
    expect(_section(DiveDetailSectionId.tags), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('unlocked: Notes and Tags gain a pencil, other cards do not', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        dive: dive,
        settings: _RecordingSettings(_settings(shown)),
        controller: controllerOver(dive),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Edit Notes'), findsOneWidget);
    expect(find.byTooltip('Edit Tags'), findsOneWidget);
    expect(_section(DiveDetailSectionId.customFields), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
  });

  testWidgets('a card the page leaves out appears, open, once added', (
    tester,
  ) async {
    final untagged = dive.copyWith(tags: const []);
    final controller = controllerOver(untagged);
    await tester.pumpWidget(
      harness(
        dive: untagged,
        settings: _RecordingSettings(_settings(shown)),
        controller: controller,
      ),
    );
    await tester.pumpAndSettle();
    expect(_section(DiveDetailSectionId.tags), findsNothing);

    controller.addCard('tags');
    await tester.pumpAndSettle();

    expect(_section(DiveDetailSectionId.tags), findsOneWidget);
    expect(find.byType(TagFormBlock), findsOneWidget);
    expect(
      tester.getTopLeft(_section(DiveDetailSectionId.tags)).dy,
      lessThan(tester.getTopLeft(_section(DiveDetailSectionId.notes)).dy),
      reason: 'the card takes its place in the section order',
    );
  });

  testWidgets('an added card closed with nothing entered leaves again', (
    tester,
  ) async {
    final untagged = dive.copyWith(tags: const []);
    final controller = controllerOver(untagged)..addCard('tags');
    await tester.pumpWidget(
      harness(
        dive: untagged,
        settings: _RecordingSettings(_settings(shown)),
        controller: controller,
      ),
    );
    await tester.pumpAndSettle();
    expect(_section(DiveDetailSectionId.tags), findsOneWidget);

    controller.closeCard('tags');
    await tester.pumpAndSettle();

    expect(_section(DiveDetailSectionId.tags), findsNothing);
  });

  testWidgets('a hidden card can be added, and is hidden again when locked', (
    tester,
  ) async {
    final settings = _RecordingSettings(
      _settings(const [DiveDetailSectionId.tags]),
    );
    final controller = controllerOver(dive);
    await tester.pumpWidget(
      harness(dive: dive, settings: settings, controller: controller),
    );
    await tester.pumpAndSettle();
    expect(_section(DiveDetailSectionId.notes), findsNothing);

    controller.addCard('notes');
    await tester.pumpAndSettle();
    expect(find.byType(MarkdownNotesField), findsOneWidget);

    controller.lock();
    await tester.pumpAndSettle();

    expect(_section(DiveDetailSectionId.notes), findsNothing);
    expect(settings.sectionsCalls, 0);
    expect(settings.expandedCalls, isEmpty);
  });

  // A card brought in from the strip, emptied and closed has nothing to
  // show. It must leave no gap behind; the strip offers it again.
  testWidgets('an added card emptied and closed draws nothing', (tester) async {
    final settings = _RecordingSettings(
      _settings(const [DiveDetailSectionId.notes]),
    );
    final controller = controllerOver(dive)..addCard('tags');
    controller.session!.set(diveTagsField, const <Tag>[]);
    controller.closeCard('tags');

    await tester.pumpWidget(
      harness(
        dive: controller.session!.working,
        settings: settings,
        controller: controller,
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.addedCardIds, {'tags'});
    expect(_section(DiveDetailSectionId.tags), findsNothing);
  });

  group('list layout', () {
    final folded = _settings(const [
      DiveDetailSectionId.tags,
      DiveDetailSectionId.notes,
    ], layout: DiveDetailLayout.list);

    testWidgets('locked: the fold rows carry no pencil', (tester) async {
      await tester.pumpWidget(
        harness(dive: dive, settings: _RecordingSettings(folded)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets('unlocked: the pencil is on the fold row, which still folds', (
      tester,
    ) async {
      final settings = _RecordingSettings(folded);
      await tester.pumpWidget(
        harness(
          dive: dive,
          settings: settings,
          controller: controllerOver(dive),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Edit Notes'), findsOneWidget);
      expect(find.byTooltip('Edit Tags'), findsOneWidget);

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      expect(settings.expandedCalls, [(DiveDetailSectionId.notes, true)]);
    });

    testWidgets('a folded section with changes shows the dot on its row', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final controller = controllerOver(dive);
      controller.session!.set(diveNotesField, 'Changed');

      await tester.pumpWidget(
        harness(
          dive: controller.session!.working,
          settings: _RecordingSettings(folded),
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MarkdownNotesField), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Unsaved changes')), findsOneWidget);

      semantics.dispose();
    });

    testWidgets('the pencil opens a folded section without saving the unfold', (
      tester,
    ) async {
      final settings = _RecordingSettings(folded);
      final controller = controllerOver(dive);
      await tester.pumpWidget(
        harness(dive: dive, settings: settings, controller: controller),
      );
      await tester.pumpAndSettle();
      expect(find.text('Calm'), findsNothing);

      await tester.tap(find.byTooltip('Edit Notes'));
      await tester.pumpAndSettle();

      expect(controller.openCardIds, {'notes'});
      expect(find.byType(MarkdownNotesField), findsOneWidget);
      expect(settings.expandedCalls, isEmpty);

      controller.lock();
      await tester.pumpAndSettle();

      expect(find.byType(MarkdownNotesField), findsNothing);
      expect(find.text('Calm'), findsNothing, reason: 'folded again');
      expect(settings.expandedCalls, isEmpty);
    });
  });
}
