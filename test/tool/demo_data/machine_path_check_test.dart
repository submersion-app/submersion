import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

import '../../../tool/demo_data/src/checks/machine_path_check.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    await db.customStatement(
      'INSERT INTO divers (id, name, notes, created_at, updated_at) '
      "VALUES ('d1', 'Alex', 'See https://example.com/a/b', 0, 0)",
    );
  });

  tearDown(() => db.close());

  test('a value naming a build folder is found', () async {
    await db.customStatement(
      "UPDATE divers SET notes = 'at /build/box/photos/reef.jpg'",
    );

    expect(await MachinePathCheck.run(db, ['/build/box']), ['divers.notes']);
  });

  test('a filesystem root is never a folder to look for', () async {
    // A home folder of `/` (some containers) would match every URL.
    expect(await MachinePathCheck.run(db, ['/']), isEmpty);
  });
}
