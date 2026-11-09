import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show DiveTank, DiveTanksCompanion;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

import '../../../../helpers/test_database.dart';

Transmitter _entry({
  required String id,
  String? diverId = 'diver-1',
  String? serial = '76287',
  String? computerId,
  int? channel,
  TankRole role = TankRole.sidemountLeft,
  String label = 'T2',
}) => Transmitter(
  id: id,
  diverId: diverId,
  transmitterSerial: serial,
  diveComputerId: computerId,
  channelIndex: channel,
  label: label,
  role: role,
  volumeL: 10,
  workingPressureBar: 232,
  material: TankMaterial.steel,
  presetName: null,
  equipmentId: null,
  createdAt: DateTime.utc(2026, 11, 1),
  updatedAt: DateTime.utc(2026, 11, 1),
);

void main() {
  late TransmitterRepository repo;

  Future<void> seedDive(
    String diveId, {
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
    String? name,
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
            tankName: Value(name),
            o2Percent: const Value(21),
            hePercent: const Value(0),
          ),
        );
  }

  Future<DiveTank> tank(String id) {
    final db = DatabaseService.instance.database;
    return (db.select(db.diveTanks)..where((t) => t.id.equals(id))).getSingle();
  }

  setUp(() async {
    await setUpTestDatabase();
    repo = TransmitterRepository();
  });

  tearDown(() async => tearDownTestDatabase());

  group('applyToDives', () {
    test('fills a set-up transmitter onto the tanks of the given dives '
        '(issue #4388)', () async {
      await seedDive('d1');
      await seedTank(id: 'k1', diveId: 'd1', serial: ' 76287 ');
      await repo.create(_entry(id: 't2'));

      final result = await repo.applyToDives(['d1']);

      expect(result, (tanksUpdated: 1, divesUpdated: 1, mixesKept: 0));
      final k1 = await tank('k1');
      expect(k1.volume, 10);
      expect(k1.workingPressure, 232);
      expect(k1.tankMaterial, 'steel');
      expect(k1.tankRole, 'sidemountLeft');
      expect(k1.tankName, 'T2');
    });

    test('keeps what the tank already has: fill-only', () async {
      await seedDive('d1');
      await seedTank(
        id: 'k1',
        diveId: 'd1',
        serial: '76287',
        volume: 7,
        role: 'sidemountRight',
        name: 'Left bottle',
      );
      await repo.create(_entry(id: 't2'));

      await repo.applyToDives(['d1']);

      final k1 = await tank('k1');
      expect(k1.volume, 7);
      expect(k1.tankRole, 'sidemountRight');
      expect(k1.tankName, 'Left bottle');
      expect(k1.workingPressure, 232, reason: 'an empty field is filled');
    });

    test('leaves dives outside the list alone', () async {
      await seedDive('d1');
      await seedDive('d2');
      await seedTank(id: 'k1', diveId: 'd1', serial: '76287');
      await seedTank(id: 'k2', diveId: 'd2', serial: '76287');
      await repo.create(_entry(id: 't2'));

      final result = await repo.applyToDives(['d1']);

      expect(result.tanksUpdated, 1);
      expect((await tank('k2')).volume, isNull);
    });

    test('skips a transmitter the diver has not set up', () async {
      await seedDive('d1');
      await seedTank(id: 'k1', diveId: 'd1', serial: '76287');
      await repo.create(
        _entry(
          id: 'auto',
          label: 'Transmitter 76287',
        ).copyWith(isConfigured: false),
      );

      final result = await repo.applyToDives(['d1']);

      expect(result.tanksUpdated, 0);
      expect((await tank('k1')).tankName, isNull);
    });

    test("uses only the dive's own diver's transmitters", () async {
      await seedDive('mine');
      await seedDive('d1', diverId: 'diver-2');
      await seedTank(id: 'k1', diveId: 'd1', serial: '76287');
      await repo.create(_entry(id: 't2', diverId: 'diver-1'));

      final result = await repo.applyToDives(['d1']);

      expect(result.tanksUpdated, 0);
    });

    test('matches by serial only, never by channel', () async {
      await seedDive('d1', computerId: 'c1');
      await seedTank(id: 'k1', diveId: 'd1', sourceIndex: 1, computerId: 'c1');
      await repo.create(
        _entry(id: 'ch', serial: null, computerId: 'c1', channel: 1),
      );

      final result = await repo.applyToDives(['d1']);

      expect(result.tanksUpdated, 0);
    });

    test('an empty list writes nothing', () async {
      expect(await repo.applyToDives(const []), (
        tanksUpdated: 0,
        divesUpdated: 0,
        mixesKept: 0,
      ));
    });
  });
}
