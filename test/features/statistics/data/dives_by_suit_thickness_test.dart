import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  late StatisticsRepository stats;
  late DiveRepository diveRepo;
  late EquipmentRepository equipmentRepo;

  setUp(() async {
    await setUpTestDatabase();
    stats = StatisticsRepository();
    diveRepo = DiveRepository();
    equipmentRepo = EquipmentRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  Future<EquipmentItem> suit(String id, String designation, double mm) =>
      equipmentRepo.createEquipment(
        EquipmentItem(
          id: id,
          name: 'Suit $designation',
          type: EquipmentType.wetsuit,
          attributes: [
            EquipmentAttribute.curated(
              equipmentId: id,
              key: 'thickness_mm',
              valueText: designation,
              valueNum: mm,
            ),
          ],
        ),
      );

  test('groups dives by linked suit primary thickness', () async {
    final suit54 = await suit('s54', '5/4', 5.0);
    final suit3 = await suit('s3', '3', 3.0);

    await diveRepo.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime(2026, 1, 1),
        equipment: [suit54],
      ),
    );
    await diveRepo.createDive(
      domain.Dive(
        id: 'd2',
        dateTime: DateTime(2026, 1, 2),
        equipment: [suit54],
      ),
    );
    await diveRepo.createDive(
      domain.Dive(id: 'd3', dateTime: DateTime(2026, 1, 3), equipment: [suit3]),
    );
    // A dive without a suit does not appear in any bucket.
    await diveRepo.createDive(
      domain.Dive(id: 'd4', dateTime: DateTime(2026, 1, 4)),
    );

    final result = await stats.getDivesBySuitThickness();
    expect(result, [(mm: 3.0, count: 1), (mm: 5.0, count: 2)]);
  });
}
