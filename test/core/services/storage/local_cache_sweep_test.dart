import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/storage/local_cache_sweep.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../helpers/temp_dir.dart';

void main() {
  group('shouldSweepLocalCache', () {
    final now = DateTime.utc(2026, 9, 26, 12);

    test('a device that has never swept is due', () {
      expect(shouldSweepLocalCache(lastSweptAt: null, now: now), isTrue);
    });

    test('a sweep within the last week is not due', () {
      expect(
        shouldSweepLocalCache(
          lastSweptAt: now.subtract(const Duration(days: 6, hours: 23)),
          now: now,
        ),
        isFalse,
      );
    });

    test('a sweep a week old is due', () {
      expect(
        shouldSweepLocalCache(
          lastSweptAt: now.subtract(const Duration(days: 7)),
          now: now,
        ),
        isTrue,
      );
    });

    test('a stamp slightly ahead of the clock is not due', () {
      // Clock skew of an hour is ordinary; it must not force a sweep.
      expect(
        shouldSweepLocalCache(
          lastSweptAt: now.add(const Duration(hours: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('a stamp far in the future is due rather than suppressing', () {
      // A broken clock must not stop the sweep until real time catches up.
      expect(
        shouldSweepLocalCache(
          lastSweptAt: now.add(const Duration(days: 400)),
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('LocalCacheSweep', () {
    late LocalCacheDatabase local;
    late AppDatabase library;
    final now = DateTime.utc(2026, 9, 26, 12);

    setUp(() {
      local = LocalCacheDatabase(NativeDatabase.memory());
      library = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await local.close();
      await library.close();
    });

    LocalCacheSweep sweep() =>
        LocalCacheSweep(localCache: local, library: library);

    Future<void> putGrid(String key, {String grid = '{}'}) => local
        .into(local.bathymetryCache)
        .insert(
          BathymetryCacheCompanion.insert(
            cacheKey: key,
            centerLat: 0,
            centerLon: 0,
            status: 'ok',
            gridJson: Value(grid),
            fetchedAt: 0,
          ),
        );

    Future<List<String>> gridKeys() async =>
        (await local.select(local.bathymetryCache).get())
            .map((r) => r.cacheKey)
            .toList();

    Future<void> addDive(String id) => library
        .into(library.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: 0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );

    Future<void> addMedia(String id) => library
        .into(library.media)
        .insert(
          MediaCompanion.insert(
            id: id,
            filePath: '',
            createdAt: 0,
            updatedAt: 0,
          ),
        );

    Future<void> addTrack(String id) => library
        .into(library.gpsTracks)
        .insert(
          GpsTracksCompanion.insert(
            id: id,
            startTime: 0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );

    Future<void> cacheDeco(String diveId) => local
        .into(local.decoClassificationCache)
        .insert(
          DecoClassificationCacheCompanion.insert(
            diveId: diveId,
            hadDeco: false,
            inputsHash: 'h',
            computedAt: 0,
          ),
        );

    Future<void> cacheAsset(String mediaId) => local
        .into(local.localAssetCache)
        .insert(
          LocalAssetCacheCompanion.insert(
            mediaId: mediaId,
            localAssetId: const Value('asset'),
            resolvedAt: 0,
            resolutionMethod: 'original_id',
          ),
        );

    Future<void> cacheGeometry(String trackId, String lod) => local
        .into(local.gpsTrackGeometryCache)
        .insert(
          GpsTrackGeometryCacheCompanion.insert(
            trackId: trackId,
            lodLevel: lod,
            status: 'empty',
            createdAt: 0,
          ),
        );

    test('deletes superseded bathymetry and keeps every current key', () async {
      const bonaire = GeoPoint(12.16, -68.29);
      const betlis = GeoPoint(47.135503, 9.144546); // Walensee
      final current = [
        BathymetryRepository.keyFor(bonaire),
        BathymetryRepository.keyFor(bonaire, spanMeters: 500),
        BathymetryRepository.keyFor(betlis),
        BathymetryRepository.keyFor(betlis, spanMeters: 1000),
      ];
      final superseded = [
        '12.16,-68.30@8000',
        '12.16,-68.30@4000',
        '12.16,-68.30@8000v2',
        '12.16,-68.30@8000v4',
        '47.135503,9.144546@8000v4@419.07',
        // Right generation, but a level Walensee no longer documents.
        '${BathymetryRepository.keyFor(betlis).split('@').take(2).join('@')}'
            '@1.0',
      ];
      for (final key in [...current, ...superseded]) {
        await putGrid(key);
      }

      final report = await sweep().run(now: now);

      expect(report.bathymetryRows, superseded.length);
      expect(await gridKeys(), unorderedEquals(current));
    });

    test('deletes cache rows whose dive, media or track is gone', () async {
      await addDive('dive-live');
      await addMedia('media-live');
      await addTrack('track-live');

      await cacheDeco('dive-live');
      await cacheDeco('dive-gone');
      await cacheAsset('media-live');
      await cacheAsset('media-gone');
      for (final lod in ['thumbnail', 'overview']) {
        await cacheGeometry('track-live', lod);
      }
      // A track deleted on another device leaves every LOD behind.
      for (final lod in ['thumbnail', 'overview', 'detail']) {
        await cacheGeometry('track-gone', lod);
      }

      final report = await sweep().run(now: now);

      expect(report.decoRows, 1);
      expect(report.assetRows, 1);
      expect(report.trackGeometryRows, 3);
      expect(
        (await local.select(local.decoClassificationCache).get()).map(
          (r) => r.diveId,
        ),
        ['dive-live'],
      );
      expect(
        (await local.select(local.localAssetCache).get()).map((r) => r.mediaId),
        ['media-live'],
      );
      expect(
        (await local.select(local.gpsTrackGeometryCache).get())
            .map((r) => r.trackId)
            .toSet(),
        {'track-live'},
      );
    });

    test('checks ids across chunk boundaries', () async {
      // More ids than one bound-variable chunk, with the live and the
      // orphaned ones interleaved so every chunk holds both.
      await library.batch((b) {
        for (var i = 0; i < 2000; i += 2) {
          b.insert(
            library.dives,
            DivesCompanion.insert(
              id: 'd$i',
              diveDateTime: 0,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
        }
      });
      await local.batch((b) {
        for (var i = 0; i < 2000; i++) {
          b.insert(
            local.decoClassificationCache,
            DecoClassificationCacheCompanion.insert(
              diveId: 'd$i',
              hadDeco: false,
              inputsHash: 'h',
              computedAt: 0,
            ),
          );
        }
      });

      final report = await sweep().run(now: now);

      expect(report.decoRows, 1000);
      final kept = (await local.select(local.decoClassificationCache).get())
          .map((r) => int.parse(r.diveId.substring(1)));
      expect(kept, hasLength(1000));
      expect(kept.every((i) => i.isEven), isTrue);
    });

    test('deletes expired reef rows', () async {
      await local
          .into(local.reefDataCache)
          .insert(
            ReefDataCacheCompanion.insert(
              provider: 'health',
              coordKey: 'k',
              payloadJson: '{}',
              status: 'ok',
              fetchedAt: now
                  .subtract(const Duration(days: 2))
                  .millisecondsSinceEpoch,
            ),
          );

      final report = await sweep().run(now: now);

      expect(report.reefRows, 1);
      expect(await local.select(local.reefDataCache).get(), isEmpty);
    });

    test('an empty cache is a no-op', () async {
      final report = await sweep().run(now: now);

      expect(report.rowsDeleted, 0);
      expect(report.vacuumed, isFalse);
    });
  });

  group('LocalCacheSweep vacuum', () {
    late Directory dir;
    late File file;
    late LocalCacheDatabase local;
    late AppDatabase library;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('local_cache_sweep_');
      file = File(p.join(dir.path, 'submersion_local.db'));
      local = LocalCacheDatabase(NativeDatabase(file));
      library = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await local.close();
      await library.close();
      await deleteTempDir(dir);
    });

    Future<void> putGrids(String generationSuffix, int count) async {
      final grid = 'x' * 100000;
      await local.batch((b) {
        for (var i = 0; i < count; i++) {
          b.insert(
            local.bathymetryCache,
            BathymetryCacheCompanion.insert(
              cacheKey: '12.$i,-68.30@8000$generationSuffix',
              centerLat: 0,
              centerLon: 0,
              status: 'ok',
              gridJson: Value(grid),
              fetchedAt: 0,
            ),
          );
        }
      });
    }

    test('shrinks the file after a sweep that frees a lot', () async {
      // Superseded generation-2 grids, about 3 MB of them.
      await putGrids('v2', 30);
      final before = await file.length();

      final report = await LocalCacheSweep(
        localCache: local,
        library: library,
      ).run();

      expect(report.bathymetryRows, 30);
      expect(report.vacuumed, isTrue);
      expect(await file.length(), lessThan(before ~/ 4));
    });

    test('does not vacuum when little is freed', () async {
      await putGrids(BathymetryRepository.selectionGeneration, 5);
      await local
          .into(local.decoClassificationCache)
          .insert(
            DecoClassificationCacheCompanion.insert(
              diveId: 'gone',
              hadDeco: false,
              inputsHash: 'h',
              computedAt: 0,
            ),
          );
      final before = await file.length();

      final report = await LocalCacheSweep(
        localCache: local,
        library: library,
      ).run();

      expect(report.decoRows, 1);
      expect(report.vacuumed, isFalse);
      expect(await file.length(), before);
    });
  });
}
