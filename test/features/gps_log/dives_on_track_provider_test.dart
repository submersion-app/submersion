import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_database.dart';

void main() {
  late GpsTrackRepository trackRepo;
  late DiveRepository diveRepo;
  late LocalCacheDatabase cacheDb;
  late List<Override> baseOverrides;

  setUp(() async {
    await setUpTestDatabase();
    // divesProvider reaches SharedPreferences (diver scoping); getBaseOverrides
    // installs the mock and the current-diver stub.
    baseOverrides = await getBaseOverrides();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(cacheDb);
    trackRepo = GpsTrackRepository();
    diveRepo = DiveRepository();
  });

  tearDown(() async {
    await cacheDb.close();
    LocalCacheDatabaseService.instance.resetForTesting();
    await tearDownTestDatabase();
  });

  /// A track spanning 08:00 to 12:00 wall-clock on 2026-05-22.
  Future<String> seedTrack() async {
    final start = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch;
    final end = DateTime.utc(2026, 5, 22, 12).millisecondsSinceEpoch;
    final id = await trackRepo.startTrack(
      startTimeMs: start,
      tzOffsetMinutes: 0,
    );
    await trackRepo.appendBufferPoint(
      id,
      GpsTrackPoint(timestamp: start ~/ 1000, latitude: 20.0, longitude: -87.0),
    );
    await trackRepo.appendBufferPoint(
      id,
      GpsTrackPoint(timestamp: end ~/ 1000, latitude: 20.05, longitude: -87.05),
    );
    await trackRepo.finalizeTrack(id, endTimeMs: end);
    return id;
  }

  Future<String> seedDive(String id, DateTime entryWallClock) async {
    await diveRepo.createDive(
      Dive(id: id, diveNumber: 1, dateTime: entryWallClock, maxDepth: 30.0),
    );
    return id;
  }

  test(
    'returns only dives whose entry falls inside the track window',
    () async {
      final trackId = await seedTrack();
      // 06:00 is more than the 30-min tolerance before the 08:00 start.
      await seedDive('before', DateTime.utc(2026, 5, 22, 6));
      await seedDive('inside', DateTime.utc(2026, 5, 22, 9, 30));
      await seedDive('after', DateTime.utc(2026, 5, 22, 14));

      final container = ProviderContainer(overrides: baseOverrides);
      addTearDown(container.dispose);

      final dives = await container.read(divesOnTrackProvider(trackId).future);
      expect(dives.map((d) => d.id).toList(), ['inside']);
    },
  );

  test('returns empty for a track with no dives', () async {
    final trackId = await seedTrack();
    final container = ProviderContainer(overrides: baseOverrides);
    addTearDown(container.dispose);
    expect(await container.read(divesOnTrackProvider(trackId).future), isEmpty);
  });

  test('trackForDiveProvider finds the covering track', () async {
    final trackId = await seedTrack();
    await seedDive('d1', DateTime.utc(2026, 5, 22, 9, 30));

    final container = ProviderContainer(overrides: baseOverrides);
    addTearDown(container.dispose);

    final track = await container.read(trackForDiveProvider('d1').future);
    expect(track, isNotNull);
    expect(track!.id, trackId);
    // Hydrated: the covering track is decoded, unlike the lean scan.
    expect(track.points, isNotEmpty);
  });

  test(
    'trackForDiveProvider returns null when no track covers the dive',
    () async {
      await seedTrack();
      await seedDive('d2', DateTime.utc(2026, 5, 23, 9, 30));

      final container = ProviderContainer(overrides: baseOverrides);
      addTearDown(container.dispose);

      expect(await container.read(trackForDiveProvider('d2').future), isNull);
    },
  );

  test('an unfinished track (null endTime) matches no dives', () async {
    final start = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch;
    final id = await trackRepo.startTrack(
      startTimeMs: start,
      tzOffsetMinutes: 0,
    );
    await seedDive('d3', DateTime.utc(2026, 5, 22, 9));

    final container = ProviderContainer(overrides: baseOverrides);
    addTearDown(container.dispose);

    expect(await container.read(divesOnTrackProvider(id).future), isEmpty);
  });
}
