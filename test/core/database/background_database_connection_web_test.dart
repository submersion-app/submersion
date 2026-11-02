import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/background_database_connection_web.dart';

class _TinyDb extends GeneratedDatabase {
  _TinyDb(super.e);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;
}

/// The browser placeholder for the background connection, imported directly.
void main() {
  test('every open throws until the browser database lands', () {
    expect(() => openMainIsolateConnection('app.db'), throwsUnsupportedError);
    expect(
      () => BackgroundDatabaseConnection.open('app.db'),
      throwsUnsupportedError,
    );
    expect(
      () => BackgroundDatabaseConnection.openPlain('cache.db'),
      throwsUnsupportedError,
    );
  });

  test(
    'closeDatabaseForAppShutdown closes a database with no worker',
    () async {
      final db = _TinyDb(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();
      expect(await closeDatabaseForAppShutdown(db), isTrue);
    },
  );
}
