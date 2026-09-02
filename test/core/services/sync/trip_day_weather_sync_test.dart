import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  final dayMillis = DateTime(2026, 3, 8).millisecondsSinceEpoch;
  final rowId = tripDayWeatherRowId(tripId: 'trip-1', dayMillis: dayMillis);

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 'trip-1',
            name: 'Bonaire',
            startDate: 0,
            endDate: 0,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.tripDayWeather)
        .insert(
          TripDayWeatherCompanion.insert(
            id: tripDayWeatherRowId(
              tripId: 'trip-1',
              dayMillis: DateTime(2026, 3, 8).millisecondsSinceEpoch,
            ),
            tripId: 'trip-1',
            date: DateTime(2026, 3, 8).millisecondsSinceEpoch,
            latitude: 12.16,
            longitude: -68.28,
            airTemp: const Value(24.0),
            cloudCover: const Value('clear'),
            fetchedAt: 1,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('tripDayWeather export, fetch, upsert, and delete round-trip', () async {
    final record = await serializer.fetchRecord('tripDayWeather', rowId);
    expect(record, isNotNull);
    expect(record!['airTemp'], 24.0);
    expect(record['cloudCover'], 'clear');

    // A remote edit merges over the local row (LWW payload apply).
    await serializer.upsertRecord('tripDayWeather', {
      ...record,
      'airTemp': 26.0,
      'updatedAt': 2,
    });
    final merged = await serializer.fetchRecord('tripDayWeather', rowId);
    expect(merged!['airTemp'], 26.0);

    expect(await serializer.recordIdsFor('tripDayWeather'), contains(rowId));

    await serializer.deleteRecord('tripDayWeather', rowId);
    expect(await serializer.fetchRecord('tripDayWeather', rowId), isNull);
  });

  test('the delta export filters on the row own hlc', () async {
    await (db.update(
      db.tripDayWeather,
    )..where((t) => t.id.equals(rowId))).write(
      const TripDayWeatherCompanion(hlc: Value('2026-08-16T00:00:00.000-0000')),
    );

    Future<int> changesetCount(String? watermark) async {
      final payload = await serializer.exportChangeset(
        deviceId: 'device-1',
        hlcWatermark: watermark,
        deletions: const [],
      );
      return payload.data.tripDayWeather.length;
    }

    // A base carries the row; a watermark newer than it excludes it; an older
    // watermark includes it.
    expect(await changesetCount(null), 1);
    expect(await changesetCount('2026-08-17T00:00:00.000-0000'), 0);
    expect(await changesetCount('2026-08-15T00:00:00.000-0000'), 1);
  });

  test('a peer row for the same day merges instead of throwing', () async {
    // Two devices that both fetch the same day must converge. A v4 id per
    // device would insert a second row and violate the unique (trip_id, date)
    // index, and because the merge runs in a transaction that aborts the
    // whole sync pull, not just this row.
    // The peer derives the same id from the same (trip, day).
    await serializer.upsertRecord('tripDayWeather', {
      'id': tripDayWeatherRowId(tripId: 'trip-1', dayMillis: dayMillis),
      'tripId': 'trip-1',
      'date': dayMillis,
      'latitude': 12.16,
      'longitude': -68.28,
      'airTemp': 26.0,
      'weatherSource': 'openMeteo',
      'fetchedAt': 2,
      'createdAt': 2,
      'updatedAt': 2,
    });

    final rows = await db.select(db.tripDayWeather).get();
    expect(rows, hasLength(1));
    expect(rows.single.airTemp, 26.0);
  });

  test('the row id is derived from trip and day, not minted per device', () {
    final day = DateTime(2026, 3, 8).millisecondsSinceEpoch;

    expect(
      tripDayWeatherRowId(tripId: 'trip-1', dayMillis: day),
      tripDayWeatherRowId(tripId: 'trip-1', dayMillis: day),
    );
    expect(
      tripDayWeatherRowId(tripId: 'trip-1', dayMillis: day),
      isNot(tripDayWeatherRowId(tripId: 'trip-2', dayMillis: day)),
    );
    expect(
      tripDayWeatherRowId(tripId: 'trip-1', dayMillis: day),
      isNot(
        tripDayWeatherRowId(
          tripId: 'trip-1',
          dayMillis: DateTime(2026, 3, 9).millisecondsSinceEpoch,
        ),
      ),
    );
  });

  test('tripDayWeather is registered as an hlc target', () {
    // An omission here is silent: _stampHlc no-ops on an unknown entity type,
    // the column stays NULL, and the incremental export's hlc > watermark
    // filter then excludes the row from every changeset forever.
    expect(SyncRepository.hlcTargets.containsKey('tripDayWeather'), isTrue);
    expect(
      SyncRepository.hlcTargets['tripDayWeather']!.table,
      'trip_day_weather',
    );
  });

  test('tripDayWeather carries an updatedAt flag', () {
    expect(SyncService.entityHasUpdatedAt['tripDayWeather'], isTrue);
  });
}
