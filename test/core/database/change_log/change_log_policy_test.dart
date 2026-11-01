import 'package:drift/drift.dart' show GeneratedDatabase, Variable;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/change_log/change_log_policy.dart';
import 'package:submersion/core/database/change_log/change_log_trigger_sql.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/child_column_clears.dart';
import 'package:submersion/core/services/sync/device_local_fields.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/conflict_field_catalogue.dart';

import '../../../helpers/test_database.dart';

Map<String, Set<String>> _columnsByTable(GeneratedDatabase db) => {
  for (final table in db.allTables)
    table.actualTableName: {for (final c in table.$columns) c.name},
  for (final spec in changeLogRawTableSpecs) spec.table: spec.columns.toSet(),
};

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  test('every table in allTables is classified', () {
    final real = _columnsByTable(db).keys.toSet();
    expect(
      real.difference(changeLogTables.keys.toSet()),
      isEmpty,
      reason: 'new tables need a ChangeLogClass',
    );
    expect(
      changeLogTables.keys.toSet().difference(real),
      isEmpty,
      reason: 'these keys are not real tables',
    );
  });

  test('a raw table spec names the columns the table has', () async {
    for (final spec in changeLogRawTableSpecs) {
      final rows = await db
          .customSelect(
            'SELECT name FROM pragma_table_info(?)',
            variables: [Variable.withString(spec.table)],
          )
          .get();
      expect(
        {for (final row in rows) row.read<String>('name')},
        spec.columns.toSet(),
        reason: spec.table,
      );
    }
  });

  test('every tracked table has a key', () {
    for (final spec in changeLogSpecsFor(db)) {
      if (changeLogTables[spec.table] == ChangeLogClass.excluded) continue;
      expect(spec.keyColumns, isNotEmpty, reason: spec.table);
    }
  });

  test('the log itself is never logged', () {
    for (final table in changeLogTables.keys.where(
      (t) => t.startsWith('change_log_'),
    )) {
      expect(changeLogTables[table], ChangeLogClass.excluded, reason: table);
    }
  });

  test('every child parent column exists on that table', () {
    final columns = _columnsByTable(db);
    for (final entry in changeLogParents.entries) {
      expect(columns, contains(entry.key));
      expect(
        columns[entry.key],
        contains(entry.value.column),
        reason: '${entry.key}.${entry.value.column}',
      );
      expect(
        columns,
        contains(entry.value.rootTable),
        reason: entry.value.rootTable,
      );
    }
  });

  test('every machine owner column exists', () {
    final columns = _columnsByTable(db);
    for (final entry in changeLogMachineOwners.entries) {
      for (final owner in entry.value.entries) {
        expect(columns[entry.key], contains(owner.key), reason: entry.key);
        expect(columns, contains(owner.value));
      }
    }
  });

  test('parent chains end', () {
    for (final start in changeLogParents.keys) {
      final seen = <String>{};
      var table = start;
      while (changeLogParents.containsKey(table)) {
        expect(seen.add(table), isTrue, reason: 'cycle through $table');
        table = changeLogParents[table]!.rootTable;
      }
    }
  });

  test('a table with a dive_id child link roots at dives', () {
    expect(changeLogParents['dive_tanks']?.rootTable, 'dives');
    expect(changeLogParents['dive_tanks']?.column, 'dive_id');
    expect(changeLogParents['dive_equipment']?.rootTable, 'dives');
    expect(
      changeLogParents['course_requirement_dives']?.rootTable,
      'course_requirements',
    );
  });

  test('the bookkeeping columns match the conflict catalogue', () {
    final expected = {
      for (final key in conflictBookkeepingColumns)
        if (key != 'id') changeLogSqlName(key),
    };
    expect(changeLogBookkeepingColumns, expected);
  });

  test('ignored columns cover bookkeeping, device facts and device locals', () {
    final media = changeLogIgnoredColumns('media');
    expect(media, containsAll(changeLogBookkeepingColumns));
    for (final group in SyncFactGroups.of('media')) {
      expect(media, contains(group.clockColumn));
      expect(media, containsAll(group.columns.values));
    }
    final settings = changeLogIgnoredColumns('diver_settings');
    for (final key in deviceLocalSyncColumns['diverSettings']!) {
      expect(settings, contains(changeLogSqlName(key)));
    }
    expect(settings, contains('dive_list_sort'));
    expect(settings, contains('list_arrangement_hlc'));
  });

  test('the SQL name helper inverts columnJsonKey', () {
    for (final name in ['dive_list_sort', 'theme_mode', 'hlc', 'bbox_x']) {
      expect(changeLogSqlName(columnJsonKey(name)), name);
    }
  });

  test('a device-local settings key is filtered out of the triggers', () {
    expect(
      changeLogRowGuard('settings', 'NEW'),
      allOf(contains('NEW."key"'), contains("'active_diver_id'")),
    );
    expect(changeLogRowGuard('dives', 'NEW'), isNull);
  });
}
