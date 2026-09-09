import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/services/gear_tree.dart';

void main() {
  EquipmentItem item(String id, EquipmentType type) =>
      EquipmentItem(id: id, name: id, type: type);
  final items = [
    item('mask', EquipmentType.mask),
    item('kit', EquipmentType.other),
    item('reg', EquipmentType.regulator),
    item('hose', EquipmentType.hose),
    item('fins', EquipmentType.fins),
    item('cam', EquipmentType.camera),
  ];
  const provenance = [
    GearProvenance(equipmentId: 'kit', viaSetId: 'winter'),
    GearProvenance(
      equipmentId: 'reg',
      viaEquipmentId: 'kit',
      viaSetId: 'winter',
    ),
    GearProvenance(
      equipmentId: 'hose',
      viaEquipmentId: 'reg',
      viaSetId: 'winter',
    ),
    GearProvenance(
      equipmentId: 'fins',
      viaEquipmentId: 'kit',
      viaSetId: 'winter',
    ),
    GearProvenance(equipmentId: 'cam', viaSetId: 'photo'),
  ];
  final links = gearLinksFor(items, provenance);

  test('buckets by set in first-seen order with loose gear last', () {
    final buckets = GearTree.build(links);
    expect(buckets.map((b) => b.setId), ['winter', 'photo', null]);
    expect(buckets[0].roots.map((n) => n.link.item.id), ['kit']);
    expect(buckets[1].roots.map((n) => n.link.item.id), ['cam']);
    expect(buckets[2].roots.map((n) => n.link.item.id), ['mask']);
  });

  test('nests parts under their parent in link order', () {
    final kit = GearTree.build(links)[0].roots.single;
    expect(kit.children.map((n) => n.link.item.id), ['reg', 'fins']);
    expect(kit.children[0].children.map((n) => n.link.item.id), ['hose']);
  });

  test('a row whose parent is not on the dive is treated as top-level', () {
    final orphan = gearLinksFor(
      [item('hose', EquipmentType.hose)],
      const [GearProvenance(equipmentId: 'hose', viaEquipmentId: 'missing')],
    );
    expect(GearTree.build(orphan).single.roots.single.link.item.id, 'hose');
  });

  test('rolledUpIds and leafItems agree', () {
    expect(GearTree.rolledUpIds(provenance), {'kit', 'reg'});
    expect(GearTree.leafItems(links).map((i) => i.id), [
      'mask',
      'hose',
      'fins',
      'cam',
    ]);
  });

  test('a corrupt loop still builds', () {
    final loop = gearLinksFor(
      [item('a', EquipmentType.other), item('b', EquipmentType.other)],
      const [
        GearProvenance(equipmentId: 'a', viaEquipmentId: 'b'),
        GearProvenance(equipmentId: 'b', viaEquipmentId: 'a'),
      ],
    );
    expect(GearTree.build(loop).single.roots, isNotEmpty);
  });
}
