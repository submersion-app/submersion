import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3118: the condition columns behind the Conditions tab's weather
/// and water-movement statistics.
void main() {
  late AppDatabase db;
  late InsightsRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertSite(String id) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion.insert(
          id: id,
          name: 'Site $id',
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  Future<void> insertDiver(String id) => db
      .into(db.divers)
      .insert(
        DiversCompanion(
          id: Value(id),
          name: Value(id),
          medicalNotes: const Value(''),
          notes: const Value(''),
          isDefault: const Value(false),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  Future<void> insertDive(
    String id, {
    int day = 1,
    String? diverId,
    String? siteId,
    bool excluded = false,
    bool planned = false,
    double? airTemp,
    String? cloudCover,
    String? precipitation,
    double? windSpeed,
    String? windDirection,
    double? humidity,
    double? surfacePressure,
    String? currentStrength,
    String? currentDirection,
    double? swellHeight,
    double? altitude,
    String? exitMethod,
  }) async {
    final ms = DateTime.utc(2026, 3, day, 10).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(ms),
            diverId: Value(diverId),
            siteId: Value(siteId),
            excludedFromStats: Value(excluded),
            isPlanned: Value(planned),
            airTemp: Value(airTemp),
            cloudCover: Value(cloudCover),
            precipitation: Value(precipitation),
            windSpeed: Value(windSpeed),
            windDirection: Value(windDirection),
            humidity: Value(humidity),
            surfacePressure: Value(surfacePressure),
            currentStrength: Value(currentStrength),
            currentDirection: Value(currentDirection),
            swellHeight: Value(swellHeight),
            altitude: Value(altitude),
            exitMethod: Value(exitMethod),
            createdAt: Value(ms),
            updatedAt: Value(ms),
          ),
        );
  }

  test('maps every condition column', () async {
    await insertDive(
      'a',
      airTemp: 24.5,
      cloudCover: 'overcast',
      precipitation: 'drizzle',
      windSpeed: 6.2,
      windDirection: 'northEast',
      humidity: 81,
      surfacePressure: 1.009,
      currentStrength: 'light',
      currentDirection: 'west',
      swellHeight: 0.8,
      altitude: 450,
      exitMethod: 'ladder',
    );

    final rows = await repository.getConditionsRows();

    expect(rows, hasLength(1));
    final r = rows.single;
    expect(r.diveId, 'a');
    expect(r.dateTime, DateTime.utc(2026, 3, 1, 10));
    expect(r.airTemp, 24.5);
    expect(r.cloudCover, CloudCover.overcast);
    expect(r.precipitation, Precipitation.drizzle);
    expect(r.windSpeed, 6.2);
    expect(r.windDirection, CurrentDirection.northEast);
    expect(r.humidity, 81);
    expect(r.surfacePressure, 1.009);
    expect(r.currentStrength, CurrentStrength.light);
    expect(r.currentDirection, CurrentDirection.west);
    expect(r.swellHeight, 0.8);
    expect(r.altitude, 450);
    expect(r.exitMethod, EntryMethod.ladder);
  });

  test('returns dives with nothing recorded, ordered by date', () async {
    await insertDive('later', day: 9);
    await insertDive('earlier', day: 2, cloudCover: 'clear');

    final rows = await repository.getConditionsRows();

    expect(rows.map((r) => r.diveId), ['earlier', 'later']);
    expect(rows.last.cloudCover, isNull);
  });

  test('a blank or display-text enum string reads as not recorded', () async {
    await insertDive('a', cloudCover: '', precipitation: 'Light Rain');

    final r = (await repository.getConditionsRows()).single;

    expect(r.cloudCover, isNull);
    expect(r.precipitation, isNull);
  });

  test('leaves out excluded and planned dives', () async {
    await insertDive('kept');
    await insertDive('excluded', excluded: true);
    await insertDive('planned', planned: true);

    final rows = await repository.getConditionsRows();

    expect(rows.map((r) => r.diveId), ['kept']);
  });

  test('honours the diver and the view filter', () async {
    await insertDiver('me');
    await insertDiver('them');
    await insertSite('reef');
    await insertSite('lake');
    await insertDive('mine-reef', diverId: 'me', siteId: 'reef');
    await insertDive('mine-lake', diverId: 'me', siteId: 'lake');
    await insertDive('theirs-reef', diverId: 'them', siteId: 'reef');

    final rows = await repository.getConditionsRows(
      diverId: 'me',
      filter: const DiveFilterState(siteId: 'reef'),
    );

    expect(rows.map((r) => r.diveId), ['mine-reef']);
  });
}
