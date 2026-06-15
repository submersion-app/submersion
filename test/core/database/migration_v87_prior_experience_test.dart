import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test(
    'v87 adds prior-experience columns to divers, preserving rows',
    () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 86');
          // Minimal pre-v87 divers shape (no prior-experience columns).
          rawDb.execute('''
          CREATE TABLE divers (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            medical_notes TEXT NOT NULL DEFAULT '',
            notes TEXT NOT NULL DEFAULT '',
            is_default INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0,
            hlc TEXT
          )
        ''');
          rawDb.execute(
            "INSERT INTO divers (id, name, created_at, updated_at) "
            "VALUES ('d1', 'Old Salt', 100, 100)",
          );
        },
      );

      final db = AppDatabase(nativeDb);
      addTearDown(() => db.close());

      // Touch the DB so the migration runs.
      final cols = await db.customSelect("PRAGMA table_info('divers')").get();
      final names = cols.map((c) => c.read<String>('name')).toSet();

      expect(
        names,
        containsAll(<String>{
          'prior_dive_count',
          'prior_dive_time_seconds',
          'diving_since',
        }),
      );

      final row = await db
          .customSelect(
            "SELECT name, prior_dive_count FROM divers WHERE id = 'd1'",
          )
          .getSingle();
      expect(row.read<String>('name'), 'Old Salt');
      expect(row.data['prior_dive_count'], isNull);
    },
  );
}
