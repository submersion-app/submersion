import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
  });

  tearDown(() async => db.close());

  Future<Set<String>> columnsOf(String table) async {
    final rows = await db.customSelect("PRAGMA table_info('$table')").get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('v94 adds computer_id to the three attribution tables', () async {
    expect(await columnsOf('dive_tanks'), contains('computer_id'));
    expect(await columnsOf('tank_pressure_profiles'), contains('computer_id'));
    expect(await columnsOf('dive_profile_events'), contains('computer_id'));
  });

  test('schema version is 94 and the migration list includes it', () {
    // Latest-version tripwire: bumping the schema must come with a matching
    // migration block and an update here.
    expect(AppDatabase.currentSchemaVersion, 94);
    expect(AppDatabase.migrationVersions, contains(94));
  });

  test('deleting a computer nulls attribution instead of cascading', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'comp-1',
            name: 'Perdix',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-1',
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'tank-1',
            diveId: 'dive-1',
            computerId: const Value('comp-1'),
          ),
        );
    await (db.delete(
      db.diveComputers,
    )..where((t) => t.id.equals('comp-1'))).go();
    final tank = await (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('tank-1'))).getSingle();
    expect(tank.computerId, isNull);
  });
}
