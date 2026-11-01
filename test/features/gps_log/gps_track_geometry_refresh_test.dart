import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_geometry.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';

import '../../helpers/test_database.dart';

/// Counts cache reads, which is what a needless provider rebuild costs on a
/// warm track.
class _CountingCache extends TrackGeometryCacheRepository {
  final reads = <String, int>{};

  @override
  Future<List<GpsTrackPoint>?> read(String trackId, TrackLod lod) {
    reads.update(trackId, (n) => n + 1, ifAbsent: () => 1);
    return super.read(trackId, lod);
  }
}

/// Counts simplifications. With [gated] set, each one waits in [waiting] until
/// the test releases it, so a test can act while the work is in flight.
class _Simplifier {
  _Simplifier({this.gated = false});

  final bool gated;
  final waiting = <Completer<void>>[];
  var runs = 0;

  Future<List<GpsTrackPoint>> call(
    List<GpsTrackPoint> points,
    double toleranceMeters,
  ) async {
    runs++;
    if (gated) {
      final gate = Completer<void>();
      waiting.add(gate);
      await gate.future;
    }
    return simplifyTrack(points, toleranceMeters);
  }

  void releaseAll() {
    for (final gate in waiting) {
      if (!gate.isCompleted) gate.complete();
    }
  }
}

void main() {
  late LocalCacheDatabase cacheDb;
  late GpsTrackRepository repo;
  late _CountingCache cache;
  late _Simplifier simplifier;

  setUp(() async {
    await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    LocalCacheDatabaseService.instance.setTestDatabase(cacheDb);
    repo = GpsTrackRepository();
    cache = _CountingCache();
    simplifier = _Simplifier();
  });

  tearDown(() async {
    await cacheDb.close();
    LocalCacheDatabaseService.instance.resetForTesting();
    await tearDownTestDatabase();
  });

  ProviderContainer newContainer() {
    final container = ProviderContainer(
      overrides: [
        trackGeometryCacheRepositoryProvider.overrideWithValue(cache),
        trackSimplifierProvider.overrideWithValue(simplifier.call),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Lets rebuilds scheduled by a tick run, for a check that something did
  /// NOT happen. Real time, because the cache answers from its own database
  /// connection.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  /// Waits for something that must happen, however loaded the machine is.
  Future<void> until(FutureOr<bool> Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!await condition()) {
      if (DateTime.now().isAfter(deadline)) fail('Condition never held');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  /// 08:00-12:00, a zigzag fix every hour wide enough that simplification
  /// keeps all five at the detail tolerance.
  Future<String> seedTrack() async {
    final startMs = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch;
    final id = await repo.startTrack(startTimeMs: startMs, tzOffsetMinutes: 0);
    for (var h = 0; h <= 4; h++) {
      await repo.appendBufferPoint(
        id,
        GpsTrackPoint(
          timestamp: startMs ~/ 1000 + h * 3600,
          latitude: 20.0 + h * 0.05,
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

  final trimMs = DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch;

  /// Holds [id]'s thumbnail open and resolves with its first value starting
  /// after the trim, or fails with the provider's own error.
  Future<void> redrawnAfterTrim(ProviderContainer container, String id) {
    final redrawn = Completer<void>();
    final key = gpsTrackGeometryProvider((id, TrackLod.thumbnail));
    final sub = container.listen(key, (_, next) {
      if (redrawn.isCompleted) return;
      if (next.hasError) {
        redrawn.completeError(next.error!, next.stackTrace);
      } else if ((next.value ?? const []).isNotEmpty &&
          next.value!.first.timestamp * 1000 >= trimMs) {
        redrawn.complete();
      }
    }, fireImmediately: true);
    addTearDown(sub.close);
    return redrawn.future.timeout(const Duration(seconds: 10));
  }

  group('cache writes (issue #3866)', () {
    test('an unrelated cache insert does not reload an active track', () async {
      final warm = await seedTrack();
      final container = newContainer();
      final key = gpsTrackGeometryProvider((warm, TrackLod.thumbnail));
      addTearDown(container.listen(key, (_, _) {}).close);
      await container.read(key.future);
      await settle();
      final before = cache.reads[warm];

      await cache.write('some-other-track', TrackLod.thumbnail, const []);
      await settle();

      expect(cache.reads[warm], before);
    });

    test('a track does not reload on its own cache write', () async {
      final id = await seedTrack();
      final container = newContainer();
      final key = gpsTrackGeometryProvider((id, TrackLod.thumbnail));
      addTearDown(container.listen(key, (_, _) {}).close);

      await container.read(key.future);
      await settle();

      expect(cache.reads[id], 1);
      expect(simplifier.runs, 1);
    });

    test('a cold list simplifies each preview once', () async {
      simplifier = _Simplifier(gated: true);
      final ids = [for (var i = 0; i < 8; i++) await seedTrack()];
      final container = newContainer();
      for (final id in ids) {
        final key = gpsTrackGeometryProvider((id, TrackLod.thumbnail));
        addTearDown(container.listen(key, (_, _) {}).close);
      }
      await until(() => simplifier.runs == ids.length);

      // One at a time: each finished preview writes to the cache while the
      // rest are still running, which is what restarted them.
      for (final (i, gate) in simplifier.waiting.toList().indexed) {
        gate.complete();
        await until(
          () async => await cache.read(ids[i], TrackLod.thumbnail) != null,
        );
        await settle();
      }

      expect(simplifier.runs, ids.length);
    });

    test('a track write during a cold load does not restart it', () async {
      simplifier = _Simplifier(gated: true);
      final id = await seedTrack();
      final other = await seedTrack();
      final container = newContainer();
      final key = gpsTrackGeometryProvider((id, TrackLod.thumbnail));
      addTearDown(container.listen(key, (_, _) {}).close);
      await until(() => simplifier.runs == 1);

      final serializer = SyncDataSerializer();
      await serializer.upsertRecord('gpsTracks', {
        ...(await serializer.fetchRecord('gpsTracks', other))!,
        'name': 'Palancar morning',
      });
      await settle();
      simplifier.releaseAll();
      await settle();

      expect(simplifier.runs, 1);
    });
  });

  group('eviction', () {
    test('evicting one track leaves the others alone', () async {
      final evicted = await seedTrack();
      final kept = await seedTrack();
      final container = newContainer();
      for (final id in [evicted, kept]) {
        final key = gpsTrackGeometryProvider((id, TrackLod.thumbnail));
        addTearDown(container.listen(key, (_, _) {}).close);
        await container.read(key.future);
      }
      await settle();
      final keptReads = cache.reads[kept];
      final evictedReads = cache.reads[evicted]!;

      await cache.invalidate(evicted);
      await until(() => cache.reads[evicted]! > evictedReads);
      await settle();

      expect(cache.reads[kept], keptReads);
    });

    test('an eviction made on another repository reaches the map', () async {
      final id = await seedTrack();
      final container = newContainer();
      final key = gpsTrackGeometryProvider((id, TrackLod.thumbnail));
      addTearDown(container.listen(key, (_, _) {}).close);
      await container.read(key.future);
      await settle();
      final before = cache.reads[id]!;

      // Sync builds its own repository rather than reading the provider.
      await TrackGeometryCacheRepository().invalidate(id);

      await until(() => cache.reads[id]! > before);
    });

    test('a trim during a simplify does not cache the old line', () async {
      simplifier = _Simplifier(gated: true);
      final id = await seedTrack();
      final container = newContainer();
      final key = gpsTrackGeometryProvider((id, TrackLod.detail));
      addTearDown(container.listen(key, (_, _) {}).close);
      await until(() => simplifier.waiting.length == 1);

      await container.read(trimTrackProvider)(id, startMs: trimMs);
      await until(() => simplifier.waiting.length == 2);

      // The job that read the old points finishes last, so without the guard
      // its write is the one left in the cache.
      final [superseded, current] = simplifier.waiting;
      current.complete();
      await until(() async => await cache.read(id, TrackLod.detail) != null);
      superseded.complete();
      await settle();

      final cached = await cache.read(id, TrackLod.detail);
      expect(cached, isNotNull);
      expect(cached!.first.timestamp * 1000, greaterThanOrEqualTo(trimMs));
      final value = await container.read(key.future);
      expect(value.first.timestamp * 1000, greaterThanOrEqualTo(trimMs));
    });

    test('a peer trim redraws a preview built earlier this session', () async {
      final id = await seedTrack();
      final container = newContainer();
      final key = gpsTrackGeometryProvider((id, TrackLod.thumbnail));
      addTearDown(container.listen(key, (_, _) {}).close);
      await container.read(key.future);
      await settle();

      // Any track write moves the preview onto its cache hit, leaving the
      // hydrated track alive with nothing listening to it.
      final serializer = SyncDataSerializer();
      await serializer.upsertRecord('gpsTracks', {
        ...(await serializer.fetchRecord('gpsTracks', id))!,
        'name': 'Palancar morning',
      });
      await settle();

      await serializer.upsertRecord('gpsTracks', {
        ...(await serializer.fetchRecord('gpsTracks', id))!,
        'trimStartTime': trimMs,
      });

      await redrawnAfterTrim(container, id);
      final cached = await cache.read(id, TrackLod.thumbnail);
      expect(cached!.first.timestamp * 1000, greaterThanOrEqualTo(trimMs));
    });
  });
}
