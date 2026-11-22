import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklists_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_section.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/features/divers/presentation/providers/profile_hides_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/liveaboard_details_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/data/services/trip_edit_save_service.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/entities/scrubber_margin.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';
import 'package:submersion/features/trips/presentation/editing/trip_checklists_sitting.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_equipment_repository.dart';
import 'package:submersion/features/trips/data/services/trip_fill_passport_copy.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/presentation/editing/trip_gear_sitting.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_edit_navigation.dart';
import 'package:submersion/features/trips/presentation/pages/trip_detail_page.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/scrubber_margin_providers.dart';
import 'package:submersion/features/trips/presentation/providers/side_trip_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_day_weather_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_story_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_app.dart';

/// The trip the page shows, as stored: a shore trip in 2030, still to come,
/// so the Overview is the prepare page, with notes.
final redSea = Trip(
  id: 't1',
  diverId: 'd1',
  name: 'Red Sea',
  startDate: DateTime(2030, 6, 1),
  endDate: DateTime(2030, 6, 8),
  location: 'Hurghada',
  notes: 'Bring the reef hook',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// Records each save the page asks for, stores its result where the page
/// reads the trip from, and can fail.
class FakeTripSave implements TripEditSaveService {
  FakeTripSave(this.stored);

  final StateController<Trip?> stored;

  final calls = <({Trip after, Set<String> cards})>[];
  bool fail = false;

  /// Whether to run the held writes a save is given, as the real one does
  /// inside its transaction.
  bool runHeld = true;

  /// Holds the write until completed.
  Completer<void>? gate;

  @override
  Future<({Trip before, Trip after})?> save({
    required String tripId,
    required Trip Function(Trip stored) apply,
    required Iterable<String> changedCardIds,
    required String? actingDiverId,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
  }) async {
    if (fail) throw StateError('the save failed');
    await gate?.future;
    final before = stored.state!;
    final after = apply(before);
    // In the real save the held writes run in its transaction: one that
    // throws (a refusal) leaves nothing written.
    if (runHeld) await alsoWrite?.call();
    calls.add((after: after, cards: changedCardIds.toSet()));
    stored.state = after;
    return (before: before, after: after);
  }

  /// Each create the page asks for (issue #4527, plan 11).
  final creates = <({Trip trip, Set<String> cards, List<String> dives})>[];

  /// The id of every create asked for, a failed one included.
  final createAttempts = <String>[];

  @override
  Future<Trip> create({
    required Trip trip,
    required Iterable<String> changedCardIds,
    List<String> draftDiveIds = const [],
    Future<void> Function()? alsoWrite,
  }) async {
    createAttempts.add(trip.id);
    if (fail) throw StateError('the create failed');
    await gate?.future;
    if (runHeld) await alsoWrite?.call();
    creates.add((
      trip: trip,
      cards: changedCardIds.toSet(),
      dives: draftDiveIds,
    ));
    stored.state = trip;
    return trip;
  }
}

/// A trip list that records deletes and hides, and writes nothing.
class FakeTripList extends StateNotifier<AsyncValue<List<TripWithStats>>>
    implements TripListNotifier {
  FakeTripList() : super(const AsyncValue.data([]));

  final deleted = <String>[];

  /// Unhide throws, as a write that fails does.
  bool failUnhide = false;

  @override
  Future<void> unhideTrip(String id) async {
    if (failUnhide) throw StateError('the unhide failed');
  }

  @override
  Future<bool> deleteTrip(String id) async {
    deleted.add(id);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A liveaboard's details without a database: [details] as stored, and
/// each write recorded.
class FakeVessels implements LiveaboardDetailsRepository {
  FakeVessels([this.details]);

  LiveaboardDetails? details;
  final writes = <LiveaboardDetails>[];

  /// The read throws, as a database that cannot be read does.
  bool failRead = false;

  @override
  Future<LiveaboardDetails?> getByTripId(String tripId) async {
    if (failRead) throw StateError('the read failed');
    return details;
  }

  @override
  Future<LiveaboardDetails> createOrUpdate(LiveaboardDetails details) async {
    writes.add(details);
    this.details = details;
    return details;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A trip's itinerary days without a database: [days] as stored, and each
/// write recorded.
class FakeItineraryDays implements ItineraryDayRepository {
  FakeItineraryDays([List<ItineraryDay> days = const []]) : days = [...days];

  final List<ItineraryDay> days;
  final saved = <ItineraryDay>[];
  final updated = <ItineraryDay>[];

  /// Holds the read until completed.
  Completer<void>? gate;

  /// The read throws, as a database that cannot be read does.
  bool failRead = false;

  @override
  Future<List<ItineraryDay>> getByTripId(String tripId) async {
    await gate?.future;
    if (failRead) throw StateError('the read failed');
    return [...days];
  }

  @override
  Future<void> saveAll(List<ItineraryDay> days) async => saved.addAll(days);

  @override
  Future<void> updateDay(ItineraryDay day) async => updated.add(day);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The trip repository's dives questions, without a database: [candidates]
/// found for any dates, and each assignment recorded.
class FakeTripDives implements TripRepository {
  FakeTripDives([this.candidates = const []]);

  List<DiveCandidate> candidates;

  /// The candidates read throws, as a database that cannot be read does.
  bool failRead = false;
  final asked = <({DateTime start, DateTime end, String diverId})>[];
  final assigned = <List<String>>[];

  /// The trip each [assigned] list went to, in the same order.
  final assignedTo = <String>[];

  /// The trips stored, by id, for what reads one.
  final byId = <String, Trip>{};

  @override
  Future<Trip?> getTripById(String id) async => byId[id];

  @override
  Stream<void> watchTripsChanges() => const Stream.empty();

  @override
  Future<List<DiveCandidate>> findCandidateDivesForTrip({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
    required String diverId,
  }) async {
    asked.add((start: startDate, end: endDate, diverId: diverId));
    if (failRead) throw StateError('the read failed');
    return candidates;
  }

  @override
  Future<void> assignDivesToTrip(List<String> diveIds, String tripId) async {
    assigned.add(diveIds);
    assignedTo.add(tripId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A trip's checklists without a database: [held] as stored, and each
/// write recorded by name.
class FakeTripChecklists implements TripChecklistsRepository {
  FakeTripChecklists(this.held, this.writes);

  final TripChecklistsHeld held;
  final List<String> writes;

  /// Holds the read until completed.
  Completer<void>? gate;

  @override
  Future<List<TripChecklist>> getChecklistsForTrip(String tripId) async {
    await gate?.future;
    return held.checklists;
  }

  @override
  Future<TripChecklist> createChecklist({
    required String tripId,
    required String name,
    String? id,
  }) async {
    writes.add('createChecklist $name');
    return TripChecklist(
      id: id ?? 'new',
      tripId: tripId,
      name: name,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  @override
  Future<void> renameChecklist(String id, String name) async =>
      writes.add('renameChecklist $id $name');

  @override
  Future<void> reorderChecklists(String tripId, List<String> ids) async =>
      writes.add('reorderChecklists ${ids.join(',')}');

  @override
  Future<void> deleteChecklist(String id) async =>
      writes.add('deleteChecklist $id');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A trip's checklist items and sections without a database: [held] as
/// stored, and each write recorded by name.
class FakeTripChecklistItems implements TripChecklistRepository {
  FakeTripChecklistItems(this.held, this.writes);

  final TripChecklistsHeld held;
  final List<String> writes;

  /// The trip start each Save as template was given.
  final templateStarts = <DateTime>[];

  @override
  Future<List<TripChecklistItem>> getAllItemsForTrip(String tripId) async =>
      held.items;

  @override
  Future<List<TripChecklistSection>> getSectionsForChecklist(
    String checklistId,
  ) async => held.sectionsOf(checklistId);

  @override
  Future<List<TripChecklistSection>> getSectionsForTrip(String tripId) async =>
      held.sections;

  @override
  Future<List<TripChecklistItem>> getByChecklistId(String checklistId) async =>
      held.itemsOf(checklistId);

  @override
  Future<TripChecklistItem> createItem(
    TripChecklistItem item, {
    bool keepSortOrder = false,
  }) async {
    writes.add('createItem ${item.title}');
    return item;
  }

  @override
  Future<void> updateItem(TripChecklistItem item) async =>
      writes.add('updateItem ${item.title} done=${item.isDone}');

  @override
  Future<void> toggleDone(String id, {required bool isDone}) async =>
      writes.add('toggleDone $id');

  @override
  Future<void> deleteItem(String id) async => writes.add('deleteItem $id');

  @override
  Future<ChecklistTemplate> saveAsTemplate({
    required String checklistId,
    required DateTime tripStartDate,
    required String name,
    String? diverId,
    ChecklistRows? rows,
  }) async {
    writes.add(
      'saveAsTemplate $name ${[for (final i in rows?.items ?? const <TripChecklistItem>[]) '${i.title}:${i.isDone}'].join(',')}',
    );
    templateStarts.add(tripStartDate);
    return ChecklistTemplate(
      id: 'tp',
      name: name,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A trip's packed gear links without a database: each write recorded.
class FakeTripPacks implements TripEquipmentRepository {
  FakeTripPacks(this.writes);

  final List<String> writes;

  @override
  Future<int> pack(String tripId, Iterable<String> equipmentIds) async {
    writes.add('pack ${equipmentIds.join(',')}');
    return equipmentIds.length;
  }

  @override
  Future<void> unpack(String tripId, String equipmentId) async =>
      writes.add('unpack $equipmentId');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A trip's cylinder board without a database: [held] as stored, and each
/// write recorded.
class FakeTripBoard implements TripCylinderRepository {
  FakeTripBoard(this.held, this.writes);

  final TripCylindersHeld held;
  final List<String> writes;

  @override
  Future<List<TripCylinder>> getCylindersForTrip(String tripId) async =>
      held.slots;

  @override
  Future<Map<String, List<TripCylinderEvent>>> getEventsForTrip(
    String tripId,
  ) async => {
    for (final e in held.events)
      e.tripCylinderId: [
        for (final o in held.events)
          if (o.tripCylinderId == e.tripCylinderId) o,
      ],
  };

  @override
  Future<Map<String, List<TripCylinderTankUse>>> getTankUsesForTrip(
    String tripId,
  ) async => held.uses;

  @override
  Future<int> countLinkedDives(String cylinderId) async => 0;

  @override
  Future<int> countTripDiveRoundsOn(String tripId, DateTime day) async => 0;

  @override
  Stream<void> watchTripCylinderChanges() => const Stream.empty();

  @override
  Stream<void> watchLedgerChanges() => const Stream.empty();

  @override
  Future<List<TripCylinder>> createCylinders(
    List<TripCylinder> cylinders,
  ) async {
    writes.add(
      'createCylinders ${[for (final c in cylinders) c.label].join(',')}',
    );
    return cylinders;
  }

  @override
  Future<void> updateCylinder(TripCylinder cylinder) async =>
      writes.add('updateCylinder ${cylinder.label}');

  @override
  Future<void> deleteCylinder(String id) async =>
      writes.add('deleteCylinder $id');

  @override
  Future<void> reorderCylinders(List<String> orderedIds) async =>
      writes.add('reorderCylinders ${orderedIds.join(',')}');

  @override
  Future<List<TripCylinderEvent>> createEvents(
    List<TripCylinderEvent> events,
  ) async {
    writes.add('createEvents ${events.length}');
    return events;
  }

  @override
  Future<void> updateEvent(TripCylinderEvent event) async =>
      writes.add('updateEvent ${event.id}');

  @override
  Future<void> deleteEvent(
    String id, {
    Future<void> Function()? alongside,
  }) async {
    writes.add('deleteEvent $id');
    await alongside?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Copies of trip fills to passports, recorded rather than written.
class FakeFillCopier implements TripFillPassportCopier {
  FakeFillCopier(this.writes);

  final List<String> writes;

  @override
  Future<void> afterSave(
    TripCylinderEvent event,
    TripCylinder slot, {
    String? diverId,
    String? stationName,
    bool stationResolved = true,
  }) async => writes.add('copy ${event.id}');

  @override
  Future<void> afterDelete(String tripEventId) async =>
      writes.add('uncopy $tripEventId');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TripPageHarness {
  TripPageHarness(
    this.save,
    this.stored,
    this.trips,
    this.shares,
    this.vessels,
    this.itinerary,
    this.tripDives,
    this.checklistWrites,
    this.gearWrites,
  );

  final FakeTripSave save;
  final StateController<Trip?> stored;
  final FakeTripList trips;
  final FakeItemShares shares;
  final FakeVessels vessels;
  final FakeItineraryDays itinerary;
  final FakeTripDives tripDives;

  /// Every checklist write, by name, in order.
  final List<String> checklistWrites;

  /// Every packing, board and passport copy write, by name, in order.
  final List<String> gearWrites;
}

final _storedProvider = StateProvider<Trip?>((ref) => redSea);

/// Pumps the trip page, at phone width, or as the list's pane when [embedded].
/// [vessel], [days] and [dives] stand in for what the page reads besides
/// the trip.
Future<TripPageHarness> pumpTripPage(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Trip? trip,
  bool openUnlocked = false,
  TripEditSection? openSection,
  TripNoteDay? openNoteDay,
  bool embedded = false,
  Size size = const Size(600, 1600),
  VoidCallback? onSittingEnded,
  VoidCallback? onDeleted,
  LiveaboardDetails? vessel,
  List<ItineraryDay> days = const [],
  List<Dive> dives = const [],
  List<Object> extraOverrides = const [],
  Widget Function(Widget page)? wrap,
  FakeItemShares? shares,
  List<Diver>? divers,
  String? activeDiverId,
  bool hasSideTrips = false,
  List<DiveCandidate> candidates = const [],
  TripChecklistsHeld checklists = const TripChecklistsHeld(),
  List<EquipmentItem> packed = const [],
  TripCylindersHeld board = const TripCylindersHeld(),
}) async {
  final checklistWrites = <String>[];
  final gearWrites = <String>[];
  final itemShares = shares ?? FakeItemShares();
  final vessels = FakeVessels(vessel);
  final itinerary = FakeItineraryDays(days);
  final tripDives = FakeTripDives(candidates);
  final shown = trip ?? redSea;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  final trips = FakeTripList();
  late TripPageHarness harness;
  final page = TripDetailPage(
    tripId: shown.id,
    openUnlocked: openUnlocked,
    openSection: openSection,
    openNoteDay: openNoteDay,
    embedded: embedded,
    onSittingEnded: onSittingEnded,
    onDeleted: onDeleted,
  );
  await tester.pumpWidget(
    testApp(
      overrides: [
        ...overrides,
        _storedProvider.overrideWith((ref) => shown),
        tripByIdProvider(
          shown.id,
        ).overrideWith((ref) async => ref.watch(_storedProvider)),
        tripWithStatsProvider(shown.id).overrideWith(
          (ref) async =>
              TripWithStats(trip: ref.watch(_storedProvider)!, diveCount: 0),
        ),
        tripStoryProvider(shown.id).overrideWith(
          (ref) async => buildTripStory(
            trip: ref.watch(_storedProvider)!,
            dives: dives,
            itineraryDays: days,
            mediaByDiveId: const {},
            sightingsByDiveId: const {},
            checklistItems: const [],
            today: DateTime.now(),
          ),
        ),
        diveIdsForTripProvider(
          shown.id,
        ).overrideWith((ref) async => [for (final d in dives) d.id]),
        divesForTripProvider(shown.id).overrideWith((ref) async => dives),
        itineraryDaysProvider(shown.id).overrideWith((ref) async => days),
        numberedItineraryDaysProvider(
          shown.id,
        ).overrideWith((ref) async => days),
        liveaboardDetailsProvider(shown.id).overrideWith((ref) async => vessel),
        liveaboardDetailsRepositoryProvider.overrideWithValue(vessels),
        itineraryDayRepositoryProvider.overrideWithValue(itinerary),
        tripRepositoryProvider.overrideWithValue(tripDives),
        tripDayWeatherProvider(shown.id).overrideWith((ref) async => const {}),
        tripDayWeatherBackfillProvider(shown.id).overrideWith((ref) async {}),
        tripGearProvider(shown.id).overrideWith((ref) async => packed),
        tripCylinderStatesProvider(
          shown.id,
        ).overrideWith((ref) async => board.states),
        tripEquipmentRepositoryProvider.overrideWithValue(
          FakeTripPacks(gearWrites),
        ),
        tripCylinderRepositoryProvider.overrideWithValue(
          FakeTripBoard(board, gearWrites),
        ),
        tripFillPassportCopierProvider.overrideWithValue(
          FakeFillCopier(gearWrites),
        ),
        tripServiceAlertsProvider(
          shown.id,
        ).overrideWith((ref) async => const []),
        tripScrubberMarginsProvider(
          shown.id,
        ).overrideWith((ref) async => const <ScrubberMargin>[]),
        tripFillForecastProvider(shown.id).overrideWith((ref) async => null),
        tripChecklistsProvider(
          shown.id,
        ).overrideWith((ref) async => checklists.checklists),
        tripChecklistProvider.overrideWith(
          (ref, id) async => checklists.itemsOf(id),
        ),
        tripChecklistSectionsProvider.overrideWith(
          (ref, id) async => checklists.sectionsOf(id),
        ),
        tripChecklistsRepositoryProvider.overrideWithValue(
          FakeTripChecklists(checklists, checklistWrites),
        ),
        tripChecklistRepositoryProvider.overrideWithValue(
          FakeTripChecklistItems(checklists, checklistWrites),
        ),
        tripChecklistAllItemsProvider(
          shown.id,
        ).overrideWith((ref) async => checklists.items),
        tripChecklistCombinedProgressProvider(
          shown.id,
        ).overrideWith((ref) async => (done: 0, total: 0)),
        tripListNotifierProvider.overrideWith((ref) => trips),
        itemSharesRepositoryProvider.overrideWithValue(itemShares),
        hasSideTripsProvider(
          shown.id,
        ).overrideWith((ref) async => hasSideTrips),
        if (divers != null)
          allDiversProvider.overrideWith((ref) async => divers),
        if (activeDiverId != null)
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) async => activeDiverId,
          ),
        tripEditSaveServiceProvider.overrideWith((ref) {
          final save = FakeTripSave(ref.watch(_storedProvider.notifier));
          harness = TripPageHarness(
            save,
            ref.watch(_storedProvider.notifier),
            trips,
            itemShares,
            vessels,
            itinerary,
            tripDives,
            checklistWrites,
            gearWrites,
          );
          return save;
        }),
        ...extraOverrides,
      ],
      child: Theme(
        data: AppThemeRegistry.resolveTheme(
          AppThemeRegistry.presets.first,
          brightness,
        ),
        child: wrap?.call(page) ?? (embedded ? Scaffold(body: page) : page),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Any page [wrap] puts in the trip page's place shares its scope.
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  container.read(tripEditSaveServiceProvider);
  return harness;
}

/// A liveaboard of [redSea]'s dates.
final liveaboard = redSea.copyWith(tripType: TripType.liveaboard);

/// The active profile is [redSea]'s owner, the only one, so the menu offers
/// Delete.
final List<Object> ownerOverrides = [
  validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
  allDiversProvider.overrideWith((ref) async => const []),
  isHiddenProvider.overrideWith((ref, key) async => false),
  itemSharingProvider.overrideWith((ref, key) async => ItemSharing.none),
];

/// Two profiles: [redSea]'s owner `d1` and `d2`.
final twoDivers = [
  Diver(
    id: 'd1',
    name: 'Ana',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  Diver(
    id: 'd2',
    name: 'Ben',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
];

/// [liveaboard]'s vessel as stored.
final mvBlue = LiveaboardDetails(
  id: 'v1',
  tripId: 't1',
  vesselName: 'MV Blue',
  operatorName: 'Blue Waters',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
