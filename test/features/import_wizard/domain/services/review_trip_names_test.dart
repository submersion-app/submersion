import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/entity_match_result.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/services/review_trip_names.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

void main() {
  final created = DateTime(2026, 1, 1);
  final now = DateTime(2026, 11, 19);

  Trip trip(String id, DateTime start, DateTime end) => Trip(
    id: id,
    name: id,
    startDate: start,
    endDate: end,
    createdAt: created,
    updatedAt: created,
  );

  // Dives keep their wall-clock time in UTC components.
  EntityItem dive(
    int month,
    int day, {
    int hour = 10,
    String? tripRef,
    bool sourceHasTrips = false,
  }) => EntityItem(
    title: 'dive',
    subtitle: '',
    diveData: IncomingDiveData(startTime: DateTime.utc(2026, month, day, hour)),
    tripRef: tripRef,
    sourceHasTrips: sourceHasTrips,
  );

  EntityItem fileTrip(String ref, DateTime start, DateTime end) => EntityItem(
    title: 'File $ref',
    subtitle: '',
    tripRef: ref,
    tripDates: (start: start, end: end),
  );

  final bonaire = trip('Bonaire', DateTime(2026, 3, 7), DateTime(2026, 3, 14));

  Map<int, String> names(
    List<EntityItem> dives, {
    Set<int>? diveSelections,
    Map<int, DuplicateAction> diveActions = const {},
    Set<int> duplicateIndices = const {},
    List<EntityItem>? trips,
    Set<int> tripSelections = const {},
    Map<int, DuplicateAction> tripActions = const {},
    Map<int, EntityMatchResult>? tripMatches,
    List<Trip>? existing,
  }) => reviewTripNames(
    dives: EntityGroup(items: dives, duplicateIndices: duplicateIndices),
    trips: trips == null
        ? null
        : EntityGroup(items: trips, entityMatches: tripMatches),
    diveSelections:
        diveSelections ?? {for (var i = 0; i < dives.length; i++) i},
    diveActions: diveActions,
    tripSelections: tripSelections,
    tripActions: tripActions,
    existingTripsFor: (_) => existing ?? [bonaire],
    now: now,
  );

  test('dateOnlySourceUsesExistingTrips', () {
    expect(names([dive(3, 10), dive(4, 1)]), {0: 'Bonaire'});
  });

  test('importedFileTripNamesItsDives', () {
    final result = names(
      [dive(3, 10, tripRef: 'a', sourceHasTrips: true)],
      trips: [fileTrip('a', DateTime(2026, 3, 9), DateTime(2026, 3, 11))],
      tripSelections: {0},
    );
    expect(result, {0: 'File a'});
  });

  test('a dive the file leaves out of its trips can still join an imported '
      'file trip by date when its own trip is unticked', () {
    final result = names(
      [dive(5, 2, tripRef: 'b', sourceHasTrips: true)],
      trips: [
        fileTrip('a', DateTime(2026, 5, 1), DateTime(2026, 5, 3)),
        fileTrip('b', DateTime(2026, 6, 1), DateTime(2026, 6, 3)),
      ],
      tripSelections: {0},
    );
    expect(result, {0: 'File a'});
  });

  test('consolidatedFileTripNamesTheExistingTrip', () {
    final result = names(
      [dive(8, 1, tripRef: 'a', sourceHasTrips: true)],
      trips: [fileTrip('a', DateTime(2026, 3, 7), DateTime(2026, 3, 14))],
      tripSelections: {0},
      tripActions: {0: DuplicateAction.consolidate},
      tripMatches: {
        0: const EntityMatchResult(
          existingId: 'Bonaire',
          existingName: 'Bonaire (match)',
          existingFields: {},
          incomingFields: {},
        ),
      },
    );
    // Linked by the diver's choice, not by date: August is outside it.
    expect(result, {0: 'Bonaire'});
  });

  test('a consolidated trip the diver cannot see is named by its match', () {
    final result = names(
      [dive(8, 1, tripRef: 'a', sourceHasTrips: true)],
      trips: [fileTrip('a', DateTime(2026, 3, 7), DateTime(2026, 3, 14))],
      tripSelections: {0},
      tripActions: {0: DuplicateAction.consolidate},
      tripMatches: {
        0: const EntityMatchResult(
          existingId: 'hidden',
          existingName: 'Hidden trip',
          existingFields: {},
          incomingFields: {},
        ),
      },
    );
    expect(result, {0: 'Hidden trip'});
  });

  test('untickedFileTripFallsBackToDate', () {
    final fileTrips = [
      fileTrip('a', DateTime(2026, 3, 9), DateTime(2026, 3, 11)),
    ];
    final dives = [dive(3, 10, tripRef: 'a', sourceHasTrips: true)];
    expect(names(dives, trips: fileTrips, tripSelections: const {}), {
      0: 'Bonaire',
    });
    // Skipped is unticked too, as is a skipped duplicate.
    expect(
      names(
        dives,
        trips: fileTrips,
        tripSelections: {0},
        tripActions: {0: DuplicateAction.skip},
      ),
      {0: 'Bonaire'},
    );
  });

  test('fileWithTripsLeavesUnreferencedDiveOut', () {
    final result = names(
      [dive(3, 10, sourceHasTrips: true)],
      trips: [fileTrip('a', DateTime(2026, 3, 9), DateTime(2026, 3, 11))],
      tripSelections: {0},
    );
    expect(result, isEmpty);
  });

  test('onlyNewDivesGetANameForEachAction', () {
    final dives = List.generate(7, (_) => dive(3, 10));
    final result = names(
      dives,
      diveSelections: {1, 2, 3, 4, 5, 6},
      duplicateIndices: {2, 3, 4, 5, 6},
      diveActions: {
        3: DuplicateAction.skip,
        4: DuplicateAction.consolidate,
        5: DuplicateAction.replaceSource,
        6: DuplicateAction.importAsNew,
      },
    );
    // 0: unselected. 1: new. 2: duplicate still undecided. 3-5: not saved
    // as a new dive. 6: imported as new.
    expect(result, {1: 'Bonaire', 6: 'Bonaire'});
  });

  test('a planned-dive fill is not a new dive', () {
    final result = names(
      [dive(3, 10)],
      duplicateIndices: {0},
      diveActions: {0: DuplicateAction.fillPlanned},
    );
    expect(result, isEmpty);
  });

  test('datedByUtcComponents', () {
    // 23:30 on the trip's last day stays that day whatever the device zone.
    expect(names([dive(3, 14, hour: 23)]), {0: 'Bonaire'});
    expect(names([dive(3, 15, hour: 0)]), isEmpty);
  });

  test('an undated dive gets no name', () {
    final result = names([const EntityItem(title: 'dive', subtitle: '')]);
    expect(result, isEmpty);
  });

  test('each dive reads its own owner trips', () {
    final result = reviewTripNames(
      dives: EntityGroup(
        items: [
          dive(3, 10).copyWith(
            target: const ImportTarget(key: 'diver:a', name: 'A', isNew: false),
          ),
          dive(3, 10).copyWith(
            target: const ImportTarget(key: 'diver:b', name: 'B', isNew: false),
          ),
        ],
      ),
      diveSelections: {0, 1},
      diveActions: const {},
      existingTripsFor: (d) => d.target?.key == 'diver:a' ? [bonaire] : [],
      now: now,
    );
    expect(result, {0: 'Bonaire'});
  });
}
