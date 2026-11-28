import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';
import 'package:submersion/features/equipment/domain/services/equipment_part_tree.dart';

EquipmentItem _item(
  String id, {
  String? name,
  EquipmentType type = EquipmentType.other,
  String? parent,
  int? slot,
  EquipmentStatus status = EquipmentStatus.active,
}) => EquipmentItem(
  id: id,
  name: name ?? id,
  type: type,
  status: status,
  parentEquipmentId: parent,
  attributes: [
    if (slot != null)
      EquipmentAttribute.curated(
        equipmentId: id,
        key: EquipmentAttrKeys.cellSlot,
        valueNum: slot.toDouble(),
      ),
  ],
);

EquipmentComponent _edge(String parent, String part, int order) =>
    EquipmentComponent(
      id: '$parent-$part',
      parentEquipmentId: parent,
      componentEquipmentId: part,
      sortOrder: order,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

/// The Equipment list's part graph over components and installed parts
/// (issue #5071).
void main() {
  test('components come first in template order', () {
    final tree = EquipmentPartTree.build(
      components: ComponentsIndex.fromRows([
        _edge('P', 'c2', 0),
        _edge('P', 'c1', 1),
      ]),
      items: [_item('P'), _item('c1'), _item('c2')],
    );
    expect(tree.childrenOf('P'), ['c2', 'c1']);
  });

  test('installed parts follow in the condition card order', () {
    final tree = EquipmentPartTree.build(
      components: ComponentsIndex.fromRows([_edge('P', 'c1', 0)]),
      items: [
        _item('P'),
        _item('c1'),
        _item('bat', type: EquipmentType.battery, parent: 'P'),
        _item(
          'i3',
          name: 'a',
          type: EquipmentType.o2Cell,
          parent: 'P',
          slot: 3,
        ),
        _item(
          'i1',
          name: 'z',
          type: EquipmentType.o2Cell,
          parent: 'P',
          slot: 1,
        ),
        _item('iN', name: 'b', type: EquipmentType.o2Cell, parent: 'P'),
        _item('iM', name: 'a', type: EquipmentType.o2Cell, parent: 'P'),
      ],
    );
    expect(tree.childrenOf('P'), ['c1', 'i1', 'i3', 'iM', 'iN', 'bat']);
  });

  test('an unfitted item is not an installed part', () {
    final tree = EquipmentPartTree.build(
      components: ComponentsIndex.empty,
      items: [
        _item('P'),
        _item('old', parent: 'P', status: EquipmentStatus.retired),
      ],
    );
    expect(tree.childrenOf('P'), isEmpty);
    expect(tree.hasParts('P'), isFalse);
  });

  test('an item both component and installed in one host is listed once', () {
    final tree = EquipmentPartTree.build(
      components: ComponentsIndex.fromRows([_edge('P', 'x', 0)]),
      items: [
        _item('P'),
        _item('x', parent: 'P'),
      ],
    );
    expect(tree.childrenOf('P'), ['x']);
    expect(tree.parentsOf('x'), ['P']);
  });

  test('parentsOf unions both links', () {
    final tree = EquipmentPartTree.build(
      components: ComponentsIndex.fromRows([_edge('A', 'x', 0)]),
      items: [
        _item('A'),
        _item('B'),
        _item('x', parent: 'B'),
      ],
    );
    expect(tree.parentsOf('x').toSet(), {'A', 'B'});
  });

  test('an installed-in host need not be among the items', () {
    final tree = EquipmentPartTree.build(
      components: ComponentsIndex.empty,
      items: [_item('x', parent: 'gone')],
    );
    expect(tree.childrenOf('gone'), ['x']);
    expect(tree.parentsOf('x'), ['gone']);
  });

  test('assemblyIds are exactly the ids with parts', () {
    final tree = EquipmentPartTree.build(
      components: ComponentsIndex.fromRows([_edge('A', 'x', 0)]),
      items: [
        _item('A'),
        _item('x'),
        _item('B'),
        _item('y', parent: 'B'),
      ],
    );
    expect(tree.assemblyIds, {'A', 'B'});
    expect(tree.hasParts('A'), isTrue);
    expect(tree.hasParts('x'), isFalse);
    expect(EquipmentPartTree.empty.assemblyIds, isEmpty);
  });
}
