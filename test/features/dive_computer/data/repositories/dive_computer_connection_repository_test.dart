import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/repositories/dive_computer_connection_repository.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveComputerConnectionRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveComputerConnectionRepository();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'diver-a',
            name: 'A',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'diver-b',
            name: 'B',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    for (final (id, diver) in [('dc', 'diver-a'), ('other', 'diver-b')]) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: id,
              name: id,
              diverId: Value(diver),
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  Future<DiveComputerConnectionRow> row(String id) => (db.select(
    db.diveComputerConnections,
  )..where((t) => t.id.equals(id))).getSingle();

  Future<Set<String>> pendingIds() async => {
    for (final r in await SyncRepository().getPendingRecords())
      if (r.entityType == 'diveComputerConnections') r.recordId,
  };

  Future<Set<String>> tombstones() async => {
    for (final r in await db.select(db.deletionLog).get())
      if (r.entityType == 'diveComputerConnections') r.recordId,
  };

  group('recordConnection', () {
    test('a first use inserts the row and marks it pending', () async {
      final used = DateTime.fromMillisecondsSinceEpoch(1000);
      final c = await repository.recordConnection(
        computerId: 'dc',
        kind: DiveComputerConnectionKind.ble,
        address: 'aa:bb',
        usedAt: used,
      );
      expect(
        c.id,
        diveComputerConnectionId(
          computerId: 'dc',
          kind: DiveComputerConnectionKind.ble,
        ),
      );
      final stored = await row(c.id);
      expect(stored.firstUsedAt, 1000);
      expect(stored.lastUsedAt, 1000);
      expect(stored.localLastUsedAt, 1000);
      expect(stored.address, 'aa:bb');
      expect(stored.hlc, isNotNull);
      expect(await pendingIds(), {c.id});
    });

    test('an older use keeps the newer last use and moves first use '
        'back', () async {
      await repository.recordConnection(
        computerId: 'dc',
        kind: DiveComputerConnectionKind.file,
        detail: 'fit',
        usedAt: DateTime.fromMillisecondsSinceEpoch(5000),
      );
      final c = await repository.recordConnection(
        computerId: 'dc',
        kind: DiveComputerConnectionKind.file,
        detail: 'fit',
        usedAt: DateTime.fromMillisecondsSinceEpoch(2000),
      );
      final stored = await row(c.id);
      expect(stored.firstUsedAt, 2000);
      expect(stored.lastUsedAt, 5000);
      expect(stored.localLastUsedAt, isNull);
    });

    test('a new address replaces the stored one', () async {
      await repository.recordConnection(
        computerId: 'dc',
        kind: DiveComputerConnectionKind.ble,
        address: 'OLD',
        usedAt: DateTime.fromMillisecondsSinceEpoch(1000),
      );
      final c = await repository.recordConnection(
        computerId: 'dc',
        kind: DiveComputerConnectionKind.ble,
        address: 'NEW',
        usedAt: DateTime.fromMillisecondsSinceEpoch(2000),
      );
      final stored = await row(c.id);
      expect(stored.address, 'NEW');
      expect(stored.localLastUsedAt, 2000);
      expect(stored.lastUsedAt, 2000);
    });

    test('a re-record that changes only device-local columns stamps no '
        'clock', () async {
      final first = await repository.recordConnection(
        computerId: 'dc',
        kind: DiveComputerConnectionKind.ble,
        address: 'OLD',
        usedAt: DateTime.fromMillisecondsSinceEpoch(5000),
      );
      final hlcBefore = (await row(first.id)).hlc;
      await repository.recordConnection(
        computerId: 'dc',
        kind: DiveComputerConnectionKind.ble,
        address: 'NEW',
        // The same moment: neither synced timestamp moves, only this
        // device's address does.
        usedAt: DateTime.fromMillisecondsSinceEpoch(5000),
      );
      final stored = await row(first.id);
      expect(stored.address, 'NEW');
      expect(stored.lastUsedAt, 5000);
      expect(stored.hlc, hlcBefore);
    });
  });

  group('computerIdForLocalAddress', () {
    test('matches case-insensitively, direct kinds only, within the '
        'diver', () async {
      await repository.recordConnection(
        computerId: 'dc',
        kind: DiveComputerConnectionKind.usb,
        address: '/dev/cu.usbserial-AB12',
      );
      await repository.recordConnection(
        computerId: 'other',
        kind: DiveComputerConnectionKind.ble,
        address: 'CC:DD',
      );
      expect(
        await repository.computerIdForLocalAddress(
          address: '/DEV/CU.USBSERIAL-ab12',
          diverId: 'diver-a',
        ),
        'dc',
      );
      expect(
        await repository.computerIdForLocalAddress(
          address: 'cc:dd',
          diverId: 'diver-a',
        ),
        isNull,
      );
      expect(
        await repository.computerIdForLocalAddress(address: 'cc:dd'),
        'other',
      );
    });

    test('ignores file and cloud rows', () async {
      await db
          .into(db.diveComputerConnections)
          .insert(
            DiveComputerConnectionsCompanion.insert(
              id: 'f',
              computerId: 'dc',
              kind: 'file',
              detail: const Value('fit'),
              firstUsedAt: 1,
              lastUsedAt: 1,
              address: const Value('X'),
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      expect(await repository.computerIdForLocalAddress(address: 'X'), isNull);
    });
  });

  group('deleting', () {
    test('deleteForComputer tombstones every connection row', () async {
      final a = await repository.recordConnection(
        computerId: 'dc',
        kind: DiveComputerConnectionKind.ble,
      );
      final b = await repository.recordConnection(
        computerId: 'dc',
        kind: DiveComputerConnectionKind.file,
        detail: 'fit',
      );
      await repository.deleteForComputer('dc');
      expect(await db.select(db.diveComputerConnections).get(), isEmpty);
      expect(await tombstones(), {a.id, b.id});
    });

    test('deleting a computer tombstones its connections', () async {
      final a = await repository.recordConnection(
        computerId: 'dc',
        kind: DiveComputerConnectionKind.usb,
        address: 'PORT',
      );
      await DiveComputerRepository().deleteComputer('dc');
      expect(await tombstones(), {a.id});
    });
  });

  test('forComputer lists the newest use first', () async {
    await repository.recordConnection(
      computerId: 'dc',
      kind: DiveComputerConnectionKind.file,
      detail: 'fit',
      usedAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );
    await repository.recordConnection(
      computerId: 'dc',
      kind: DiveComputerConnectionKind.ble,
      usedAt: DateTime.fromMillisecondsSinceEpoch(9000),
    );
    final list = await repository.forComputer('dc');
    expect(list.map((c) => c.kind), [
      DiveComputerConnectionKind.ble,
      DiveComputerConnectionKind.file,
    ]);
    expect(list.last.detail, 'fit');
  });

  test('a repository given its own database writes there, not to the '
      'app\'s', () async {
    final other = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(other.close);
    await other
        .into(other.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'elsewhere',
            name: 'x',
            createdAt: 1,
            updatedAt: 1,
          ),
        );

    await DiveComputerConnectionRepository(database: other).recordConnection(
      computerId: 'elsewhere',
      kind: DiveComputerConnectionKind.usb,
      address: 'COM3',
    );

    expect(
      await other.select(other.diveComputerConnections).get(),
      hasLength(1),
    );
    expect(await db.select(db.diveComputerConnections).get(), isEmpty);
  });
}
