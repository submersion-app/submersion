import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

const _preV195MediaSpecies = '''
  CREATE TABLE media_species (
    id TEXT NOT NULL PRIMARY KEY,
    media_id TEXT NOT NULL,
    species_id TEXT NOT NULL,
    sighting_id TEXT,
    bbox_x REAL,
    bbox_y REAL,
    bbox_width REAL,
    bbox_height REAL,
    notes TEXT,
    created_at INTEGER NOT NULL
  )
''';

/// v195 gives `media_species` its own Hybrid Logical Clock (issue #1638).
/// Until then the table rode the parent `media.hlc`, and since tagging a
/// photo never edits the photo, the parent clock never advanced and the tag
/// was invisible to every incremental changeset.
void main() {
  test('v195 is the current schema version and is in the ladder', () {
    // Renumbered from 192: main landed the transmitter-serial rung at 194
    // while this branch was open, 192 and 193 are held by other open
    // branches, and a rung at or below the shipped version never runs its
    // onUpgrade step. This is the newest rung, so it owns the exact
    // assertion; relax it to greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 195);
    expect(AppDatabase.migrationVersions, contains(195));
  });

  test('a fresh database has media_species.hlc', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('media_species')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('hlc'));
  });

  test('the column is nullable, so a pre-v195 row stays readable', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('media_species')")
        .get();
    final hlc = cols.firstWhere((c) => c.read<String>('name') == 'hlc');
    // A NOT NULL column would break the backfill's own precondition: it
    // finds the legacy rows by `hlc IS NULL`.
    expect(hlc.read<int>('notnull'), 0);
  });

  test(
    'a database stranded before v195 gains the column via beforeOpen',
    () async {
      // A database that arrives by restore or sync-adopt never runs onUpgrade,
      // so the backstop is the only thing that adds the column there.
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute(_preV195MediaSpecies);
          rawDb.execute(
            "INSERT INTO media_species (id, media_id, species_id, created_at) "
            "VALUES ('tag-legacy', 'p1', 'c1', 1000)",
          );
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('media_species')")
          .get();
      expect(cols.map((c) => c.read<String>('name')), contains('hlc'));
      final row = await db
          .customSelect("SELECT hlc FROM media_species WHERE id = 'tag-legacy'")
          .getSingle();
      expect(
        row.read<String?>('hlc'),
        isNull,
        reason: 'the rung only adds the column; the backfill stamps the rows',
      );
    },
  );

  test('v195 adds the column on upgrade, preserving tags', () async {
    // A database one version back, so opening it runs onUpgrade rather than
    // onCreate. The rung and the backstop deliberately call the same
    // idempotent helper, so this cannot prove which of the two added the
    // column; what it does pin is that an upgrading database ends up with
    // the column AND keeps the tags it already had.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 194');
        rawDb.execute(_preV195MediaSpecies);
        rawDb.execute(
          'INSERT INTO media_species (id, media_id, species_id, created_at) '
          "VALUES ('tag-1', 'p1', 'c1', 1000)",
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('media_species')")
        .get();
    expect(cols.map((c) => c.read<String>('name')), contains('hlc'));

    // Column-only rung: the tag survives with its links intact and a null
    // clock, which is what backfillMissingHlc then stamps.
    final row = await db
        .customSelect(
          'SELECT media_id, species_id, hlc FROM media_species '
          "WHERE id = 'tag-1'",
        )
        .getSingle();
    expect(row.data['media_id'], 'p1');
    expect(row.data['species_id'], 'c1');
    expect(row.read<String?>('hlc'), isNull);
  });

  test('the assert is a no-op when the table is absent', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('CREATE TABLE unrelated (id TEXT)');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();
  });
}
