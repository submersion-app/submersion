import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Transmitter keys, as the transmitter edit page keeps them: a serial or a
/// computer channel behind a transmitter item, one per diver, whose setup
/// every key of the item shares.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  late List<Set<String>> refreshed;
  const t = kSeedTime;

  Future<void> gear(String id, String type, {String? serial}) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: 'Gear $id',
          type: type,
          createdAt: t,
          updatedAt: t,
          diverId: const Value(kDiverA),
          serialNumber: Value(serial),
        ),
      );

  Map<String, Object?> key(Map<String, Object?> more) => {
    'transmitter_equipment_id': 'tx',
    ...more,
  };

  Future<String> created(Map<String, Object?> fields) async =>
      (await h.run([createOp('transmitters', key(fields))])).created.single.id;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    refreshed = [];
    h = ChildWriteHarness(
      db,
      catalog: (repositories) => WriteCatalog(
        repositories,
        refreshFindings: (ids) => refreshed.add(ids.toSet()),
      ),
    );
    await h.seed();
    await gear('tx', 'transmitter');
    await gear('al80', 'tank');
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'perdix',
            name: 'Perdix',
            createdAt: t,
            updatedAt: t,
            diverId: const Value(kDiverA),
          ),
        );
  });
  tearDown(() => tearDownTestDatabase());

  test('a key is added, edited and removed', () async {
    final id = await created({
      'transmitter_serial': ' 123456 ',
      'role': 'stage',
      'equipment_id': 'al80',
    });
    final doc = (await h.one('transmitters', id))!;
    expect(doc['transmitter_serial'], '123456');
    expect(doc['label'], 'Gear tx');
    expect(doc['role'], 'stage');
    expect(doc['is_configured'], isTrue);
    expect(refreshed, [
      {'tx'},
    ]);

    await h.run([
      updateOp('transmitters', id, {'volume_l': 11.1}),
    ]);
    expect((await h.one('transmitters', id))!['volume_l'], 11.1);

    await h.run([deleteOp('transmitters', id)]);
    expect(await h.one('transmitters', id), isNull);
  });

  test('a key needs a serial or a computer channel', () async {
    final plan = await h.preview([
      createOp('transmitters', key({'role': 'backGas'})),
      createOp('transmitters', key({'channel_index': 0})),
      createOp('transmitters', key({'transmitter_serial': '000'})),
    ]);

    for (final item in plan.items) {
      expect(item.block!.reason, BlockReason.invalidValue);
    }
  });

  test('a channel round-trips as the read lists it', () async {
    final id = await created({
      'dive_computer_id': 'perdix',
      'channel_index': 0,
    });

    final again = await h.preview([
      updateOp('transmitters', id, {
        'dive_computer_id': 'perdix',
        'channel_index': 0,
      }),
    ]);

    expect(again.unchanged.single.id, id);
  });

  // No silent takeover: the agent updates the key that holds the serial.
  test('a serial another key holds is a duplicate, in a set too', () async {
    await gear('tx2', 'transmitter');
    await created({'transmitter_serial': '777'});

    final plan = await h.preview([
      createOp('transmitters', {
        'transmitter_equipment_id': 'tx2',
        'transmitter_serial': '777',
      }),
      createOp('transmitters', key({'transmitter_serial': '888'})),
      createOp('transmitters', key({'transmitter_serial': '888'})),
    ]);

    expect(plan.items.first.block!.reason, BlockReason.duplicateRecord);
    expect(plan.items.last.block!.reason, BlockReason.duplicateRecord);
  });

  test('setup fields apply to every key of the item, listed', () async {
    final first = await created({'transmitter_serial': '111'});
    await created({'dive_computer_id': 'perdix', 'channel_index': 1});

    final plan = await h.preview([
      updateOp('transmitters', first, {'role': 'deco'}),
    ]);
    expect(plan.items.single.alsoChanges, {'transmitters': 1});
    await h.apply(plan);

    final roles = {
      for (final row in await db.select(db.transmitters).get()) row.tankRole,
    };
    expect(roles, {'deco'});
  });

  test('an empty item serial takes the key\'s, listed', () async {
    final plan = await h.preview([
      createOp('transmitters', key({'transmitter_serial': '424242'})),
    ]);
    expect(plan.items.single.alsoChanges, {'equipment': 1});
    await h.apply(plan);

    expect((await h.one('equipment', 'tx'))!['serial_number'], '424242');
  });

  test('applying to past dives fills their tanks, listed', () async {
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'past',
            diveId: 'd1',
            transmitterSerial: const Value('555'),
          ),
        );

    final plan = await h.preview([
      createOp(
        'transmitters',
        key({
          'transmitter_serial': '555',
          'volume_l': 11.1,
          'apply_to_existing_dives': true,
        }),
      ),
    ]);
    expect(plan.items.single.alsoChanges['dive_tanks'], 1);
    await h.apply(plan);

    final tank = await (db.select(
      db.diveTanks,
    )..where((r) => r.id.equals('past'))).getSingle();
    expect(tank.volume, 11.1);
  });

  test('a cylinder that is not a tank is refused', () async {
    await gear('reg', 'regulator');

    final plan = await h.preview([
      createOp(
        'transmitters',
        key({'transmitter_serial': '1', 'equipment_id': 'reg'}),
      ),
      createOp('transmitters', {
        'transmitter_equipment_id': 'al80',
        'transmitter_serial': '2',
      }),
    ]);

    for (final item in plan.items) {
      expect(item.block!.reason, BlockReason.invalidValue);
    }
  });
}
