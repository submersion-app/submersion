import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_altitude_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_details_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_environment_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_card_marker.dart';
import 'package:submersion/features/dive_log/presentation/widgets/responsive_section_pair.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_environment_card_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_form_block.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';
import 'dive_detail_section_list_harness.dart';

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
    double above = 0,
  }) {
    final list = sectionListFor(dive);
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
            // [above] pushes the list down the page, out of a short window.
            child: Column(
              children: [
                SizedBox(height: above),
                controller == null
                    ? list
                    : RecordEditScope<Dive>(
                        controller: controller,
                        child: list,
                      ),
              ],
            ),
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

  testWidgets('unlocked: Notes, Tags and Custom fields gain a pencil', (
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
    expect(find.byTooltip('Edit Custom Fields'), findsOneWidget);
    expect(_section(DiveDetailSectionId.customFields), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(3));
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

  // Sections are matched by key, so a card arriving above an open editor
  // moves it instead of building it again, which would drop its caret.
  testWidgets('a card added above an open editor does not rebuild it', (
    tester,
  ) async {
    final untagged = dive.copyWith(tags: const []);
    final controller = controllerOver(untagged)..openCard('notes');
    await tester.pumpWidget(
      harness(
        dive: untagged,
        settings: _RecordingSettings(_settings(shown)),
        controller: controller,
      ),
    );
    await tester.pumpAndSettle();
    final editor = tester.state(find.byType(MarkdownNotesField));

    controller.addCard('tags');
    await tester.pumpAndSettle();

    expect(find.byType(TagFormBlock), findsOneWidget);
    expect(tester.state(find.byType(MarkdownNotesField)), same(editor));
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

  // With another editor still open the page keeps the cards it had. One the
  // diver has emptied and closed meanwhile has nothing to draw there, and
  // must not hold an empty place: the strip is how it is reached again.
  testWidgets('a card emptied and closed while another is open draws '
      'nothing', (tester) async {
    final settings = _RecordingSettings(
      _settings(const [
        DiveDetailSectionId.altitude,
        DiveDetailSectionId.notes,
      ]),
    );
    final controller = controllerOver(dive.copyWith(altitude: 1850))
      ..openCard('notes')
      ..openCard('altitude');
    controller.session!.set(diveAltitudeField, null);
    controller.closeCard('altitude');

    await tester.pumpWidget(
      harness(
        dive: controller.session!.working,
        settings: settings,
        controller: controller,
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.openCardIds, {'notes'});
    expect(_section(DiveDetailSectionId.altitude), findsNothing);
  });

  group('list layout', () {
    final folded = _settings(const [
      DiveDetailSectionId.tags,
      DiveDetailSectionId.notes,
    ], layout: DiveDetailLayout.list);

    // The card's frame sits inside its fold, which opens for the editor, so
    // an added card is asked to show itself here as in the card layout.
    testWidgets('a card added from the strip is scrolled into view', (
      tester,
    ) async {
      // A short window, with the list pushed below it.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(600, 300);
      addTearDown(tester.view.reset);
      final untagged = dive.copyWith(tags: const []);
      final controller = controllerOver(untagged);
      await tester.pumpWidget(
        harness(
          dive: untagged,
          settings: _RecordingSettings(folded),
          controller: controller,
          above: 600,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TagFormBlock), findsNothing);

      controller.addCard('tags');
      await tester.pumpAndSettle();

      final editor = tester.getRect(find.byType(TagFormBlock));
      expect(editor.top, greaterThanOrEqualTo(0));
      expect(editor.top, lessThan(300));
      expect(controller.revealRequest, isNull, reason: 'answered');
    });

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

    // An open card is unfolded for the sitting whatever the diver's setting
    // says. A tap on its row could only change that setting unseen, and
    // fold the section by surprise once the card was closed.
    testWidgets('the row of an open card does not save a fold', (tester) async {
      final settings = _RecordingSettings(folded);
      final controller = controllerOver(dive)..openCard('notes');
      await tester.pumpWidget(
        harness(dive: dive, settings: settings, controller: controller),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find
            .descendant(
              of: find.byKey(const ValueKey('diveSectionFold_notes')),
              matching: find.text('Notes'),
            )
            .first,
      );
      await tester.pumpAndSettle();

      expect(settings.expandedCalls, isEmpty);
      expect(find.byType(MarkdownNotesField), findsOneWidget);
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

  // Issue #4562: the cards that add a layer to the pinned profile strip are
  // marked, so the strip can tell when they are in view.
  group('pinned strip markers', () {
    Finder marker(DiveDetailSectionId id) =>
        find.byWidgetPredicate((w) => w is PinnedStripCardMarker && w.id == id);

    testWidgets('a card with a strip layer is marked, others are not', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(dive: dive, settings: _RecordingSettings(_settings(shown))),
      );
      await tester.pumpAndSettle();

      expect(marker(DiveDetailSectionId.notes), findsOneWidget);
      expect(marker(DiveDetailSectionId.tags), findsNothing);
      expect(marker(DiveDetailSectionId.customFields), findsNothing);
    });

    testWidgets('a folded card is not marked until it unfolds', (tester) async {
      final settings = _RecordingSettings(
        _settings(const [
          DiveDetailSectionId.tags,
          DiveDetailSectionId.notes,
        ], layout: DiveDetailLayout.list),
      );
      await tester.pumpWidget(harness(dive: dive, settings: settings));
      await tester.pumpAndSettle();
      expect(marker(DiveDetailSectionId.notes), findsNothing);

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();
      expect(marker(DiveDetailSectionId.notes), findsOneWidget);
    });

    testWidgets('both cards of a pair are marked', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1400, 2000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        harness(
          // The deco pair shows only for a dive with a profile.
          dive: dive.copyWith(
            profile: [
              for (var t = 0; t <= 600; t += 10)
                DiveProfilePoint(
                  timestamp: t,
                  depth: t < 300 ? t / 20 : (600 - t) / 20,
                ),
            ],
          ),
          settings: _RecordingSettings(
            _settings(const [
              DiveDetailSectionId.decoStatus,
              DiveDetailSectionId.tissueLoading,
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ResponsiveSectionPair), findsOneWidget);
      expect(marker(DiveDetailSectionId.decoStatus), findsOneWidget);
      expect(marker(DiveDetailSectionId.tissueLoading), findsOneWidget);
    });
  });

  // On a wide page Details and Environment share a row, and only when
  // Environment has something to show. A card must not move, or lose what
  // is being typed into it, while its editor is open.
  group('cards side by side', () {
    final plain = Dive(id: 'dive-1', dateTime: DateTime(2024, 6, 1, 10));
    final logged = plain.copyWith(airTemp: 21);
    const pair = [DiveDetailSectionId.details, DiveDetailSectionId.environment];

    Future<void> pumpWide(
      WidgetTester tester,
      Dive dive, {
      RecordEditController<Dive>? controller,
      List<DiveDetailSectionId> visible = pair,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 1600);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        harness(
          dive: dive,
          settings: _RecordingSettings(_settings(visible)),
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();
    }

    AppLocalizations l10nOf(WidgetTester tester) =>
        AppLocalizations.of(tester.element(find.byType(Scaffold)));

    Finder fieldOf(String label) => find.descendant(
      of: find.widgetWithText(FormRow, label),
      matching: find.byType(TextFormField),
    );

    bool hasFocus(WidgetTester tester, Finder field) => tester
        .widget<EditableText>(
          find.descendant(of: field, matching: find.byType(EditableText)),
        )
        .focusNode
        .hasFocus;

    final details = find.byType(DiveDetailsSection);
    final environmentFrame = find.byWidgetPredicate(
      (w) => w is RecordCardFrame<Dive> && w.card.id == 'environment',
    );

    void expectBesideDetails(WidgetTester tester, Finder card) {
      final left = tester.getRect(details);
      final right = tester.getRect(card);
      expect(right.top, left.top, reason: 'on the same row as Details');
      expect(right.left, greaterThan(left.right - 1));
    }

    testWidgets('locked: the pair reads as before, with no pencil', (
      tester,
    ) async {
      await pumpWide(tester, logged);

      expectBesideDetails(tester, find.byType(DiveEnvironmentSection));
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets(
      'unlocked: a paired card gains a pencil and opens in its slot',
      (tester) async {
        final controller = controllerOver(logged);
        await pumpWide(tester, logged, controller: controller);
        expect(find.byTooltip('Edit Environment'), findsOneWidget);

        await tester.tap(find.byTooltip('Edit Environment'));
        await tester.pumpAndSettle();

        expect(find.byType(DiveEnvironmentCardEditor), findsOneWidget);
        expectBesideDetails(tester, environmentFrame);
      },
    );

    testWidgets('an empty Environment card opened from the strip sits beside '
        'Details at once', (tester) async {
      final controller = controllerOver(plain);
      await pumpWide(tester, plain, controller: controller);
      expect(environmentFrame, findsNothing);

      controller.addCard('environment');
      await tester.pumpAndSettle();

      expect(find.byType(DiveEnvironmentCardEditor), findsOneWidget);
      expectBesideDetails(tester, environmentFrame);
    });

    testWidgets('typing its first value does not rebuild the editor', (
      tester,
    ) async {
      final controller = controllerOver(plain);
      await pumpWide(tester, plain, controller: controller);
      controller.addCard('environment');
      await tester.pumpAndSettle();
      final editor = find.byType(DiveEnvironmentCardEditor);
      final before = tester.state(editor);
      final label = l10nOf(tester).diveLog_edit_label_airTemp;

      await tester.tap(find.text(label));
      await tester.pump();
      await tester.enterText(fieldOf(label), '2');
      // The page shows the working copy, which now has something logged.
      await tester.pumpWidget(
        harness(
          dive: controller.session!.working,
          settings: _RecordingSettings(_settings(pair)),
          controller: controller,
        ),
      );
      await tester.pump();

      expect(controller.session!.working.airTemp, 2);
      expect(identical(tester.state(editor), before), isTrue);
      expect(hasFocus(tester, fieldOf(label)), isTrue);
      expectBesideDetails(tester, environmentFrame);
    });

    // The pair has no card of its own for a narrow pane: stacked, it shows
    // the row card, and so the same frame around the same read card.
    testWidgets('stacked in a narrow pane, an open card keeps its read card '
        'behind it', (tester) async {
      final controller = controllerOver(logged)..openCard('environment');
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(600, 1600);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        harness(
          dive: logged,
          settings: _RecordingSettings(_settings(pair)),
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveEnvironmentCardEditor), findsOneWidget);
      expect(
        tester.widget<RecordCardFrame<Dive>>(environmentFrame).child,
        isA<DiveEnvironmentSection>(),
      );
    });

    testWidgets('closed again with nothing in it, Details has the row to '
        'itself', (tester) async {
      final controller = controllerOver(plain);
      await pumpWide(tester, plain, controller: controller);
      final alone = tester.getSize(details).width;
      controller.addCard('environment');
      await tester.pumpAndSettle();
      expect(tester.getSize(details).width, lessThan(alone));

      controller.closeCard('environment');
      await tester.pumpAndSettle();

      expect(environmentFrame, findsNothing);
      expect(tester.getSize(details).width, alone);
    });

    // A lookup started from the Environment card can set the altitude,
    // which the Altitude card owns. That card waits for the editor to close.
    testWidgets('a card a rule filled does not come in while another is '
        'open', (tester) async {
      const visible = [
        DiveDetailSectionId.altitude,
        DiveDetailSectionId.environment,
      ];
      final controller = controllerOver(plain);
      await pumpWide(tester, plain, controller: controller, visible: visible);
      controller.addCard('environment');
      await tester.pumpAndSettle();
      final editor = find.byType(DiveEnvironmentCardEditor);
      final top = tester.getTopLeft(editor).dy;

      controller.session!.set(diveAltitudeField, 1200.0);
      await tester.pumpWidget(
        harness(
          dive: controller.session!.working,
          settings: _RecordingSettings(_settings(visible)),
          controller: controller,
        ),
      );
      await tester.pump();

      expect(find.byType(DiveAltitudeSection), findsNothing);
      expect(tester.getTopLeft(editor).dy, top);

      controller.closeCard('environment');
      await tester.pumpAndSettle();

      expect(find.byType(DiveAltitudeSection), findsOneWidget);
    });

    // The single-card path: Altitude is on the page only above sea level.
    testWidgets('typing the first altitude does not rebuild its editor', (
      tester,
    ) async {
      final controller = controllerOver(plain);
      await pumpWide(
        tester,
        plain,
        controller: controller,
        visible: const [
          DiveDetailSectionId.details,
          DiveDetailSectionId.altitude,
        ],
      );
      controller.addCard('altitude');
      await tester.pumpAndSettle();
      final editor = find.byType(DiveAltitudeCardEditor);
      final before = tester.state(editor);
      final label = l10nOf(tester).diveLog_edit_label_altitude;

      await tester.tap(find.text(label));
      await tester.pump();
      await tester.enterText(fieldOf(label), '12');
      await tester.pumpWidget(
        harness(
          dive: controller.session!.working,
          settings: _RecordingSettings(
            _settings(const [
              DiveDetailSectionId.details,
              DiveDetailSectionId.altitude,
            ]),
          ),
          controller: controller,
        ),
      );
      await tester.pump();

      expect(controller.session!.working.altitude, 12);
      expect(identical(tester.state(editor), before), isTrue);
      expect(hasFocus(tester, fieldOf(label)), isTrue);
    });
  });
}
