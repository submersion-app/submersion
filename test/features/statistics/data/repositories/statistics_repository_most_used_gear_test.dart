import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../../helpers/test_database.dart';

/// Most used gear counts a cylinder linked only through the transmitter
/// registry (`dive_tanks.equipment_id`), and a dive carrying the same
/// item through both paths counts once (condition phase 4b).
void main() {
  late AppDatabase db;
  late StatisticsRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = StatisticsRepository();
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
}
