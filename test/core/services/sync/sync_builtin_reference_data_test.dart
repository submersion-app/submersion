import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Replace-adopt clears each synced table via [SyncDataSerializer.deleteAllRecords]
/// and refills it from the cloud payload. Every exporter that filters
/// `isBuiltIn` rows out of that payload therefore makes its table unrestorable
/// by the refill: whatever the clear removes is gone for good.
///
/// This asserts the contract for all such tables at once, and fails when a new
/// one appears -- the fourth `isBuiltIn` table must make the same choice
/// deliberately rather than inherit the bug.
///
/// Recovery differs per table and none of it runs during an adopt: species are
/// re-seeded at app startup, field presets lazily on read, dive types only in
/// `beforeOpen`. The clear must not depend on any of them.
const _entityForTable = {
  'dive_types': 'diveTypes',
  'dive_roles': 'diveRoles',
  'species': 'species',
  'field_presets': 'fieldPresets',
};

const _diverId = 'diver-1';

/// Minimal rows: every NOT NULL column without a default, plus is_built_in.
String _insert(String table, {required String id, required bool builtIn}) {
  final b = builtIn ? 1 : 0;
  switch (table) {
    case 'dive_types':
      return "INSERT INTO dive_types (id, name, created_at, updated_at, "
          "is_built_in) VALUES ('$id', '$id', 0, 0, $b)";
    case 'dive_roles':
      return "INSERT INTO dive_roles (id, name, created_at, updated_at, "
          "is_built_in) VALUES ('$id', '$id', 0, 0, $b)";
    case 'species':
      return "INSERT INTO species (id, common_name, category, is_built_in) "
          "VALUES ('$id', '$id', 'fish', $b)";
    case 'field_presets':
      return "INSERT INTO field_presets (id, diver_id, view_mode, name, "
          "config_json, created_at, is_built_in) VALUES ('$id', '$_diverId', "
          "'table', '$id', '{}', 0, $b)";
    default:
      throw ArgumentError('no insert template for $table');
  }
}

Future<int> _count(String table, {required bool builtIn}) async {
  final row = await DatabaseService.instance.database
      .customSelect(
        'SELECT count(*) AS c FROM $table WHERE is_built_in = ${builtIn ? 1 : 0}',
      )
      .getSingle();
  return row.read<int>('c');
}

/// Every table in the schema carrying an `is_built_in` column.
Future<Set<String>> _tablesWithBuiltInColumn() async {
  final db = DatabaseService.instance.database;
  final tables = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  final found = <String>{};
  for (final t in tables) {
    final name = t.read<String>('name');
    final cols = await db.customSelect("PRAGMA table_info('$name')").get();
    if (cols.any((c) => c.read<String>('name') == 'is_built_in')) {
      found.add(name);
    }
  }
  return found;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setUpTestDatabase();
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('$_diverId', 'Test', 0, 0)",
    );
  });
  tearDown(() => tearDownTestDatabase());

  test('every isBuiltIn table is covered by this contract', () async {
    expect(
      await _tablesWithBuiltInColumn(),
      _entityForTable.keys.toSet(),
      reason:
          'a new isBuiltIn table must decide whether deleteAllRecords may '
          'clear it, and whether anything re-seeds it',
    );
  });

  test('exports omit built-in rows, so a refill cannot restore them', () async {
    final data = (await SyncDataSerializer().exportData(
      deviceId: 'peer',
      deletions: const [],
    )).data;
    expect(data.diveTypes, isEmpty);
    expect(data.species, isEmpty);
    expect(data.fieldPresets, isEmpty);
  });

  for (final entry in _entityForTable.entries) {
    final table = entry.key;
    final entity = entry.value;

    test(
      'deleteAllRecords($entity) clears custom rows but keeps built-ins',
      () async {
        final db = DatabaseService.instance.database;
        await db.customStatement('DELETE FROM $table');
        await db.customStatement(_insert(table, id: 'b1', builtIn: true));
        await db.customStatement(_insert(table, id: 'c1', builtIn: false));

        await SyncDataSerializer().deleteAllRecords(entity);

        expect(
          await _count(table, builtIn: true),
          1,
          reason: '$table built-in rows are absent from every export',
        );
        expect(
          await _count(table, builtIn: false),
          0,
          reason:
              '$table custom rows are exported, so the refill restores them',
        );
      },
    );
  }
}
