import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';

import '../../helpers/test_database.dart';

/// Issue #3106: computers registered before connections existed get the
/// connections their stored data already proves, on every device alike.
void main() {
  late AppDatabase db;

  const created = 1700000000000;
  const downloaded = 1750000000000;

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertComputer(
    String id, {
    String? manufacturer,
    String? connectionType,
    String? bluetoothAddress,
    int? lastDownload,
  }) async {
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value(id),
            manufacturer: Value(manufacturer),
            connectionType: Value(connectionType),
            bluetoothAddress: Value(bluetoothAddress),
            lastDownloadTimestamp: Value(lastDownload),
            createdAt: const Value(created),
            updatedAt: const Value(created),
          ),
        );
  }

  Future<void> insertSource(
    String id, {
    required String computerId,
    String? sourceFormat,
    String? sourceFileFormat,
    required DateTime createdAt,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value('dive-$id'),
            diveDateTime: const Value(created),
            computerId: Value(computerId),
            createdAt: const Value(created),
            updatedAt: const Value(created),
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: id,
            diveId: 'dive-$id',
            computerId: Value(computerId),
            isPrimary: const Value(true),
            sourceFormat: Value(sourceFormat),
            sourceFileFormat: Value(sourceFileFormat),
            importedAt: createdAt,
            createdAt: createdAt,
          ),
        );
  }

  Future<List<DiveComputerConnectionRow>> connectionsOf(String id) =>
      (db.select(db.diveComputerConnections)
            ..where((t) => t.computerId.equals(id))
            ..orderBy([(t) => OrderingTerm.asc(t.kind)]))
          .get();

  test('a Bluetooth computer seeds one ble connection with its local '
      'address', () async {
    await insertComputer(
      'ble',
      connectionType: 'bluetooth',
      bluetoothAddress: 'AA:BB',
      lastDownload: downloaded,
    );

    expect(await db.seedDiveComputerConnectionsForTest(), 1);

    final rows = await connectionsOf('ble');
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(
      row.id,
      diveComputerConnectionId(
        computerId: 'ble',
        kind: DiveComputerConnectionKind.ble,
      ),
    );
    expect(row.kind, 'ble');
    expect(row.address, 'AA:BB');
    expect(row.firstUsedAt, created);
    expect(row.lastUsedAt, downloaded);
    expect(row.localLastUsedAt, downloaded);
    expect(row.hlc, isNull);
  });

  test('a type another device flipped does not override this device\'s '
      'address: a BLE address seeds ble, a port seeds usb', () async {
    // The laptop downloaded over USB last, so the synced type reads usb,
    // while this phone still holds its own Bluetooth identifier (the cause
    // of issue #3106 itself).
    await insertComputer(
      'phone',
      connectionType: 'usb',
      bluetoothAddress: 'C4E774E2-7D1F-DB41-EBD3-69D345D782F3',
      lastDownload: downloaded,
    );
    await insertComputer(
      'mac',
      connectionType: 'bluetooth',
      bluetoothAddress: 'AA:BB:CC:DD:EE:FF',
    );
    await insertComputer(
      'laptop',
      connectionType: 'bluetooth',
      bluetoothAddress: '/dev/cu.usbserial-A10',
    );
    await insertComputer(
      'windows',
      connectionType: 'bluetooth',
      bluetoothAddress: 'COM3',
    );

    await db.seedDiveComputerConnectionsForTest();

    expect((await connectionsOf('phone')).single.kind, 'ble');
    expect((await connectionsOf('mac')).single.kind, 'ble');
    expect((await connectionsOf('laptop')).single.kind, 'usb');
    expect((await connectionsOf('windows')).single.kind, 'usb');
  });

  test('a direct connection with no address here is not marked as used '
      'here', () async {
    await insertComputer(
      'synced',
      connectionType: 'usb',
      lastDownload: downloaded,
    );
    await db.seedDiveComputerConnectionsForTest();
    final row = (await connectionsOf('synced')).single;
    expect(row.address, isNull);
    expect(row.lastUsedAt, downloaded);
    expect(row.localLastUsedAt, isNull);
  });

  test('a Garmin cloud computer seeds cloud/garminConnect', () async {
    await insertComputer(
      'garmin',
      manufacturer: 'Garmin',
      connectionType: 'cloud',
      lastDownload: downloaded,
    );
    await db.seedDiveComputerConnectionsForTest();
    final row = (await connectionsOf('garmin')).single;
    expect(row.kind, 'cloud');
    expect(row.detail, 'garminConnect');
    expect(row.address, isNull);
  });

  test('a file-imported computer seeds one file connection per '
      'format', () async {
    await insertComputer('file');
    await insertSource(
      's1',
      computerId: 'file',
      sourceFileFormat: 'fit',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1710000000000),
    );
    await insertSource(
      's2',
      computerId: 'file',
      sourceFileFormat: 'fit',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1720000000000),
    );
    await insertSource(
      's3',
      computerId: 'file',
      sourceFileFormat: 'uddf',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1730000000000),
    );
    await insertSource(
      's4',
      computerId: 'file',
      sourceFormat: 'dive_computer',
      sourceFileFormat: 'ignored',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1730000000000),
    );

    expect(await db.seedDiveComputerConnectionsForTest(), 2);

    final rows = await connectionsOf('file');
    expect(rows.map((r) => r.detail), unorderedEquals(['fit', 'uddf']));
    final fit = rows.firstWhere((r) => r.detail == 'fit');
    expect(fit.firstUsedAt, 1710000000000);
    expect(fit.lastUsedAt, 1720000000000);
    expect(fit.localLastUsedAt, isNull);
  });

  test('a computer that already has a connection is skipped, and a second '
      'run inserts nothing', () async {
    await insertComputer('ble', connectionType: 'bluetooth');
    await insertComputer('usb', connectionType: 'usb');
    await db
        .into(db.diveComputerConnections)
        .insert(
          DiveComputerConnectionsCompanion.insert(
            id: 'existing',
            computerId: 'usb',
            kind: 'file',
            detail: const Value('uddf'),
            firstUsedAt: 1,
            lastUsedAt: 1,
            createdAt: 1,
            updatedAt: 1,
          ),
        );

    expect(await db.seedDiveComputerConnectionsForTest(), 1);
    expect(await db.seedDiveComputerConnectionsForTest(), 0);
    expect((await connectionsOf('usb')).single.id, 'existing');
  });

  test('seeded rows are not marked pending', () async {
    await insertComputer('ble', connectionType: 'bluetooth');
    await db.seedDiveComputerConnectionsForTest();
    final pending = await SyncRepository().getPendingRecords();
    expect(
      pending.where((r) => r.entityType == 'diveComputerConnections'),
      isEmpty,
    );
  });
}
