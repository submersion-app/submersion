import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../helpers/test_database.dart';

void main() {
  late EquipmentRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = EquipmentRepository();
  });
  tearDown(tearDownTestDatabase);

  EquipmentItem suit({List<EquipmentAttribute> attributes = const []}) =>
      EquipmentItem(
        id: '',
        name: 'Suit',
        type: EquipmentType.wetsuit,
        attributes: attributes,
      );

  test('create persists attributes with deterministic curated ids', () async {
    final created = await repository.createEquipment(
      suit(
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: '',
            key: 'thickness_mm',
            valueText: '5/4',
            valueNum: 5.0,
          ),
          const EquipmentAttribute(
            id: '',
            equipmentId: '',
            key: 'Favorite color',
            isCustom: true,
            valueText: 'blue',
          ),
        ],
      ),
    );

    final loaded = await repository.getEquipmentById(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.thickness, '5/4');
    expect(loaded.attrNum('thickness_mm'), 5.0);

    final thickness = loaded.attributes.firstWhere(
      (a) => a.key == 'thickness_mm',
    );
    expect(thickness.id, 'attr_${created.id}_thickness_mm');

    final custom = loaded.attributes.firstWhere((a) => a.isCustom);
    expect(custom.valueText, 'blue');
    expect(custom.id, isNotEmpty);
  });

  test('update diffs: changed values update, removed rows tombstone', () async {
    final created = await repository.createEquipment(
      suit(
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: '',
            key: 'thickness_mm',
            valueText: '5',
            valueNum: 5.0,
          ),
          EquipmentAttribute.curated(
            equipmentId: '',
            key: 'size',
            valueText: 'L',
          ),
        ],
      ),
    );

    // Change thickness, drop size.
    await repository.updateEquipment(
      (await repository.getEquipmentById(created.id))!.copyWith(
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: created.id,
            key: 'thickness_mm',
            valueText: '7',
            valueNum: 7.0,
          ),
        ],
      ),
    );

    final loaded = await repository.getEquipmentById(created.id);
    expect(loaded!.thickness, '7');
    expect(loaded.size, isNull);

    // Tombstone written for the cleared attribute.
    final db = DatabaseService.instance.database;
    final tombstones = await db
        .customSelect(
          "SELECT record_id FROM deletion_log "
          "WHERE entity_type = 'equipmentAttributes'",
        )
        .get();
    expect(
      tombstones.map((r) => r.read<String>('record_id')),
      contains('attr_${created.id}_size'),
    );
  });

  test('getAllEquipment hydrates attributes in one batch', () async {
    await repository.createEquipment(
      suit(
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: '',
            key: 'thickness_mm',
            valueText: '3',
            valueNum: 3.0,
          ),
        ],
      ),
    );
    final all = await repository.getAllEquipment();
    expect(all.single.thickness, '3');
  });
}
