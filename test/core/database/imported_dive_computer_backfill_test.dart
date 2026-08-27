import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/imported_computer_identity.dart';

import '../../helpers/test_database.dart';

/// Issue #1288: dives created by a file import carry only the
/// `dive_computer_model`/`_serial` display snapshots. Nothing ever registered
/// a `dive_computers` row for them, so a logbook built entirely from files
/// named a computer on every dive and still reported "No dive computers
/// registered" in the filter, which reads the registry.
///
/// The #1064 self-heal cannot reach these: it adopts `computer_id` from
/// `dive_data_sources`, and a file import leaves that null too. This one
/// registers the device from the snapshots instead.
void main() {
  late AppDatabase db;

  const nowMs = 1750000000000;

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDiver(String id) async {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value('Diver $id'),
            createdAt: const Value(nowMs),
            updatedAt: const Value(nowMs),
          ),
        );
  }

  Future<void> insertDive(
    String id, {
    String? computerId,
    String? model,
    String? serial,
    String? diverId,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            diveDateTime: const Value(nowMs),
            computerId: Value(computerId),
            diveComputerModel: Value(model),
            diveComputerSerial: Value(serial),
            createdAt: const Value(nowMs),
            updatedAt: const Value(nowMs),
          ),
        );
  }

  Future<void> insertComputer(
    String id, {
    String? diverId,
    String? manufacturer,
    String? model,
    String? serial,
  }) async {
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            diverId: Value(diverId),
            name: Value('Computer $id'),
            manufacturer: Value(manufacturer),
            model: Value(model),
            serialNumber: Value(serial),
            createdAt: const Value(nowMs),
            updatedAt: const Value(nowMs),
          ),
        );
  }

  Future<void> insertDataSource(
    String id, {
    required String diveId,
    String? computerId,
    String? sourceFormat,
    String? sourceFileFormat,
  }) async {
    final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: id,
            diveId: diveId,
            computerId: Value(computerId),
            isPrimary: const Value(true),
            sourceFormat: Value(sourceFormat),
            sourceFileFormat: Value(sourceFileFormat),
            importedAt: now,
            createdAt: now,
          ),
        );
  }

  Future<void> logDeletion(String recordId) async {
    await db
        .into(db.deletionLog)
        .insert(
          DeletionLogCompanion.insert(
            id: 'del-$recordId',
            entityType: 'diveComputers',
            recordId: recordId,
            deletedAt: nowMs,
          ),
        );
  }

  Future<String?> computerIdOf(String diveId) async {
    final row = await (db.select(
      db.dives,
    )..where((d) => d.id.equals(diveId))).getSingle();
    return row.computerId;
  }

  test(
    'registers a computer for a file-imported dive and attributes it',
    () async {
      await insertDiver('diver-1');
      await insertDive(
        'dive-1',
        model: 'Perdix 2',
        serial: 'SN-1',
        diverId: 'diver-1',
      );

      await db.backfillImportedDiveComputersForTest();

      final computer = (await db.select(db.diveComputers).get()).single;
      expect(computer.model, 'Perdix 2');
      expect(computer.serialNumber, 'SN-1');
      expect(computer.diverId, 'diver-1');
      expect(computer.name, 'Perdix 2');
      expect(await computerIdOf('dive-1'), computer.id);
    },
  );

  test(
    'registers one computer for many dives naming the same device',
    () async {
      await insertDive('dive-1', model: 'Perdix 2', serial: 'SN-1');
      await insertDive('dive-2', model: 'Perdix 2', serial: 'SN-1');
      await insertDive('dive-3', model: 'Perdix 2', serial: 'SN-1');

      await db.backfillImportedDiveComputersForTest();

      final computers = await db.select(db.diveComputers).get();
      expect(computers, hasLength(1));
      for (final id in ['dive-1', 'dive-2', 'dive-3']) {
        expect(await computerIdOf(id), computers.single.id);
      }
    },
  );

  test('registers a computer per distinct device', () async {
    await insertDive('dive-1', model: 'Perdix 2', serial: 'SN-1');
    await insertDive('dive-2', model: 'Teric', serial: 'SN-2');

    await db.backfillImportedDiveComputersForTest();

    expect(await db.select(db.diveComputers).get(), hasLength(2));
  });

  test('leaves a dive that names no computer alone', () async {
    await insertDive('dive-manual');

    await db.backfillImportedDiveComputersForTest();

    expect(await db.select(db.diveComputers).get(), isEmpty);
    expect(await computerIdOf('dive-manual'), isNull);
  });

  test('ignores a blank model string', () async {
    await insertDive('dive-blank', model: '   ');

    await db.backfillImportedDiveComputersForTest();

    expect(await db.select(db.diveComputers).get(), isEmpty);
    expect(await computerIdOf('dive-blank'), isNull);
  });

  test('leaves an already attributed dive alone', () async {
    await insertComputer('dc-a', model: 'Something Else');
    await insertDive(
      'dive-attributed',
      computerId: 'dc-a',
      model: 'Perdix 2',
      serial: 'SN-1',
    );

    await db.backfillImportedDiveComputersForTest();

    expect(await computerIdOf('dive-attributed'), 'dc-a');
    expect(await db.select(db.diveComputers).get(), hasLength(1));
  });

  test('adopts a computer already registered by a download', () async {
    // The device was downloaded over BLE and later the same dives arrived in
    // a file. Minting a second row would split one physical computer in two,
    // and there is no merge action to undo that.
    await insertDiver('diver-1');
    await insertComputer(
      'downloaded',
      diverId: 'diver-1',
      manufacturer: 'Shearwater',
      model: 'Perdix 2',
      serial: 'SN-1',
    );
    await insertDive(
      'dive-1',
      model: 'Shearwater Perdix 2',
      serial: 'SN-1',
      diverId: 'diver-1',
    );

    await db.backfillImportedDiveComputersForTest();

    expect(await db.select(db.diveComputers).get(), hasLength(1));
    expect(await computerIdOf('dive-1'), 'downloaded');
  });

  test(
    'registers at the deterministic id so a synced fleet converges',
    () async {
      await insertDiver('diver-1');
      await insertDive(
        'dive-1',
        model: 'Perdix 2',
        serial: 'SN-1',
        diverId: 'diver-1',
      );

      await db.backfillImportedDiveComputersForTest();

      expect(
        (await db.select(db.diveComputers).get()).single.id,
        importedDiveComputerId(
          diverId: 'diver-1',
          model: 'Perdix 2',
          serialNumber: 'SN-1',
        ),
      );
    },
  );

  test('does not queue sync work: every device heals independently', () async {
    await insertDive('dive-1', model: 'Perdix 2', serial: 'SN-1');

    await db.backfillImportedDiveComputersForTest();

    // Deterministic ids mean each device derives the same row locally, so
    // pushing them would be pure duplicate traffic (and a rename made on one
    // device must not be clobbered by another device's backfill).
    expect(await db.select(db.syncRecords).get(), isEmpty);
  });

  test('is idempotent across repeated opens', () async {
    await insertDive('dive-1', model: 'Perdix 2', serial: 'SN-1');

    await db.backfillImportedDiveComputersForTest();
    final firstId = await computerIdOf('dive-1');
    await db.backfillImportedDiveComputersForTest();

    expect(await db.select(db.diveComputers).get(), hasLength(1));
    expect(await computerIdOf('dive-1'), firstId);
  });

  test('collapses spelling noise onto one registration', () async {
    await insertDive('dive-1', model: 'Perdix 2', serial: 'SN-1');
    await insertDive('dive-2', model: '  PERDIX   2 ', serial: ' sn-1 ');

    await db.backfillImportedDiveComputersForTest();

    final computers = await db.select(db.diveComputers).get();
    expect(computers, hasLength(1));
    expect(await computerIdOf('dive-2'), computers.single.id);
  });

  // beforeOpen runs against minimal old-schema fixtures too. The PRAGMA guard
  // must skip rather than raise "no such column".
  test('skips a legacy schema that lacks the snapshot columns', () async {
    final legacy = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute(
            'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
          );
          rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
          rawDb.execute("INSERT INTO dives (id) VALUES ('legacy-dive')");
        },
      ),
    );
    addTearDown(legacy.close);

    final rows = await legacy.customSelect('SELECT id FROM dives').get();

    expect(rows.single.read<String>('id'), 'legacy-dive');
  });

  // deleteComputer nulls dives.computer_id and writes a tombstone, but leaves
  // the dive_computer_model/_serial snapshots in place by design. Those are
  // exactly the rows this backfill claims, so without a guard a deliberate
  // delete would not survive the next app open.
  group('respects a deliberate delete', () {
    test('does not resurrect a tombstoned computer', () async {
      await insertDiver('diver-1');
      await insertDive(
        'dive-1',
        model: 'Perdix 2',
        serial: 'SN-1',
        diverId: 'diver-1',
      );
      // The row the user deleted was registered at the deterministic id, so
      // re-minting it would resurrect a tombstoned primary key: the peer that
      // applied the delete would just delete it again, forever.
      await logDeletion(
        importedDiveComputerId(
          diverId: 'diver-1',
          model: 'Perdix 2',
          serialNumber: 'SN-1',
        ),
      );

      await db.backfillImportedDiveComputersForTest();

      expect(await db.select(db.diveComputers).get(), isEmpty);
      expect(await computerIdOf('dive-1'), isNull);
    });

    test('does not invent a computer for a downloaded dive', () async {
      // The download path stamps the same model/serial snapshots onto every
      // dive it writes. After its computer is deleted, those snapshots must
      // not conjure a phantom device, which would also be a corrupted copy:
      // the snapshot is the combined full name, with no manufacturer.
      await insertDive(
        'dive-downloaded',
        model: 'Shearwater Perdix',
        serial: 'SN-123',
      );
      await insertDataSource(
        'src-1',
        diveId: 'dive-downloaded',
        sourceFormat: 'dive_computer',
      );

      await db.backfillImportedDiveComputersForTest();

      expect(await db.select(db.diveComputers).get(), isEmpty);
      expect(await computerIdOf('dive-downloaded'), isNull);
    });

    test('still registers a file-imported dive alongside a download', () async {
      await insertDive(
        'dive-downloaded',
        model: 'Shearwater Perdix',
        serial: 'SN-123',
      );
      await insertDataSource(
        'src-1',
        diveId: 'dive-downloaded',
        sourceFormat: 'dive_computer',
      );
      await insertDive('dive-imported', model: 'Suunto D5');
      await insertDataSource(
        'src-2',
        diveId: 'dive-imported',
        sourceFileFormat: 'uddf',
      );

      await db.backfillImportedDiveComputersForTest();

      final computers = await db.select(db.diveComputers).get();
      expect(computers, hasLength(1));
      expect(computers.single.model, 'Suunto D5');
      expect(await computerIdOf('dive-imported'), computers.single.id);
      expect(await computerIdOf('dive-downloaded'), isNull);
    });
  });
}
