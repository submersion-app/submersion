import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/trips/data/repositories/trip_day_weather_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late TripDayWeatherRepository repository;
  late TripRepository tripRepository;
  late String testTripId;
  late String otherTripId;

  final day1 = DateTime(2026, 3, 8);
  final day2 = DateTime(2026, 3, 9);

  Trip createTestTrip({String name = 'Test Trip'}) {
    final now = DateTime.now();
    return Trip(
      id: '',
      name: name,
      startDate: day1,
      endDate: DateTime(2026, 3, 14),
      createdAt: now,
      updatedAt: now,
    );
  }

  TripDayWeather sample({
    String id = 'w1',
    String? tripId,
    DateTime? date,
    double? airTemp = 21.5,
    CloudCover? cloudCover = CloudCover.clear,
  }) {
    final now = DateTime(2026, 3, 15);
    return TripDayWeather(
      id: id,
      tripId: tripId ?? testTripId,
      date: date ?? day1,
      latitude: 12.16,
      longitude: -68.28,
      airTemp: airTemp,
      cloudCover: cloudCover,
      windSpeed: 6.5,
      windDirection: CurrentDirection.north,
      humidity: 70,
      surfacePressure: 1.011,
      weatherCode: 0,
      fetchedAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() async {
    await setUpTestDatabase();
    repository = TripDayWeatherRepository();
    tripRepository = TripRepository();

    // Two trips, to prove the queries are scoped. trip_id is a non-nullable
    // FK and beforeOpen turns foreign keys on.
    testTripId = (await tripRepository.createTrip(
      createTestTrip(name: 'Weather Test Trip'),
    )).id;
    otherTripId = (await tripRepository.createTrip(
      createTestTrip(name: 'Other Trip'),
    )).id;
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('TripDayWeatherRepository', () {
    test('getForTrip is empty before anything is stored', () async {
      expect(await repository.getForTrip(testTripId), isEmpty);
    });

    test('upsert then read back, keyed by date millis', () async {
      await repository.upsert(sample());

      final stored = await repository.getForTrip(testTripId);

      expect(stored, hasLength(1));
      final row = stored[tripDayMillis(day1)]!;
      expect(row.airTemp, 21.5);
      expect(row.cloudCover, CloudCover.clear);
      expect(row.windDirection, CurrentDirection.north);
      expect(row.weatherCode, 0);
      expect(row.weatherSource, WeatherSource.openMeteo);
      expect(row.latitude, 12.16);
      // A calendar day in a device-independent frame, so UTC.
      expect(row.date, DateTime.utc(2026, 3, 8));
    });

    test('a null payload field round-trips as null', () async {
      await repository.upsert(sample(airTemp: null, cloudCover: null));

      final row = (await repository.getForTrip(
        testTripId,
      ))[tripDayMillis(day1)]!;

      expect(row.airTemp, isNull);
      expect(row.cloudCover, isNull);
      expect(row.precipitation, isNull);
    });

    test('upserting the same day twice keeps one row', () async {
      await repository.upsert(sample());
      // A different id for the same day: the day is the identity, so this
      // must replace rather than accumulate.
      await repository.upsert(sample(id: 'w2', airTemp: 25));

      final stored = await repository.getForTrip(testTripId);

      expect(stored, hasLength(1));
      expect(stored[tripDayMillis(day1)]!.airTemp, 25);
    });

    test('a date with a time component is stored under UTC midnight', () {
      // The repository owns the (trip, date) uniqueness invariant, so it
      // normalizes rather than trusting every caller to. A row keyed on a
      // stray time would be invisible to day-keyed lookups and would refetch
      // forever. UTC, so the key does not move with the device timezone.
      return () async {
        await repository.upsert(sample(date: DateTime(2026, 3, 8, 17, 30)));

        final stored = await repository.getForTrip(testTripId);

        expect(stored.keys.single, tripDayMillis(day1));
        expect(stored[tripDayMillis(day1)]!.date, DateTime.utc(2026, 3, 8));
      }();
    });

    test('the same day at two times of day stays one row', () async {
      await repository.upsert(sample(date: DateTime(2026, 3, 8, 6)));
      await repository.upsert(
        sample(id: 'w2', date: DateTime(2026, 3, 8, 23), airTemp: 25),
      );

      final stored = await repository.getForTrip(testTripId);

      expect(stored, hasLength(1));
      expect(stored[tripDayMillis(day1)]!.airTemp, 25);
    });

    test('two different days both persist', () async {
      await repository.upsert(sample());
      await repository.upsert(sample(id: 'w2', date: day2, airTemp: 19));

      final stored = await repository.getForTrip(testTripId);

      expect(stored, hasLength(2));
      expect(stored[tripDayMillis(day2)]!.airTemp, 19);
    });

    test('getForTrip is scoped to one trip', () async {
      await repository.upsert(sample());
      await repository.upsert(sample(id: 'w2', tripId: otherTripId));

      expect(await repository.getForTrip(testTripId), hasLength(1));
      expect(await repository.getForTrip(otherTripId), hasLength(1));
    });

    test('deleteByTripId removes only that trip rows', () async {
      await repository.upsert(sample());
      await repository.upsert(sample(id: 'w2', tripId: otherTripId));

      await repository.deleteByTripId(testTripId);

      expect(await repository.getForTrip(testTripId), isEmpty);
      expect(await repository.getForTrip(otherTripId), hasLength(1));
    });

    test('deleteByTripId on a trip with no weather is a no-op', () async {
      await repository.deleteByTripId(testTripId);

      expect(await repository.getForTrip(testTripId), isEmpty);
    });

    test('deleting a trip takes its weather rows with it', () async {
      await repository.upsert(sample());
      await repository.upsert(sample(id: 'w2', tripId: otherTripId));

      await tripRepository.deleteTrip(testTripId);

      expect(await repository.getForTrip(testTripId), isEmpty);
      expect(await repository.getForTrip(otherTripId), hasLength(1));
    });

    test('watchWeatherChanges emits after a write', () async {
      final emissions = <void>[];
      final subscription = repository.watchWeatherChanges().listen(
        emissions.add,
      );
      addTearDown(subscription.cancel);

      await repository.upsert(sample());
      await Future<void>.delayed(Duration.zero);

      expect(emissions, isNotEmpty);
    });
  });

  group('rows upsert did not write', () {
    // Every row in this group goes straight into the table, because that is
    // the only way one can carry an id other than the derived one: a peer on
    // an older build of this feature, or a database written before the id
    // became deterministic. Reconciling rows it did not create is exactly
    // what the repository is being asked to do here.
    // Built from the day key plus an explicit offset, never from a local
    // DateTime's epoch. The day is UTC midnight, so a local value lands on a
    // neighbouring UTC day under a large enough offset and stops being a
    // stray for the day under test: the fixture would be asserting timezone
    // arithmetic instead of reconciliation, which is how these passed at
    // UTC+0 and failed at UTC+9.
    Future<void> insertRaw({
      required String id,
      required DateTime day,
      Duration offset = Duration.zero,
      double? airTemp,
      int updatedAt = 0,
      int createdAt = 0,
    }) async {
      await DatabaseService.instance.database
          .into(DatabaseService.instance.database.tripDayWeather)
          .insert(
            db.TripDayWeatherCompanion(
              id: Value(id),
              tripId: Value(testTripId),
              date: Value(tripDayMillis(day) + offset.inMilliseconds),
              latitude: const Value(12.16),
              longitude: const Value(-68.28),
              airTemp: Value(airTemp),
              weatherSource: Value(WeatherSource.openMeteo.name),
              fetchedAt: const Value(0),
              createdAt: Value(createdAt),
              updatedAt: Value(updatedAt),
            ),
          );
    }

    Future<List<db.TripDayWeatherData>> allRows() => DatabaseService
        .instance
        .database
        .select(DatabaseService.instance.database.tripDayWeather)
        .get();

    test('upsert replaces a same-day row stored under a foreign id', () async {
      // The unique index is on (trip_id, date) but insertOnConflictUpdate
      // targets the primary key, so a foreign-id row on the same midnight
      // makes the canonical insert miss the conflict target and hit the
      // index. Without cleanup this throws rather than merging.
      await insertRaw(id: 'from-a-peer', day: day1, airTemp: 10);

      await repository.upsert(sample(airTemp: 25));

      final rows = await allRows();
      expect(rows, hasLength(1));
      expect(rows.single.airTemp, 25);
      expect(rows.single.id, isNot('from-a-peer'));
    });

    test('upsert replaces a same-day row stored off midnight', () async {
      await insertRaw(
        id: 'from-an-older-build',
        day: day1,
        offset: const Duration(hours: 17, minutes: 30),
        airTemp: 10,
      );

      await repository.upsert(sample(airTemp: 25));

      final rows = await allRows();
      expect(rows, hasLength(1));
      expect(rows.single.date, tripDayMillis(day1));
      expect(rows.single.airTemp, 25);
    });

    test('a row for another day is left alone', () async {
      await insertRaw(id: 'other-day', day: day2, airTemp: 10);

      await repository.upsert(sample());

      final rows = await allRows();
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.id), contains('other-day'));
    });

    test('replacing a stray logs its deletion for sync', () async {
      // A stray is a synced record. Dropping it without a tombstone lets the
      // peer that sent it hand it straight back on the next pull.
      await insertRaw(id: 'from-a-peer', day: day1);

      await repository.upsert(sample());

      final deletions = await SyncRepository().getAllDeletions();
      expect(
        deletions.where(
          (d) =>
              d.entityType == 'tripDayWeather' && d.recordId == 'from-a-peer',
        ),
        hasLength(1),
      );
    });

    test('upsert keeps the createdAt of the stray it absorbs', () async {
      // The stray is this day's row under an old id, not a different record,
      // so the day keeps the age it already had.
      await insertRaw(
        id: 'from-a-peer',
        day: day1,
        offset: const Duration(hours: 17, minutes: 30),
        createdAt: 1000,
      );

      await repository.upsert(sample());

      expect((await allRows()).single.createdAt, 1000);
    });

    test(
      'getForTrip prefers the canonical row over a same-day stray',
      () async {
        // Reads land between a sync import and the next upsert, so the choice
        // cannot wait for the write side to tidy up, and it cannot depend on
        // the order SQLite happens to return rows in.
        await repository.upsert(sample(airTemp: 25));
        await insertRaw(
          id: 'from-a-peer',
          day: day1,
          offset: const Duration(hours: 17, minutes: 30),
          airTemp: 10,
          updatedAt: 9999999,
        );

        final stored = await repository.getForTrip(testTripId);

        expect(stored, hasLength(1));
        expect(stored[tripDayMillis(day1)]!.airTemp, 25);
      },
    );

    test('getForTrip falls back to the most recently updated stray', () async {
      // Off-midnight strays within the same UTC day. "Same day" is a UTC
      // question now: a row stored at 23:00 local on a negative offset falls
      // on the following UTC day and is genuinely a different day's row.
      await insertRaw(
        id: 'peer-a',
        day: day1,
        offset: const Duration(hours: 6),
        airTemp: 10,
        updatedAt: 100,
      );
      await insertRaw(
        id: 'peer-b',
        day: day1,
        offset: const Duration(hours: 23),
        airTemp: 20,
        updatedAt: 200,
      );

      final stored = await repository.getForTrip(testTripId);

      expect(stored, hasLength(1));
      expect(stored[tripDayMillis(day1)]!.airTemp, 20);
    });

    test('getForTrip does not write while resolving strays', () async {
      // Reads stay pure: a cleanup here would fire the table tick and
      // invalidate the provider that just read.
      await insertRaw(
        id: 'peer-a',
        day: day1,
        offset: const Duration(hours: 6),
      );
      await insertRaw(
        id: 'peer-b',
        day: day1,
        offset: const Duration(hours: 23),
      );

      await repository.getForTrip(testTripId);

      expect(await allRows(), hasLength(2));
    });
  });
}
