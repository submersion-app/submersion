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

  ImportTarget target(String key) =>
      ImportTarget(key: key, name: key, isNew: key.startsWith('new:'));

  // Dives keep their wall-clock time in UTC components.
  EntityItem dive(
    int month,
    int day, {
    int hour = 10,
    String? tripRef,
    bool? sourceHasTrips,
    bool hasSourceTime = true,
    String? targetKey,
  }) => EntityItem(
    title: 'dive',
    subtitle: '',
    diveData: IncomingDiveData(startTime: DateTime.utc(2026, month, day, hour)),
    tripRef: tripRef,
    sourceHasTrips: sourceHasTrips,
    hasSourceTime: hasSourceTime,
    target: targetKey == null ? null : target(targetKey),
  );

  EntityItem fileTrip(
    String ref,
    DateTime? start,
    DateTime? end, {
    String? name,
    String? targetKey,
  }) => EntityItem(
    title: name ?? 'File $ref',
    subtitle: '',
    tripRef: ref,
    sourceTrip: (name: name ?? 'File $ref', start: start, end: end),
    target: targetKey == null ? null : target(targetKey),
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
    List<Trip> Function(EntityItem dive)? existingTripsFor,
    Set<int> mergesIntoTripless = const {},
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
    existingTripsFor: existingTripsFor ?? (_) => [bonaire],
    mergesIntoTripless: mergesIntoTripless,
    now: now,
  );

  test('dateOnlySourceUsesExistingTrips', () {
    expect(names([dive(3, 10), dive(4, 1)]), {0: 'Bonaire'});
  });

  test('importedFileTripNamesItsDives', () {
    final result = names(
      [dive(3, 10, tripRef: 'a')],
      trips: [fileTrip('a', DateTime(2026, 3, 9), DateTime(2026, 3, 11))],
      tripSelections: {0},
    );
    expect(result, {0: 'File a'});
  });

  test('a dive the file leaves out of its trips can still join an imported '
      'file trip by date when its own trip is unticked', () {
    final result = names(
      [dive(5, 2, tripRef: 'b')],
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
      [dive(8, 1, tripRef: 'a')],
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
      [dive(8, 1, tripRef: 'a')],
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
    final dives = [dive(3, 10, tripRef: 'a')];
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

  test('a trip imported as new counts even outside the selection', () {
    // Deselect all keeps the action, and the importer adds every
    // import-as-new row (UniversalAdapter._resolveSelections).
    final result = names(
      [dive(3, 10, tripRef: 'a')],
      trips: [fileTrip('a', DateTime(2026, 3, 9), DateTime(2026, 3, 11))],
      tripActions: {0: DuplicateAction.importAsNew},
    );
    expect(result, {0: 'File a'});
  });

  test('fileWithTripsLeavesUnreferencedDiveOut', () {
    final result = names(
      [dive(3, 10)],
      trips: [fileTrip('a', DateTime(2026, 3, 9), DateTime(2026, 3, 11))],
      tripSelections: {0},
    );
    expect(result, isEmpty);
  });

  test('a merged batch dive whose own file had no trips is placed', () {
    final result = names(
      [dive(3, 10, sourceHasTrips: false)],
      trips: [fileTrip('a', DateTime(2026, 5, 9), DateTime(2026, 5, 11))],
      tripSelections: {0},
    );
    expect(result, {0: 'Bonaire'});
  });

  test('a nameless file trip is not imported, so its dives go by date', () {
    final result = names(
      [dive(3, 10, tripRef: 'a')],
      trips: [const EntityItem(title: 'Unnamed', subtitle: '', tripRef: 'a')],
      tripSelections: {0},
    );
    expect(result, {0: 'Bonaire'});
  });

  test('a file trip missing its end runs to now, as the importer saves it', () {
    final result = names(
      [dive(10, 2, tripRef: 'a')],
      trips: [fileTrip('a', DateTime(2026, 9, 1), null)],
      tripSelections: {0},
      existingTripsFor: (_) => const [],
    );
    expect(result, {0: 'File a'});
  });

  test('a file trip reads its dates as the saved trip reads them back', () {
    // A source may give a trip's end as a UTC instant; the saved trip reads
    // back in local time, so its last day is the local day of that instant.
    final end = DateTime.utc(2026, 3, 14, 20);
    final local = end.toLocal();
    final result = names(
      [dive(local.month, local.day, hour: 9, tripRef: 'b')],
      trips: [
        fileTrip('a', DateTime(2026, 3, 7), end),
        fileTrip('b', DateTime(2026, 6, 1), DateTime(2026, 6, 3)),
      ],
      tripSelections: {0},
      existingTripsFor: (_) => const [],
    );
    expect(result, {0: 'File a'});
  });

  test('a tie between a file trip and an existing one names neither', () {
    // The importer gives the file trip a random id, so which of two trips
    // starting at the same moment wins cannot be known before the save.
    final result = names(
      [dive(3, 10, tripRef: 'b')],
      trips: [
        fileTrip('a', DateTime(2026, 3, 7), DateTime(2026, 3, 12)),
        fileTrip('b', DateTime(2026, 6, 1), DateTime(2026, 6, 3)),
      ],
      tripSelections: {0},
    );
    expect(result, isEmpty);
  });

  test('a tie between two file trips names neither', () {
    final result = names(
      [dive(3, 10, tripRef: 'c')],
      trips: [
        fileTrip('a', DateTime(2026, 3, 8), DateTime(2026, 3, 12)),
        fileTrip('b', DateTime(2026, 3, 8), DateTime(2026, 3, 11)),
        fileTrip('c', DateTime(2026, 6, 1), DateTime(2026, 6, 3)),
      ],
      tripSelections: {0, 1},
    );
    expect(result, isEmpty);
  });

  test('a tie between two existing trips is settled by their ids', () {
    final other = trip('Zeeland', DateTime(2026, 3, 7), DateTime(2026, 3, 9));
    expect(names([dive(3, 8)], existingTripsFor: (_) => [bonaire, other]), {
      0: 'Zeeland',
    });
  });

  test('a file trip starting later than an existing one still wins', () {
    final result = names(
      [dive(3, 10, tripRef: 'b')],
      trips: [
        fileTrip('a', DateTime(2026, 3, 8), DateTime(2026, 3, 12)),
        fileTrip('b', DateTime(2026, 6, 1), DateTime(2026, 6, 3)),
      ],
      tripSelections: {0},
    );
    expect(result, {0: 'File a'});
  });

  group('per profile (multi-diver file import)', () {
    test('a dive reads only its own profile file trips', () {
      final result = names(
        [
          dive(3, 10, tripRef: 'a', targetKey: 'diver:A'),
          dive(3, 10, tripRef: 'a', targetKey: 'diver:B'),
        ],
        trips: [
          fileTrip(
            'a',
            DateTime(2026, 3, 9),
            DateTime(2026, 3, 11),
            targetKey: 'diver:A',
          ),
          fileTrip(
            'a',
            DateTime(2026, 3, 9),
            DateTime(2026, 3, 11),
            targetKey: 'diver:B',
          ),
        ],
        // B's copy is unticked: B's dive goes by date among B's trips.
        tripSelections: {0},
        existingTripsFor: (d) =>
            d.target?.key == 'diver:B' ? [bonaire] : const [],
      );
      expect(result, {0: 'File a', 1: 'Bonaire'});
    });

    test('a profile whose slice has no trips places its dives by date', () {
      final result = names(
        [
          dive(3, 10, tripRef: 'a', targetKey: 'diver:A'),
          dive(3, 10, targetKey: 'diver:B'),
        ],
        trips: [
          fileTrip(
            'a',
            DateTime(2026, 3, 9),
            DateTime(2026, 3, 11),
            targetKey: 'diver:A',
          ),
        ],
        tripSelections: {0},
      );
      expect(result, {0: 'File a', 1: 'Bonaire'});
    });

    test("another profile's file trips are not date candidates", () {
      final result = names(
        [dive(3, 10, targetKey: 'new:Sam')],
        trips: [
          fileTrip(
            'a',
            DateTime(2026, 3, 9),
            DateTime(2026, 3, 11),
            targetKey: 'diver:A',
          ),
        ],
        tripSelections: {0},
        existingTripsFor: (_) => const [],
      );
      expect(result, isEmpty);
    });
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

  test('a dive imported as new is named even outside the selection', () {
    final result = names(
      [dive(3, 10)],
      diveSelections: const {},
      duplicateIndices: {0},
      diveActions: {0: DuplicateAction.importAsNew},
    );
    expect(result, {0: 'Bonaire'});
  });

  test('a merge into a dive with no trip passes its trip on', () {
    // The merge saves the dive standalone, placed by date, then copies its
    // trip onto the matched dive when that one has none.
    final result = names(
      [dive(3, 10), dive(3, 11)],
      duplicateIndices: {0, 1},
      diveActions: {
        0: DuplicateAction.consolidate,
        1: DuplicateAction.consolidate,
      },
      mergesIntoTripless: {0},
    );
    expect(result, {0: 'Bonaire'});
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

  test('a download with no reported start time gets no name', () {
    expect(names([dive(3, 10, hasSourceTime: false)]), isEmpty);
  });

  test('each dive reads its own owner trips', () {
    final result = names([
      dive(3, 10, targetKey: 'diver:a'),
      dive(3, 10, targetKey: 'diver:b'),
    ], existingTripsFor: (d) => d.target?.key == 'diver:a' ? [bonaire] : []);
    expect(result, {0: 'Bonaire'});
  });
}
