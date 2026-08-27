import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/tide/entities/tide_constituent.dart';
import 'package:submersion/features/tides/data/repositories/noaa_station_cache_repository.dart';

void main() {
  late LocalCacheDatabase db;
  late NoaaStationCacheRepository repo;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    repo = NoaaStationCacheRepository(
      db,
      now: () => DateTime.utc(2026, 8, 9, 12),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('read returns null for unknown station', () async {
    expect(await repo.read('0000000'), isNull);
  });

  test('ok roundtrip preserves constituents and datum offset', () async {
    await repo.write(
      stationId: '9414290',
      name: 'San Francisco',
      latitude: 37.806,
      longitude: -122.466,
      constituents: {
        'M2': const TideConstituent(name: 'M2', amplitude: 0.576, phase: 208.2),
      },
      datumOffsetMllw: 0.951,
      status: NoaaStationCacheStatus.ok,
    );

    final cached = await repo.read('9414290');
    expect(cached, isNotNull);
    expect(cached!.status, NoaaStationCacheStatus.ok);
    expect(cached.constituents['M2']!.amplitude, 0.576);
    expect(cached.constituents['M2']!.phase, 208.2);
    expect(cached.datumOffsetMllw, 0.951);
    expect(cached.fetchedAt, DateTime.utc(2026, 8, 9, 12));
  });

  test('unavailable roundtrip has empty constituents', () async {
    await repo.write(
      stationId: '1111111',
      name: 'No Harmonics',
      latitude: 0,
      longitude: 0,
      status: NoaaStationCacheStatus.unavailable,
      constituents: const {},
    );

    final cached = await repo.read('1111111');
    expect(cached!.status, NoaaStationCacheStatus.unavailable);
    expect(cached.constituents, isEmpty);
    expect(cached.datumOffsetMllw, isNull);
  });

  test(
    'corrupt constituents JSON reads as a cache miss, not a throw',
    () async {
      // A malformed row must degrade like an absent one so the resolver
      // refetches (overwriting it) instead of erroring the tide section.
      await db
          .into(db.noaaTideStations)
          .insert(
            NoaaTideStationsCompanion.insert(
              stationId: '9414290',
              name: 'San Francisco',
              latitude: 37.806,
              longitude: -122.466,
              constituentsJson: const Value('{"M2": {broken'),
              status: 'ok',
              fetchedAt: DateTime.utc(2026, 8, 9).millisecondsSinceEpoch,
            ),
          );

      expect(await repo.read('9414290'), isNull);
    },
  );

  test('write replaces an existing row', () async {
    await repo.write(
      stationId: '9414290',
      name: 'SF',
      latitude: 1,
      longitude: 2,
      constituents: const {},
      status: NoaaStationCacheStatus.unavailable,
    );
    await repo.write(
      stationId: '9414290',
      name: 'San Francisco',
      latitude: 37.806,
      longitude: -122.466,
      constituents: {
        'K1': const TideConstituent(name: 'K1', amplitude: 0.37, phase: 225.4),
      },
      datumOffsetMllw: 0.951,
      status: NoaaStationCacheStatus.ok,
    );
    final cached = await repo.read('9414290');
    expect(cached!.status, NoaaStationCacheStatus.ok);
    expect(cached.constituents.keys, ['K1']);
  });
}
