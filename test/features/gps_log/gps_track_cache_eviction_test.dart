import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_database.dart';

void main() {
  late LocalCacheDatabase cacheDb;
  late GpsTrackRepository repo;
  late List<Override> baseOverrides;

  setUp(() async {
    await setUpTestDatabase();
    baseOverrides = await getBaseOverrides();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(cacheDb);
    repo = GpsTrackRepository();
  });

  tearDown(() async {
    await cacheDb.close();
    LocalCacheDatabaseService.instance.resetForTesting();
    await tearDownTestDatabase();
  });

  /// 08:00-12:00, a fix every hour.
  Future<String> seed() async {
    final startMs = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch;
    final id = await repo.startTrack(startTimeMs: startMs, tzOffsetMinutes: 0);
    for (var h = 0; h <= 4; h++) {
      await repo.appendBufferPoint(
        id,
        GpsTrackPoint(
          timestamp: startMs ~/ 1000 + h * 3600,
          latitude: 20.0 + h * 0.05,
          // Zigzag ~100 m wide so Douglas-Peucker keeps every fix even at
          // the 2 m detail tolerance; a straight line would collapse to two.
          longitude: -87.0 + (h.isEven ? 0.0 : 0.002),
        ),
      );
    }
    await repo.finalizeTrack(
      id,
      endTimeMs: DateTime.utc(2026, 5, 22, 12).millisecondsSinceEpoch,
    );
    return id;
  }

  test('a trim reaches the map even on a warm persisted cache', () async {
    final id = await seed();

    // Warm the cache, as a previous launch would have.
    final warm = ProviderContainer(overrides: baseOverrides);
    await warm.read(gpsTrackGeometryProvider((id, TrackLod.detail)).future);
    warm.dispose();
    expect(
      await TrackGeometryCacheRepository().read(id, TrackLod.detail),
      isNotNull,
    );

    // Fresh container: the geometry provider returns early on the cache hit
    // and never watches gpsTrackDetailProvider, so invalidating the detail
    // provider alone could not reach it - the map kept the untrimmed line
    // while the stats header updated.
    final container = ProviderContainer(overrides: baseOverrides);
    addTearDown(container.dispose);
    final before = await container.read(
      gpsTrackGeometryProvider((id, TrackLod.detail)).future,
    );
    expect(before.length, 5);

    await container.read(trimTrackProvider)(
      id,
      startMs: DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch,
    );

    final after = await container.read(
      gpsTrackGeometryProvider((id, TrackLod.detail)).future,
    );
    expect(after.length, 3);
    expect(
      after.first.timestamp * 1000,
      greaterThanOrEqualTo(
        DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch,
      ),
    );
  });

  test('every LOD is evicted, not just the one on screen', () async {
    final id = await seed();
    final container = ProviderContainer(overrides: baseOverrides);
    addTearDown(container.dispose);

    for (final lod in TrackLod.values) {
      await container.read(gpsTrackGeometryProvider((id, lod)).future);
    }

    await container.read(trimTrackProvider)(
      id,
      startMs: DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch,
    );

    final cache = TrackGeometryCacheRepository();
    for (final lod in TrackLod.values) {
      expect(
        await cache.read(id, lod),
        isNull,
        reason: '$lod still cached after a trim',
      );
    }
  });

  test('deleting a track leaves no orphan cache rows', () async {
    final id = await seed();
    final container = ProviderContainer(overrides: baseOverrides);
    addTearDown(container.dispose);

    for (final lod in TrackLod.values) {
      await container.read(gpsTrackGeometryProvider((id, lod)).future);
    }

    await container.read(deleteTrackProvider)(id);

    // The cache has no TTL, no foreign key, and no GC, so anything left here
    // is leaked for the lifetime of the install.
    final cache = TrackGeometryCacheRepository();
    for (final lod in TrackLod.values) {
      expect(await cache.read(id, lod), isNull);
    }
    expect(await repo.getTrack(id), isNull);
  });

  test('a split evicts the parent cache', () async {
    final id = await seed();
    final container = ProviderContainer(overrides: baseOverrides);
    addTearDown(container.dispose);

    await container.read(
      gpsTrackGeometryProvider((id, TrackLod.detail)).future,
    );
    await container.read(splitTrackProvider)(
      id,
      DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch,
    );

    expect(
      await TrackGeometryCacheRepository().read(id, TrackLod.detail),
      isNull,
    );
  });
}
