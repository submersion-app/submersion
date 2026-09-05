import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v193 is the current schema version and is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, 193);
    expect(AppDatabase.migrationVersions, contains(193));
  });

  test(
    'a fresh database has diver_settings.default_planner_water_type as salt',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final column = cols.firstWhere(
        (c) => c.read<String>('name') == 'default_planner_water_type',
      );
      expect(column.read<int>('notnull'), 1);
      expect(column.read<String?>('dflt_value'), contains('salt'));
    },
  );
}
