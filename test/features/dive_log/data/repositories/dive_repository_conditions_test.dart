import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertSite(
    String id, {
    double? latitude,
    double? longitude,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: id,
            name: 'Site $id',
            createdAt: now,
            updatedAt: now,
            latitude: Value(latitude),
            longitude: Value(longitude),
          ),
        );
  }

  Future<void> insertDive(
    String id, {
    String? siteId,
    String? diverId,
    int? diveDateTime,
    int? entryTime,
    DivesCompanion weather = const DivesCompanion(),
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: diveDateTime ?? now,
            createdAt: now,
            updatedAt: now,
            siteId: Value(siteId),
            diverId: Value(diverId),
            entryTime: Value(entryTime),
            windSpeed: weather.windSpeed,
            windDirection: weather.windDirection,
            cloudCover: weather.cloudCover,
            precipitation: weather.precipitation,
            humidity: weather.humidity,
            weatherCode: weather.weatherCode,
            weatherSource: weather.weatherSource,
            weatherFetchedAt: weather.weatherFetchedAt,
            airTemp: weather.airTemp,
            surfacePressure: weather.surfacePressure,
          ),
        );
  }

  Future<Dive> readRow(String id) async =>
      (db.select(db.dives)..where((t) => t.id.equals(id))).getSingle();

  group('DiveRepository.getDivesNeedingConditions', () {
    test('returns a dive whose site has coordinates and no weather', () async {
      await insertSite('s1', latitude: 12.5, longitude: -68.25);
      await insertDive('d1', siteId: 's1');

      final candidates = await repository.getDivesNeedingConditions();

      expect(candidates, hasLength(1));
      expect(candidates.single.id, 'd1');
      expect(candidates.single.latitude, 12.5);
      expect(candidates.single.longitude, -68.25);
    });

    test('excludes a dive with no site', () async {
      await insertDive('d1');

      expect(await repository.getDivesNeedingConditions(), isEmpty);
    });

    test('excludes a dive whose site has no coordinates', () async {
      await insertSite('s1');
      await insertDive('d1', siteId: 's1');

      expect(await repository.getDivesNeedingConditions(), isEmpty);
    });

    test('excludes a dive whose fillable columns are all populated', () async {
      await insertSite('s1', latitude: 12.5, longitude: -68.25);
      await insertDive(
        'd1',
        siteId: 's1',
        weather: const DivesCompanion(
          windSpeed: Value(4.0),
          windDirection: Value('north'),
          cloudCover: Value('clear'),
          precipitation: Value('none'),
          humidity: Value(70.0),
          weatherCode: Value(0),
          airTemp: Value(28.0),
          surfacePressure: Value(1.013),
        ),
      );

      expect(await repository.getDivesNeedingConditions(), isEmpty);
    });

    test('includes a dive with only some weather columns filled', () async {
      await insertSite('s1', latitude: 12.5, longitude: -68.25);
      await insertDive(
        'd1',
        siteId: 's1',
        weather: const DivesCompanion(
          windSpeed: Value(4.0),
          airTemp: Value(28.0),
        ),
      );

      final candidates = await repository.getDivesNeedingConditions();

      expect(candidates.map((c) => c.id), ['d1']);
    });

    test('prefers entryTime over diveDateTime for the sample hour', () async {
      await insertSite('s1', latitude: 12.5, longitude: -68.25);
      final day = DateTime.utc(2024, 3, 9, 6);
      final entry = DateTime.utc(2024, 3, 9, 14, 30);
      await insertDive(
        'd1',
        siteId: 's1',
        diveDateTime: day.millisecondsSinceEpoch,
        entryTime: entry.millisecondsSinceEpoch,
      );

      final candidates = await repository.getDivesNeedingConditions();

      expect(candidates.single.dateTime, entry);
    });

    test('falls back to diveDateTime when entryTime is null', () async {
      await insertSite('s1', latitude: 12.5, longitude: -68.25);
      final day = DateTime.utc(2024, 3, 9, 6);
      await insertDive(
        'd1',
        siteId: 's1',
        diveDateTime: day.millisecondsSinceEpoch,
      );

      final candidates = await repository.getDivesNeedingConditions();

      expect(candidates.single.dateTime, day);
    });

    test('restricts to the requested diver when diverId is given', () async {
      await insertSite('s1', latitude: 12.5, longitude: -68.25);
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: 'diver-a',
              name: 'A',
              createdAt: DateTime.now().millisecondsSinceEpoch,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: 'diver-b',
              name: 'B',
              createdAt: DateTime.now().millisecondsSinceEpoch,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      await insertDive('d1', siteId: 's1', diverId: 'diver-a');
      await insertDive('d2', siteId: 's1', diverId: 'diver-b');

      final candidates = await repository.getDivesNeedingConditions(
        diverId: 'diver-a',
      );

      expect(candidates.map((c) => c.id), ['d1']);
    });
  });

  group('DiveRepository.countDivesNeedingConditions', () {
    test('counts the same dives the candidate query returns', () async {
      await insertSite('s1', latitude: 12.5, longitude: -68.25);
      await insertSite('s2');
      await insertDive('d1', siteId: 's1');
      await insertDive('d2', siteId: 's1');
      await insertDive('d3', siteId: 's2'); // site has no coordinates
      await insertDive('d4'); // no site

      expect(await repository.countDivesNeedingConditions(), 2);
    });

    test('counts zero when every fillable column is populated', () async {
      await insertSite('s1', latitude: 12.5, longitude: -68.25);
      await insertDive(
        'd1',
        siteId: 's1',
        weather: const DivesCompanion(
          windSpeed: Value(4.0),
          windDirection: Value('north'),
          cloudCover: Value('clear'),
          precipitation: Value('none'),
          humidity: Value(70.0),
          weatherCode: Value(0),
          airTemp: Value(28.0),
          surfacePressure: Value(1.013),
        ),
      );

      expect(await repository.countDivesNeedingConditions(), 0);
    });

    test('restricts to the requested diver', () async {
      await insertSite('s1', latitude: 12.5, longitude: -68.25);
      for (final id in ['diver-a', 'diver-b']) {
        await db
            .into(db.divers)
            .insert(
              DiversCompanion.insert(
                id: id,
                name: id,
                createdAt: DateTime.now().millisecondsSinceEpoch,
                updatedAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );
      }
      await insertDive('d1', siteId: 's1', diverId: 'diver-a');
      await insertDive('d2', siteId: 's1', diverId: 'diver-b');

      expect(
        await repository.countDivesNeedingConditions(diverId: 'diver-a'),
        1,
      );
    });
  });

  group('DiveRepository.fillDiveConditions (fills only NULL columns)', () {
    final fetchedAt = DateTime.utc(2024, 5, 1, 12);

    test('fills every empty column and stamps the source', () async {
      await insertSite('s1', latitude: 12.5, longitude: -68.25);
      await insertDive('d1', siteId: 's1');

      final filled = await repository.fillDiveConditions(
        'd1',
        windSpeed: 5.5,
        windDirection: CurrentDirection.southEast,
        cloudCover: CloudCover.partlyCloudy,
        precipitation: Precipitation.none,
        humidity: 72.0,
        weatherCode: 2,
        airTemp: 29.5,
        surfacePressure: 1.011,
        source: WeatherSource.openMeteo,
        fetchedAt: fetchedAt,
      );

      expect(filled, isTrue);
      final row = await readRow('d1');
      expect(row.windSpeed, 5.5);
      expect(row.windDirection, CurrentDirection.southEast.name);
      expect(row.cloudCover, CloudCover.partlyCloudy.name);
      expect(row.precipitation, Precipitation.none.name);
      expect(row.humidity, 72.0);
      expect(row.weatherCode, 2);
      expect(row.airTemp, 29.5);
      expect(row.surfacePressure, 1.011);
      expect(row.weatherSource, WeatherSource.openMeteo.name);
      expect(row.weatherFetchedAt, fetchedAt.millisecondsSinceEpoch);
    });

    test('never overwrites a column that already has a value', () async {
      await insertSite('s1', latitude: 12.5, longitude: -68.25);
      await insertDive(
        'd1',
        siteId: 's1',
        weather: const DivesCompanion(
          windSpeed: Value(1.5),
          cloudCover: Value('overcast'),
          airTemp: Value(19.0),
        ),
      );

      final filled = await repository.fillDiveConditions(
        'd1',
        windSpeed: 9.9,
        windDirection: CurrentDirection.north,
        cloudCover: CloudCover.clear,
        precipitation: Precipitation.rain,
        humidity: 55.0,
        weatherCode: 61,
        airTemp: 30.0,
        surfacePressure: 1.005,
        source: WeatherSource.openMeteo,
        fetchedAt: fetchedAt,
      );

      expect(filled, isTrue);
      final row = await readRow('d1');
      // Pre-existing values survive untouched.
      expect(row.windSpeed, 1.5);
      expect(row.cloudCover, 'overcast');
      expect(row.airTemp, 19.0);
      // Empty ones get filled.
      expect(row.windDirection, CurrentDirection.north.name);
      expect(row.precipitation, Precipitation.rain.name);
      expect(row.humidity, 55.0);
      expect(row.weatherCode, 61);
      expect(row.surfacePressure, 1.005);
    });

    test('leaves an existing weatherSource stamp alone', () async {
      await insertSite('s1', latitude: 12.5, longitude: -68.25);
      final manualStamp = DateTime.utc(2020, 1, 1).millisecondsSinceEpoch;
      await insertDive(
        'd1',
        siteId: 's1',
        weather: DivesCompanion(
          windSpeed: const Value(1.5),
          weatherSource: Value(WeatherSource.manual.name),
          weatherFetchedAt: Value(manualStamp),
        ),
      );

      await repository.fillDiveConditions(
        'd1',
        humidity: 55.0,
        source: WeatherSource.openMeteo,
        fetchedAt: fetchedAt,
      );

      final row = await readRow('d1');
      expect(row.humidity, 55.0);
      expect(row.weatherSource, WeatherSource.manual.name);
      expect(row.weatherFetchedAt, manualStamp);
    });

    test('returns false and writes nothing when there is no gap', () async {
      await insertSite('s1', latitude: 12.5, longitude: -68.25);
      await insertDive(
        'd1',
        siteId: 's1',
        weather: const DivesCompanion(humidity: Value(70.0)),
      );
      final before = await readRow('d1');

      final filled = await repository.fillDiveConditions(
        'd1',
        humidity: 55.0,
        source: WeatherSource.openMeteo,
        fetchedAt: fetchedAt,
      );

      expect(filled, isFalse);
      final after = await readRow('d1');
      expect(after.humidity, 70.0);
      expect(after.weatherSource, isNull);
      expect(after.updatedAt, before.updatedAt);
    });

    test('returns false for an unknown dive id', () async {
      final filled = await repository.fillDiveConditions(
        'nope',
        humidity: 55.0,
        source: WeatherSource.openMeteo,
        fetchedAt: fetchedAt,
      );

      expect(filled, isFalse);
    });
  });
}
