import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';

/// beforeOpen data self-heal: dives that have a primary profile series but no
/// dive_data_sources row (older file imports) get a synthesized primary source
/// so the grouped-by-source view (3D/spatial/compare) stops spinning.
///
/// Seeds `dive_profile_series`, not the retired `dive_profiles`: v183 dropped
/// that table and the helper reads the series now.
void main() {
  // Minimal pre-seeded schema at currentSchemaVersion: only the three tables
  // the backfill touches. beforeOpen's other backstops self-guard on missing
  // tables, and ensurePerformanceIndexes swallows index DDL errors, so a
  // partial schema is safe (same technique as the v105 heading test).
  NativeDatabase seeded(void Function(dynamic rawDb) rows) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute(
          'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
        );
        rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
        // The v183 shape, minus the foreign keys the other parent tables
        // would need: this fixture carries no dive_computers or dive_tanks.
        rawDb.execute('''
          CREATE TABLE dive_profile_series (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            computer_id TEXT,
            source_id TEXT,
            is_primary INTEGER NOT NULL DEFAULT 1,
            sample_count INTEGER NOT NULL,
            start_timestamp INTEGER NOT NULL,
            end_timestamp INTEGER NOT NULL,
            max_depth REAL NOT NULL,
            first_depth REAL NOT NULL,
            last_depth REAL NOT NULL,
            has_deco_type INTEGER NOT NULL DEFAULT 0,
            has_deco_stop INTEGER NOT NULL DEFAULT 0,
            has_positive_ceiling INTEGER NOT NULL DEFAULT 0,
            codec_version INTEGER NOT NULL,
            samples BLOB NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT
          )
        ''');
        rawDb.execute('''
          CREATE TABLE dive_data_sources (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            is_primary INTEGER NOT NULL DEFAULT 0,
            imported_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        rows(rawDb);
      },
    );
  }

  /// One real packed series for [diveId], blob and summary built by the
  /// production codec so the row is indistinguishable from a written one.
  void insertSeries(
    dynamic rawDb,
    String id,
    String diveId, {
    bool isPrimary = true,
  }) {
    final encoded = const ProfileSeriesCodec().encode(const [
      ProfileSample(timestamp: 0, depth: 5.0),
      ProfileSample(timestamp: 10, depth: 8.0),
    ]);
    final s = encoded.summary;
    rawDb.execute(
      'INSERT INTO dive_profile_series (id, dive_id, is_primary, '
      'sample_count, start_timestamp, end_timestamp, max_depth, first_depth, '
      'last_depth, codec_version, samples, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        diveId,
        isPrimary ? 1 : 0,
        s.sampleCount,
        s.startTimestamp,
        s.endTimestamp,
        s.maxDepth,
        s.firstDepth,
        s.lastDepth,
        encoded.codecVersion,
        encoded.bytes,
        1,
        1,
      ],
    );
  }

  test(
    'heals a dive that has a primary profile series but no data source',
    () async {
      final db = AppDatabase(
        seeded((rawDb) {
          rawDb.execute("INSERT INTO dives (id) VALUES ('orphan')");
          insertSeries(rawDb, 'ps1', 'orphan');
        }),
      );
      addTearDown(() => db.close());

      final rows = await db
          .customSelect(
            "SELECT id, is_primary, imported_at FROM dive_data_sources "
            "WHERE dive_id = 'orphan'",
          )
          .get();

      expect(rows, hasLength(1));
      expect(rows.single.data['id'], 'legacy-src-orphan');
      expect(rows.single.data['is_primary'], 1);
      // imported_at is a Drift dateTime() column: unix SECONDS, not millis.
      final importedAt = rows.single.data['imported_at'] as int;
      expect(importedAt, greaterThan(1000000000)); // > 2001
      expect(
        importedAt,
        lessThan(100000000000),
      ); // < year 5138 (i.e. not millis)
    },
  );

  test('leaves a dive that already has a data source untouched', () async {
    final db = AppDatabase(
      seeded((rawDb) {
        rawDb.execute("INSERT INTO dives (id) VALUES ('sourced')");
        insertSeries(rawDb, 'ps1', 'sourced');
        rawDb.execute(
          "INSERT INTO dive_data_sources "
          "(id, dive_id, is_primary, imported_at, created_at) "
          "VALUES ('real-src', 'sourced', 1, 111, 111)",
        );
      }),
    );
    addTearDown(() => db.close());

    final rows = await db
        .customSelect(
          "SELECT id FROM dive_data_sources WHERE dive_id = 'sourced'",
        )
        .get();

    expect(rows.map((r) => r.data['id']), ['real-src']);
  });

  test('a dive_profile_series missing the columns the heal reads opens '
      'without throwing', () async {
    // A parallel branch's differently-shaped series table (or a hand-built
    // fixture): beforeOpen's IF NOT EXISTS DDL leaves it alone, so the
    // helper's table check alone would let the EXISTS predicate name a
    // column that is not there and abort the open.
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute(
            'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
          );
          rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
          rawDb.execute('''
            CREATE TABLE dive_profile_series (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL,
              computer_id TEXT
            )
          ''');
          rawDb.execute('''
            CREATE TABLE dive_data_sources (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL,
              is_primary INTEGER NOT NULL DEFAULT 0,
              imported_at INTEGER NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          rawDb.execute("INSERT INTO dives (id) VALUES ('orphan')");
        },
      ),
    );
    addTearDown(() => db.close());

    await expectLater(db.customSelect('SELECT 1').get(), completes);
    final rows = await db
        .customSelect('SELECT id FROM dive_data_sources')
        .get();
    expect(rows, isEmpty);
  });

  test('does not heal a dive whose only series is non-primary', () async {
    final db = AppDatabase(
      seeded((rawDb) {
        rawDb.execute("INSERT INTO dives (id) VALUES ('demoted')");
        insertSeries(rawDb, 'ps1', 'demoted', isPrimary: false);
      }),
    );
    addTearDown(() => db.close());

    final rows = await db
        .customSelect(
          "SELECT id FROM dive_data_sources WHERE dive_id = 'demoted'",
        )
        .get();

    expect(rows, isEmpty);
  });
}
