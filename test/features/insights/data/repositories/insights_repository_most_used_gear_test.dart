import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

/// Most used gear counts a cylinder linked only through the transmitter
/// registry (`dive_tanks.equipment_id`), and a dive carrying the same
/// item through both paths counts once (condition phase 4b).
void main() {
  late AppDatabase db;
  late InsightsRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> equipment(String id, String type) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: type,
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  Future<void> dive(String id, int day) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diveDateTime: DateTime.utc(2026, 1, day).millisecondsSinceEpoch,
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  Future<void> link(String diveId, String equipmentId) => db
      .into(db.diveEquipment)
      .insert(
        DiveEquipmentCompanion.insert(diveId: diveId, equipmentId: equipmentId),
      );

  Future<void> tank(String id, String diveId, String equipmentId) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion.insert(
          id: id,
          diveId: diveId,
        ).copyWith(equipmentId: Value(equipmentId)),
      );

  test('cylinders count through dive tanks, once per dive', () async {
    await equipment('al80', 'tank');
    await equipment('reg', 'regulator');
    await dive('d1', 1);
    await dive('d2', 2);
    await tank('k1', 'd1', 'al80');
    await tank('k2', 'd2', 'al80');
    await link('d1', 'reg');
    // The regulator also rides a tank row on d1: still one dive.
    await tank('k3', 'd1', 'reg');

    final ranking = await repository.getMostUsedGear();
    expect(ranking.map((r) => '${r.id}:${r.count}'), ['al80:2', 'reg:1']);
  });

  test('reports hours in value, each dive once', () async {
    await equipment('reg', 'regulator');
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: 1000,
            createdAt: 1,
            updatedAt: 1,
          ).copyWith(runtime: const Value(5400)),
        );
    await link('d1', 'reg');
    await tank('k1', 'd1', 'reg');

    final ranking = await repository.getMostUsedGear();
    expect(ranking.single.count, 1);
    expect(ranking.single.value, 1.5);
  });

  test('a null limit returns every item, the default stops at ten', () async {
    for (var i = 0; i < 12; i++) {
      await equipment('e$i', 'other');
      await dive('d$i', i + 1);
      await link('d$i', 'e$i');
    }

    expect(await repository.getMostUsedGear(limit: null), hasLength(12));
    expect(await repository.getMostUsedGear(), hasLength(10));
  });

  test('a registered transmitter serial counts', () async {
    await equipment('tx', 'transmitter');
    await dive('d1', 1);
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'k1',
            diveId: 'd1',
          ).copyWith(transmitterSerial: const Value('A1')),
        );
    await db
        .into(db.transmitters)
        .insert(
          TransmittersCompanion.insert(
            id: 't1',
            label: 't1',
            tankRole: 'backGas',
            createdAt: 1,
            updatedAt: 1,
            transmitterSerial: const Value('A1'),
            transmitterEquipmentId: const Value('tx'),
          ),
        );

    final ranking = await repository.getMostUsedGear();
    expect(ranking.single.id, 'tx');
  });

  test('tank regulators count, first and extra (#3375)', () async {
    await equipment('r1', 'regulator');
    await equipment('r2', 'regulator');
    await dive('d1', 1);
    await dive('d2', 2);
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(id: 'k1', diveId: 'd1').copyWith(
            regulatorEquipmentId: const Value('r1'),
            extraRegulatorIds: const Value('["r2"]'),
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'k2',
            diveId: 'd2',
          ).copyWith(regulatorEquipmentId: const Value('r1')),
        );

    final ranking = await repository.getMostUsedGear();
    expect(ranking.map((r) => '${r.id}:${r.count}'), ['r1:2', 'r2:1']);
  });
}
