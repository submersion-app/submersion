import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show DiveTank, DiveTanksCompanion, GasSwitchesCompanion;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
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
    double o2 = 21,
    double he = 0,
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
            o2Percent: Value(o2),
            hePercent: Value(he),
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

  test('serialCountsForComputer counts an entry a download created, or one '
      'naming no cylinder, as unassigned (issue #3676)', () async {
    await seedDiverAndDive(computerId: 'c1');
    for (final (i, serial) in ['180777', '109623', '555111'].indexed) {
      await seedTank(
        id: 'k$i',
        diveId: 'd1',
        serial: serial,
        order: i,
        computerId: 'c1',
      );
    }
    await repo.create(_entry(id: 'set-up', serial: '180777'));
    await repo.create(
      _entry(id: 'auto', serial: '109623').copyWith(isConfigured: false),
    );
    await repo.create(
      _entry(id: 'no-cylinder', serial: '555111', volumeL: null),
    );

    final counts = await repo.serialCountsForComputer('c1', diverId: 'diver-1');
    expect(counts, (known: 1, unassigned: 2));
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

      expect(result, (tanksUpdated: 2, divesUpdated: 2, mixesKept: 0));
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

  // #3307: a bailout entry applied to past dives must not leave each "OC"
  // transmitter on the 100% default beside a duplicate bailout cylinder.
  group('applying a bailout entry fixes the mix', () {
    Future<void> seedOcDive() async {
      await seedDiverAndDive();
      await seedTank(
        id: 'k1',
        diveId: 'd1',
        serial: '180777',
        sourceIndex: 0,
        role: 'oxygenSupply',
        roleSource: 'transmitterName',
        o2: 100,
      );
      await seedTank(
        id: 'dil',
        diveId: 'd1',
        serial: '111',
        order: 1,
        sourceIndex: 1,
        role: 'diluent',
        o2: 10,
        he: 50,
      );
      await seedTank(
        id: 'oc',
        diveId: 'd1',
        order: 3,
        sourceIndex: 3,
        role: 'bailout',
        o2: 18,
        he: 45,
      );
    }

    Future<DiveTank?> tankRow(String id) {
      final db = DatabaseService.instance.database;
      return (db.select(
        db.diveTanks,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
    }

    test('from the OC cylinder that was breathed', () async {
      await seedOcDive();
      final db = DatabaseService.instance.database;
      await db
          .into(db.gasSwitches)
          .insert(
            const GasSwitchesCompanion(
              id: Value('s1'),
              diveId: Value('d1'),
              timestamp: Value(2400),
              tankId: Value('oc'),
              createdAt: Value(0),
            ),
          );
      await TankPressureRepository().insertTankPressures('d1', {
        'k1': [
          for (var t = 0; t <= 3000; t += 10)
            (
              timestamp: t,
              pressure: t < 2400 ? 200.0 : 200.0 - (t - 2400) / 10,
            ),
        ],
      });
      final entry = await repo.create(_entry(role: TankRole.bailout));

      final result = await repo.applyToExistingDives(entry);

      final k1 = (await tankRow('k1'))!;
      expect(k1.tankRole, 'bailout');
      expect(k1.roleSource, isNull);
      expect(k1.o2Percent, 18);
      expect(k1.hePercent, 45);
      expect(await tankRow('oc'), isNull);
      expect(result.mixesKept, 0);
    });

    test('falls back to the single sensorless bailout', () async {
      await seedOcDive();
      final entry = await repo.create(_entry(role: TankRole.bailout));

      final result = await repo.applyToExistingDives(entry);

      final k1 = (await tankRow('k1'))!;
      expect(k1.o2Percent, 18);
      expect(await tankRow('oc'), isNull);
      expect(result.mixesKept, 0);
    });

    test('keeps the mix and counts it when there is no source', () async {
      await seedDiverAndDive();
      await seedTank(
        id: 'k1',
        diveId: 'd1',
        serial: '180777',
        sourceIndex: 0,
        role: 'oxygenSupply',
        roleSource: 'transmitterName',
        o2: 100,
      );
      final entry = await repo.create(_entry(role: TankRole.bailout));

      final result = await repo.applyToExistingDives(entry);

      final k1 = (await tankRow('k1'))!;
      expect(k1.tankRole, 'bailout');
      expect(k1.o2Percent, 100);
      expect(result.mixesKept, 1);
    });

    // Review: the other computer's bailout cylinder is not this
    // transmitter's gas.
    test(
      'picks the single bailout of the transmitter\'s own computer',
      () async {
        await seedDiverAndDive(computerId: 'c1');
        final db = DatabaseService.instance.database;
        await db.customStatement(
          "INSERT OR IGNORE INTO dive_computers (id, name, connection_type, "
          "created_at, updated_at) VALUES ('c2', 'Petrel', 'ble', 1, 1)",
        );
        await seedTank(
          id: 'k1',
          diveId: 'd1',
          serial: '180777',
          sourceIndex: 0,
          computerId: 'c1',
          role: 'oxygenSupply',
          roleSource: 'transmitterName',
          o2: 100,
        );
        await seedTank(
          id: 'oc1',
          diveId: 'd1',
          order: 3,
          sourceIndex: 3,
          computerId: 'c1',
          role: 'bailout',
          o2: 18,
          he: 45,
        );
        await seedTank(
          id: 'oc2',
          diveId: 'd1',
          order: 4,
          sourceIndex: 3,
          computerId: 'c2',
          role: 'bailout',
          o2: 21,
        );
        final entry = await repo.create(_entry(role: TankRole.bailout));

        final result = await repo.applyToExistingDives(entry);

        expect((await tankRow('k1'))!.o2Percent, 18);
        expect(await tankRow('oc1'), isNull);
        expect(await tankRow('oc2'), isNotNull);
        expect(result.mixesKept, 0);
      },
    );

    test('counts kept mixes per dive, not per tank', () async {
      await seedDiverAndDive();
      for (final id in ['k1', 'k2']) {
        await seedTank(
          id: id,
          diveId: 'd1',
          serial: '180777',
          order: id == 'k1' ? 0 : 1,
          sourceIndex: id == 'k1' ? 0 : 1,
          role: 'oxygenSupply',
          roleSource: 'transmitterName',
          o2: 100,
        );
      }
      final entry = await repo.create(_entry(role: TankRole.bailout));

      final result = await repo.applyToExistingDives(entry);

      expect(result.mixesKept, 1);
    });

    // Review: two computers on one transmitter each logged a series. Its
    // own computer (c1) saw it drain on the loop like an O2 supply; only
    // the other computer's series looks like a bailout, and must not count.
    test(
      'reads the pressure series of the transmitter\'s own computer',
      () async {
        await seedDiverAndDive(computerId: 'c1');
        final db = DatabaseService.instance.database;
        await db.customStatement(
          "INSERT OR IGNORE INTO dive_computers (id, name, connection_type, "
          "created_at, updated_at) VALUES ('c2', 'Petrel', 'ble', 1, 1)",
        );
        await seedTank(
          id: 'k1',
          diveId: 'd1',
          serial: '180777',
          sourceIndex: 0,
          computerId: 'c1',
          role: 'oxygenSupply',
          roleSource: 'transmitterName',
          o2: 100,
        );
        for (final (id, o2, he, order) in [
          ('oc1', 18.0, 45.0, 3),
          ('oc2', 21.0, 0.0, 4),
        ]) {
          await seedTank(
            id: id,
            diveId: 'd1',
            order: order,
            sourceIndex: order,
            computerId: 'c1',
            role: 'bailout',
            o2: o2,
            he: he,
          );
        }
        await db
            .into(db.gasSwitches)
            .insert(
              const GasSwitchesCompanion(
                id: Value('s1'),
                diveId: Value('d1'),
                timestamp: Value(2400),
                tankId: Value('oc1'),
                computerId: Value('c1'),
                createdAt: Value(0),
              ),
            );
        await TankPressureRepository().insertTankSeries('d1', [
          (
            tankId: 'k1',
            sourceId: null,
            computerId: 'c1',
            samples: [
              for (var t = 0; t <= 3000; t += 10)
                (timestamp: t, pressure: 200.0 - t / 120),
            ],
          ),
          (
            tankId: 'k1',
            sourceId: null,
            computerId: 'c2',
            samples: [
              for (var t = 0; t <= 3000; t += 10)
                (
                  timestamp: t,
                  pressure: t < 2400 ? 200.0 : 200.0 - (t - 2400) / 10,
                ),
            ],
          ),
        ]);
        final entry = await repo.create(_entry(role: TankRole.bailout));

        final result = await repo.applyToExistingDives(entry);

        expect((await tankRow('k1'))!.o2Percent, 100);
        expect(result.mixesKept, 1);
      },
    );

    // Review: a Deco entry (the repair registers the role it chose) must
    // replace the 100% default too.
    test(
      'a Deco entry fixes the mix from the deco cylinder breathed',
      () async {
        await seedDiverAndDive();
        await seedTank(
          id: 'k1',
          diveId: 'd1',
          serial: '180777',
          sourceIndex: 0,
          role: 'oxygenSupply',
          roleSource: 'transmitterName',
          o2: 100,
        );
        await seedTank(
          id: 'deco',
          diveId: 'd1',
          order: 3,
          sourceIndex: 3,
          role: 'deco',
          o2: 50,
        );
        final db = DatabaseService.instance.database;
        await db
            .into(db.gasSwitches)
            .insert(
              const GasSwitchesCompanion(
                id: Value('s1'),
                diveId: Value('d1'),
                timestamp: Value(2400),
                tankId: Value('deco'),
                createdAt: Value(0),
              ),
            );
        await TankPressureRepository().insertTankPressures('d1', {
          'k1': [
            for (var t = 0; t <= 3000; t += 10)
              (
                timestamp: t,
                pressure: t < 2400 ? 200.0 : 200.0 - (t - 2400) / 10,
              ),
          ],
        });
        final entry = await repo.create(_entry(role: TankRole.deco));

        final result = await repo.applyToExistingDives(entry);

        final k1 = (await tankRow('k1'))!;
        expect(k1.tankRole, 'deco');
        expect(k1.o2Percent, 50);
        expect(result.mixesKept, 0);
      },
    );
  });
}
