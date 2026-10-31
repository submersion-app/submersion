import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/change_log/data/services/change_log_dependencies.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await insertDiver(db, 'me');
    await insertDive(db, 'dive', diverId: 'me');
    await db.customStatement(
      'INSERT INTO dive_sites (id, diver_id, name, created_at, updated_at) '
      "VALUES ('site', 'me', 'Reef', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO equipment (id, diver_id, name, type, created_at, '
      "updated_at) VALUES ('gear', 'me', 'Reg', 'regulator', 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  test('a no-action reference is found', () async {
    await db.customStatement("UPDATE dives SET site_id = 'site'");
    final index = await ChangeLogDependencyIndex.load(db);

    final references = await index.referencesTo('dive_sites', 'site');

    expect(
      references.map((r) => '${r.table}.${r.column}:${r.recordId}'),
      contains('dives.site_id:dive'),
    );
  });

  test('a cascading reference is found, with its composite id', () async {
    await db.customStatement(
      "INSERT INTO dive_equipment (dive_id, equipment_id) VALUES ('dive', 'gear')",
    );
    final index = await ChangeLogDependencyIndex.load(db);

    final references = await index.referencesTo('equipment', 'gear');

    expect(
      references.map((r) => '${r.table}:${r.recordId}'),
      contains('dive_equipment:dive|gear'),
    );
  });

  test('no reference means an empty list', () async {
    final index = await ChangeLogDependencyIndex.load(db);

    expect(await index.referencesTo('dive_sites', 'site'), isEmpty);
  });

  test('machine tables are not references', () async {
    await db.customStatement(
      'INSERT INTO tide_records (id, dive_id, height_meters, tide_state, '
      "created_at) VALUES ('tide', 'dive', 1.0, 'rising', 0)",
    );
    final index = await ChangeLogDependencyIndex.load(db);

    expect(await index.referencesTo('dives', 'dive'), isEmpty);
  });

  test('a missing parent is reported', () async {
    final index = await ChangeLogDependencyIndex.load(db);

    expect(
      await index.missingParents('dive_tanks', {'dive_id': 'gone'}, const {}),
      ['dives|gone'],
    );
  });

  test('a parent in the restoring set is not missing', () async {
    final index = await ChangeLogDependencyIndex.load(db);

    expect(
      await index.missingParents(
        'dive_tanks',
        {'dive_id': 'gone'},
        const {'dives|gone'},
      ),
      isEmpty,
    );
  });

  test('a live parent and a null reference are not missing', () async {
    final index = await ChangeLogDependencyIndex.load(db);

    expect(
      await index.missingParents('dive_tanks', {
        'dive_id': 'dive',
        'equipment_id': null,
      }, const {}),
      isEmpty,
    );
  });
}
