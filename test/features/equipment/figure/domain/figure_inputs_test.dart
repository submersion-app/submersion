import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';
import 'package:submersion/features/equipment/figure/domain/figure_inputs.dart';

/// The mapper is the one place the figure reads the equipment entity, so it
/// pins how a child is recognised: a parent link, or being a part of an
/// assembly in the components index.
void main() {
  EquipmentItem gear(
    String id,
    EquipmentType type, {
    String? parentId,
    List<EquipmentAttribute> attributes = const [],
  }) => EquipmentItem(
    id: id,
    name: 'Item $id',
    type: type,
    parentEquipmentId: parentId,
    attributes: attributes,
  );

  test('a parent link makes a child', () {
    final inputs = figureInputsFromItems([
      gear('ccr', EquipmentType.rebreather),
      gear('cell', EquipmentType.o2Cell, parentId: 'ccr'),
    ]);
    expect(inputs.map((i) => i.isChild), [false, true]);
  });

  test('an assembly part is a child through the components index', () {
    final index = ComponentsIndex.fromRows([
      EquipmentComponent(
        id: 'c1',
        parentEquipmentId: 'reg',
        componentEquipmentId: 'second',
        role: 'Primary second stage',
        sortOrder: 0,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ]);
    final inputs = figureInputsFromItems([
      gear('reg', EquipmentType.regulator),
      gear('second', EquipmentType.secondStage),
    ], components: index);
    expect(inputs.map((i) => i.isChild), [false, true]);
  });

  test('catalog attributes are copied, custom ones are not', () {
    final inputs = figureInputsFromItems([
      gear(
        'bcd',
        EquipmentType.bcd,
        attributes: const [
          EquipmentAttribute(
            id: 'a1',
            equipmentId: 'bcd',
            key: 'bcd_style',
            isCustom: false,
            valueText: 'wing',
            valueNum: null,
            sortOrder: 0,
          ),
          EquipmentAttribute(
            id: 'a2',
            equipmentId: 'bcd',
            key: 'note',
            isCustom: true,
            valueText: 'loaner',
            valueNum: null,
            sortOrder: 1,
          ),
        ],
      ),
    ]);
    expect(inputs.single.attributes, {'bcd_style': 'wing'});
  });

  test('names and order are preserved', () {
    final inputs = figureInputsFromItems([
      gear('b', EquipmentType.fins),
      gear('a', EquipmentType.mask),
    ]);
    expect(inputs.map((i) => i.id), ['b', 'a']);
    expect(inputs.first.name, 'Item b');
  });
}
