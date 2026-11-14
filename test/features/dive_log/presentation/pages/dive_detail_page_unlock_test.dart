import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_log/data/services/dive_edit_save_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_edit_save_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_altitude_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_details_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_environment_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_nav_buttons.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_habitat.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/domain/services/bleaching_alert_level.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_form_block.dart';
import 'package:submersion/features/weather/data/services/weather_service.dart';
import 'package:submersion/features/weather/domain/entities/weather_data.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Stands in for the save service: applies the sitting to [stored] and
/// records what it was asked to write, or fails on demand.
class _FakeSave implements DiveEditSaveService {
  _FakeSave(this.stored);

  Dive stored;
  Object? failWith;
  final calls = <({Dive merged, List<String> cards})>[];

  @override
  Future<({Dive before, Dive after})?> save({
    required String diveId,
    required Dive Function(Dive stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
  }) async {
    final error = failWith;
    if (error != null) throw error;
    final before = stored;
    final merged = apply(before);
    calls.add((merged: merged, cards: changedCardIds.toList()));
    await alsoWrite?.call();
    stored = merged;
    return (before: before, after: merged);
  }
}

/// Answers every weather fetch with [data].
class _FakeWeather extends WeatherService {
  _FakeWeather(this.data)
    : super(client: MockClient((_) async => http.Response('', 500)));

  final WeatherData data;

  @override
  Future<WeatherData?> fetchWeather({
    required double latitude,
    required double longitude,
    required DateTime date,
    required DateTime entryTime,
  }) async => data;
}

/// Counts refreshes of the site list instead of reading sites.
class _SpySites extends SiteListNotifier {
  _SpySites(super.repository, super.ref);

  int refreshes = 0;

  @override
  Future<void> refresh() async => refreshes++;
}

/// The dive page unlocked for editing in place (issue #4527), behind the
/// build switch.
void main() {
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2023, 1, 1),
    notes: 'Calm',
  );

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  /// Pumps the page on top of a home route, with only Tags and Notes shown
  /// so both are on screen, and returns the router and the fake service.
  Future<({GoRouter router, _FakeSave save})> pumpPage(
    WidgetTester tester, {
    bool unlockEditing = true,
    bool embedded = false,
    Size size = const Size(700, 1000),
    Dive? stored,
    Set<DiveDetailSectionId> visible = const {
      DiveDetailSectionId.tags,
      DiveDetailSectionId.notes,
    },
    Completer<void>? reloadGate,
    String initialLocation = '/home/dive',
    List<Override> extra = const [],
    bool imperial = false,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    final save = _FakeSave(stored ?? dive);
    var loads = 0;
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(
        AppSettings(
          hasAcceptedPlanningDisclaimer: true,
          depthUnit: imperial ? DepthUnit.feet : DepthUnit.meters,
          altitudeUnit: imperial ? AltitudeUnit.feet : AltitudeUnit.meters,
          diveDetailSections: [
            for (final id in DiveDetailSectionId.values)
              DiveDetailSectionConfig(id: id, visible: visible.contains(id)),
          ],
        ),
      ),
    );
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        // The dive as a root page, the way a deep link opens it.
        GoRoute(
          path: '/root-dive',
          builder: (context, state) =>
              DiveDetailPage(diveId: dive.id, unlockEditing: unlockEditing),
        ),
        GoRoute(
          path: '/dives',
          builder: (context, state) => const Scaffold(body: Text('PANE')),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('HOME')),
          routes: [
            GoRoute(
              path: 'dive',
              builder: (context, state) => DiveDetailPage(
                diveId: dive.id,
                embedded: embedded,
                unlockEditing: unlockEditing,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/dives/:id',
          builder: (context, state) =>
              Scaffold(body: Text('OTHER ${state.pathParameters['id']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          // Reads the fake's dive, so a save shows on the page as it would
          // from the database.
          diveProvider(dive.id).overrideWith((ref) async {
            // Every load after the first waits on [reloadGate], so a test
            // can look at the page before the saved dive is read back.
            if (++loads > 1 && reloadGate != null) await reloadGate.future;
            return save.stored;
          }),
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
          diveNeighborsProvider(
            dive.id,
          ).overrideWith((ref) => (previousId: null, nextId: 'dive-2')),
          diveEditSaveServiceProvider.overrideWithValue(save),
          ...extra,
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return (router: router, save: save);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Unlock to edit'));
    await settle(tester);
  }

  Future<void> openNotes(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Edit Notes'));
    await settle(tester);
  }

  AppBarTextAction action(WidgetTester tester, String label) =>
      tester.widget<AppBarTextAction>(
        find.byWidgetPredicate(
          (w) => w is AppBarTextAction && w.label == label,
        ),
      );

  String location(GoRouter router) => router.state.uri.toString();

  testWidgets('switch off: the page has no lock', (tester) async {
    await pumpPage(tester, unlockEditing: false);

    expect(find.text('Calm'), findsOneWidget);
    expect(find.byTooltip('Unlock to edit'), findsNothing);
  });

  testWidgets('in the list pane the page has no lock yet', (tester) async {
    await pumpPage(tester, embedded: true, size: const Size(1200, 900));

    expect(find.byTooltip('Unlock to edit'), findsNothing);
  });

  testWidgets('unlock swaps the bar and moves nothing in the page', (
    tester,
  ) async {
    await pumpPage(tester);
    // The page's own scroll view, not the Add strip's sideways one. The
    // strip sits above it, so what must not move is the page inside it.
    final scroll = find.byWidgetPredicate(
      (w) => w is SingleChildScrollView && w.scrollDirection == Axis.vertical,
    );
    Offset notesInScroll() =>
        tester.getTopLeft(find.text('Calm')) - tester.getTopLeft(scroll);
    final before = notesInScroll();
    expect(find.byType(DiveNavButtons), findsOneWidget);

    await unlock(tester);

    expect(find.text('Cancel'), findsOneWidget);
    expect(action(tester, 'Save').onPressed, isNull);
    expect(find.byTooltip('Unlock to edit'), findsNothing);
    expect(find.byType(DiveNavButtons), findsNothing);
    expect(find.byTooltip('Edit Notes'), findsOneWidget);
    expect(notesInScroll(), before);
  });

  testWidgets('the strip offers Tags for a dive with none', (tester) async {
    await pumpPage(tester);
    expect(find.byKey(const ValueKey('addStrip_tags')), findsNothing);

    await unlock(tester);

    expect(find.byKey(const ValueKey('addStrip_tags')), findsOneWidget);
    expect(find.byKey(const ValueKey('addStrip_notes')), findsNothing);
  });

  testWidgets('a note edit is saved and the page locks', (tester) async {
    final page = await pumpPage(tester);
    await unlock(tester);
    await openNotes(tester);

    await tester.enterText(
      find.descendant(
        of: find.byType(MarkdownNotesField),
        matching: find.byType(TextField),
      ),
      'Calm, then current',
    );
    await settle(tester);
    expect(action(tester, 'Save').onPressed, isNotNull);

    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(page.save.calls.single.merged.notes, 'Calm, then current');
    expect(page.save.calls.single.cards, ['notes']);
    expect(find.byTooltip('Unlock to edit'), findsOneWidget);
    expect(find.text('Calm, then current'), findsOneWidget);
  });

  group('a write the sitting holds for another record', () {
    Future<void> typeNote(WidgetTester tester) async {
      await unlock(tester);
      await openNotes(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(MarkdownNotesField),
          matching: find.byType(TextField),
        ),
        'Calm, then current',
      );
      await settle(tester);
    }

    RecordEditController<Dive> controller(WidgetTester tester) => tester
        .widget<RecordEditScope<Dive>>(find.byType(RecordEditScope<Dive>))
        .notifier!;

    testWidgets('is run by the save, and the site list is read again', (
      tester,
    ) async {
      _SpySites? sites;
      final page = await pumpPage(
        tester,
        extra: [
          siteListNotifierProvider.overrideWith(
            (ref) => sites = _SpySites(ref.watch(siteRepositoryProvider), ref),
          ),
        ],
      );
      await typeNote(tester);
      var ran = 0;
      controller(tester).session!.holdWrite('site', () async => ran++);

      await tester.tap(find.text('Save'));
      await settle(tester);

      expect(page.save.calls, hasLength(1));
      expect(ran, 1);
      expect(sites?.refreshes, 1);
    });

    testWidgets('is dropped when the sitting is cancelled', (tester) async {
      await pumpPage(tester);
      await typeNote(tester);
      var ran = 0;
      controller(tester).session!.holdWrite('site', () async => ran++);

      await tester.tap(find.text('Cancel'));
      await settle(tester);
      await tester.tap(find.text('Discard'));
      await settle(tester);

      expect(find.byTooltip('Unlock to edit'), findsOneWidget);
      expect(ran, 0);
    });

    testWidgets('a sitting that holds none leaves the site list alone', (
      tester,
    ) async {
      _SpySites? sites;
      await pumpPage(
        tester,
        extra: [
          siteListNotifierProvider.overrideWith(
            (ref) => sites = _SpySites(ref.watch(siteRepositoryProvider), ref),
          ),
        ],
      );
      await typeNote(tester);

      await tester.tap(find.text('Save'));
      await settle(tester);

      expect(find.byTooltip('Unlock to edit'), findsOneWidget);
      expect(sites, isNull);
    });
  });

  testWidgets('typing a change and typing it back disables Save again', (
    tester,
  ) async {
    await pumpPage(tester);
    await unlock(tester);
    await openNotes(tester);
    final field = find.descendant(
      of: find.byType(MarkdownNotesField),
      matching: find.byType(TextField),
    );

    await tester.enterText(field, 'Calm!');
    await settle(tester);
    expect(action(tester, 'Save').onPressed, isNotNull);

    await tester.enterText(field, 'Calm');
    await settle(tester);

    expect(action(tester, 'Save').onPressed, isNull);
  });

  testWidgets('Cancel with changes asks, and Discard leaves the dive alone', (
    tester,
  ) async {
    final page = await pumpPage(tester);
    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(MarkdownNotesField),
        matching: find.byType(TextField),
      ),
      'Something else',
    );
    await settle(tester);

    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await settle(tester);

    expect(page.save.calls, isEmpty);
    expect(find.byTooltip('Unlock to edit'), findsOneWidget);
    expect(find.text('Calm'), findsOneWidget);
    expect(find.text('Something else'), findsNothing);
  });

  testWidgets('Cancel with no changes locks at once', (tester) async {
    await pumpPage(tester);
    await unlock(tester);

    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.byTooltip('Unlock to edit'), findsOneWidget);
  });

  testWidgets('a card added from the strip and cancelled leaves no trace', (
    tester,
  ) async {
    final page = await pumpPage(tester);
    await unlock(tester);

    await tester.tap(find.byKey(const ValueKey('addStrip_tags')));
    await settle(tester);
    expect(find.byType(TagFormBlock), findsOneWidget);
    expect(find.byKey(const ValueKey('addStrip_tags')), findsNothing);

    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(find.byType(TagFormBlock), findsNothing);
    expect(page.save.calls, isEmpty);

    await unlock(tester);
    expect(find.byKey(const ValueKey('addStrip_tags')), findsOneWidget);
  });

  testWidgets('back with changes asks before leaving', (tester) async {
    final page = await pumpPage(tester);
    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(MarkdownNotesField),
        matching: find.byType(TextField),
      ),
      'Something else',
    );
    await settle(tester);

    // The system back gesture.
    await tester.binding.handlePopRoute();
    await settle(tester);

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(location(page.router), '/home/dive');

    await tester.tap(find.text('Keep editing'));
    await settle(tester);
    expect(find.text('Something else'), findsOneWidget);
  });

  testWidgets('a failed save stays unlocked and says so', (tester) async {
    final semantics = tester.ensureSemantics();
    final page = await pumpPage(tester);
    page.save.failWith = StateError('gone');
    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(MarkdownNotesField),
        matching: find.byType(TextField),
      ),
      'Something else',
    );
    await settle(tester);

    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(
      find.text("Couldn't save your changes. Nothing was changed."),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Something else'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Unsaved changes')), findsOneWidget);
    expect(action(tester, 'Save').onPressed, isNotNull);

    semantics.dispose();
  });

  testWidgets('a stored change mid-sitting reaches an untouched card', (
    tester,
  ) async {
    final page = await pumpPage(tester);
    await unlock(tester);
    await tester.tap(find.byKey(const ValueKey('addStrip_tags')));
    await settle(tester);

    // A sync changes the notes underneath while the diver is on Tags.
    page.save.stored = dive.copyWith(notes: 'From another device');
    ProviderScope.containerOf(
      tester.element(find.byType(DiveDetailPage)),
    ).invalidate(diveProvider(dive.id));
    await settle(tester);

    expect(find.text('From another device'), findsOneWidget);
    expect(find.text('Calm'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget, reason: 'still unlocked');
    expect(find.byType(TagFormBlock), findsOneWidget, reason: 'card kept');

    // The diver's own change is kept, and the save writes only that card
    // on top of the dive as it is stored now.
    final night = Tag(
      id: 'night',
      name: 'Night',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
    tester.widget<TagFormBlock>(find.byType(TagFormBlock)).onTagsChanged([
      night,
    ]);
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);

    final call = page.save.calls.single;
    expect(call.cards, ['tags']);
    expect(call.merged.notes, 'From another device');
    expect(call.merged.tags.map((tag) => tag.id), ['night']);
  });

  Finder notesField() => find.descendant(
    of: find.byType(MarkdownNotesField),
    matching: find.byType(TextField),
  );

  // The page binds the arrow keys to the previous and next dive. Inside an
  // editor they belong to the text.
  testWidgets('the arrow keys move the caret inside an editor', (tester) async {
    await pumpPage(tester);
    await unlock(tester);
    await openNotes(tester);
    await tester.tap(notesField());
    await settle(tester);
    final text = tester.widget<TextField>(notesField()).controller!;
    text.selection = const TextSelection.collapsed(offset: 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);

    expect(text.selection.baseOffset, 2);
  });

  testWidgets('saved values show at once, before the dive is read back', (
    tester,
  ) async {
    final gate = Completer<void>();
    await pumpPage(tester, reloadGate: gate);
    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(notesField(), 'Calm, then current');
    await settle(tester);

    await tester.tap(find.text('Save'));
    await settle(tester);

    // Locked again, and the reload is still waiting.
    expect(find.byTooltip('Unlock to edit'), findsOneWidget);
    expect(find.text('Calm, then current'), findsOneWidget);
    expect(find.text('Calm'), findsNothing);

    gate.complete();
    await settle(tester);
    expect(find.text('Calm, then current'), findsOneWidget);
  });

  testWidgets('a hidden card emptied and closed is offered again', (
    tester,
  ) async {
    final wreck = Tag(
      id: 'wreck',
      name: 'Wreck',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
    await pumpPage(
      tester,
      stored: dive.copyWith(tags: [wreck]),
      visible: const {DiveDetailSectionId.notes},
    );
    await unlock(tester);
    await tester.tap(find.byKey(const ValueKey('addStrip_tags')));
    await settle(tester);

    tester
        .widget<TagFormBlock>(find.byType(TagFormBlock))
        .onTagsChanged(const []);
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);

    expect(find.byType(TagFormBlock), findsNothing);
    expect(
      find.byKey(const ValueKey('addStrip_tags')),
      findsOneWidget,
      reason: 'the card shows nothing now, so the strip must reach it',
    );
    expect(action(tester, 'Save').onPressed, isNotNull);
  });

  // A dive opened as a root page moves into the list pane when the window
  // is wide enough. Mid-sitting that would drop the changes unasked.
  testWidgets('widening the window does not end a sitting', (tester) async {
    final page = await pumpPage(tester, initialLocation: '/root-dive');
    await unlock(tester);
    await openNotes(tester);
    await tester.enterText(notesField(), 'Something else');
    await settle(tester);

    tester.view.physicalSize = const Size(1400, 1000);
    await settle(tester);

    expect(location(page.router), '/root-dive');
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Something else'), findsOneWidget);
  });

  testWidgets('the arrow keys change dive only while locked', (tester) async {
    final page = await pumpPage(tester);
    await unlock(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(location(page.router), '/home/dive');

    await tester.tap(find.text('Cancel'));
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);

    expect(location(page.router), '/dives/dive-2');
  });

  group('the Altitude and Environment cards', () {
    const cards = {
      DiveDetailSectionId.notes,
      DiveDetailSectionId.altitude,
      DiveDetailSectionId.environment,
    };
    // Tall enough that every row of an open card is on screen.
    const tall = Size(700, 2600);
    const reef = DiveSite(
      id: 'site-1',
      name: 'Reef',
      location: GeoPoint(-16.5, 145.8),
      waterType: WaterType.salt,
    );
    const addAltitude = ValueKey('addStrip_altitude');
    const addEnvironment = ValueKey('addStrip_environment');

    AppLocalizations l10nOf(WidgetTester tester) =>
        AppLocalizations.of(tester.element(find.byType(DiveDetailPage)));

    RecordEditController<Dive> controller(WidgetTester tester) => tester
        .widget<RecordEditScope<Dive>>(find.byType(RecordEditScope<Dive>))
        .notifier!;

    /// The text field of the row labelled [label], once that row is open.
    Finder fieldOf(String label) => find.descendant(
      of: find.widgetWithText(FormRow, label),
      matching: find.byType(TextFormField),
    );

    /// Opens the row labelled [label] and types [text] into it.
    Future<void> typeIn(WidgetTester tester, String label, String text) async {
      await tester.tap(find.widgetWithText(FormRow, label));
      await tester.pump();
      await tester.enterText(fieldOf(label), text);
      await settle(tester);
    }

    List<Override> noSatellite() => [
      reefHealthForDiveProvider.overrideWith(
        (ref, request) async => const ReefPart<ReefHealth>.empty(),
      ),
      reefHabitatProvider.overrideWith(
        (ref, location) async => const ReefPart<ReefHabitat>.empty(),
      ),
    ];

    testWidgets('a sea-level dive with nothing logged is offered both', (
      tester,
    ) async {
      await pumpPage(tester, visible: cards, size: tall);
      await unlock(tester);

      expect(find.byKey(addAltitude), findsOneWidget);
      expect(find.byKey(addEnvironment), findsOneWidget);
      expect(find.byTooltip('Edit Environment'), findsNothing);
    });

    // The Environment card shows for satellite conditions alone, which only
    // a provider knows about. The strip must not offer a card that is there.
    testWidgets('a dive showing satellite conditions is not offered '
        'Environment', (tester) async {
      await pumpPage(
        tester,
        visible: cards,
        size: tall,
        stored: dive.copyWith(site: reef),
        extra: [
          reefHealthForDiveProvider.overrideWith(
            (ref, request) async => ReefPart.ok(
              ReefHealth(
                sst: 30.1,
                sstAnomaly: 0.8,
                degreeHeatingWeeks: 4.2,
                alertLevel: BleachingAlertLevel.watch,
                observedAt: DateTime.utc(2023, 1, 1, 12),
              ),
            ),
          ),
          reefHabitatProvider.overrideWith(
            (ref, location) async =>
                const ReefPart.ok(ReefHabitat(onReef: true)),
          ),
        ],
      );
      await unlock(tester);

      expect(find.byTooltip('Edit Environment'), findsOneWidget);
      expect(find.byKey(addEnvironment), findsNothing);
      expect(find.byKey(addAltitude), findsOneWidget);
    });

    testWidgets('unreadable input: Done and Save both refuse, and Save says '
        'why', (tester) async {
      final page = await pumpPage(tester, visible: cards, size: tall);
      await unlock(tester);
      await tester.tap(find.byKey(addAltitude));
      await settle(tester);
      final l10n = l10nOf(tester);
      final altitude = l10n.diveLog_edit_label_altitude;

      // A readable change first, so there is something to save.
      await typeIn(tester, l10n.diveLog_edit_label_surfacePressure, '900');
      await typeIn(tester, altitude, '1.2.3');

      await tester.tap(find.text('Done'));
      await settle(tester);
      expect(find.byType(DiveAltitudeCardEditor), findsOneWidget);

      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(page.save.calls, isEmpty);
      expect(find.text(l10n.recordEdit_fixInvalid), findsOneWidget);
      expect(find.text(l10n.recordEdit_saveFailed), findsNothing);
      expect(find.byTooltip('Unlock to edit'), findsNothing);

      await tester.enterText(fieldOf(altitude), '120');
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);

      final saved = page.save.calls.single;
      expect(saved.merged.altitude, 120);
      expect(saved.merged.surfacePressure, closeTo(0.9, 1e-9));
      expect(saved.cards, ['altitude']);
      expect(find.byTooltip('Unlock to edit'), findsOneWidget);
    });

    testWidgets('unreadable input is forgotten after Cancel', (tester) async {
      await pumpPage(tester, visible: cards, size: tall);
      await unlock(tester);
      await tester.tap(find.byKey(addAltitude));
      await settle(tester);
      await typeIn(tester, l10nOf(tester).diveLog_edit_label_altitude, '1.2.3');
      expect(controller(tester).invalidCardIds, {'altitude'});

      await tester.tap(find.text('Cancel'));
      await settle(tester);

      // Nothing readable was changed, so there is nothing to ask about.
      expect(find.text('Discard'), findsNothing);
      expect(find.byTooltip('Unlock to edit'), findsOneWidget);

      await unlock(tester);
      expect(controller(tester).invalidCardIds, isEmpty);
      expect(controller(tester).refusedForInvalidInput, isFalse);
      expect(action(tester, 'Save').onPressed, isNull);
    });

    // 4050 ft reads back as 1,234.44 m and 25.69 inHg as 0.86996 bar.
    testWidgets('opening and closing a card in imperial units leaves the '
        'sitting clean', (tester) async {
      final page = await pumpPage(
        tester,
        visible: cards,
        size: tall,
        imperial: true,
        stored: dive.copyWith(altitude: 1234.5, surfacePressure: 0.87),
      );
      await unlock(tester);
      await tester.tap(find.byTooltip('Edit Altitude Dive'));
      await settle(tester);

      // The Environment card shows the pressure as well: look in the editor.
      Finder inEditor(String text) => find.descendant(
        of: find.byType(DiveAltitudeCardEditor),
        matching: find.text(text),
      );
      await tester.tap(inEditor('4050 ft'));
      await settle(tester);
      await tester.tap(inEditor('25.69 inHg'));
      await settle(tester);
      await tester.tap(find.text('Done'));
      await settle(tester);

      expect(find.byType(DiveAltitudeCardEditor), findsNothing);
      expect(controller(tester).isDirty, isFalse);
      expect(action(tester, 'Save').onPressed, isNull);
      expect(page.save.calls, isEmpty);
    });

    testWidgets('emptying the altitude and saving stores no altitude', (
      tester,
    ) async {
      final page = await pumpPage(
        tester,
        visible: cards,
        size: tall,
        stored: dive.copyWith(altitude: 900),
      );
      await unlock(tester);
      await tester.tap(find.byTooltip('Edit Altitude Dive'));
      await settle(tester);

      await typeIn(tester, l10nOf(tester).diveLog_edit_label_altitude, '');
      await tester.tap(find.text('Save'));
      await settle(tester);

      final saved = page.save.calls.single;
      expect(saved.merged.altitude, isNull);
      expect(saved.cards, ['altitude']);
    });

    testWidgets('the entry method carries the exit method with it', (
      tester,
    ) async {
      final page = await pumpPage(
        tester,
        visible: cards,
        size: tall,
        stored: dive.copyWith(airTemp: 20),
      );
      await unlock(tester);
      await tester.tap(find.byTooltip('Edit Environment'));
      await settle(tester);
      expect(find.byType(DiveEnvironmentCardEditor), findsOneWidget);

      await tester.tap(
        find.text(l10nOf(tester).diveLog_edit_label_entryMethod),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shore').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await settle(tester);

      final saved = page.save.calls.single;
      expect(saved.merged.entryMethod, EntryMethod.shore);
      expect(saved.merged.exitMethod, EntryMethod.shore);
      expect(saved.cards, ['environment']);
    });

    // The fetch belongs to the Environment card and fills a value the
    // Altitude card owns. Both cards already carry a change here, so the
    // set of changed cards does not move: the page redraws the Altitude
    // card only because a card that is not open changed again.
    testWidgets('a fetched pressure shows on the closed Altitude card', (
      tester,
    ) async {
      final page = await pumpPage(
        tester,
        visible: cards,
        size: tall,
        stored: dive.copyWith(altitude: 900, site: reef),
        extra: [
          ...noSatellite(),
          weatherServiceProvider.overrideWithValue(
            _FakeWeather(const WeatherData(humidity: 70, surfacePressure: 0.9)),
          ),
        ],
      );
      await unlock(tester);
      final l10n = l10nOf(tester);
      final altitudeCard = find.byType(DiveAltitudeSection);
      Finder onAltitudeCard(Finder what) =>
          find.descendant(of: altitudeCard, matching: what);

      // Change the altitude and close its card.
      await tester.tap(find.byTooltip('Edit Altitude Dive'));
      await settle(tester);
      await typeIn(tester, l10n.diveLog_edit_label_altitude, '950');
      await tester.tap(find.text('Done'));
      await settle(tester);
      expect(onAltitudeCard(find.byType(RecordChangedDot)), findsOneWidget);
      expect(onAltitudeCard(find.text('900 mbar')), findsNothing);

      // Change the Environment card too, then fetch.
      await tester.tap(find.byKey(addEnvironment));
      await settle(tester);
      await typeIn(tester, l10n.diveLog_edit_label_humidity, '50');
      expect(controller(tester).session!.changedCardIds, {
        'altitude',
        'environment',
      });
      await tester.tap(find.text('Fetch Weather'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.common_action_ok));
      await tester.pumpAndSettle();

      expect(onAltitudeCard(find.text('900 mbar')), findsOneWidget);

      await tester.tap(find.text('Save'));
      await settle(tester);
      final saved = page.save.calls.single;
      expect(saved.merged.altitude, 950);
      expect(saved.merged.surfacePressure, 0.9);
      expect(saved.merged.humidity, 70);
      expect(saved.cards, unorderedEquals(['altitude', 'environment']));
    });

    // Typing the first value into an empty card changes whether the page
    // shows that card at all, and for Environment whether it shares a row
    // with Details. Neither may rebuild the editor being typed into.
    group('the first value typed into a card added from the strip', () {
      // Wide enough for Details and Environment to share a row, and below
      // the width at which the page moves into the list-and-detail layout.
      const wide = Size(1000, 2600);

      bool hasFocus(WidgetTester tester, Finder field) => tester
          .widget<EditableText>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus;

      testWidgets('keeps the Environment editor, beside Details', (
        tester,
      ) async {
        await pumpPage(
          tester,
          size: wide,
          visible: const {
            DiveDetailSectionId.details,
            DiveDetailSectionId.environment,
          },
        );
        await unlock(tester);
        await tester.tap(find.byKey(addEnvironment));
        await settle(tester);
        final editor = find.byType(DiveEnvironmentCardEditor);
        final before = tester.state(editor);
        final details = find.byType(DiveDetailsSection);
        expect(
          tester.getRect(editor).left,
          greaterThan(tester.getRect(details).right - 1),
        );
        final label = l10nOf(tester).diveLog_edit_label_airTemp;

        await typeIn(tester, label, '2');

        expect(controller(tester).session!.working.airTemp, 2);
        expect(identical(tester.state(editor), before), isTrue);
        expect(hasFocus(tester, fieldOf(label)), isTrue);
        expect(
          tester.getRect(editor).left,
          greaterThan(tester.getRect(details).right - 1),
        );
      });

      testWidgets('keeps the Altitude editor', (tester) async {
        await pumpPage(tester, size: wide, visible: cards);
        await unlock(tester);
        await tester.tap(find.byKey(addAltitude));
        await settle(tester);
        final editor = find.byType(DiveAltitudeCardEditor);
        final before = tester.state(editor);
        final label = l10nOf(tester).diveLog_edit_label_altitude;

        await typeIn(tester, label, '12');

        expect(controller(tester).session!.working.altitude, 12);
        expect(identical(tester.state(editor), before), isTrue);
        expect(hasFocus(tester, fieldOf(label)), isTrue);
      });
    });
  });
}
