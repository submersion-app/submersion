import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

/// Issue #1064: dives downloaded before v1.6 stamped `dives.computer_id` carry
/// the attribution only on their `dive_data_sources` rows, which made them
/// invisible to the "dives from this computer" filter. The beforeOpen self-heal
/// adopts the attribution from those rows.
void main() {
  late AppDatabase db;

  const nowMs = 1750000000000;
  final nowDt = DateTime.fromMillisecondsSinceEpoch(nowMs);

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertComputer(String id) async {
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: id,
            name: 'Computer $id',
            createdAt: nowMs,
            updatedAt: nowMs,
          ),
        );
  }

  Future<void> insertDive(String id, {String? computerId}) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: const Value(nowMs),
            computerId: Value(computerId),
            createdAt: const Value(nowMs),
            updatedAt: const Value(nowMs),
          ),
        );
  }

  Future<void> insertSource(
    String id, {
    required String diveId,
    String? computerId,
    bool isPrimary = false,
  }) async {
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: id,
            diveId: diveId,
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            importedAt: nowDt,
            createdAt: nowDt,
          ),
        );
  }

  Future<String?> computerIdOf(String diveId) async {
    final row = await (db.select(
      db.dives,
    )..where((d) => d.id.equals(diveId))).getSingle();
    return row.computerId;
  }

  test('adopts the computer id from the dive data source row', () async {
    await insertComputer('dc-a');
    await insertDive('dive-legacy');
    await insertSource(
      'src-1',
      diveId: 'dive-legacy',
      computerId: 'dc-a',
      isPrimary: true,
    );

    await db.backfillDiveComputerIdsForTest();

    expect(await computerIdOf('dive-legacy'), 'dc-a');
  });

  test('leaves an already attributed dive alone', () async {
    await insertComputer('dc-a');
    await insertComputer('dc-b');
    await insertDive('dive-attributed', computerId: 'dc-a');
    await insertSource(
      'src-1',
      diveId: 'dive-attributed',
      computerId: 'dc-b',
      isPrimary: true,
    );

    await db.backfillDiveComputerIdsForTest();

    expect(await computerIdOf('dive-attributed'), 'dc-a');
  });

  test('leaves a dive with no computer-bearing source null', () async {
    await insertDive('dive-manual');
    await insertSource('src-1', diveId: 'dive-manual', isPrimary: true);

    await db.backfillDiveComputerIdsForTest();

    expect(await computerIdOf('dive-manual'), isNull);
  });

  test('prefers the primary source when a dive has several', () async {
    await insertComputer('dc-secondary');
    await insertComputer('dc-primary');
    await insertDive('dive-multi');
    // Inserted secondary-first so a query that ignored is_primary would pick
    // the wrong computer.
    await insertSource(
      'src-a-secondary',
      diveId: 'dive-multi',
      computerId: 'dc-secondary',
    );
    await insertSource(
      'src-b-primary',
      diveId: 'dive-multi',
      computerId: 'dc-primary',
      isPrimary: true,
    );

    await db.backfillDiveComputerIdsForTest();

    expect(await computerIdOf('dive-multi'), 'dc-primary');
  });

  test('breaks ties on source id so every device resolves alike', () async {
    await insertComputer('dc-x');
    await insertComputer('dc-y');
    await insertDive('dive-tie');
    // Two non-primary sources: the lower source id wins, deterministically.
    await insertSource('src-z', diveId: 'dive-tie', computerId: 'dc-y');
    await insertSource('src-a', diveId: 'dive-tie', computerId: 'dc-x');

    await db.backfillDiveComputerIdsForTest();

    expect(await computerIdOf('dive-tie'), 'dc-x');
  });

  // beforeOpen runs against minimal old-schema fixtures too, which predate the
  // computer_id columns. The PRAGMA guard must skip rather than raise
  // "no such column".
  test('skips a legacy schema that lacks the computer_id columns', () async {
    final legacy = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute(
            'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
          );
          rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
          rawDb.execute('''
            CREATE TABLE dive_data_sources (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL,
              is_primary INTEGER NOT NULL DEFAULT 0,
              imported_at INTEGER NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          rawDb.execute("INSERT INTO dives (id) VALUES ('legacy-dive')");
        },
      ),
    );
    addTearDown(legacy.close);

    // Opening is what runs beforeOpen; reaching this query means it did not
    // throw on the missing columns.
    final rows = await legacy.customSelect('SELECT id FROM dives').get();

    expect(rows.single.read<String>('id'), 'legacy-dive');
  });

  test('is idempotent across repeated opens', () async {
    await insertComputer('dc-a');
    await insertDive('dive-legacy');
    await insertSource(
      'src-1',
      diveId: 'dive-legacy',
      computerId: 'dc-a',
      isPrimary: true,
    );

    await db.backfillDiveComputerIdsForTest();
    await db.backfillDiveComputerIdsForTest();

    expect(await computerIdOf('dive-legacy'), 'dc-a');
  });
}
