import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/bathymetry/data/sources/swiss_bathy_tile_cache_repository.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';

void main() {
  late LocalCacheDatabase db;
  late SwissBathyTileCacheRepository repo;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    repo = SwissBathyTileCacheRepository(db);
  });

  tearDown(() => db.close());

  group('SwissBathyTileCacheRepository.read', () {
    test('returns the grid for a valid cached row', () async {
      final grid = BathymetryGrid(
        originLat: 47.2,
        originLon: 9.1,
        cellSizeLatDeg: 0.001,
        cellSizeLonDeg: 0.001,
        rows: 2,
        cols: 2,
        depthsMeters: [1.0, 2.0, 3.0, 4.0],
        sourceId: 'swissbathy3d',
        resolutionMeters: 2,
        fetchedAt: DateTime.utc(2026, 1, 1),
      );
      await repo.writeOk('2726_1221', grid, referenceLevelMeters: 405.92);

      final entry = await repo.read('2726_1221');
      expect(entry, isNotNull);
      expect(entry!.grid.depthAt(0, 0), 1.0);
    });

    test(
      'a row with corrupt/unparseable gridJson is deleted and read() '
      'reports it as uncached instead of a cached negative (regression: '
      'previously the corrupt row was left in place, and a later call to '
      'hasCachedAnswer() would then wrongly report the tile as already '
      'resolved, forever masking the real data behind the corruption)',
      () async {
        await db
            .into(db.swissBathyTileCache)
            .insert(
              SwissBathyTileCacheCompanion.insert(
                tileKey: '2726_1221',
                status: 'ok',
                gridJson: const Value('not valid json {{{'),
                fetchedAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );

        final entry = await repo.read('2726_1221');
        expect(entry, isNull);

        final remaining = await (db.select(
          db.swissBathyTileCache,
        )..where((t) => t.tileKey.equals('2726_1221'))).get();
        expect(remaining, isEmpty);

        // The row is gone entirely, not just downgraded -- hasCachedAnswer()
        // must see "never resolved", not "already answered", so the caller
        // retries instead of treating the coordinate as confirmed empty.
        expect(await repo.hasCachedAnswer('2726_1221'), isFalse);
      },
    );

    test("a row with status 'ok' but a null gridJson (an inconsistent row) is "
        'deleted, same as a corrupt row, instead of just returning null and '
        'leaving it in place', () async {
      await db
          .into(db.swissBathyTileCache)
          .insert(
            SwissBathyTileCacheCompanion.insert(
              tileKey: '2726_1221',
              status: 'ok',
              fetchedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );

      final entry = await repo.read('2726_1221');
      expect(entry, isNull);

      final remaining = await (db.select(
        db.swissBathyTileCache,
      )..where((t) => t.tileKey.equals('2726_1221'))).get();
      expect(remaining, isEmpty);

      expect(await repo.hasCachedAnswer('2726_1221'), isFalse);
    });

    test('a row with valid JSON that does not decode to a BathymetryGrid is '
        'also treated as corrupt and deleted', () async {
      await db
          .into(db.swissBathyTileCache)
          .insert(
            SwissBathyTileCacheCompanion.insert(
              tileKey: '2726_1221',
              status: 'ok',
              gridJson: const Value('{"unexpected": "shape"}'),
              fetchedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );

      final entry = await repo.read('2726_1221');
      expect(entry, isNull);

      final remaining = await (db.select(
        db.swissBathyTileCache,
      )..where((t) => t.tileKey.equals('2726_1221'))).get();
      expect(remaining, isEmpty);
    });

    test('a cached negative ("empty") row is left untouched, not deleted, '
        'when no expected reference level is given or it matches', () async {
      await repo.writeEmpty('2726_1221', referenceLevelMeters: 419.00);

      final entry = await repo.read('2726_1221');
      expect(entry, isNull);
      expect(await repo.hasCachedAnswer('2726_1221'), isTrue);

      final withMatch = await repo.read(
        '2726_1221',
        expectedReferenceLevelMeters: 419.00,
      );
      expect(withMatch, isNull);
      expect(await repo.hasCachedAnswer('2726_1221'), isTrue);
    });

    test('a cached negative ("empty") row under a different reference level '
        'than expected is deleted, so the tile is retried instead of staying '
        'a permanent negative (regression: a lake bbox/level correction that '
        'turns a tile genuinely dry under the OLD lake assignment into real, '
        'covered water under the new one must not leave it pinned "no data" '
        'forever, exactly like the analogous "ok" row case above -- Copilot '
        'review)', () async {
      await repo.writeEmpty('2726_1221', referenceLevelMeters: 433.58);

      final entry = await repo.read(
        '2726_1221',
        expectedReferenceLevelMeters: 419.00,
      );
      expect(entry, isNull);
      expect(await repo.hasCachedAnswer('2726_1221'), isFalse);
    });

    test('a cached negative ("empty") row written before referenceLevelMeters '
        'existed (null) is treated as a mismatch too when a caller now '
        'expects a specific level', () async {
      await db
          .into(db.swissBathyTileCache)
          .insert(
            SwissBathyTileCacheCompanion.insert(
              tileKey: '2726_1221',
              status: 'empty',
              fetchedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );

      final entry = await repo.read(
        '2726_1221',
        expectedReferenceLevelMeters: 419.00,
      );
      expect(entry, isNull);
      expect(await repo.hasCachedAnswer('2726_1221'), isFalse);
    });

    test(
      'a row cached under a different reference level than expected is '
      'deleted and read() returns null, same as corruption (regression: '
      'a swiss_lake_levels.dart correction that changes which lake a '
      'coordinate resolves to, or its documented mean level, must not '
      'leave a tile serving depths computed against the old level forever)',
      () async {
        final grid = BathymetryGrid(
          originLat: 47.2,
          originLon: 9.1,
          cellSizeLatDeg: 0.001,
          cellSizeLonDeg: 0.001,
          rows: 2,
          cols: 2,
          depthsMeters: [1.0, 2.0, 3.0, 4.0],
          sourceId: 'swissbathy3d',
          resolutionMeters: 2,
          fetchedAt: DateTime.utc(2026, 1, 1),
        );
        await repo.writeOk(
          '2726_1221',
          grid,
          referenceLevelMeters: 433.58, // e.g. Vierwaldstättersee
        );

        final entry = await repo.read(
          '2726_1221',
          expectedReferenceLevelMeters: 419.00, // e.g. Rotsee, post-fix
        );
        expect(entry, isNull);

        final remaining = await (db.select(
          db.swissBathyTileCache,
        )..where((t) => t.tileKey.equals('2726_1221'))).get();
        expect(remaining, isEmpty);
        expect(await repo.hasCachedAnswer('2726_1221'), isFalse);
      },
    );

    test(
      'a row cached before referenceLevelMeters existed (null) is treated '
      'as a mismatch too when a caller now expects a specific level -- '
      'there is no way to tell whether its baked-in depths are still '
      'correct, so it gets one re-resolution rather than being trusted',
      () async {
        await db
            .into(db.swissBathyTileCache)
            .insert(
              SwissBathyTileCacheCompanion.insert(
                tileKey: '2726_1221',
                status: 'ok',
                gridJson: const Value('{}'),
                fetchedAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );

        final entry = await repo.read(
          '2726_1221',
          expectedReferenceLevelMeters: 419.00,
        );
        expect(entry, isNull);
        expect(await repo.hasCachedAnswer('2726_1221'), isFalse);
      },
    );

    test('passing no expectedReferenceLevelMeters skips the check entirely, '
        'returning the row as-is regardless of what level it was cached '
        'under', () async {
      final grid = BathymetryGrid(
        originLat: 47.2,
        originLon: 9.1,
        cellSizeLatDeg: 0.001,
        cellSizeLonDeg: 0.001,
        rows: 2,
        cols: 2,
        depthsMeters: [1.0, 2.0, 3.0, 4.0],
        sourceId: 'swissbathy3d',
        resolutionMeters: 2,
        fetchedAt: DateTime.utc(2026, 1, 1),
      );
      await repo.writeOk('2726_1221', grid, referenceLevelMeters: 433.58);

      final entry = await repo.read('2726_1221');
      expect(entry, isNotNull);
      expect(entry!.referenceLevelMeters, 433.58);
    });

    test('a matching reference level is returned normally', () async {
      final grid = BathymetryGrid(
        originLat: 47.2,
        originLon: 9.1,
        cellSizeLatDeg: 0.001,
        cellSizeLonDeg: 0.001,
        rows: 2,
        cols: 2,
        depthsMeters: [1.0, 2.0, 3.0, 4.0],
        sourceId: 'swissbathy3d',
        resolutionMeters: 2,
        fetchedAt: DateTime.utc(2026, 1, 1),
      );
      await repo.writeOk('2726_1221', grid, referenceLevelMeters: 419.00);

      final entry = await repo.read(
        '2726_1221',
        expectedReferenceLevelMeters: 419.00,
      );
      expect(entry, isNotNull);
      expect(entry!.grid.depthAt(0, 0), 1.0);
    });
  });

  group('SwissBathyTileCacheRepository.deleteIfLevelUnknown', () {
    test('an uncached tile key is a no-op, returns false', () async {
      final deleted = await repo.deleteIfLevelUnknown('2726_1221', [419.00]);
      expect(deleted, isFalse);
    });

    test('a row whose stored level matches one of the current levels is left '
        'untouched, returns false', () async {
      await repo.writeEmpty('2726_1221', referenceLevelMeters: 419.00);

      final deleted = await repo.deleteIfLevelUnknown('2726_1221', [
        433.58,
        419.00,
      ]);

      expect(deleted, isFalse);
      expect(await repo.hasCachedAnswer('2726_1221'), isTrue);
    });

    test('a row whose stored level matches none of the current levels is '
        'deleted, returns true (the fallback-cached-tile edge case: the '
        "tile's own center resolves to no lake, so there is no single "
        'expected level to check against)', () async {
      await repo.writeEmpty('2726_1221', referenceLevelMeters: 419.00);

      final deleted = await repo.deleteIfLevelUnknown('2726_1221', [
        433.58,
        405.92,
      ]);

      expect(deleted, isTrue);
      expect(await repo.hasCachedAnswer('2726_1221'), isFalse);
    });

    test('a row with no stored level at all (pre-v17) is treated as unknown '
        'and deleted, even against an empty currentLevels list', () async {
      await db
          .into(db.swissBathyTileCache)
          .insert(
            SwissBathyTileCacheCompanion.insert(
              tileKey: '2726_1221',
              status: 'empty',
              fetchedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );

      final deleted = await repo.deleteIfLevelUnknown(
        '2726_1221',
        const <double>[],
      );

      expect(deleted, isTrue);
      expect(await repo.hasCachedAnswer('2726_1221'), isFalse);
    });

    test(
      'also deletes a matching-status "ok" row under an unknown level',
      () async {
        final grid = BathymetryGrid(
          originLat: 47.2,
          originLon: 9.1,
          cellSizeLatDeg: 0.001,
          cellSizeLonDeg: 0.001,
          rows: 2,
          cols: 2,
          depthsMeters: [1.0, 2.0, 3.0, 4.0],
          sourceId: 'swissbathy3d',
          resolutionMeters: 2,
          fetchedAt: DateTime.utc(2026, 1, 1),
        );
        await repo.writeOk('2726_1221', grid, referenceLevelMeters: 419.00);

        final deleted = await repo.deleteIfLevelUnknown('2726_1221', [433.58]);

        expect(deleted, isTrue);
        expect(await repo.hasCachedAnswer('2726_1221'), isFalse);
      },
    );
  });
}
