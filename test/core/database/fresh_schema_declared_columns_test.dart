import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// A fresh database runs every beforeOpen backstop over the tables Drift
/// created, so a backstop that spells a column differently from the Drift
/// table leaves an extra column here. On an upgraded database the same
/// misspelling means the column Drift reads never exists, and every read of
/// the table fails: the v319 deco band columns were added as `ppo2_*` where
/// Drift reads `pp_o2_*`, and every upgraded diver's settings fell back to
/// the defaults (issue #3809).
void main() {
  test(
    'a fresh database holds exactly the columns its tables declare',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(setup: registerAppSqlFunctions),
      );
      addTearDown(db.close);

      for (final table in db.allTables) {
        final name = table.actualTableName;
        final rows = await db.customSelect("PRAGMA table_info('$name')").get();
        final onDisk = {for (final r in rows) r.read<String>('name')};
        final declared = {for (final c in table.$columns) c.name};
        expect(
          onDisk.difference(declared),
          isEmpty,
          reason: '$name has columns its Drift table does not declare',
        );
        expect(
          declared.difference(onDisk),
          isEmpty,
          reason: '$name lacks columns its Drift table declares',
        );
      }
    },
  );
}
