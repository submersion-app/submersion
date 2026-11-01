import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/data_quality/data/services/quality_neighbor_sql.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_times_sql.dart';

/// Returns the concatenated EXPLAIN QUERY PLAN detail lines for [sql].
///
/// [params] is how many `?` placeholders [sql] has. The plan does not depend
/// on their values, but a statement with one unbound does not run.
Future<String> plan(AppDatabase db, String sql, {int params = 0}) async {
  final rows = await db
      .customSelect(
        'EXPLAIN QUERY PLAN $sql',
        variables: List.filled(params, const Variable<int>(1)),
      )
      .get();
  return rows.map((r) => r.read<String>('detail')).join('\n');
}

/// Page-1 shape of DiveRepository.getDiveSummaries (default date sort, no
/// cursor, no filters). Keep in sync with dive_repository_impl.dart.
const _summariesPage1Sql =
    "SELECT d.id, COALESCE(d.entry_time, d.dive_date_time) AS sort_timestamp, "
    "s.name AS site_name, t.name AS trip_name "
    "FROM dives d LEFT JOIN dive_sites s ON d.site_id = s.id "
    "LEFT JOIN trips t ON d.trip_id = t.id "
    "WHERE d.diver_id = 'x' "
    "ORDER BY sort_timestamp DESC, COALESCE(d.dive_number, 0) DESC, d.id DESC "
    "LIMIT 50";

/// Filter shape of QualityContextBuilder._neighbors. Keep in sync with
/// quality_context_builder.dart.
const _sameDiverNeighborsSql =
    'SELECT id FROM dives WHERE id != ?1 AND diver_id IS ?2 '
    'AND COALESCE(entry_time, dive_date_time) BETWEEN ?3 AND ?4 '
    'ORDER BY COALESCE(entry_time, dive_date_time) ASC';

/// Filter shape of the shared-gear lookup in QualityContextBuilder. Keep in
/// sync with quality_context_builder.dart.
const _otherDiverNeighborsSql =
    'SELECT id FROM dives '
    'WHERE id != ?1 AND diver_id IS NOT NULL AND diver_id != ?2 '
    'AND COALESCE(entry_time, dive_date_time) BETWEEN ?3 AND ?4';

const _sameDiverSeek =
    'idx_dives_diver_start (diver_id=? AND <expr>>? AND <expr><?)';
const _timeSeek = 'idx_dives_start (<expr>>? AND <expr><?)';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    await db.customSelect('SELECT 1').get(); // open: onCreate + beforeOpen
  });

  tearDown(() => db.close());

  test(
    'per-dive series fetch uses idx_dive_profile_series_dive_primary',
    () async {
      final p = await plan(
        db,
        "SELECT * FROM dive_profile_series WHERE dive_id = 'x' AND is_primary = 1",
      );
      expect(p, contains('idx_dive_profile_series_dive_primary'));
    },
  );

  test('per-tank series fetch uses idx_tank_pressure_series_dive_tank', () async {
    final p = await plan(
      db,
      "SELECT * FROM tank_pressure_series WHERE dive_id = 'x' AND tank_id = 't'",
    );
    expect(p, contains('idx_tank_pressure_series_dive_tank'));
  });

  test('per-dive tanks fetch uses idx_dive_tanks_dive_id', () async {
    final p = await plan(db, "SELECT * FROM dive_tanks WHERE dive_id = 'x'");
    expect(p, contains('idx_dive_tanks_dive_id'));
  });

  test('paginated summaries page 1 does not scan dives', () async {
    final p = await plan(db, _summariesPage1Sql);
    expect(p, isNot(contains('SCAN dives')));
    expect(p, contains('USING INDEX'));
  });

  test('the trip-header join looks trips up, never scans them', () async {
    // The list's group headers (#1193) read four scalars off trips. This is
    // the hottest query in the app, so the join has to resolve by key: a
    // SCAN here would cost one trips pass per page.
    //
    // SQLite names the ALIAS in its plan, not the table: the row reads
    // "SEARCH t USING INDEX sqlite_autoindex_trips_1 (id=?) LEFT-JOIN". An
    // assertion against "SCAN trips" therefore never matches whatever the
    // planner does, and passes even on a full scan. Match the alias, with a
    // word boundary so "SCAN trips" would still be caught if the output ever
    // changes shape.
    final p = await plan(db, _summariesPage1Sql);
    expect(
      p,
      isNot(matches(RegExp(r'SCAN (t|trips)\b'))),
      reason: 'a scan of trips costs one full pass per page',
    );
    expect(p, contains('SEARCH t USING'));
  });

  test('the site join looks sites up, never scans them', () async {
    // Same reasoning, and the reason the fixture selects a site column: with
    // nothing read from s, SQLite drops the join and the guard covers
    // nothing.
    final p = await plan(db, _summariesPage1Sql);
    expect(p, isNot(matches(RegExp(r'SCAN (s|dive_sites)\b'))));
    expect(p, contains('SEARCH s USING'));
  });

  test(
    'per-dive data sources fetch uses idx_dive_data_sources_dive_id',
    () async {
      final p = await plan(
        db,
        "SELECT * FROM dive_data_sources WHERE dive_id = 'x'",
      );
      expect(p, contains('idx_dive_data_sources_dive_id'));
    },
  );

  test(
    'surface interval lookups seek idx_dives_entry_date, never scan',
    () async {
      final p = await plan(
        db,
        'SELECT d.id, ${diveSurfaceIntervalSecondsSql('d')} FROM dives d',
      );
      expect(p, contains('idx_dives_entry_date'));
      expect(p, isNot(contains('SCAN $kSurfaceIntervalPreviousAlias')));
      expect(p, isNot(contains('SCAN undived_sibling')));
    },
  );

  test('the undived check seeks idx_dives_outing, never scans', () async {
    final p = await plan(
      db,
      'SELECT d.id FROM dives d WHERE NOT ${diveUndivedSql('d')}',
    );
    expect(p, contains('idx_dives_outing'));
    expect(p, isNot(contains('SCAN undived_sibling')));
  });

  test('the earlier dives revision seeks, never scans', () async {
    final p = await plan(
      db,
      'SELECT d.id, ${earlierDivesRevisionSql('d')} FROM dives d',
    );
    expect(p, contains('idx_dives_entry_date'));
    expect(p, isNot(contains('SCAN history_dive')));
  });

  // The neighbor window once compared every pair of a diver's dives, and the
  // per-dive lookups read every dive a diver has, so a full scan was
  // quadratic twice over (issue #3863). Each of these must seek a time range.
  void pinNeighborWindowSeeks() {
    test('the same-diver pair window seeks a time range', () async {
      expect(
        await plan(db, qualityPairWindowSql, params: 1),
        contains(_sameDiverSeek),
      );
    });

    test('targeted expansion seeks a time range', () async {
      expect(
        await plan(db, qualityExpandNeighborsSql(2, 1000), params: 2),
        contains(_sameDiverSeek),
      );
    });

    test('the shared-gear pair window seeks a time range', () async {
      expect(
        await plan(db, qualitySharedGearWindowSql, params: 1),
        contains(_timeSeek),
      );
    });

    test('the per-dive same-diver lookup seeks a time range', () async {
      expect(
        await plan(db, _sameDiverNeighborsSql, params: 4),
        contains(_sameDiverSeek),
      );
    });

    test('the per-dive other-diver lookup seeks a time range', () async {
      expect(
        await plan(db, _otherDiverNeighborsSql, params: 4),
        contains(_timeSeek),
      );
    });
  }

  group('neighbor window on an empty database', pinNeighborWindowSeeks);

  // Creating an index runs ANALYZE, so a library's real plans come from
  // statistics this empty test database would not otherwise have.
  group('neighbor window with statistics', () {
    setUp(() async {
      await db.customStatement(
        'INSERT INTO divers (id, name, created_at, updated_at) '
        "VALUES ('bill', 'bill', 1, 1), ('anna', 'anna', 1, 1)",
      );
      // Two profiles and unassigned dives: the shared-gear query only runs
      // on a multi-profile library, so its statistics have to look like one.
      await db.customStatement(
        'WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n '
        'WHERE i < 2000) '
        'INSERT INTO dives (id, diver_id, dive_date_time, entry_time, '
        'created_at, updated_at) '
        "SELECT 'd' || i, "
        "CASE i % 3 WHEN 0 THEN 'bill' WHEN 1 THEN 'anna' END, "
        'i * 86400000, CASE WHEN i % 2 = 0 THEN i * 86400000 END, 1, 1 FROM n',
      );
      await db.customStatement('ANALYZE');
    });

    pinNeighborWindowSeeks();
  });
}
