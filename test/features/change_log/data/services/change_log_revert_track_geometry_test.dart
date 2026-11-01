import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late LocalCacheDatabase cacheDb;
  late GpsTrackRepository tracks;
  late TrackGeometryCacheRepository cache;
  late ChangeLogRevertService service;
  final repository = ChangeLogRepository();

  setUp(() async {
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    LocalCacheDatabaseService.instance.setTestDatabase(cacheDb);
    SyncClock.instance.configure(nodeId: 'node-test', now: () => 5000);
    tracks = GpsTrackRepository();
    cache = TrackGeometryCacheRepository();
    service = ChangeLogRevertService(afterDiveWrites: (_) {});
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await cacheDb.close();
    LocalCacheDatabaseService.instance.resetForTesting();
    await tearDownTestDatabase();
  });

  final startMs = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch;
  final trimMs = DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch;

  Future<String> seedTrack() async {
    final id = await tracks.startTrack(
      startTimeMs: startMs,
      tzOffsetMinutes: 0,
    );
    for (var h = 0; h <= 4; h++) {
      await tracks.appendBufferPoint(
        id,
        GpsTrackPoint(
          timestamp: startMs ~/ 1000 + h * 3600,
          latitude: 20.0 + h * 0.05,
          longitude: -87.0 + (h.isEven ? 0.0 : 0.002),
        ),
      );
    }
    await tracks.finalizeTrack(
      id,
      endTimeMs: DateTime.utc(2026, 5, 22, 12).millisecondsSinceEpoch,
    );
    return id;
  }

  /// Log whatever has happened so far as settled history, so the next
  /// operation is the only one a revert can pick up.
  Future<void> startFresh() async {
    await repository.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
    await SyncRepository().clearPendingRecords();
  }

  Future<String> newestOperation() async {
    await repository.settleAll();
    final row = await db
        .customSelect(
          'SELECT id FROM change_log_operations '
          'WHERE event_count > 0 ORDER BY last_event_id DESC LIMIT 1',
        )
        .getSingle();
    return row.read<String>('id');
  }

  Future<void> revertNewest() async =>
      service.execute(await service.planOperation(await newestOperation()));

  test('reverting a trim drops the line it drew', () async {
    final id = await seedTrack();
    final other = await seedTrack();
    await startFresh();
    await tracks.setTrimBounds(id, startMs: trimMs);
    await cache.write(id, TrackLod.detail, const []);
    await cache.write(other, TrackLod.detail, const []);

    await revertNewest();

    expect((await tracks.getTrack(id))!.trimStartTime, isNull);
    expect(await cache.read(id, TrackLod.detail), isNull);
    expect(await cache.read(other, TrackLod.detail), isNotNull);
  });

  test('reverting a trim redraws an open map', () async {
    final id = await seedTrack();
    await startFresh();
    await tracks.setTrimBounds(id, startMs: trimMs);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final key = gpsTrackGeometryProvider((id, TrackLod.detail));
    final untrimmed = Completer<void>();
    final sub = container.listen(key, (_, next) {
      if (next.hasError && !untrimmed.isCompleted) {
        untrimmed.completeError(next.error!, next.stackTrace);
      } else if (next.value?.length == 5 && !untrimmed.isCompleted) {
        untrimmed.complete();
      }
    });
    addTearDown(sub.close);
    expect(await container.read(key.future), hasLength(3));

    await revertNewest();

    await untrimmed.future.timeout(const Duration(seconds: 10));
  });

  test('undoing a track delete redraws its empty preview', () async {
    final id = await seedTrack();
    await startFresh();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final key = gpsTrackGeometryProvider((id, TrackLod.thumbnail));
    // Only a redraw after the delete counts, not the first line drawn.
    var deleted = false;
    final restored = Completer<void>();
    final sub = container.listen(key, (_, next) {
      if (next.hasError && !restored.isCompleted) {
        restored.completeError(next.error!, next.stackTrace);
      } else if (deleted &&
          (next.value?.isNotEmpty ?? false) &&
          !restored.isCompleted) {
        restored.complete();
      }
    });
    addTearDown(sub.close);
    expect(await container.read(key.future), isNotEmpty);

    await container.read(deleteTrackProvider)(id);
    expect(await container.read(key.future), isEmpty);
    deleted = true;

    await revertNewest();

    await restored.future.timeout(const Duration(seconds: 10));
  });

  test('a failed eviction does not fail the revert', () async {
    final failing = ChangeLogRevertService(
      afterDiveWrites: (_) {},
      evictTrackGeometry: (_) async => throw StateError('cache broken'),
    );
    final id = await seedTrack();
    await startFresh();
    await tracks.setTrimBounds(id, startMs: trimMs);

    final operation = await newestOperation();
    await failing.execute(await failing.planOperation(operation));

    expect((await tracks.getTrack(id))!.trimStartTime, isNull);
  });
}
