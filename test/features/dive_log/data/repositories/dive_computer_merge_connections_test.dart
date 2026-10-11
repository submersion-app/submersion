import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_merge_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3106: merging per-interface duplicates keeps every way the device
/// was downloaded, on the surviving record.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('diver-1'),
            name: Value('Diver'),
            createdAt: Value(1000),
            updatedAt: Value(1000),
          ),
        );
    for (final id in ['survivor', 'duplicate']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion(
              id: Value(id),
              diverId: const Value('diver-1'),
              name: Value(id),
              manufacturer: const Value('Shearwater'),
              model: const Value('Perdix 2'),
              serialNumber: const Value('A1B2C3D4'),
              createdAt: const Value(1000),
              updatedAt: const Value(1000),
            ),
          );
    }
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertConnection({
    required String computerId,
    required DiveComputerConnectionKind kind,
    String? detail,
    String? address,
    required int first,
    required int last,
    int? local,
  }) async {
    await db
        .into(db.diveComputerConnections)
        .insert(
          DiveComputerConnectionsCompanion.insert(
            id: diveComputerConnectionId(
              computerId: computerId,
              kind: kind,
              detail: detail,
            ),
            computerId: computerId,
            kind: kind.name,
            detail: Value(detail),
            firstUsedAt: first,
            lastUsedAt: last,
            address: Value(address),
            localLastUsedAt: Value(local),
            createdAt: first,
            updatedAt: last,
          ),
        );
  }

  test('a shared connection folds into the survivor\'s row and a new one '
      'moves over; the duplicate\'s rows are tombstoned', () async {
    await insertConnection(
      computerId: 'survivor',
      kind: DiveComputerConnectionKind.ble,
      first: 10,
      last: 10,
    );
    await insertConnection(
      computerId: 'duplicate',
      kind: DiveComputerConnectionKind.ble,
      address: 'AA',
      first: 5,
      last: 20,
      local: 20,
    );
    await insertConnection(
      computerId: 'duplicate',
      kind: DiveComputerConnectionKind.file,
      detail: 'shearwaterDb',
      first: 3,
      last: 4,
    );

    await DiveComputerMergeRepository().mergeComputers(
      survivorId: 'survivor',
      duplicateIds: ['duplicate'],
    );

    final rows = await db.select(db.diveComputerConnections).get();
    expect(rows.every((r) => r.computerId == 'survivor'), isTrue);
    expect(
      rows.map((r) => (r.kind, r.detail)),
      unorderedEquals([('ble', null), ('file', 'shearwaterDb')]),
    );
    final ble = rows.firstWhere((r) => r.kind == 'ble');
    expect(ble.firstUsedAt, 5);
    expect(ble.lastUsedAt, 20);
    expect(ble.localLastUsedAt, 20);
    expect(ble.address, 'AA');

    final tombstoned = {
      for (final r in await db.select(db.deletionLog).get())
        if (r.entityType == 'diveComputerConnections') r.recordId,
    };
    expect(tombstoned, {
      diveComputerConnectionId(
        computerId: 'duplicate',
        kind: DiveComputerConnectionKind.ble,
      ),
      diveComputerConnectionId(
        computerId: 'duplicate',
        kind: DiveComputerConnectionKind.file,
        detail: 'shearwaterDb',
      ),
    });
  });

  test('the address this device used most recently wins the fold', () async {
    await insertConnection(
      computerId: 'survivor',
      kind: DiveComputerConnectionKind.ble,
      address: 'OLD-ID',
      first: 1,
      last: 10,
      local: 10,
    );
    await insertConnection(
      computerId: 'duplicate',
      kind: DiveComputerConnectionKind.ble,
      address: 'CURRENT-ID',
      first: 2,
      last: 30,
      local: 30,
    );

    await DiveComputerMergeRepository().mergeComputers(
      survivorId: 'survivor',
      duplicateIds: ['duplicate'],
    );

    final row = (await db.select(db.diveComputerConnections).get()).single;
    expect(row.address, 'CURRENT-ID');
    expect(row.localLastUsedAt, 30);
  });
}
