import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_draft.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_fields.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_hero.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/shared_items/item_sharing_field.dart';

import '../../../../helpers/test_database.dart';
import 'trip_detail_page_new_harness.dart';
import 'trip_detail_page_unlock_harness.dart' show twoDivers;
import 'trip_page_drag_helpers.dart';

/// A new trip opens on the trip page, already unlocked, its Overview in
/// the prepare shape (issue #4527, phase 3, plan 11).
void main() {
  final l = AppLocalizationsEn();

  setUp(() async => setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  final candidates = [
    DiveCandidate(
      dive: Dive(id: 'v1', dateTime: DateTime(2030, 5, 31, 9)),
    ),
  ];

  RecordEditController<Trip> controllerOf(WidgetTester tester) =>
      RecordEditScope.maybeOf<Trip>(
        tester.element(find.byType(RecordCardFrame<Trip>).first),
      )!;

  Finder nameField() => find.byKey(const Key('trip-edit-name'));

  Future<void> typeName(WidgetTester tester, [String name = 'Bonaire']) async {
    await tester.enterText(nameField(), name);
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  Future<void> tapCancel(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();
  }

  testWidgets('a new trip opens unlocked with its header and notes open', (
    tester,
  ) async {
    await pumpNewTripPage(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text(l.trips_edit_appBar_add), findsOneWidget);
    expect(nameField(), findsOneWidget);
    expect(find.byKey(const Key('trip-edit-notes')), findsOneWidget);
    expect(find.byKey(const Key('trip-prepare-overview')), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    // The Overview always draws the Plan row, so the strip never offers it.
    expect(
      find.descendant(
        of: find.byType(AddStrip),
        matching: find.text(l.trips_overview_plan),
      ),
      findsNothing,
    );
  });

  testWidgets('Save waits for the first entry', (tester) async {
    final harness = await pumpNewTripPage(tester);

    await tapSave(tester);

    expect(harness.save.creates, isEmpty);
    expect(find.byType(RecordEditBar), findsOneWidget);
  });

  testWidgets('an untouched new trip leaves without asking', (tester) async {
    final harness = await pumpNewTripPage(tester);

    await tapCancel(tester);

    expect(find.text(l.forms_discard_title), findsNothing);
    expect(harness.poppedAtAll, isTrue);
    expect(harness.popped, isNull);
  });

  testWidgets('an entry asks before leaving, and nothing is written', (
    tester,
  ) async {
    final harness = await pumpNewTripPage(tester, candidates: candidates);
    await typeName(tester);

    await tapCancel(tester);
    expect(find.text(l.forms_discard_title), findsOneWidget);
    await tester.tap(find.text(l.forms_discard_keepEditing));
    await tester.pumpAndSettle();
    expect(find.byType(RecordEditBar), findsOneWidget);

    await tapCancel(tester);
    await tester.tap(find.text(l.forms_discard_discard));
    await tester.pumpAndSettle();

    expect(harness.popped, isNull);
    expect(harness.save.creates, isEmpty);
    expect(harness.save.calls, isEmpty);
    expect(harness.tripDives.asked, isEmpty);
    expect(harness.tripDives.assigned, isEmpty);
    expect(harness.shares.setCalls, isEmpty);
  });

  testWidgets('Save creates the trip and pops its id', (tester) async {
    final harness = await pumpNewTripPage(tester);
    await typeName(tester);

    await tapSave(tester);

    final created = harness.save.creates.single;
    expect(created.trip.name, 'Bonaire');
    expect(created.trip.diverId, 'd1');
    expect(created.trip.tripType, TripType.shore);
    expect(created.cards, contains('header'));
    expect(harness.popped, created.trip.id);
  });

  testWidgets('in the pane, Save hands the id to the pane', (tester) async {
    final harness = await pumpNewTripPage(tester, embedded: true);
    expect(find.text(l.trips_edit_appBar_add), findsOneWidget);
    await typeName(tester);

    await tester.tap(find.text(l.forms_save));
    await tester.pump(const Duration(milliseconds: 500));

    expect(harness.createdIds, [harness.save.creates.single.trip.id]);
  });

  testWidgets('in the pane, Cancel with an entry asks first', (tester) async {
    final harness = await pumpNewTripPage(tester, embedded: true);
    await typeName(tester);

    await tester.tap(find.text(l.forms_cancel));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(l.forms_discard_title), findsOneWidget);
    await tester.tap(find.text(l.forms_discard_discard));
    await tester.pump(const Duration(milliseconds: 500));

    expect(harness.cancelled, 1);
    expect(harness.save.createAttempts, isEmpty);
  });

  testWidgets('in the pane, Cancel tells the pane and creates nothing', (
    tester,
  ) async {
    final harness = await pumpNewTripPage(tester, embedded: true);

    await tester.tap(find.text(l.forms_cancel));
    await tester.pump(const Duration(milliseconds: 500));

    expect(harness.cancelled, 1);
    expect(harness.createdIds, isEmpty);
    expect(harness.save.createAttempts, isEmpty);
  });

  testWidgets('a Save that fails keeps everything, and a retry creates once '
      'with the same id', (tester) async {
    final harness = await pumpNewTripPage(tester);
    await typeName(tester);
    harness.save.fail = true;

    await tapSave(tester);
    expect(find.text(l.recordEdit_saveFailed), findsOneWidget);
    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text('Bonaire'), findsWidgets);

    harness.save.fail = false;
    await tapSave(tester);

    final created = harness.save.creates.single;
    expect(harness.save.createAttempts, [created.trip.id, created.trip.id]);
    expect(harness.popped, created.trip.id);
  });

  testWidgets('a profile switch before Save keeps the trip the profile it '
      'was opened for', (tester) async {
    final harness = await pumpNewTripPage(tester);
    await typeName(tester);

    harness.container.read(newTripPageDiverProvider.notifier).state = 'd2';
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(harness.save.creates.single.trip.diverId, 'd1');
  });

  testWidgets("after a profile switch the question offers the trip's own "
      "profile's dives", (tester) async {
    final harness = await pumpNewTripPage(tester, candidates: candidates);
    await typeName(tester);

    harness.container.read(newTripPageDiverProvider.notifier).state = 'd2';
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(harness.tripDives.asked.single.diverId, 'd1');
  });

  testWidgets('a larger trip from a draft shows on the page', (tester) async {
    final draft = TripDraft(
      trip: Trip(
        id: '',
        name: 'Misool',
        startDate: DateTime(2030, 5, 30),
        endDate: DateTime(2030, 6, 2),
        parentTripId: 'p1',
        createdAt: DateTime(2030),
        updatedAt: DateTime(2030),
      ),
      diveIds: const ['a'],
    );
    await pumpNewTripPage(
      tester,
      draft: draft,
      trips: {
        'p1': Trip(
          id: 'p1',
          name: 'Raja Ampat',
          startDate: DateTime(2030, 5, 20),
          endDate: DateTime(2030, 6, 10),
          createdAt: DateTime(2030),
          updatedAt: DateTime(2030),
        ),
      },
    );

    expect(find.text(l.trips_partOf('Raja Ampat')), findsOneWidget);
  });

  testWidgets('a new trip builds with no stored row, every offered card '
      'opened', (tester) async {
    final harness = await pumpNewTripPage(tester);
    final controller = controllerOf(tester);
    final id = controller.session!.stored.id;

    controller.session!.set(tripTypeField, TripType.liveaboard);
    await tester.pumpAndSettle();
    for (final card in ['plan', 'vessel', 'notes', 'documents']) {
      controller.openCard(card);
      await tester.pumpAndSettle();
    }

    expect(tester.takeException(), isNull);
    expect(find.byType(TabBar), findsNothing);
    expect(harness.container.exists(tripWithStatsProvider(id)), isFalse);
    expect(harness.container.exists(tripStoryProvider(id)), isFalse);
    expect(harness.container.exists(tripByIdProvider(id)), isFalse);
    // The prepare page's rows that count what other tabs hold.
    expect(
      harness.container.exists(tripChecklistAllItemsProvider(id)),
      isFalse,
    );
    expect(harness.container.exists(tripGearProvider(id)), isFalse);
  });

  testWidgets('a liveaboard lays out its Vessel, and its name is required', (
    tester,
  ) async {
    final harness = await pumpNewTripPage(tester);
    await typeName(tester);
    controllerOf(tester).session!.set(tripTypeField, TripType.liveaboard);
    await tester.pumpAndSettle();

    // Laid out open as the trip becomes a liveaboard, before any Save.
    final vesselName = find.byKey(const Key('trip-edit-vessel-name'));
    expect(vesselName, findsOneWidget);
    await tapSave(tester);
    expect(harness.save.creates, isEmpty);

    await tester.enterText(vesselName, 'MV Green');
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(harness.save.creates.single.trip.tripType, TripType.liveaboard);
    expect(harness.vessels.writes.single.vesselName, 'MV Green');
  });

  testWidgets('a new trip asks which dives in its dates join it at Save, and '
      'the picked ones join it', (tester) async {
    final harness = await pumpNewTripPage(tester, candidates: candidates);
    await typeName(tester);

    await tapSave(tester);
    expect(find.text(l.trips_diveScan_title), findsOneWidget);
    expect(harness.save.creates, isEmpty);
    await tester.tap(find.text(l.trips_diveScan_addButton(1)));
    await tester.pumpAndSettle();

    expect(harness.save.creates, hasLength(1));
    expect(harness.tripDives.assigned.single, ['v1']);
    // To the trip just made, under the id it was created with.
    expect(
      harness.tripDives.assignedTo.single,
      harness.save.creates.single.trip.id,
    );
    expect(find.text(l.trips_diveScan_added(1)), findsOneWidget);
  });

  /// [diveIdsForTripProvider] of [tripId], counting its reads, kept alive
  /// as a page showing that trip would keep it.
  ({List<Object> overrides, int Function() reads}) countedDivesOf(
    String tripId,
  ) {
    var reads = 0;
    return (
      overrides: [
        diveIdsForTripProvider(tripId).overrideWith((ref) async {
          reads++;
          return const <String>[];
        }),
      ],
      reads: () => reads,
    );
  }

  testWidgets('a dive taken from another trip leaves that trip read again', (
    tester,
  ) async {
    final egypt = countedDivesOf('egypt-trip');
    final harness = await pumpNewTripPage(
      tester,
      candidates: [
        DiveCandidate(
          dive: Dive(id: 'v1', dateTime: DateTime(2030, 5, 31, 9)),
          currentTripId: 'egypt-trip',
          currentTripName: 'Egypt',
        ),
      ],
      extraOverrides: egypt.overrides,
    );
    harness.container.listen(diveIdsForTripProvider('egypt-trip'), (_, _) {});
    await tester.pumpAndSettle();
    final before = egypt.reads();
    await typeName(tester);

    await tapSave(tester);
    // A dive on another trip starts unticked: tick it, then add it.
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.trips_diveScan_addButton(1)));
    await tester.pumpAndSettle();

    expect(harness.tripDives.assigned.single, ['v1']);
    expect(egypt.reads(), greaterThan(before));
  });

  testWidgets('a shared new trip shows who it is shared with, by the '
      "diver's default", (tester) async {
    await pumpNewTripPage(tester, divers: twoDivers, shareByDefault: true);

    expect(find.byType(ItemSharingField), findsOneWidget);
    expect(find.text('Everyone'), findsOneWidget);
  });

  testWidgets('a new trip shared with one profile writes that share under '
      'its id, by the acting profile', (tester) async {
    final harness = await pumpNewTripPage(tester, divers: twoDivers);

    tester
        .widget<ItemSharingField>(find.byType(ItemSharingField))
        .onChanged(const ItemSharing(profileIds: {'d2'}));
    await tester.pumpAndSettle();
    expect(harness.shares.setCalls, isEmpty);
    await typeName(tester);
    await tapSave(tester);

    final id = harness.save.creates.single.trip.id;
    expect(harness.shares.setCalls, [
      (id, const ItemSharing(profileIds: {'d2'})),
    ]);
    expect(harness.shares.setActingDivers, ['d1']);
  });

  testWidgets('dismissing the question creates the trip with no dives', (
    tester,
  ) async {
    final harness = await pumpNewTripPage(tester, candidates: candidates);
    await typeName(tester);

    await tapSave(tester);
    await tester.tap(find.text(l.trips_diveScan_cancel).last);
    await tester.pumpAndSettle();

    expect(harness.save.creates, hasLength(1));
    expect(harness.tripDives.assigned, isEmpty);
  });

  testWidgets('no active diver creates without asking', (tester) async {
    final harness = await pumpNewTripPage(
      tester,
      candidates: candidates,
      activeDiverId: null,
    );
    await typeName(tester);

    await tapSave(tester);

    expect(find.text(l.trips_diveScan_title), findsNothing);
    expect(harness.save.creates, hasLength(1));
  });

  testWidgets('a draft is a change of the header, is not asked about, and '
      'its dives join the trip', (tester) async {
    final draft = TripDraft(
      trip: Trip(
        id: '',
        name: 'Bonaire 2030',
        startDate: DateTime(2030, 5, 30),
        endDate: DateTime(2030, 6, 2),
        location: 'Bonaire',
        createdAt: DateTime(2030),
        updatedAt: DateTime(2030),
      ),
      diveIds: const ['a', 'b'],
    );
    final harness = await pumpNewTripPage(
      tester,
      draft: draft,
      candidates: candidates,
    );
    expect(find.text('Bonaire 2030'), findsWidgets);

    await tapSave(tester);

    expect(find.text(l.trips_diveScan_title), findsNothing);
    expect(harness.tripDives.asked, isEmpty);
    final created = harness.save.creates.single;
    expect(created.trip.name, 'Bonaire 2030');
    expect(created.trip.location, 'Bonaire');
    expect(created.dives, ['a', 'b']);
  });

  testWidgets('the trips a draft took its dives from are read again', (
    tester,
  ) async {
    final source = countedDivesOf('p');
    final draft = TripDraft(
      trip: Trip(
        id: '',
        name: 'Bonaire 2030',
        startDate: DateTime(2030, 5, 30),
        endDate: DateTime(2030, 6, 2),
        createdAt: DateTime(2030),
        updatedAt: DateTime(2030),
      ),
      diveIds: const ['a'],
      sourceTripIds: const {'p'},
    );
    final harness = await pumpNewTripPage(
      tester,
      draft: draft,
      extraOverrides: source.overrides,
    );
    harness.container.listen(diveIdsForTripProvider('p'), (_, _) {});
    await tester.pumpAndSettle();
    final before = source.reads();

    await tapSave(tester);

    expect(harness.save.creates, hasLength(1));
    expect(source.reads(), greaterThan(before));
  });

  /// Opens the date picker of [tile], types [date] (month/day/year) into
  /// it and confirms.
  Future<void> pickDate(WidgetTester tester, String tile, String date) async {
    await tester.tap(find.byKey(Key(tile)));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byIcon(Icons.edit_outlined),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byType(TextField),
      ),
      date,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  DateTime endPickerOpensAt(WidgetTester tester) => tester
      .widget<DatePickerDialog>(find.byType(DatePickerDialog))
      .initialDate!;

  // As the form's did (#2266 review): a new trip's end is a placeholder
  // until the diver picks one, so its picker opens at the start just
  // picked, not weeks away from it.
  testWidgets('the end picker opens at a start just picked, until an end is '
      'picked', (tester) async {
    await pumpNewTripPage(tester);

    await pickDate(tester, 'trip-edit-start', '01/15/2023');
    await tester.tap(find.byKey(const Key('trip-edit-end')));
    await tester.pumpAndSettle();
    expect(endPickerOpensAt(tester), DateTime(2023, 1, 15));
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    await pickDate(tester, 'trip-edit-end', '01/20/2023');
    await tester.tap(find.byKey(const Key('trip-edit-end')));
    await tester.pumpAndSettle();
    expect(endPickerOpensAt(tester), DateTime(2023, 1, 20));
  });

  const headerFields = [
    'trip-edit-type',
    'trip-edit-name',
    'trip-edit-start',
    'trip-edit-end',
    'trip-edit-return-flight',
    'trip-edit-location',
    'trip-edit-resort',
    'trip-edit-liveaboard-name',
  ];

  Rect headerCard(WidgetTester tester) => tester.getRect(
    find.ancestor(
      of: find.byKey(const Key('trip-edit-name'), skipOffstage: false),
      matching: find.byType(RecordCardFrame<Trip>, skipOffstage: false),
    ),
  );

  // The header editor sits on the prepare page, under the hero, and
  // scrolls with it (issue #4927).
  for (final (name, size, embedded) in [
    ('a phone', const Size(402, 874), false),
    ('a desktop window', const Size(1280, 800), false),
    ('the master-detail pane', const Size(900, 800), true),
  ]) {
    testWidgets('on $name every field of the header editor drags into view, '
        'on the prepare page under the hero', (tester) async {
      await pumpNewTripPage(tester, size: size, embedded: embedded);
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byKey(const Key('trip-prepare-overview')),
          matching: nameField(),
        ),
        findsOneWidget,
      );
      expect(
        headerCard(tester).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(TripStoryHero)).bottom),
      );

      for (final key in headerFields) {
        final field = find.byKey(Key(key), skipOffstage: false);
        await dragPageUntilShown(
          tester,
          field,
          bottom: size.height,
          from: Offset(size.width / 2, size.height / 2),
        );
        expectFullyShown(tester, field, bottom: size.height);
      }
    });
  }

  testWidgets('on a phone with the keyboard up, the header editor shows the '
      'focused field and scrolls to its last', (tester) async {
    await pumpNewTripPage(tester, size: const Size(402, 874));
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    // The keyboard, as an iPhone 17 Pro shows it for the name field.
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    const keyboardTop = 874.0 - 336;
    expect(tester.getRect(nameField()).bottom, lessThanOrEqualTo(keyboardTop));
    final last = find.byKey(
      const Key('trip-edit-liveaboard-name'),
      skipOffstage: false,
    );
    await dragPageUntilShown(
      tester,
      last,
      bottom: keyboardTop,
      from: const Offset(201, 300),
    );
    expectFullyShown(tester, last, bottom: keyboardTop);
  });
}
