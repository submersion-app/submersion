import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  group('Migration v73 - GPS entry/exit on dives', () {
    test('fresh database has GPS columns on dives', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final cols = await db.customSelect("PRAGMA table_info('dives')").get();
      final names = cols.map((c) => c.read<String>('name')).toSet();

      expect(
        names,
        containsAll(<String>[
          'entry_latitude',
          'entry_longitude',
          'exit_latitude',
          'exit_longitude',
        ]),
      );
    });

    test('a dive round-trips its GPS coordinates', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'gps-1',
              diveDateTime: now,
              createdAt: now,
              updatedAt: now,
              entryLatitude: const Value(12.34567),
              entryLongitude: const Value(98.76543),
              exitLatitude: const Value(12.34612),
              exitLongitude: const Value(98.76489),
            ),
          );

      final row = await (db.select(
        db.dives,
      )..where((t) => t.id.equals('gps-1'))).getSingle();
      expect(row.entryLatitude, 12.34567);
      expect(row.exitLongitude, 98.76489);
    });

    test(
      'v72 -> v73 upgrade adds GPS columns to an existing dives table',
      () async {
        // Minimal pre-v73 dives table at user_version = 72 (no GPS columns).
        final native = NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('PRAGMA user_version = 72');
            rawDb.execute('''
            CREATE TABLE dives (
              id TEXT NOT NULL PRIMARY KEY,
              dive_date_time INTEGER NOT NULL DEFAULT 0,
              dive_type TEXT NOT NULL DEFAULT 'recreational',
              notes TEXT NOT NULL DEFAULT '',
              is_favorite INTEGER NOT NULL DEFAULT 0,
              dive_mode TEXT NOT NULL DEFAULT 'oc',
              cns_start REAL NOT NULL DEFAULT 0,
              is_planned INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          },
        );
        final db = AppDatabase(native);
        addTearDown(db.close);

        // Opening the database runs onUpgrade from 72, executing the v73
        // ALTER TABLE statements.
        final cols = await db.customSelect("PRAGMA table_info('dives')").get();
        final names = cols.map((c) => c.read<String>('name')).toSet();
        expect(
          names,
          containsAll(<String>[
            'entry_latitude',
            'entry_longitude',
            'exit_latitude',
            'exit_longitude',
          ]),
        );
      },
    );
  });
}
