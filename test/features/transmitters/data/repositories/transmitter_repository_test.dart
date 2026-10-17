import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show DiveTanksCompanion;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

import '../../../../helpers/test_database.dart';

Transmitter _entry({
  String id = 't1',
  String? diverId = 'diver-1',
  String? serial = '180777',
  String? computerId,
  int? channel,
  TankRole role = TankRole.oxygenSupply,
  double? volumeL = 2.0,
  String? equipmentId,
}) => Transmitter(
  id: id,
  diverId: diverId,
  transmitterSerial: serial,
  diveComputerId: computerId,
  channelIndex: channel,
  label: 'O2',
  role: role,
  volumeL: volumeL,
  workingPressureBar: 232,
  material: TankMaterial.steel,
  presetName: null,
  equipmentId: equipmentId,
  createdAt: DateTime.utc(2026, 9, 8),
  updatedAt: DateTime.utc(2026, 9, 8),
);

void main() {
  late TransmitterRepository repo;

  Future<void> seedDiverAndDive({
    String diveId = 'd1',
    String diverId = 'diver-1',
    String? computerId,
    DateTime? dateTime,
  }) async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT OR IGNORE INTO divers (id, name, created_at, updated_at) "
      "VALUES ('$diverId', 'A', 1, 1)",
    );
    if (computerId != null) {
      await db.customStatement(
        "INSERT OR IGNORE INTO dive_computers (id, name, connection_type, "
        "created_at, updated_at) VALUES ('$computerId', 'Perdix', 'ble', 1, 1)",
      );
    }
    await DiveRepository().createDive(
      domain.Dive(
        id: diveId,
        dateTime: dateTime ?? DateTime.utc(2026, 9, 1, 10),
        diverId: diverId,
        computerId: computerId,
      ),
    );
  }

  Future<void> seedTank({
    required String id,
    required String diveId,
    String? serial,
    int order = 0,
    int? sourceIndex,
    String? computerId,
    double? volume,
    String role = 'backGas',
    String? roleSource,
    String? equipmentId,
  }) async {
    final db = DatabaseService.instance.database;
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value(id),
            diveId: Value(diveId),
            transmitterSerial: Value(serial),
            tankOrder: Value(order),
            sourceTankIndex: Value(sourceIndex),
            computerId: Value(computerId),
            volume: Value(volume),
            tankRole: Value(role),
            roleSource: Value(roleSource),
            equipmentId: Value(equipmentId),
          ),
        );
  }

  setUp(() async {
    await setUpTestDatabase();
    repo = TransmitterRepository();
  });

  tearDown(() async => tearDownTestDatabase());

  test('create normalizes the serial and round-trips every field', () async {
    await seedDiverAndDive();
    final created = await repo.create(_entry(serial: ' 180777 '));

    final loaded = await repo.getById(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.transmitterSerial, '180777');
    expect(loaded.role, TankRole.oxygenSupply);
    expect(loaded.volumeL, 2.0);
    expect(loaded.workingPressureBar, 232);
    expect(loaded.material, TankMaterial.steel);
    expect(loaded.label, 'O2');
  });

  test(
    'create refuses a second entry with the same serial for one diver',
    () async {
      await seedDiverAndDive();
      await repo.create(_entry());

      expect(
        () => repo.create(_entry(id: 't2', serial: ' 180777')),
        throwsA(isA<TransmitterConflictException>()),
      );
    },
  );

  test('create refuses an entry with neither serial nor channel', () async {
    await seedDiverAndDive();
    expect(
      () => repo.create(_entry(serial: null)),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('create refuses a duplicate (computer, channel) key', () async {
    await seedDiverAndDive(computerId: 'c1');
    await repo.create(_entry(serial: null, computerId: 'c1', channel: 1));

    expect(
      () => repo.create(
        _entry(id: 't2', serial: null, computerId: 'c1', channel: 1),
      ),
      throwsA(isA<TransmitterConflictException>()),
    );
  });

  test('getForDiver returns only that diver, label order', () async {
    await seedDiverAndDive();
    await seedDiverAndDive(diveId: 'd2', diverId: 'diver-2');
    await repo.create(_entry(id: 'a', serial: '1'));
    await repo.create(_entry(id: 'b', serial: '2', diverId: 'diver-2'));

    final mine = await repo.getForDiver('diver-1');
    expect(mine.map((t) => t.id), ['a']);
  });

  test(
    'getUnassignedSerials lists serials seen on dives with no entry',
    () async {
      await seedDiverAndDive();
      await seedDiverAndDive(diveId: 'd2');
      await seedTank(id: 'k1', diveId: 'd1', serial: '180777');
      await seedTank(id: 'k2', diveId: 'd2', serial: '180777', order: 0);
      await seedTank(id: 'k3', diveId: 'd2', serial: '109623', order: 1);
      await seedTank(id: 'k4', diveId: 'd2', serial: '000000', order: 2);
      await repo.create(_entry(serial: '109623'));

      final unassigned = await repo.getUnassignedSerials('diver-1');
      expect(unassigned, [(serial: '180777', diveCount: 2)]);
    },
  );

  test('serialCountsForComputer splits known from unassigned', () async {
    await seedDiverAndDive(computerId: 'c1');
    await seedTank(id: 'k1', diveId: 'd1', serial: '180777', computerId: 'c1');
    await seedTank(
      id: 'k2',
      diveId: 'd1',
      serial: '109623',
      order: 1,
      computerId: 'c1',
    );
    await repo.create(_entry(serial: '180777'));

    final counts = await repo.serialCountsForComputer('c1', diverId: 'diver-1');
    expect(counts, (known: 1, unassigned: 1));
  });

  test(
    'applyToExistingDives fills empty specs and only a backGas role',
    () async {
      await seedDiverAndDive();
      await seedDiverAndDive(diveId: 'd2');
      await seedTank(id: 'k1', diveId: 'd1', serial: '180777');
      await seedTank(
        id: 'k2',
        diveId: 'd2',
        serial: '180777',
        volume: 12,
        role: 'diluent',
      );
      await seedTank(id: 'k3', diveId: 'd2', serial: '109623', order: 1);
      final entry = await repo.create(_entry());

      final result = await repo.applyToExistingDives(entry);

      expect(result, (tanksUpdated: 2, divesUpdated: 2));
      final db = DatabaseService.instance.database;
      final k1 = await (db.select(
        db.diveTanks,
      )..where((t) => t.id.equals('k1'))).getSingle();
      expect(k1.volume, 2.0);
      expect(k1.workingPressure, 232);
      expect(k1.tankMaterial, 'steel');
      expect(k1.tankRole, 'oxygenSupply');
      expect(k1.tankName, 'O2');
      final k2 = await (db.select(
        db.diveTanks,
      )..where((t) => t.id.equals('k2'))).getSingle();
      expect(k2.volume, 12, reason: 'a reported volume is never overwritten');
      expect(k2.tankRole, 'diluent', reason: 'only backGas is replaced');
      expect(k2.workingPressure, 232);
      final k3 = await (db.select(
        db.diveTanks,
      )..where((t) => t.id.equals('k3'))).getSingle();
      expect(k3.volume, isNull, reason: 'another serial is untouched');
    },
  );

  test('applyToExistingDives replaces a role read off the transmitter name, '
      'even with Back Gas, and drops its source (#2595)', () async {
    await seedDiverAndDive();
    await seedDiverAndDive(diveId: 'd2');
    // A bailout the diver named "OC" was imported as the oxygen supply.
    await seedTank(
      id: 'k1',
      diveId: 'd1',
      serial: '180777',
      role: 'oxygenSupply',
      roleSource: 'transmitterName',
    );
    // The same role on a dive where the diver set it stays theirs.
    await seedTank(id: 'k2', diveId: 'd2', serial: '180777', role: 'diluent');
    final entry = await repo.create(_entry(role: TankRole.backGas));

    await repo.applyToExistingDives(entry);

    final db = DatabaseService.instance.database;
    final k1 = await (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('k1'))).getSingle();
    expect(k1.tankRole, 'backGas');
    expect(k1.roleSource, isNull);
    final k2 = await (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('k2'))).getSingle();
    expect(k2.tankRole, 'diluent');
  });

  test('applyToExistingDives confirms a name-derived role the entry agrees '
      'with (#2595)', () async {
    await seedDiverAndDive();
    await seedTank(
      id: 'k1',
      diveId: 'd1',
      serial: '180777',
      volume: 2.0,
      role: 'oxygenSupply',
      roleSource: 'transmitterName',
    );
    final entry = await repo.create(_entry());

    final result = await repo.applyToExistingDives(entry);

    expect(result.tanksUpdated, 1);
    final db = DatabaseService.instance.database;
    final k1 = await (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('k1'))).getSingle();
    expect(k1.tankRole, 'oxygenSupply');
    expect(k1.roleSource, isNull);
  });

  test(
    'applyToExistingDives matches a channel entry on the source index',
    () async {
      await seedDiverAndDive(computerId: 'c1');
      await seedTank(
        id: 'k1',
        diveId: 'd1',
        order: 0,
        sourceIndex: 1,
        computerId: 'c1',
      );
      final entry = await repo.create(
        _entry(serial: null, computerId: 'c1', channel: 1),
      );

      final result = await repo.applyToExistingDives(entry);

      expect(result.tanksUpdated, 1);
    },
  );

  test(
    'a row stored raw by sync still conflicts and still matches tanks',
    () async {
      // A peer can upsert a transmitter row without the local normalization,
      // so the repository must compare canonical forms on both sides.
      await seedDiverAndDive();
      await seedTank(id: 'k1', diveId: 'd1', serial: '180777');
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO transmitters (id, diver_id, transmitter_serial, label, "
        "tank_role, volume_l, created_at, updated_at) "
        "VALUES ('raw', 'diver-1', ' 180777 ', 'Padded', 'stage', 11.1, 1, 1)",
      );

      expect(
        () => repo.create(_entry(id: 'dup', serial: '180777')),
        throwsA(isA<TransmitterConflictException>()),
      );

      final raw = (await repo.getById('raw'))!;
      final result = await repo.applyToExistingDives(raw);
      expect(result.tanksUpdated, 1);
      final k1 = await (db.select(
        db.diveTanks,
      )..where((t) => t.id.equals('k1'))).getSingle();
      expect(k1.volume, 11.1);
    },
  );

  test(
    'lastRoleForEquipment returns the most recently dived role (#3367)',
    () async {
      final db = DatabaseService.instance.database;
      await seedDiverAndDive(dateTime: DateTime.utc(2026, 9, 1, 10));
      await seedDiverAndDive(
        diveId: 'd2',
        dateTime: DateTime.utc(2026, 9, 10, 10),
      );
      await db.customStatement(
        "INSERT INTO equipment (id, diver_id, name, type, created_at, "
        "updated_at) VALUES ('tank1', 'diver-1', 'Sidemount AL80', 'tank', "
        "1, 1)",
      );
      await seedTank(
        id: 'k1',
        diveId: 'd1',
        equipmentId: 'tank1',
        role: 'backGas',
      );
      await seedTank(
        id: 'k2',
        diveId: 'd2',
        equipmentId: 'tank1',
        role: 'sidemountLeft',
      );

      final role = await repo.lastRoleForEquipment('tank1');

      expect(role, TankRole.sidemountLeft);
    },
  );

  test(
    'lastRoleForEquipment falls back to backGas with no dive history (#3367)',
    () async {
      final role = await repo.lastRoleForEquipment('no-such-equipment');

      expect(role, TankRole.backGas);
    },
  );

  test("lastRoleForEquipment ignores another profile's history on a cylinder "
      'shared with it (#3378)', () async {
    await seedDiverAndDive(dateTime: DateTime.utc(2026, 9, 1, 10));
    await seedDiverAndDive(
      diveId: 'd2',
      diverId: 'diver-2',
      dateTime: DateTime.utc(2026, 9, 10, 10),
    );
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO equipment (id, diver_id, name, type, created_at, "
      "updated_at) VALUES ('tank1', 'diver-1', 'Shared AL80', 'tank', 1, "
      "1)",
    );
    await seedTank(
      id: 'k1',
      diveId: 'd1',
      equipmentId: 'tank1',
      role: 'backGas',
    );
    // A more recent dive on the same shared cylinder, but another
    // profile's own, which must never supply diver-1's suggested role.
    await seedTank(
      id: 'k2',
      diveId: 'd2',
      equipmentId: 'tank1',
      role: 'sidemountLeft',
    );

    final role = await repo.lastRoleForEquipment('tank1', diverId: 'diver-1');

    expect(role, TankRole.backGas);
  });

  test("lastRoleForEquipment skips a role read off the transmitter's name "
      '(#3378)', () async {
    await seedDiverAndDive(dateTime: DateTime.utc(2026, 9, 1, 10));
    await seedDiverAndDive(
      diveId: 'd2',
      dateTime: DateTime.utc(2026, 9, 10, 10),
    );
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO equipment (id, diver_id, name, type, created_at, "
      "updated_at) VALUES ('tank1', 'diver-1', 'Bailout AL40', 'tank', 1, "
      "1)",
    );
    await seedTank(
      id: 'k1',
      diveId: 'd1',
      equipmentId: 'tank1',
      role: 'bailout',
    );
    // The computer's unconfirmed guess from a name like 'OC': suggesting
    // it would let applyToExistingDives confirm it on every dive.
    await seedTank(
      id: 'k2',
      diveId: 'd2',
      equipmentId: 'tank1',
      role: 'oxygenSupply',
      roleSource: 'transmitterName',
    );

    final role = await repo.lastRoleForEquipment('tank1', diverId: 'diver-1');

    expect(role, TankRole.bailout);
  });

  test('lastRoleForEquipment ignores a planned dive (#3378)', () async {
    await seedDiverAndDive(dateTime: DateTime.utc(2026, 9, 1, 10));
    await seedDiverAndDive(
      diveId: 'd2',
      dateTime: DateTime.utc(2026, 12, 1, 10),
    );
    final db = DatabaseService.instance.database;
    await db.customStatement("UPDATE dives SET is_planned = 1 WHERE id = 'd2'");
    await db.customStatement(
      "INSERT INTO equipment (id, diver_id, name, type, created_at, "
      "updated_at) VALUES ('tank1', 'diver-1', 'AL80', 'tank', 1, 1)",
    );
    await seedTank(
      id: 'k1',
      diveId: 'd1',
      equipmentId: 'tank1',
      role: 'backGas',
    );
    await seedTank(id: 'k2', diveId: 'd2', equipmentId: 'tank1', role: 'stage');

    final role = await repo.lastRoleForEquipment('tank1', diverId: 'diver-1');

    expect(role, TankRole.backGas);
  });

  test('delete removes the row and logs a tombstone', () async {
    await seedDiverAndDive();
    final created = await repo.create(_entry());
    await repo.delete(created.id);

    expect(await repo.getById(created.id), isNull);
    final db = DatabaseService.instance.database;
    final tombstones = await db
        .customSelect(
          "SELECT COUNT(*) AS n FROM deletion_log "
          "WHERE entity_type = 'transmitters' AND record_id = '${created.id}'",
        )
        .getSingle();
    expect(tombstones.read<int>('n'), 1);
  });
}
