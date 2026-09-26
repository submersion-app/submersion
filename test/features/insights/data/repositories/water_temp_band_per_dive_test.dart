import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #1873: the band each dive falls in, so per-band averages bin a dive
/// exactly as the band counts of issue #1827 do.
void main() {
  late AppDatabase db;
  late InsightsRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = InsightsRepository();
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
    bool excludedFromGasStats = false,
    String diveMode = 'oc',
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
            excludedFromGasStats: Value(excludedFromGasStats),
            diveMode: Value(diveMode),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  test('maps each dive with a temperature to its band index', () async {
    await dive('cold', 5.0);
    await dive('edge10', 10.0);
    await dive('edge18', 18.0);
    await dive('tropical', 28.0);
    await dive('unknown', null);

    final result = await repo.getWaterTempBandPerDive(
      unit: TemperatureUnit.celsius,
    );

    expect(result, {'cold': 0, 'edge10': 1, 'edge18': 2, 'tropical': 3});
  });

  test('a dive displayed as 65 F maps to the 65-75 F band', () async {
    // Stored as 18.33 C (64.994 F) by a Kelvin UDDF import, shown as 65°F.
    await dive('a', 18.33);

    final result = await repo.getWaterTempBandPerDive(
      unit: TemperatureUnit.fahrenheit,
    );

    expect(result, {'a': 2});
  });

  test('agrees with the band counts for every dive', () async {
    const temps = [4.9, 9.95, 10.0, 17.94, 17.96, 18.33, 23.9, 24.0, 31.0];
    for (var i = 0; i < temps.length; i++) {
      await dive('d$i', temps[i]);
    }

    for (final unit in TemperatureUnit.values) {
      final perDive = await repo.getWaterTempBandPerDive(unit: unit);
      final counts = await repo.getDivesByWaterTempBand(unit: unit);
      final tallied = List.filled(counts.length, 0);
      for (final band in perDive.values) {
        tallied[band]++;
      }
      expect(tallied, counts.map((b) => b.count).toList(), reason: '$unit');
    }
  });

  test('uses the normal scope, not the gas scope', () async {
    await dive('gauge', 5.0, diveMode: 'gauge');
    await dive('noGas', 5.0, excludedFromGasStats: true);
    await dive('excluded', 5.0, excludedFromStats: true);

    final result = await repo.getWaterTempBandPerDive(
      unit: TemperatureUnit.celsius,
    );

    expect(result, {'gauge': 0, 'noGas': 0});
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

    final result = await repo.getWaterTempBandPerDive(
      unit: TemperatureUnit.celsius,
      filter: const DiveFilterState(tagIds: ['cold']),
    );

    expect(result, {'a': 0});
  });

  test('maps only the given diver', () async {
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

    final result = await repo.getWaterTempBandPerDive(
      unit: TemperatureUnit.celsius,
      diverId: 'me',
    );

    expect(result, {'a': 0});
  });
}
