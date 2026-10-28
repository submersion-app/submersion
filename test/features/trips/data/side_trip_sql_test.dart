import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/trips/data/side_trip_sql.dart';

import '../../../helpers/test_database.dart';

/// The side-trip rule in SQL (issue #3658): a link counts only when the parent
/// exists, has no parent of its own, and is not the trip itself.
void main() {
  late AppDatabase db;

  Future<void> trip(String id, {String? parent}) => db.customStatement(
    'INSERT INTO trips (id, name, start_date, end_date, parent_trip_id, '
    'created_at, updated_at) VALUES (?, ?, 0, 0, ?, 0, 0)',
    [id, id, parent],
  );

  Future<Set<String>> ids(String sql, [List<String> args = const []]) async {
    final rows = await db
        .customSelect(sql, variables: [for (final a in args) Variable(a)])
        .get();
    return {for (final r in rows) r.read<String>('id')};
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await trip('A');
    await trip('B', parent: 'A');
    await trip('C', parent: 'B');
    await trip('D', parent: 'D');
    await trip('E', parent: 'gone');
  });
  tearDown(tearDownTestDatabase);

  test('sideTripIdsSql lists only valid side trips', () async {
    expect(await ids(sideTripIdsSql('?1'), ['A']), {'B'});
    expect(await ids(sideTripIdsSql('?1'), ['B']), isEmpty);
    expect(await ids(sideTripIdsSql('?1'), ['D']), isEmpty);
  });

  test('validParentIdSql names the parent only for a valid link', () async {
    expect(await ids(validParentIdSql('?1'), ['B']), {'A'});
    for (final id in ['A', 'C', 'D', 'E']) {
      expect(await ids(validParentIdSql('?1'), [id]), isEmpty, reason: id);
    }
  });

  test('topLevelTripSql keeps every trip that is not a valid side trip', () {
    return expectLater(
      ids('SELECT t.id FROM trips t WHERE $topLevelTripSql'),
      completion({'A', 'C', 'D', 'E'}),
    );
  });

  test('tripDivesScopeSql takes the trip and its valid side trips', () async {
    for (final (id, tripId) in [
      ('d1', 'A'),
      ('d2', 'B'),
      ('d3', 'C'),
      ('d4', 'E'),
    ]) {
      await db.customStatement(
        'INSERT INTO dives (id, dive_date_time, trip_id, created_at, '
        'updated_at) VALUES (?, 0, ?, 0, 0)',
        [id, tripId],
      );
    }
    final scope = tripDivesScopeSql('d', '?1');
    final sql = 'SELECT d.id FROM dives d WHERE $scope';
    expect(await ids(sql, ['A']), {'d1', 'd2'});
    expect(await ids(sql, ['B']), {'d2'});
    expect(await ids(sql, ['E']), {'d4'});
  });
}
