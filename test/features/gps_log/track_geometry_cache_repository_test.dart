import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

GpsTrackPoint p(int t) =>
    GpsTrackPoint(timestamp: t, latitude: t * 0.001, longitude: 0.0);

void main() {
  late LocalCacheDatabase db;
  late TrackGeometryCacheRepository repo;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(db);
    repo = TrackGeometryCacheRepository();
  });

  tearDown(() async {
    await db.close();
    LocalCacheDatabaseService.instance.resetForTesting();
  });

  test('returns null for an uncached track', () async {
    expect(await repo.read('missing', TrackLod.thumbnail), isNull);
  });

  test('round-trips written geometry', () async {
    final points = [p(1), p(2), p(3)];
    await repo.write('track-1', TrackLod.detail, points);
    final read = await repo.read('track-1', TrackLod.detail);
    expect(read, isNotNull);
    expect(read!.length, 3);
    expect(read.first.timestamp, 1);
  });

  test('keeps LOD levels independent', () async {
    await repo.write('track-1', TrackLod.thumbnail, [p(1), p(2)]);
    await repo.write('track-1', TrackLod.detail, [p(1), p(2), p(3)]);
    expect((await repo.read('track-1', TrackLod.thumbnail))!.length, 2);
    expect((await repo.read('track-1', TrackLod.detail))!.length, 3);
  });

  test('caches an empty result as a definitive answer, not a miss', () async {
    await repo.write('track-empty', TrackLod.overview, const []);
    final read = await repo.read('track-empty', TrackLod.overview);
    expect(read, isNotNull);
    expect(read, isEmpty);
  });

  test('invalidate clears every LOD for a track', () async {
    await repo.write('track-1', TrackLod.thumbnail, [p(1), p(2)]);
    await repo.write('track-1', TrackLod.detail, [p(1), p(2), p(3)]);
    await repo.invalidate('track-1');
    expect(await repo.read('track-1', TrackLod.thumbnail), isNull);
    expect(await repo.read('track-1', TrackLod.detail), isNull);
  });

  test('invalidate leaves other tracks untouched', () async {
    await repo.write('track-1', TrackLod.detail, [p(1), p(2)]);
    await repo.write('track-2', TrackLod.detail, [p(1), p(2)]);
    await repo.invalidate('track-1');
    expect(await repo.read('track-2', TrackLod.detail), isNotNull);
  });

  test('rewriting the same key replaces rather than duplicates', () async {
    await repo.write('track-1', TrackLod.detail, [p(1), p(2)]);
    await repo.write('track-1', TrackLod.detail, [p(1), p(2), p(3)]);
    expect((await repo.read('track-1', TrackLod.detail))!.length, 3);
  });

  group('TrackLod tolerances', () {
    test('match the spec', () {
      expect(TrackLod.thumbnail.toleranceMeters, 50.0);
      expect(TrackLod.overview.toleranceMeters, 10.0);
      expect(TrackLod.detail.toleranceMeters, 2.0);
    });
  });

  group('corrupt blobs', () {
    /// Overwrites a cached row's blob with bytes gzip cannot decode.
    Future<void> corrupt(String trackId, TrackLod lod) async {
      await (db.update(db.gpsTrackGeometryCache)
            ..where((t) => t.trackId.equals(trackId))
            ..where((t) => t.lodLevel.equals(lod.name)))
          .write(
            GpsTrackGeometryCacheCompanion(
              points: Value(Uint8List.fromList([0, 1, 2, 3, 4])),
            ),
          );
    }

    test('a corrupt blob reads as a miss, not an error', () async {
      await repo.write('track-1', TrackLod.detail, [p(0), p(1)]);
      await corrupt('track-1', TrackLod.detail);

      // Everything here is re-derivable, so the caller must see a miss and
      // rebuild - not an exception it has no way to recover from.
      expect(await repo.read('track-1', TrackLod.detail), isNull);
    });

    test('the poisoned row is evicted, so it cannot recur', () async {
      await repo.write('track-1', TrackLod.detail, [p(0), p(1)]);
      await corrupt('track-1', TrackLod.detail);
      await repo.read('track-1', TrackLod.detail);

      // This store has no TTL and no GC. Leaving the row in place meant every
      // later read hit the same bad bytes and the track stayed broken for the
      // life of the install.
      final rows = await db.select(db.gpsTrackGeometryCache).get();
      expect(rows.where((r) => r.trackId == 'track-1'), isEmpty);
    });

    test('other LODs of the same track survive the eviction', () async {
      await repo.write('track-1', TrackLod.detail, [p(0), p(1)]);
      await repo.write('track-1', TrackLod.thumbnail, [p(0), p(1)]);
      await corrupt('track-1', TrackLod.detail);

      await repo.read('track-1', TrackLod.detail);
      expect(await repo.read('track-1', TrackLod.thumbnail), hasLength(2));
    });

    test('a re-write after eviction is readable again', () async {
      await repo.write('track-1', TrackLod.detail, [p(0), p(1)]);
      await corrupt('track-1', TrackLod.detail);
      expect(await repo.read('track-1', TrackLod.detail), isNull);

      await repo.write('track-1', TrackLod.detail, [p(0), p(1), p(2)]);
      expect(await repo.read('track-1', TrackLod.detail), hasLength(3));
    });
  });
}
