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
      await repo.writeOk('2726_1221', grid);

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

    test(
      'a cached negative ("empty") row is left untouched, not deleted',
      () async {
        await repo.writeEmpty('2726_1221');

        final entry = await repo.read('2726_1221');
        expect(entry, isNull);
        expect(await repo.hasCachedAnswer('2726_1221'), isTrue);
      },
    );
  });
}
