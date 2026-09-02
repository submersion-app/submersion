import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/core/database/database.dart';

import '../../helpers/legacy_profile_fixtures.dart';

/// The pre-series shape stamped at v180 so only the 182 rung runs, from
/// the shared fixtures ([legacyDdlAt180]). The FK parents exist because
/// the series tables reference them and foreign keys are on once the
/// database opens.
NativeDatabase dbAt180({void Function(sqlite3.Database rawDb)? seed}) {
  return NativeDatabase.memory(
    setup: (rawDb) {
      legacyDdlAt180(rawDb);
      seed?.call(rawDb);
    },
  );
}

Future<Set<String>> tableNames(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<Set<String>> indexNames(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<Set<String>> columnsOf(AppDatabase db, String table) async {
  final cols = await db.customSelect("PRAGMA table_info('$table')").get();
  return cols.map((c) => c.read<String>('name')).toSet();
}

const profileSeriesColumns = {
  'id',
  'dive_id',
  'computer_id',
  'source_id',
  'is_primary',
  'sample_count',
  'start_timestamp',
  'end_timestamp',
  'max_depth',
  'first_depth',
  'last_depth',
  'has_deco_type',
  'has_deco_stop',
  'has_positive_ceiling',
  'codec_version',
  'samples',
  'created_at',
  'updated_at',
  'hlc',
};

const tankSeriesColumns = {
  'id',
  'dive_id',
  'tank_id',
  'computer_id',
  'sample_count',
  'start_timestamp',
  'end_timestamp',
  'codec_version',
  'samples',
  'created_at',
  'updated_at',
  'hlc',
};

void main() {
  group('schema', () {
    test(
      'v182 creates both series tables and their indexes on upgrade',
      () async {
        final db = AppDatabase(dbAt180());
        addTearDown(db.close);

        final tables = await tableNames(db);
        expect(
          tables,
          containsAll(['dive_profile_series', 'tank_pressure_series']),
        );
        expect(
          await columnsOf(db, 'dive_profile_series'),
          profileSeriesColumns,
        );
        expect(await columnsOf(db, 'tank_pressure_series'), tankSeriesColumns);
        final indexes = await indexNames(db);
        expect(
          indexes,
          containsAll([
            'idx_dive_profile_series_dive_primary',
            'idx_tank_pressure_series_dive_tank',
          ]),
        );
        // The v183 rung in the same ladder run drops the legacy tables once
        // the pack above has moved every sample into the series.
        expect(
          tables.intersection({'dive_profiles', 'tank_pressure_profiles'}),
          isEmpty,
        );
      },
    );

    test('a fresh database has the tables with the same columns', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();

      expect(await columnsOf(db, 'dive_profile_series'), profileSeriesColumns);
      expect(await columnsOf(db, 'tank_pressure_series'), tankSeriesColumns);
      // The Drift declaration and the raw DDL must agree, or a fresh install
      // and an upgraded one would diverge.
      final driftProfile = db.diveProfileSeries.$columns
          .map((c) => c.$name)
          .toSet();
      final driftTank = db.tankPressureSeries.$columns
          .map((c) => c.$name)
          .toSet();
      expect(driftProfile, profileSeriesColumns);
      expect(driftTank, tankSeriesColumns);
    });

    test(
      'the backstop is idempotent across a second open of one database',
      () async {
        // Two Drift executors over one SQLite handle: the first open runs the
        // ladder, the second runs only beforeOpen, so the backstop's IF NOT
        // EXISTS DDL genuinely executes a second time. A second query on the
        // same executor would never re-enter beforeOpen.
        final raw = sqlite3.sqlite3.openInMemory();
        addTearDown(raw.close);
        legacyDdlAt180(raw);

        final first = AppDatabase(
          NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
        );
        await first.customSelect('SELECT 1').get();
        await first.close();

        final second = AppDatabase(
          NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
        );
        addTearDown(second.close);
        await expectLater(second.customSelect('SELECT 1').get(), completes);
        expect(
          await tableNames(second),
          containsAll(['dive_profile_series', 'tank_pressure_series']),
        );
        final version = await second
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.data.values.first, 183);
      },
    );

    test('v182 is present in the migration ladder', () {
      expect(AppDatabase.migrationVersions, contains(182));
      expect(AppDatabase.minimumCompatibleSchemaVersion, 183);
    });
  });

  group('packing on upgrade', () {
    void seed(sqlite3.Database rawDb) {
      rawDb.execute("INSERT INTO dives (id) VALUES ('d1')");
      rawDb.execute("INSERT INTO dive_computers (id) VALUES ('c1')");
      rawDb.execute(
        "INSERT INTO dive_data_sources (id, dive_id, computer_id, "
        "imported_at, created_at) VALUES ('s1', 'd1', 'c1', 0, 0)",
      );
      rawDb.execute("INSERT INTO dive_tanks (id, dive_id) VALUES ('t1', 'd1')");
      rawDb.execute(
        "INSERT INTO dive_profiles (id, dive_id, computer_id, source_id, "
        "is_primary, timestamp, depth) VALUES "
        "('p1', 'd1', 'c1', 's1', 1, 0, 0.0), "
        "('p2', 'd1', 'c1', 's1', 1, 10, 15.0), "
        "('p3', 'd1', 'c1', 's1', 1, 10, 15.0)",
      );
      rawDb.execute(
        "INSERT INTO tank_pressure_profiles (id, dive_id, tank_id, timestamp, "
        "pressure, computer_id) VALUES ('q1', 'd1', 't1', 0, 200.0, 'c1')",
      );
    }

    test('upgrading from 180 packs the legacy rows', () async {
      final db = AppDatabase(dbAt180(seed: seed));
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();

      final series = await db
          .customSelect('SELECT * FROM dive_profile_series')
          .get();
      expect(series, hasLength(1));
      expect(series.single.read<int>('sample_count'), 2);
      expect(series.single.read<double>('max_depth'), 15.0);
      final tanks = await db
          .customSelect('SELECT * FROM tank_pressure_series')
          .get();
      expect(tanks, hasLength(1));
      expect(tanks.single.read<String>('tank_id'), 't1');
      // The v183 rung drops the legacy tables after the pack.
      final legacy = await db
          .customSelect(
            "SELECT COUNT(*) AS n FROM sqlite_master "
            "WHERE name = 'dive_profiles'",
          )
          .getSingle();
      expect(legacy.read<int>('n'), 0);
    });

    test(
      'two devices upgrading the same rows converge on the same ids',
      () async {
        Future<List<String>> idsAfterUpgrade() async {
          final db = AppDatabase(dbAt180(seed: seed));
          addTearDown(db.close);
          await db.customSelect('SELECT 1').get();
          final a = await db
              .customSelect('SELECT id FROM dive_profile_series ORDER BY id')
              .get();
          final b = await db
              .customSelect('SELECT id FROM tank_pressure_series ORDER BY id')
              .get();
          return [
            for (final r in [...a, ...b]) r.read<String>('id'),
          ];
        }

        expect(await idsAfterUpgrade(), await idsAfterUpgrade());
      },
    );

    // The backstop's late-pack case moved to
    // migration_v183_drop_legacy_tables_test.dart: v183 drops the legacy
    // tables inside the same ladder run, so no legacy row can arrive after
    // the rung any more. What the backstop still guarantees (a device that
    // reached 182 on a parallel branch packs before the drop) is covered
    // there.
  });
}
