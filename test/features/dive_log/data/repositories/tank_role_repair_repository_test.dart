import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_role_repair_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// Issue #3307: making a name-derived "O2 supply" transmitter the bailout.
/// The computer's gas list gave the same bailout a pressureless cylinder;
/// when that cylinder is still as imported it is merged in, its switches
/// moved first because deleting a tank cascades to its switches.
void main() {
  late AppDatabase db;
  late TankRoleRepairRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    db = DatabaseService.instance.database;
    repo = TankRoleRepairRepository();
    for (final id in ['c1', 'c2']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion(
              id: Value(id),
              name: Value('Computer $id'),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
    }
    await DiveRepository().createDive(
      domain.Dive(id: 'd1', dateTime: DateTime.utc(2026, 7, 1, 10)),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<void> tank(
    String id, {
    required int order,
    required String role,
    String? roleSource,
    double o2 = 21,
    double he = 0,
    String? serial,
    String computerId = 'c1',
    double? volume,
    String? preset,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion(
          id: Value(id),
          diveId: const Value('d1'),
          tankOrder: Value(order),
          tankRole: Value(role),
          roleSource: Value(roleSource),
          o2Percent: Value(o2),
          hePercent: Value(he),
          transmitterSerial: Value(serial),
          computerId: Value(computerId),
          sourceTankIndex: Value(order),
          volume: Value(volume),
          presetName: Value(preset),
        ),
      );

  Future<void> gasSwitch(String id, int t, String tankId) => db
      .into(db.gasSwitches)
      .insert(
        GasSwitchesCompanion(
          id: Value(id),
          diveId: const Value('d1'),
          timestamp: Value(t),
          tankId: Value(tankId),
          createdAt: const Value(0),
        ),
      );

  Future<void> seed({
    double? ocVolume,
    String ocComputer = 'c1',
    String? ocPreset,
  }) async {
    await tank('dil', order: 0, role: 'diluent', o2: 10, he: 50, serial: '1');
    await tank(
      'tx',
      order: 1,
      role: 'oxygenSupply',
      roleSource: 'transmitterName',
      o2: 100,
      serial: '222',
    );
    await tank(
      'oc',
      order: 3,
      role: 'bailout',
      o2: 18,
      he: 45,
      volume: ocVolume,
      computerId: ocComputer,
      preset: ocPreset,
    );
    await gasSwitch('s1', 2400, 'oc');
    await gasSwitch('s2', 2700, 'oc');
  }

  Future<DiveTank?> row(String id) => (db.select(
    db.diveTanks,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<String>> switchTanks() async => [
    for (final s in await (db.select(
      db.gasSwitches,
    )..orderBy([(s) => OrderingTerm.asc(s.timestamp)])).get())
      s.tankId,
  ];

  test(
    're-roles, takes the OC mix and merges an as-imported cylinder',
    () async {
      await seed();
      final result = await repo.useAsBailout(
        diveId: 'd1',
        tankId: 'tx',
        ocTankId: 'oc',
      );
      expect(result, isNotNull);
      expect(result!.merged, isTrue);
      final tx = (await row('tx'))!;
      expect(tx.tankRole, 'bailout');
      expect(tx.roleSource, isNull);
      expect(tx.o2Percent, 18);
      expect(tx.hePercent, 45);
      expect(await row('oc'), isNull);
      expect(await switchTanks(), ['tx', 'tx']);
      final tombstones = await (db.select(
        db.deletionLog,
      )..where((d) => d.recordId.equals('oc'))).get();
      expect(tombstones, hasLength(1));
    },
  );

  test('keeps an OC cylinder the diver edited', () async {
    await seed(ocVolume: 11.1);
    final result = await repo.useAsBailout(
      diveId: 'd1',
      tankId: 'tx',
      ocTankId: 'oc',
    );
    expect(result!.merged, isFalse);
    expect(await row('oc'), isNotNull);
    expect(await switchTanks(), ['oc', 'oc']);
    expect((await row('tx'))!.o2Percent, 18);
  });

  test('second repair after the cylinder was merged re-roles without '
      'merging', () async {
    await seed();
    await tank(
      'tx2',
      order: 2,
      role: 'oxygenSupply',
      roleSource: 'transmitterName',
      o2: 100,
      serial: '333',
    );
    await repo.useAsBailout(diveId: 'd1', tankId: 'tx', ocTankId: 'oc');
    final second = await repo.useAsBailout(
      diveId: 'd1',
      tankId: 'tx2',
      ocTankId: 'oc',
    );
    expect(second, isNotNull);
    expect(second!.merged, isFalse);
    final tx2 = (await row('tx2'))!;
    expect(tx2.tankRole, 'bailout');
    expect(tx2.roleSource, isNull);
    expect(tx2.o2Percent, 100, reason: 'no mix to take; kept as is');
    expect(await switchTanks(), ['tx', 'tx']);
  });

  test('does not merge across computers', () async {
    await seed(ocComputer: 'c2');
    final result = await repo.useAsBailout(
      diveId: 'd1',
      tankId: 'tx',
      ocTankId: 'oc',
    );
    expect(result!.merged, isFalse);
    expect(await row('oc'), isNotNull);
    expect(await switchTanks(), ['oc', 'oc']);
  });

  test('undo restores the cylinder and its switches', () async {
    await seed();
    final result = await repo.useAsBailout(
      diveId: 'd1',
      tankId: 'tx',
      ocTankId: 'oc',
    );
    await repo.undoUseAsBailout(result!.undo);
    final tx = (await row('tx'))!;
    expect(tx.tankRole, 'oxygenSupply');
    expect(tx.roleSource, 'transmitterName');
    expect(tx.o2Percent, 100);
    final oc = (await row('oc'))!;
    expect(oc.o2Percent, 18);
    expect(oc.hePercent, 45);
    expect(await switchTanks(), ['oc', 'oc']);
  });

  test('returns null for a tank whose role the diver set', () async {
    await seed();
    await (db.update(db.diveTanks)..where((t) => t.id.equals('tx'))).write(
      const DiveTanksCompanion(roleSource: Value(null)),
    );
    final result = await repo.useAsBailout(
      diveId: 'd1',
      tankId: 'tx',
      ocTankId: 'oc',
    );
    expect(result, isNull);
    expect((await row('tx'))!.tankRole, 'oxygenSupply');
  });

  // Review: a preset the diver picked is an edit.
  test('keeps an OC cylinder the diver gave a preset', () async {
    await seed(ocPreset: 'al40');
    final result = await repo.useAsBailout(
      diveId: 'd1',
      tankId: 'tx',
      ocTankId: 'oc',
    );
    expect(result!.merged, isFalse);
    expect(await row('oc'), isNotNull);
  });

  // Review: a tombstone left behind would delete the restored cylinder on
  // other devices once it syncs.
  test('undo withdraws the merged cylinder\'s tombstone', () async {
    await seed();
    final result = await repo.useAsBailout(
      diveId: 'd1',
      tankId: 'tx',
      ocTankId: 'oc',
    );
    await repo.undoUseAsBailout(result!.undo);
    final tombstones = await (db.select(
      db.deletionLog,
    )..where((d) => d.recordId.equals('oc'))).get();
    expect(tombstones, isEmpty);
  });

  // Review: a transmitter breathed as a deco gas takes that cylinder's role,
  // not Bailout.
  test('takes the role of the OC cylinder it was breathed as', () async {
    await seed();
    await (db.update(db.diveTanks)..where((t) => t.id.equals('oc'))).write(
      const DiveTanksCompanion(
        tankRole: Value('deco'),
        o2Percent: Value(100),
        hePercent: Value(0),
      ),
    );
    await repo.useAsBailout(diveId: 'd1', tankId: 'tx', ocTankId: 'oc');
    expect((await row('tx'))!.tankRole, 'deco');
  });
}
