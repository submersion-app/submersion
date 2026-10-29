import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/features/trips/data/side_trip_sql.dart';

/// The trip list, the top-trips ranking and the history sample join every
/// trip to its dives and its side trips' dives (issue #3658). That join
/// must look dives up by trip_id: an OR with a correlated subquery made
/// SQLite walk every one of the diver's dives for every trip, seconds on a
/// log of a few thousand dives.
void main() {
  late AppDatabase db;

  // A realistic log, analyzed as the app analyzes it when it builds its
  // indexes: on an empty database SQLite picks a diver index even for the
  // plain equality join, so the plan would say nothing.
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('x', 'x', 0, 0)",
    );
    for (var t = 0; t < 30; t++) {
      await db.customStatement(
        'INSERT INTO trips (id, name, start_date, end_date, parent_trip_id, '
        'created_at, updated_at) VALUES (?, ?, 0, 0, ?, 0, 0)',
        ['t$t', 't$t', t.isOdd ? 't${t - 1}' : null],
      );
    }
    for (var d = 0; d < 600; d++) {
      await db.customStatement(
        'INSERT INTO dives (id, diver_id, dive_date_time, trip_id, '
        'created_at, updated_at) VALUES (?, ?, ?, ?, 0, 0)',
        ['d$d', 'x', d, 't${d % 30}'],
      );
    }
    await db.customStatement('ANALYZE');
  });
  tearDown(() => db.close());

  Future<String> plan(String sql) async {
    final rows = await db.customSelect('EXPLAIN QUERY PLAN $sql').get();
    return rows.map((r) => r.read<String>('detail')).join('\n');
  }

  test('the trip list join finds dives through idx_dives_trip_id', () async {
    final join = tripDivesJoinSql(
      tripAlias: 't',
      diveAlias: 'd',
      extraOn: " AND d.diver_id = 'x'${DiveStatsScope.and(alias: 'd')}",
    );
    final p = await plan(
      'SELECT t.id, COUNT(DISTINCT d.id) FROM trips t $join GROUP BY t.id',
    );
    expect(p, contains('idx_dives_trip_id'));
    expect(p, isNot(contains('CORRELATED')));
  });

  test('the inner join used by rankings does too', () async {
    final join = tripDivesJoinSql(tripAlias: 't', diveAlias: 'd', joinKind: '');
    final p = await plan(
      'SELECT t.id, COUNT(d.id) FROM trips t $join '
      'WHERE $topLevelTripSql GROUP BY t.id',
    );
    expect(p, contains('idx_dives_trip_id'));
  });
}
