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
        dateTime: DateTime.utc(2026, 9, 1, 10),
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
