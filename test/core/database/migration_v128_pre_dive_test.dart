import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('v128 creates the four pre-dive checklist tables', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 112');
        // Minimal parents so FK references resolve.
        rawDb.execute('CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('CREATE TABLE trips (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute(
          'CREATE TABLE equipment_sets (id TEXT NOT NULL PRIMARY KEY)',
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final expectations = {
      'pre_dive_checklist_templates': [
        'id',
        'strict_order',
        'is_built_in',
        'builtin_key',
        'hlc',
      ],
      'pre_dive_checklist_template_items': [
        'id',
        'template_id',
        'item_type',
        'is_required',
        'value_min',
        'hlc',
      ],
      'pre_dive_sessions': [
        'id',
        'template_name',
        'strict_order',
        'dive_id',
        'trip_id',
        'status',
        'started_at',
        'hlc',
      ],
      'pre_dive_session_items': [
        'id',
        'session_id',
        'state',
        'value_number',
        'completed_at',
        'equipment_id',
        'hlc',
      ],
    };
    for (final entry in expectations.entries) {
      final cols = await db
          .customSelect("PRAGMA table_info('${entry.key}')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, isNotEmpty, reason: '${entry.key} table missing');
      for (final col in entry.value) {
        expect(names, contains(col), reason: '${entry.key} missing $col');
      }
    }
  });

  test('v128 is the current schema version (exact-latest tripwire)', () {
    // Exact assertion: the newest migration owns the tripwire, so the next
    // schema bump must move it forward. Relax to greaterThanOrEqualTo and add
    // a fresh exact test when a later migration lands on top of v128.
    expect(AppDatabase.currentSchemaVersion, 128);
    expect(AppDatabase.migrationVersions, contains(128));
  });
}
