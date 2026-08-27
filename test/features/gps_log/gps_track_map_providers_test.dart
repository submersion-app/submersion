import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';

import '../../helpers/test_database.dart';

void main() {
  late LocalCacheDatabase cacheDb;
  late GpsTrackRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(cacheDb);
    repo = GpsTrackRepository();
  });

  tearDown(() async {
    await cacheDb.close();
    LocalCacheDatabaseService.instance.resetForTesting();
    await tearDownTestDatabase();
  });

  /// Seeds a track of 100 near-collinear fixes: a straight run east with a
  /// sub-metre north wobble, so aggressive simplification should collapse it
  /// to a handful of points.
  Future<String> seedWobblyTrack() async {
    final id = await repo.startTrack(
      startTimeMs: 1700000000000,
      tzOffsetMinutes: 0,
    );
    for (var i = 0; i < 100; i++) {
      await repo.appendBufferPoint(
        id,
        GpsTrackPoint(
          timestamp: 1700000000 + i,
          // 1e-8 deg is ~1 mm of wobble - far below any tolerance.
          latitude: (i.isEven ? 1e-8 : -1e-8),
          longitude: i * 0.0001,
        ),
      );
    }
    await repo.finalizeTrack(id, endTimeMs: 1700000099000);
    return id;
  }

  test('simplifies on first read and writes the result to cache', () async {
    final id = await seedWobblyTrack();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final simplified = await container.read(
      gpsTrackGeometryProvider((id, TrackLod.thumbnail)).future,
    );

    expect(simplified.length, lessThan(100));
    expect(simplified.length, greaterThanOrEqualTo(2));

    // The cache now holds it, so a cold provider would not re-simplify.
    final cached = await TrackGeometryCacheRepository().read(
      id,
      TrackLod.thumbnail,
    );
    expect(cached, isNotNull);
    expect(cached!.length, simplified.length);
  });

  test('a second read returns the cached geometry unchanged', () async {
    final id = await seedWobblyTrack();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final first = await container.read(
      gpsTrackGeometryProvider((id, TrackLod.thumbnail)).future,
    );
    container.invalidate(gpsTrackGeometryProvider((id, TrackLod.thumbnail)));
    final second = await container.read(
      gpsTrackGeometryProvider((id, TrackLod.thumbnail)).future,
    );

    expect(second.length, first.length);
    expect(second.first.timestamp, first.first.timestamp);
    expect(second.last.timestamp, first.last.timestamp);
  });

  test('different LOD levels produce independently cached results', () async {
    final id = await seedWobblyTrack();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(
      gpsTrackGeometryProvider((id, TrackLod.thumbnail)).future,
    );
    await container.read(
      gpsTrackGeometryProvider((id, TrackLod.detail)).future,
    );

    final cache = TrackGeometryCacheRepository();
    expect(await cache.read(id, TrackLod.thumbnail), isNotNull);
    expect(await cache.read(id, TrackLod.detail), isNotNull);
  });

  test('returns empty for a track id that does not exist', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = await container.read(
      gpsTrackGeometryProvider(('nope', TrackLod.detail)).future,
    );
    expect(result, isEmpty);
  });
}
