import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

Map<String, dynamic> _detailedConfig(String stat2Field) {
  return {
    'mode': 'detailed',
    'slots': [
      {'slotId': 'title', 'field': 'siteName'},
      {'slotId': 'date', 'field': 'dateTime'},
      {'slotId': 'stat1', 'field': 'maxDepth'},
      {'slotId': 'stat2', 'field': stat2Field},
    ],
    'extraFields': <String>[],
  };
}

void main() {
  group('Migration v65 - detailed stat2 bottomTime to runtime', () {
    NativeDatabase setupDb(List<(String id, String mode, String json)> rows) {
      return NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 64');
          rawDb.execute('''
            CREATE TABLE divers (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              created_at INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL DEFAULT 0
            )
          ''');
          rawDb.execute('''
            CREATE TABLE view_configs (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT NOT NULL REFERENCES divers(id) ON DELETE CASCADE,
              view_mode TEXT NOT NULL,
              config_json TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          rawDb.execute("INSERT INTO divers (id, name) VALUES ('d1', 'Alice')");

          for (final r in rows) {
            rawDb.execute(
              "INSERT INTO view_configs (id, diver_id, view_mode, config_json, updated_at)"
              " VALUES ('${r.$1}', 'd1', '${r.$2}', ?, 0)",
              [r.$3],
            );
          }
        },
      );
    }

    Future<String> readConfig(AppDatabase db, String id) async {
      final row = await db
          .customSelect("SELECT config_json FROM view_configs WHERE id = '$id'")
          .getSingle();
      return row.read<String>('config_json');
    }

    test('flips detailed stat2 bottomTime to runtime', () async {
      final db = AppDatabase(
        setupDb([
          ('row1', 'detailed', jsonEncode(_detailedConfig('bottomTime'))),
        ]),
      );
      addTearDown(db.close);

      final json =
          jsonDecode(await readConfig(db, 'row1')) as Map<String, dynamic>;
      final stat2 =
          (json['slots'] as List).firstWhere(
                (s) => (s as Map)['slotId'] == 'stat2',
              )
              as Map;
      expect(stat2['field'], equals('runtime'));
    });

    test('leaves customized stat2 fields untouched', () async {
      final db = AppDatabase(
        setupDb([
          ('row1', 'detailed', jsonEncode(_detailedConfig('waterTemp'))),
        ]),
      );
      addTearDown(db.close);

      final json =
          jsonDecode(await readConfig(db, 'row1')) as Map<String, dynamic>;
      final stat2 =
          (json['slots'] as List).firstWhere(
                (s) => (s as Map)['slotId'] == 'stat2',
              )
              as Map;
      expect(stat2['field'], equals('waterTemp'));
    });

    test('does not touch compact view mode', () async {
      final compact = {
        'mode': 'compact',
        'slots': [
          {'slotId': 'slot4', 'field': 'bottomTime'},
        ],
        'extraFields': <String>[],
      };
      final db = AppDatabase(
        setupDb([('row1', 'compact', jsonEncode(compact))]),
      );
      addTearDown(db.close);

      final json =
          jsonDecode(await readConfig(db, 'row1')) as Map<String, dynamic>;
      expect(
        ((json['slots'] as List).first as Map)['field'],
        equals('bottomTime'),
      );
    });

    test('survives malformed JSON in another row', () async {
      final db = AppDatabase(
        setupDb([
          ('bad', 'detailed', 'not valid json'),
          ('good', 'detailed', jsonEncode(_detailedConfig('bottomTime'))),
        ]),
      );
      addTearDown(db.close);

      final good =
          jsonDecode(await readConfig(db, 'good')) as Map<String, dynamic>;
      final stat2 =
          (good['slots'] as List).firstWhere(
                (s) => (s as Map)['slotId'] == 'stat2',
              )
              as Map;
      expect(stat2['field'], equals('runtime'));
      expect(await readConfig(db, 'bad'), equals('not valid json'));
    });
  });
}
