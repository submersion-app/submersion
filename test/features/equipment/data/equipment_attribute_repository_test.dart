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

  test('a rebreather persists and reloads its curated attributes', () async {
    final created = await repository.createEquipment(
      EquipmentItem(
        id: '',
        name: 'JJ-CCR',
        type: EquipmentType.rebreather,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: '',
            key: 'unit_type',
            valueText: 'eccr',
          ),
          EquipmentAttribute.curated(
            equipmentId: '',
            key: 'scrubber_duration_h',
            valueNum: 3.0,
          ),
          EquipmentAttribute.curated(
            equipmentId: '',
            key: 'o2_cell_count',
            valueNum: 3,
          ),
          EquipmentAttribute.curated(
            equipmentId: '',
            key: 'diluent_cylinder_l',
            valueNum: 3.0,
          ),
        ],
      ),
    );

    final loaded = await repository.getEquipmentById(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.type, EquipmentType.rebreather);
    expect(loaded.attrText('unit_type'), 'eccr');
    expect(loaded.attrNum('scrubber_duration_h'), 3.0);
    expect(loaded.attrNum('o2_cell_count'), 3);
    expect(loaded.attrNum('diluent_cylinder_l'), 3.0);

    // Curated ids are deterministic so independent devices converge.
    final unitType = loaded.attributes.firstWhere((a) => a.key == 'unit_type');
    expect(unitType.id, 'attr_${created.id}_unit_type');
    expect(unitType.isCustom, isFalse);
  });
}
