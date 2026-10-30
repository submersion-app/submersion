import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';
import '../../../tool/demo_data/src/checks/coverage_check.dart';

void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  test('an empty table that is not excluded is reported', () async {
    final empty = await CoverageCheck.emptyTables(db);

    expect(empty, contains('dives'));
    expect(empty, isNot(contains('sync_records')));
  });

  test('a filled table is not reported', () async {
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('d1', 'Alex', 0, 0)",
    );

    expect(await CoverageCheck.emptyTables(db), isNot(contains('divers')));
  });

  test('every exclusion names a real table and gives a reason', () {
    final tables = {for (final t in db.allTables) t.actualTableName};

    for (final MapEntry(:key, :value) in demoCoverageExclusions.entries) {
      expect(tables, contains(key));
      expect(value.trim(), isNotEmpty, reason: key);
    }
  });
}
