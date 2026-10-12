import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(tearDownTestDatabase);

  test('rung 287 creates the shared library tables', () async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    expect(
      names,
      containsAll([
        'shared_libraries',
        'shared_library_members',
        'shared_library_memberships',
        'shared_site_states',
        'shared_site_suggestions',
      ]),
    );
  });

  test('dive_sites carries shared_library_id', () async {
    final cols = await db.customSelect("PRAGMA table_info('dive_sites')").get();
    expect(
      cols.map((r) => r.read<String>('name')),
      contains('shared_library_id'),
    );
  });

  test('the schema version is 287', () {
    expect(AppDatabase.currentSchemaVersion, 287);
    expect(AppDatabase.migrationVersions.last, 287);
  });
}
