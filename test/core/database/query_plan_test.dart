import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Returns the concatenated EXPLAIN QUERY PLAN detail lines for [sql].
Future<String> plan(AppDatabase db, String sql) async {
  final rows = await db.customSelect('EXPLAIN QUERY PLAN $sql').get();
  return rows.map((r) => r.read<String>('detail')).join('\n');
}

/// Page-1 shape of DiveRepository.getDiveSummaries (default date sort, no
/// cursor, no filters). Keep in sync with dive_repository_impl.dart.
const _summariesPage1Sql =
    "SELECT d.id, COALESCE(d.entry_time, d.dive_date_time) AS sort_timestamp "
    "FROM dives d LEFT JOIN dive_sites s ON d.site_id = s.id "
    "WHERE d.diver_id = 'x' "
    "ORDER BY sort_timestamp DESC, COALESCE(d.dive_number, 0) DESC, d.id DESC "
    "LIMIT 50";

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
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
}
