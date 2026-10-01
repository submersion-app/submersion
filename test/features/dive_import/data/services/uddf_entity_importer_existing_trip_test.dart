import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../core/services/export/uddf/uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;
import '../../../../helpers/test_database.dart';

/// Imported dives land in the diver's existing trip whose dates cover them
/// (issue #2618). A MacDive library has no trips, so before this every trip
/// showed 0 dives after the import.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  final created = DateTime(2026, 1, 1);

  Future<Trip> existingTrip(
    String id,
    String? diverId, {
    bool isShared = false,
  }) => TripRepository().createTrip(
    Trip(
      id: id,
      diverId: diverId,
      name: id,
      startDate: DateTime(2026, 3, 7),
      endDate: DateTime(2026, 3, 14),
      isShared: isShared,
      createdAt: created,
      updatedAt: created,
    ),
  );

  // The shape the MacDive mappers emit: wall-clock time in UTC components
  // and no tripRef.
  Map<String, dynamic> dive(DateTime wallClock, {String? tripRef}) => {
    'dateTime': wallClock,
    'maxDepth': 18.0,
    'duration': const Duration(minutes: 45),
    'tripRef': ?tripRef,
  };

  Future<void> import(UddfImportResult data, String diverId) =>
      UddfEntityImporter().import(
        data: data,
        selections: UddfImportSelections.selectAll(data),
        repositories: buildRepositories(),
        diverId: diverId,
      );

  Future<Map<int, String?>> tripIdByDay(String diverId) async => {
    for (final d in await DiveRepository().getAllDives(diverId: diverId))
      d.dateTime.toUtc().day: d.tripId,
  };

  test(
    'a dive inside an existing trip joins it, one outside does not',
    () async {
      final diverId = await createTestDiver();
      final trip = await existingTrip('bonaire', diverId);

      await import(
        UddfImportResult(
          dives: [
            dive(DateTime.utc(2026, 3, 10, 9)),
            // Late on the last day still counts.
            dive(DateTime.utc(2026, 3, 14, 21)),
            dive(DateTime.utc(2026, 3, 20, 9)),
          ],
        ),
        diverId,
      );

      expect(await tripIdByDay(diverId), {10: trip.id, 14: trip.id, 20: null});
      final stats = await TripRepository().getAllTripsWithStats(
        diverId: diverId,
      );
      expect(stats.single.diveCount, 2);
    },
  );

  test('a trip the file links keeps its dives', () async {
    final diverId = await createTestDiver();
    await existingTrip('bonaire', diverId);

    await import(
      UddfImportResult(
        trips: [
          {
            'uddfId': 'trip_file',
            'name': 'From the file',
            'startDate': DateTime(2026, 3, 9),
            'endDate': DateTime(2026, 3, 11),
          },
        ],
        dives: [dive(DateTime.utc(2026, 3, 10, 9), tripRef: 'trip_file')],
      ),
      diverId,
    );

    final fromFile = (await TripRepository().getAllTrips(
      diverId: diverId,
    )).singleWhere((t) => t.name == 'From the file');
    expect(await tripIdByDay(diverId), {10: fromFile.id});
  });

  test("another diver's private trip is never used", () async {
    final diverId = await createTestDiver();
    const otherId = 'diver-other';
    await DiverRepository().createDiver(
      Diver(id: otherId, name: 'Other', createdAt: created, updatedAt: created),
    );
    await existingTrip('theirs', otherId);

    await import(
      UddfImportResult(dives: [dive(DateTime.utc(2026, 3, 10, 9))]),
      diverId,
    );

    expect(await tripIdByDay(diverId), {10: null});
  });

  test("another diver's shared trip is used", () async {
    final diverId = await createTestDiver();
    const otherId = 'diver-other';
    await DiverRepository().createDiver(
      Diver(id: otherId, name: 'Other', createdAt: created, updatedAt: created),
    );
    final shared = await existingTrip('shared', otherId, isShared: true);

    await import(
      UddfImportResult(dives: [dive(DateTime.utc(2026, 3, 10, 9))]),
      diverId,
    );

    expect(await tripIdByDay(diverId), {10: shared.id});
  });
}
