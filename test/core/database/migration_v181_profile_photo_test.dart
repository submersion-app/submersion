import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Minimal pre-v181 shape: divers and buddies without the photo column,
/// stamped at v180 so the upgrade to 181 runs.
NativeDatabase _dbAt180() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 180');
      rawDb.execute('''
        CREATE TABLE divers (
          id TEXT NOT NULL PRIMARY KEY
        )
      ''');
      rawDb.execute('''
        CREATE TABLE buddies (
          id TEXT NOT NULL PRIMARY KEY
        )
      ''');
      rawDb.execute("INSERT INTO divers (id) VALUES ('d1')");
      rawDb.execute("INSERT INTO buddies (id) VALUES ('b1')");
    },
  );
}

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final cols = await db.customSelect("PRAGMA table_info('$table')").get();
  return cols.map((c) => c.read<String>('name')).toSet();
}

void main() {
  test('v181 adds a nullable photo column to divers and buddies', () async {
    final db = AppDatabase(_dbAt180());
    addTearDown(() => db.close());

    expect(await _columns(db, 'divers'), contains('photo'));
    expect(await _columns(db, 'buddies'), contains('photo'));

    // Pre-existing rows survive and default to no photo.
    final diver = await db
        .customSelect("SELECT photo FROM divers WHERE id = 'd1'")
        .getSingle();
    expect(diver.data['photo'], isNull);
  });

  test('fresh databases get the photo column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await _columns(db, 'divers'), contains('photo'));
    expect(await _columns(db, 'buddies'), contains('photo'));
  });

  test('the helper no-ops when the tables are absent', () async {
    final native = NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('PRAGMA user_version = 180'),
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    await expectLater(db.customSelect('SELECT 1').get(), completes);
  });

  test('v181 is present in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(181));
    expect(AppDatabase.migrationVersions, contains(181));
  });

  test('the sync compatibility floor is not lowered', () {
    // v181 itself left the floor at 170; the packed-profile-series branch
    // later raised it to 183, so this pins only that no rung lowers it.
    expect(
      AppDatabase.minimumCompatibleSchemaVersion,
      greaterThanOrEqualTo(170),
    );
  });
}
