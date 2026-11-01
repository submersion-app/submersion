import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/change_log/change_log_policy.dart';
import 'package:submersion/core/database/change_log/change_log_trigger_sql.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_record_overlay.dart';

import '../../../helpers/test_database.dart';

ChangeLogTableSpec _specFor(AppDatabase db, String table) =>
    changeLogSpecsFor(db).singleWhere((s) => s.table == table);

List<String> _allTriggers(AppDatabase db) => [
  for (final spec in changeLogSpecsFor(db))
    ...buildChangeLogTriggers(
      spec,
      changeLogTables[spec.table]!,
      schemaVersion: 1,
    ),
];

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  test('a single key is its own column', () {
    expect(changeLogRecordIdSql('OLD', ['id']), 'OLD."id"');
  });

  test('a composite key joins with a pipe, matching syncRecordId', () async {
    final keys = _specFor(db, 'dive_equipment').keyColumns;
    expect(keys, ['dive_id', 'equipment_id']);

    final row = await db
        .customSelect(
          'SELECT ${changeLogRecordIdSql('o', keys)} AS id '
          "FROM (SELECT 'd1' AS dive_id, 'e1' AS equipment_id) AS o",
        )
        .getSingle();

    expect(
      row.read<String>('id'),
      syncRecordId('diveEquipment', {'diveId': 'd1', 'equipmentId': 'e1'}),
    );
  });

  test('a natural key record uses that key', () {
    expect(_specFor(db, 'settings').keyColumns, ['key']);
    expect(_specFor(db, 'dive_safety_reviews').keyColumns, ['dive_id']);
  });

  test('no credential column appears in any generated trigger', () {
    final sql = _allTriggers(db).join('\n');
    for (final column in changeLogCredentialColumns) {
      expect(sql, isNot(contains('"$column"')), reason: column);
    }
    expect(sql, isNot(contains('"shared_library_memberships"')));
  });

  test('a delete copy keeps ignored columns but never a clock', () {
    final delete = buildChangeLogTriggers(
      _specFor(db, 'dives'),
      ChangeLogClass.tracked,
      schemaVersion: 1,
    ).singleWhere((s) => s.contains('AFTER DELETE'));

    expect(delete, contains('OLD."created_at"'));
    expect(delete, isNot(contains('OLD."hlc"')));
  });

  test('a tracked table gets all three triggers', () {
    final statements = buildChangeLogTriggers(
      _specFor(db, 'dives'),
      ChangeLogClass.tracked,
      schemaVersion: 1,
    );
    expect(statements, hasLength(3));
    expect(
      statements.every(
        (s) => s.contains('CREATE TRIGGER "$kChangeLogTriggerPrefix'),
      ),
      isTrue,
    );
  });

  test('a delete copy only table gets one trigger', () {
    final statements = buildChangeLogTriggers(
      _specFor(db, 'dive_profile_series'),
      ChangeLogClass.deleteCopyOnly,
      schemaVersion: 1,
    );
    expect(statements, hasLength(1));
    expect(statements.single, contains('AFTER DELETE'));
  });

  test('an excluded table gets none', () {
    expect(
      buildChangeLogTriggers(
        _specFor(db, 'sync_records'),
        ChangeLogClass.excluded,
        schemaVersion: 1,
      ),
      isEmpty,
    );
  });

  test('an update only compares tracked columns', () {
    final update = buildChangeLogTriggers(
      _specFor(db, 'dives'),
      ChangeLogClass.tracked,
      schemaVersion: 1,
    ).singleWhere((s) => s.contains('AFTER UPDATE'));

    expect(update, contains('OLD."notes" IS NOT NEW."notes"'));
    expect(update, isNot(contains('OLD."updated_at" IS NOT')));
    expect(update, isNot(contains('OLD."hlc"')));
  });

  test('generated triggers are stable across runs', () {
    final first = _allTriggers(db);
    final second = _allTriggers(db);
    expect(first, second);
    expect(changeLogTriggersHash(first), changeLogTriggersHash(second));
    expect(
      changeLogTriggersHash(first),
      isNot(changeLogTriggersHash(first.skip(1).toList())),
    );
  });

  test('a declared column the file lacks is left out', () {
    final spec = _specFor(db, 'dives');
    final narrowed = spec.narrowedTo({'id', 'notes'});
    expect(narrowed.columns, ['id', 'notes']);
    expect(narrowed.keyColumns, ['id']);
  });
}
