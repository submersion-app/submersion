import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// v148 (site media attachments, issues #211/#627): adds the `media(site_id)`
/// query index, collapses any pre-existing duplicate (platform_asset_id,
/// site_id) pairs keeping the oldest row, and adds the partial unique index
/// that prevents the same gallery asset being linked to one site twice --
/// the site-side mirror of the dive-side v38 pair.
void main() {
  // Stamped at 147 so ONLY the v148 step runs, isolating what is asserted.
  NativeDatabase setupDb(
    void Function(dynamic rawDb) seed, {
    bool withSiteId = true,
  }) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 147');
        rawDb.execute('''
          CREATE TABLE media (
            id TEXT NOT NULL PRIMARY KEY,
            platform_asset_id TEXT,
            dive_id TEXT,
            ${withSiteId ? 'site_id TEXT,' : ''}
            created_at INTEGER NOT NULL
          )
        ''');
        seed(rawDb);
      },
    );
  }

  void insertMedia(
    dynamic rawDb,
    String id, {
    String? assetId,
    String? siteId,
    required int createdAt,
  }) {
    rawDb.execute(
      'INSERT INTO media (id, platform_asset_id, site_id, created_at) '
      'VALUES (?, ?, ?, ?)',
      [id, assetId, siteId, createdAt],
    );
  }

  Future<Set<String>> indexNames(AppDatabase db) async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  Future<List<String>> mediaIds(AppDatabase db) async {
    final rows = await db
        .customSelect('SELECT id FROM media ORDER BY id')
        .get();
    return rows.map((r) => r.read<String>('id')).toList();
  }

  test('creates the site query index and the site dedupe index', () async {
    final db = AppDatabase(setupDb((_) {}));
    addTearDown(db.close);

    final names = await indexNames(db);
    expect(names, contains('idx_media_site_id'));
    expect(names, contains('idx_media_asset_site_unique'));
  });

  test(
    'collapses duplicate asset/site pairs, keeping the oldest row',
    () async {
      final db = AppDatabase(
        setupDb((rawDb) {
          // Same gallery asset linked to the same site three times.
          insertMedia(
            rawDb,
            'oldest',
            assetId: 'a1',
            siteId: 's1',
            createdAt: 10,
          );
          insertMedia(
            rawDb,
            'middle',
            assetId: 'a1',
            siteId: 's1',
            createdAt: 20,
          );
          insertMedia(
            rawDb,
            'newest',
            assetId: 'a1',
            siteId: 's1',
            createdAt: 30,
          );
        }),
      );
      addTearDown(db.close);

      expect(await mediaIds(db), ['oldest']);
    },
  );

  test('collapses duplicates that share the oldest created_at', () async {
    // created_at is epoch MILLISECONDS, and a bulk import loop writes many
    // rows inside one millisecond, so ties at the minimum are reachable --
    // notably after a site merge repoints two rows onto the survivor site.
    // A tie-blind cleanup leaves both rows behind and the unique index
    // below then fails, which aborts the whole migration and leaves the
    // database unopenable.
    final db = AppDatabase(
      setupDb((rawDb) {
        insertMedia(rawDb, 'tie-a', assetId: 'a1', siteId: 's1', createdAt: 10);
        insertMedia(rawDb, 'tie-b', assetId: 'a1', siteId: 's1', createdAt: 10);
        insertMedia(rawDb, 'later', assetId: 'a1', siteId: 's1', createdAt: 30);
      }),
    );
    addTearDown(db.close);

    // Exactly one survivor, and it is one of the oldest pair.
    final survivors = await mediaIds(db);
    expect(survivors, hasLength(1));
    expect(survivors.single, anyOf('tie-a', 'tie-b'));
    // The unique index must exist, i.e. its creation was not aborted.
    expect(await indexNames(db), contains('idx_media_asset_site_unique'));
  });

  test('leaves rows alone when either half of the pair is null', () async {
    final db = AppDatabase(
      setupDb((rawDb) {
        // Same asset, no site: two library rows that must both survive.
        insertMedia(rawDb, 'lib-1', assetId: 'a1', createdAt: 10);
        insertMedia(rawDb, 'lib-2', assetId: 'a1', createdAt: 20);
        // Same site, no asset: two desktop/local rows that must both survive.
        insertMedia(rawDb, 'local-1', siteId: 's1', createdAt: 10);
        insertMedia(rawDb, 'local-2', siteId: 's1', createdAt: 20);
        // Same asset on two DIFFERENT sites is not a duplicate.
        insertMedia(rawDb, 'x-1', assetId: 'a2', siteId: 's1', createdAt: 10);
        insertMedia(rawDb, 'x-2', assetId: 'a2', siteId: 's2', createdAt: 20);
      }),
    );
    addTearDown(db.close);

    expect(await mediaIds(db), [
      'lib-1',
      'lib-2',
      'local-1',
      'local-2',
      'x-1',
      'x-2',
    ]);
  });

  test(
    'the unique index rejects a duplicate link created afterwards',
    () async {
      final db = AppDatabase(
        setupDb((rawDb) {
          insertMedia(
            rawDb,
            'first',
            assetId: 'a1',
            siteId: 's1',
            createdAt: 10,
          );
        }),
      );
      addTearDown(db.close);

      await expectLater(
        db.customStatement(
          'INSERT INTO media (id, platform_asset_id, site_id, created_at) '
          "VALUES ('dup', 'a1', 's1', 40)",
        ),
        throwsA(isA<Exception>()),
      );

      // The same asset on a different site is still allowed.
      await db.customStatement(
        'INSERT INTO media (id, platform_asset_id, site_id, created_at) '
        "VALUES ('other-site', 'a1', 's2', 40)",
      );
      expect(await mediaIds(db), ['first', 'other-site']);
    },
  );

  test('no-ops on a media table that predates the site_id column', () async {
    // Migration-test fixtures build only the columns their own step needs,
    // so the v148 step is guarded on site_id existing rather than assuming
    // a complete media table.
    final db = AppDatabase(
      setupDb((rawDb) {
        rawDb.execute(
          'INSERT INTO media (id, platform_asset_id, created_at) '
          "VALUES ('m1', 'a1', 10)",
        );
      }, withSiteId: false),
    );
    addTearDown(db.close);

    // Opening must not throw, and neither site index can exist.
    expect(await mediaIds(db), ['m1']);
    final names = await indexNames(db);
    expect(names, isNot(contains('idx_media_site_id')));
    expect(names, isNot(contains('idx_media_asset_site_unique')));
  });
}
