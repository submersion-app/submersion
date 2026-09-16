import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/features/statistics/domain/water_temp_bands.dart';

import '../../../../helpers/test_database.dart';

/// Issue #1827: dives bucketed by water temperature, with the bands defined
/// in the diver's own temperature unit.
void main() {
  late AppDatabase db;
  late StatisticsRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = StatisticsRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  Future<void> dive(
    String id,
    double? waterTemp, {
    String? diverId,
    bool excludedFromStats = false,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            diveDateTime: Value(now),
            waterTemp: Value(waterTemp),
            excludedFromStats: Value(excludedFromStats),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  List<int> counts(List<WaterTempBandCount> bands) =>
      bands.map((b) => b.count).toList();

  group('band edges', () {
    test('Celsius bands follow the issue: 10, 18 and 24', () {
      expect(waterTempBandEdges(TemperatureUnit.celsius), [10, 18, 24]);
    });

    test('Fahrenheit bands are round Fahrenheit numbers, not converted', () {
      expect(waterTempBandEdges(TemperatureUnit.fahrenheit), [50, 65, 75]);
    });
  });

  test('returns an empty list when no dive has a water temperature', () async {
    await dive('a', null);

    final result = await repo.getDivesByWaterTempBand(
      unit: TemperatureUnit.celsius,
    );

    expect(result, isEmpty);
  });

  test('buckets Celsius dives, lower edge inclusive', () async {
    await dive('cold', 5.0);
    await dive('edge10', 10.0);
    await dive('temperate', 17.9);
    await dive('edge18', 18.0);
    await dive('tropical', 28.0);
    await dive('unknown', null);

    final result = await repo.getDivesByWaterTempBand(
      unit: TemperatureUnit.celsius,
    );

    expect(result, [
      (lower: null, upper: 10, count: 1),
      (lower: 10, upper: 18, count: 2),
      (lower: 18, upper: 24, count: 1),
      (lower: 24, upper: null, count: 1),
    ]);
  });

  test('keeps empty bands so the chart shape stays comparable', () async {
    await dive('a', 26.0);
    await dive('b', 27.0);

    final result = await repo.getDivesByWaterTempBand(
      unit: TemperatureUnit.celsius,
    );

    expect(counts(result), [0, 0, 0, 2]);
  });

  test('Fahrenheit bands re-bin dives rather than relabel Celsius', () async {
    // 18.0 C is 64.4 F: 18-24 C, but 50-65 F.
    await dive('a', 18.0);
    // 23.9 C is 75.02 F: 18-24 C, but 75+ F.
    await dive('b', 23.9);

    final celsius = await repo.getDivesByWaterTempBand(
      unit: TemperatureUnit.celsius,
    );
    final fahrenheit = await repo.getDivesByWaterTempBand(
      unit: TemperatureUnit.fahrenheit,
    );

    expect(counts(celsius), [0, 0, 2, 0]);
    expect(fahrenheit, [
      (lower: null, upper: 50, count: 0),
      (lower: 50, upper: 65, count: 1),
      (lower: 65, upper: 75, count: 0),
      (lower: 75, upper: null, count: 1),
    ]);
  });

  test('a dive displayed as 65 F counts in the 65-75 F band', () async {
    // A UDDF file stores 65 F as 291.48 K, which reads back as 18.33 C, or
    // 64.994 F. The app shows it as "65°F", so it must not fall into 50-65.
    await dive('a', 18.33);

    final result = await repo.getDivesByWaterTempBand(
      unit: TemperatureUnit.fahrenheit,
    );

    expect(counts(result), [0, 0, 1, 0]);
  });

  test('respects the statistics filter', () async {
    await dive('a', 5.0);
    await dive('b', 28.0);
    await db
        .into(db.tags)
        .insert(
          TagsCompanion(
            id: const Value('cold'),
            name: const Value('cold'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await db
        .into(db.diveTags)
        .insert(
          DiveTagsCompanion(
            id: const Value('a-cold'),
            diveId: const Value('a'),
            tagId: const Value('cold'),
            createdAt: Value(now),
          ),
        );

    final result = await repo.getDivesByWaterTempBand(
      unit: TemperatureUnit.celsius,
      filter: const DiveFilterState(tagIds: ['cold']),
    );

    expect(counts(result), [1, 0, 0, 0]);
  });

  test('leaves out dives excluded from statistics', () async {
    await dive('a', 5.0);
    await dive('b', 5.0, excludedFromStats: true);

    final result = await repo.getDivesByWaterTempBand(
      unit: TemperatureUnit.celsius,
    );

    expect(counts(result), [1, 0, 0, 0]);
  });

  test('counts only the given diver', () async {
    for (final id in ['me', 'other']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion(
              id: Value(id),
              name: Value(id),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }
    await dive('a', 5.0, diverId: 'me');
    await dive('b', 28.0, diverId: 'other');

    final result = await repo.getDivesByWaterTempBand(
      unit: TemperatureUnit.celsius,
      diverId: 'me',
    );

    expect(counts(result), [1, 0, 0, 0]);
  });
}
