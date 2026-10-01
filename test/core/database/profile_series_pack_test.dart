import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/profile_series_pack.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series_identity.dart';

import '../../helpers/legacy_profile_fixtures.dart';

Future<List<Map<String, Object?>>> rows(AppDatabase db, String sql) async {
  final result = await db.customSelect(sql).get();
  return result.map((r) => r.data).toList();
}

void main() {
  const codec = ProfileSeriesCodec();
  const tankCodec = TankPressureSeriesCodec();

  /// A database already at v182 whose legacy tables are empty at open, plus
  /// the raw handle that recreates and seeds them afterwards.
  ///
  /// Seeding after the open is load bearing for two reasons: the beforeOpen
  /// backstop packs every unpacked dive, so rows seeded before the open
  /// would already be packed and each test's explicit [packLegacyProfileRows]
  /// call would have nothing left to report; and the same open runs the v183
  /// rung, which drops the two (still empty) legacy tables once it finds
  /// nothing left to pack, so this recreates them on the open connection
  /// rather than relying on the ladder to keep them around.
  Future<({AppDatabase db, sqlite3.Database raw})> openLegacy() async {
    final raw = sqlite3.sqlite3.openInMemory();
    addTearDown(raw.close);
    legacyDdlAt180(raw, userVersion: 182);
    final db = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    createLegacyProfileTables(raw);
    return (db: db, raw: raw);
  }

  Future<AppDatabase> seededLegacy() async {
    final open = await openLegacy();
    seedParents(open.raw);
    seedProfiles(open.raw);
    seedPressures(open.raw);
    return open.db;
  }

  test('packs each identity group into one series with derived ids', () async {
    final db = await seededLegacy();

    final report = await packLegacyProfileRows(db, nowMs: 1700000000000);
    expect(report.profileSeries, 4);
    expect(report.tankSeries, 2);
    expect(report.droppedSamples, 2, reason: 'p3 and q2 are exact duplicates');
    expect(report.skippedOrphans, 0);

    final series = await rows(
      db,
      'SELECT * FROM dive_profile_series ORDER BY dive_id, computer_id, '
      'source_id, is_primary',
    );
    expect(series, hasLength(4));

    final c1 = series.singleWhere(
      (r) => r['computer_id'] == 'c1' && r['dive_id'] == 'd1',
    );
    expect(
      c1['id'],
      profileSeriesMigratedId(
        diveId: 'd1',
        computerId: 'c1',
        sourceId: 's1',
        isPrimary: true,
      ),
    );
    expect(c1['is_primary'], 1);
    expect(c1['sample_count'], 4);
    expect(c1['start_timestamp'], 0);
    expect(c1['end_timestamp'], 20);
    expect(c1['max_depth'], 18.0);
    expect(c1['first_depth'], 0.0);
    expect(c1['last_depth'], 18.0);
    expect(c1['has_deco_type'], 1);
    expect(c1['has_deco_stop'], 1);
    expect(c1['has_positive_ceiling'], 1);
    expect(c1['codec_version'], 1);
    expect(c1['created_at'], 1700000000000);
    expect(c1['updated_at'], 1700000000000);
    final decoded = codec.decode(c1['samples'] as dynamic);
    expect(decoded, [
      const ProfileSample(
        timestamp: 0,
        depth: 0.0,
        temperature: 20.0,
        ndl: 3000,
      ),
      const ProfileSample(
        timestamp: 10,
        depth: 12.5,
        temperature: 19.5,
        ndl: 2900,
      ),
      const ProfileSample(
        timestamp: 10,
        depth: 12.7,
        temperature: 19.5,
        ndl: 2900,
      ),
      const ProfileSample(
        timestamp: 20,
        depth: 18.0,
        ceiling: 3.0,
        decoType: 2,
      ),
    ]);

    final edit = series.singleWhere(
      (r) => r['computer_id'] == null && r['dive_id'] == 'd1',
    );
    expect(edit['source_id'], 's1');
    expect(edit['is_primary'], 1);
    expect(
      codec.decode(edit['samples'] as dynamic).map((s) => s.heartRateSource),
      ['appleWatch', 'appleWatch'],
    );

    final legacy = series.singleWhere((r) => r['dive_id'] == 'd2');
    expect(legacy['computer_id'], isNull);
    expect(legacy['source_id'], isNull);
    expect(
      legacy['id'],
      profileSeriesMigratedId(
        diveId: 'd2',
        computerId: null,
        sourceId: null,
        isPrimary: true,
      ),
    );

    final tanks = await rows(
      db,
      'SELECT * FROM tank_pressure_series ORDER BY tank_id',
    );
    expect(tanks, hasLength(2));
    expect(
      tanks[0]['id'],
      tankPressureSeriesMigratedId(
        diveId: 'd1',
        tankId: 't1',
        computerId: 'c1',
      ),
    );
    expect(tanks[0]['sample_count'], 2);
    expect(tankCodec.decode(tanks[0]['samples'] as dynamic), [
      const TankPressureSample(timestamp: 0, pressure: 200.0),
      const TankPressureSample(timestamp: 60, pressure: 190.0),
    ]);
    expect(tanks[1]['computer_id'], isNull);
  });

  test('packing notifies subscribers of the series tables it wrote', () async {
    final db = await seededLegacy();
    final profileUpdates = db.tableUpdates(
      TableUpdateQuery.onTable(db.diveProfileSeries),
    );
    final tankUpdates = db.tableUpdates(
      TableUpdateQuery.onTable(db.tankPressureSeries),
    );

    final profileEvent = expectLater(profileUpdates, emits(anything));
    final tankEvent = expectLater(tankUpdates, emits(anything));
    await packLegacyProfileRows(db, nowMs: 1);

    await profileEvent;
    await tankEvent;
  });

  test('re-running the packer inserts nothing new', () async {
    final db = await seededLegacy();

    await packLegacyProfileRows(db, nowMs: 1);
    final again = await packLegacyProfileRows(db, nowMs: 2);
    expect(again.profileSeries, 0);
    expect(again.tankSeries, 0);
    final count = await db
        .customSelect('SELECT COUNT(*) AS n FROM dive_profile_series')
        .getSingle();
    expect(count.read<int>('n'), 4);
  });

  test(
    'an already packed dive is left alone when a legacy row arrives later',
    () async {
      // The self-heal is per dive, not per group: once a dive holds any
      // series row the packer never revisits it, which is what keeps the
      // beforeOpen backstop cheap on a packed database.
      final open = await openLegacy();
      seedParents(open.raw);
      seedProfiles(open.raw);
      await packLegacyProfileRows(open.db, nowMs: 1);

      open.raw.execute(
        'INSERT INTO dive_profiles (id, dive_id, computer_id, source_id, '
        "is_primary, timestamp, depth) VALUES ('p99', 'd1', 'c2', NULL, 0, "
        '0, 1.0)',
      );
      final again = await packLegacyProfileRows(open.db, nowMs: 2);
      expect(again.profileSeries, 0);
    },
  );

  test(
    'two independently packed copies produce identical series ids',
    () async {
      Future<Set<String>> idsOf() async {
        final db = await seededLegacy();
        await packLegacyProfileRows(db, nowMs: 5);
        final a = await rows(db, 'SELECT id FROM dive_profile_series');
        final b = await rows(db, 'SELECT id FROM tank_pressure_series');
        return {
          for (final r in [...a, ...b]) r['id'] as String,
        };
      }

      expect(await idsOf(), await idsOf());
    },
  );

  /// Packs a seeded fixture whose `sync_metadata` carries [persisted] as the
  /// device's last clock value, and returns the hlc the series rows got. A
  /// fixture stamped at 182 never runs onCreate, so the table a synced
  /// device would have is created here.
  Future<String?> hlcAfterPack(String? persisted) async {
    final open = await openLegacy();
    seedParents(open.raw);
    seedProfiles(open.raw);
    open.raw.execute(
      'CREATE TABLE sync_metadata (id TEXT NOT NULL PRIMARY KEY, '
      'device_id TEXT NOT NULL, hlc TEXT, created_at INTEGER NOT NULL, '
      'updated_at INTEGER NOT NULL)',
    );
    open.raw.execute(
      'INSERT INTO sync_metadata (id, device_id, hlc, created_at, '
      "updated_at) VALUES ('global', 'dev-1', ?, 0, 0)",
      [persisted],
    );
    await packLegacyProfileRows(open.db, nowMs: 1700000000000);
    final row = await open.db
        .customSelect('SELECT hlc FROM dive_profile_series LIMIT 1')
        .getSingle();
    return row.readNullable<String>('hlc');
  }

  test(
    'stamps the migration hlc from the device id in sync_metadata',
    () async {
      expect(
        await hlcAfterPack(null),
        const Hlc(1700000000000, 0, 'dev-1').toString(),
      );
    },
  );

  test('advances the persisted clock instead of minting from now', () async {
    // SyncClock.receive can push this device's clock past wall-clock time,
    // and a stamp below the publish watermark would never ride a changeset.
    expect(
      await hlcAfterPack('000001800000000000:000005:dev-1'),
      const Hlc(1800000000000, 6, 'dev-1').toString(),
    );
  });

  test(
    'falls back to a fresh clock when the persisted value is junk',
    () async {
      expect(
        await hlcAfterPack('garbage'),
        const Hlc(1700000000000, 0, 'dev-1').toString(),
      );
    },
  );

  test('leaves hlc null when the device has never synced', () async {
    final open = await openLegacy();
    seedParents(open.raw);
    seedProfiles(open.raw);

    await packLegacyProfileRows(open.db, nowMs: 1);
    final row = await open.db
        .customSelect('SELECT hlc FROM dive_profile_series LIMIT 1')
        .getSingle();
    expect(row.readNullable<String>('hlc'), isNull);
  });

  test(
    'skippedAlreadyPacked counts a late legacy row for a packed dive',
    () async {
      final open = await openLegacy();
      seedParents(open.raw);
      seedProfiles(open.raw);
      seedPressures(open.raw);

      // First pass packs everything.
      final first = await packLegacyProfileRows(open.db, nowMs: 1700000000000);
      expect(first.profileSeries, 4);
      expect(first.skippedAlreadyPacked, 0);

      // A row that arrives after the dive already has its series: an older
      // peer republishing, or a retried ladder. It must not be packed, and the
      // report has to say so rather than looking like an empty no-op.
      open.raw.execute(
        'INSERT INTO dive_profiles (id, dive_id, computer_id, source_id, '
        'is_primary, timestamp, depth) VALUES '
        "('p-late', 'd1', NULL, NULL, 1, 40, 3.0)",
      );
      final second = await packLegacyProfileRows(open.db, nowMs: 1700000000001);
      expect(second.profileSeries, 0);
      // d1 and d2 both carry legacy profile rows and both already have series,
      // and d1's pressure rows are packed too.
      expect(second.skippedAlreadyPacked, 3);
      expect(
        (await rows(
          open.db,
          'SELECT SUM(sample_count) AS n FROM dive_profile_series',
        )).single['n'],
        10,
      );
    },
  );

  test('no-ops when the legacy tables are absent', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA user_version = 182'),
      ),
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    final report = await packLegacyProfileRows(db, nowMs: 1);
    expect(report.profileSeries, 0);
    expect(report.tankSeries, 0);
    expect(report.droppedSamples, 0);
    expect(report.skippedOrphans, 0);
  });

  test('skippedRows counts legacy rows without a timestamp or depth', () async {
    final open = await openLegacy();
    seedParents(open.raw);
    // Loosen the columns the fixture declares NOT NULL by rebuilding the
    // table (already recreated by openLegacy) without those constraints.
    open.raw.execute('DROP TABLE dive_profiles');
    open.raw.execute('''
      CREATE TABLE dive_profiles (
        id TEXT NOT NULL PRIMARY KEY,
        dive_id TEXT NOT NULL,
        computer_id TEXT,
        source_id TEXT,
        is_primary INTEGER NOT NULL DEFAULT 1,
        timestamp INTEGER,
        depth REAL
      )
    ''');
    open.raw.execute(
      "INSERT INTO dive_profiles (id, dive_id, timestamp, depth) VALUES "
      "('p1', 'd1', 0, 1.0), ('p2', 'd1', NULL, 2.0), ('p3', 'd1', 10, 3.0)",
    );
    final report = await packLegacyProfileRows(open.db, nowMs: 1);
    expect(report.profileSeries, 1);
    expect(report.skippedRows, 1);
  });

  test('skippedRows counts a legacy tank row without a tank id, timestamp, or '
      'pressure', () async {
    final open = await openLegacy();
    seedParents(open.raw);
    // Loosen the columns the fixture declares NOT NULL by rebuilding the
    // table (already recreated by openLegacy) without those constraints,
    // mirroring the profile-side test above.
    open.raw.execute('DROP TABLE tank_pressure_profiles');
    open.raw.execute('''
        CREATE TABLE tank_pressure_profiles (
          id TEXT NOT NULL PRIMARY KEY,
          dive_id TEXT NOT NULL,
          tank_id TEXT,
          timestamp INTEGER,
          pressure REAL,
          computer_id TEXT
        )
      ''');
    open.raw.execute(
      'INSERT INTO tank_pressure_profiles (id, dive_id, tank_id, '
      "timestamp, pressure) VALUES ('q1', 'd1', 't1', 0, 200.0), "
      "('q2', 'd1', 't1', NULL, 190.0), ('q3', 'd1', NULL, 30, 185.0), "
      "('q4', 'd1', 't1', 60, NULL), ('q5', 'd1', 't1', 90, 180.0)",
    );
    final report = await packLegacyProfileRows(open.db, nowMs: 1);
    expect(report.tankSeries, 1);
    expect(report.skippedRows, 3);

    final tanks = await rows(open.db, 'SELECT * FROM tank_pressure_series');
    expect(tanks, hasLength(1));
    expect(tankCodec.decode(tanks.single['samples'] as dynamic), [
      const TankPressureSample(timestamp: 0, pressure: 200.0),
      const TankPressureSample(timestamp: 90, pressure: 180.0),
    ]);
  });

  test(
    'the migration hlc carries the device id, not the persisted node id',
    () async {
      // legacyFixture no longer accepts a seed callback: build the database
      // the way hlcAfterPack (above) does, seeding after the open so the
      // beforeOpen backstop finds nothing to pack.
      final open = await openLegacy();
      seedParents(open.raw);
      seedProfiles(open.raw);
      open.raw.execute(
        'CREATE TABLE sync_metadata (id TEXT NOT NULL PRIMARY KEY, '
        'device_id TEXT NOT NULL, hlc TEXT, created_at INTEGER NOT NULL, '
        'updated_at INTEGER NOT NULL)',
      );
      open.raw.execute(
        'INSERT INTO sync_metadata (id, device_id, hlc, created_at, '
        "updated_at) VALUES ('global', 'dev-1', "
        "'000001800000000000:000005:other', 0, 0)",
      );
      await packLegacyProfileRows(open.db, nowMs: 1700000000000);
      final row = await open.db
          .customSelect('SELECT hlc FROM dive_profile_series LIMIT 1')
          .getSingle();
      expect(
        row.read<String>('hlc'),
        const Hlc(1800000000000, 6, 'dev-1').toString(),
      );
    },
  );
}
