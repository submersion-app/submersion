import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/child_column_clears.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// A peer's explicit null on a parent-gated child used to be dropped by the
/// upsert (#2644). These are the rules that decide when it is a deliberate
/// clear and which column it names.
void main() {
  group('isNewerChildCopy', () {
    const base = Hlc(1000, 0, 'a');
    const later = Hlc(2000, 0, 'b');

    test('a copy with no clock is never newer', () {
      expect(isNewerChildCopy(remote: null, local: base), isFalse);
      expect(isNewerChildCopy(remote: null, local: null), isFalse);
    });

    test('a stamped copy beats an unstamped local row', () {
      expect(isNewerChildCopy(remote: base, local: null), isTrue);
    });

    test('strictly newer only', () {
      expect(isNewerChildCopy(remote: later, local: base), isTrue);
      expect(isNewerChildCopy(remote: base, local: base), isFalse);
      expect(isNewerChildCopy(remote: base, local: later), isFalse);
    });
  });

  test(
    'explicitlyClearedKeys: an explicit null over a value, nothing else',
    () {
      final cleared = explicitlyClearedKeys(
        remote: {'a': null, 'b': null, 'c': 1},
        local: {'a': 'x', 'b': null, 'c': 2, 'd': 'kept'},
      );
      // b was already null, c is a value, d is omitted by the remote.
      expect(cleared, {'a'});
    },
  );

  test('columnJsonKey is the camel-case form of the SQL name', () {
    expect(columnJsonKey('transmitter_serial'), 'transmitterSerial');
    expect(columnJsonKey('o2_percent'), 'o2Percent');
    expect(columnJsonKey('id'), 'id');
  });

  group('against the schema', () {
    late AppDatabase db;

    setUp(() async {
      db = await setUpTestDatabase();
    });
    tearDown(() async {
      await tearDownTestDatabase();
    });

    test('clearable tank columns: nullable, not key, not clock', () {
      final cols = clearableColumns(db.diveTanks, keyColumns: const ['id']);
      expect(cols['transmitterSerial'], 'transmitter_serial');
      expect(cols['computerId'], 'computer_id');
      expect(cols.containsKey('hlc'), isFalse);
      expect(cols.containsKey('id'), isFalse);
      expect(cols.containsKey('diveId'), isFalse, reason: 'NOT NULL');
      expect(cols.containsKey('o2Percent'), isFalse, reason: 'NOT NULL');
    });

    test('a nullable column with a default is not clearable', () {
      final cols = clearableColumns(
        db.diveEquipment,
        keyColumns: const ['dive_id', 'equipment_id'],
      );
      expect(cols['viaSetId'], 'via_set_id');
      expect(
        cols.containsKey('updatedAt'),
        isFalse,
        reason:
            'a fresh insert fills it, and clearing it would erase the age '
            'signal the deletion guards read',
      );
    });

    test('every parent-gated table: toJson keys are the camel-case column '
        'names', () async {
      await db.customStatement('PRAGMA foreign_keys = OFF');
      for (final MapEntry(key: type, value: tableName)
          in SyncDataSerializer.parentGatedTables.entries) {
        final table = db.allTables.firstWhere(
          (t) => t.actualTableName == tableName,
        );
        // One minimal row: each NOT NULL column without a default gets a
        // placeholder of its SQL type.
        final info = await db
            .customSelect(
              'SELECT * FROM pragma_table_info(?)',
              variables: [Variable.withString(tableName)],
            )
            .get();
        final names = <String>[];
        final values = <Object?>[];
        for (final c in info) {
          final notNull = (c.data['notnull'] as int? ?? 0) == 1;
          if (!notNull || c.data['dflt_value'] != null) continue;
          final sqlType = (c.data['type'] as String? ?? '').toUpperCase();
          names.add('"${c.read<String>('name')}"');
          values.add(switch (sqlType) {
            final t when t.contains('INT') => 0,
            final t when t.contains('REAL') => 0.0,
            final t when t.contains('BLOB') => Uint8List(0),
            _ => 'x',
          });
        }
        await db.customStatement(
          'INSERT INTO "$tableName" (${names.join(', ')}) '
          'VALUES (${names.map((_) => '?').join(', ')})',
          values,
        );
        final row = await db
            .customSelect('SELECT * FROM "$tableName" LIMIT 1')
            .getSingle();
        final data = table.map(row.data) as DataClass;
        expect(
          data.toJson().keys.toSet(),
          {for (final c in table.$columns) columnJsonKey(c.$name)},
          reason:
              '$type ($tableName): a JSON key is not the camel-case '
              'form of its column, so a peer clear would miss it',
        );
      }
    });
  });
}
