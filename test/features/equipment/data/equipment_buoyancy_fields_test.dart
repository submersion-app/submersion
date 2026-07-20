import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EquipmentRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = EquipmentRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  EquipmentItem suit() => EquipmentItem(
    id: '',
    name: '7mm Wetsuit',
    type: EquipmentType.wetsuit,
    attributes: [
      EquipmentAttribute.curated(
        equipmentId: '',
        key: 'buoyancy_kg',
        valueNum: -2.5,
      ),
      EquipmentAttribute.curated(
        equipmentId: '',
        key: 'dry_weight_kg',
        valueNum: 3.0,
      ),
    ],
  );

  test('buoyancyKg and weightKg round-trip through create/getById', () async {
    final created = await repository.createEquipment(suit());
    final loaded = await repository.getEquipmentById(created.id);
    expect(loaded!.buoyancyKg, -2.5);
    expect(loaded.weightKg, 3.0);
  });

  test('fields survive updateEquipment', () async {
    final created = await repository.createEquipment(suit());
    await repository.updateEquipment(
      created.copyWith(
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: created.id,
            key: 'buoyancy_kg',
            valueNum: 4.0,
          ),
          EquipmentAttribute.curated(
            equipmentId: created.id,
            key: 'dry_weight_kg',
            valueNum: 2.0,
          ),
        ],
      ),
    );
    final loaded = await repository.getEquipmentById(created.id);
    expect(loaded!.buoyancyKg, 4.0);
    expect(loaded.weightKg, 2.0);
  });

  test('searchEquipment mapping carries the fields', () async {
    await repository.createEquipment(suit());
    final results = await repository.searchEquipment('7mm');
    expect(results.single.buoyancyKg, -2.5);
    expect(results.single.weightKg, 3.0);
  });

  test('dive batch equipment join carries the fields', () async {
    final created = await repository.createEquipment(suit());
    final diveRepository = DiveRepository();
    final dive = await diveRepository.createDive(
      Dive(
        id: '',
        diveNumber: 1,
        dateTime: DateTime(2026, 1, 1),
        equipment: [created],
      ),
    );
    final loaded = await diveRepository.getDiveById(dive.id);
    expect(loaded!.equipment.single.buoyancyKg, -2.5);
    expect(loaded.equipment.single.weightKg, 3.0);
  });

  test('liftCapacityKg round-trips and carries through the dive join', () async {
    final wing = await repository.createEquipment(
      EquipmentItem(
        id: '',
        name: 'Wing 18',
        type: EquipmentType.bcd,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: '',
            key: EquipmentAttrKeys.liftCapacityKg,
            valueNum: 18.0,
          ),
        ],
      ),
    );
    final loaded = await repository.getEquipmentById(wing.id);
    expect(loaded!.liftCapacityKg, 18.0);

    // The buoyancy twin reads liftCapacityKg off dive-joined equipment, so the
    // curated attribute must survive the dive equipment hydration path.
    final diveRepository = DiveRepository();
    final dive = await diveRepository.createDive(
      Dive(
        id: '',
        diveNumber: 2,
        dateTime: DateTime(2026, 1, 2),
        equipment: [loaded],
      ),
    );
    final loadedDive = await diveRepository.getDiveById(dive.id);
    expect(loadedDive!.equipment.single.liftCapacityKg, 18.0);
  });
}
