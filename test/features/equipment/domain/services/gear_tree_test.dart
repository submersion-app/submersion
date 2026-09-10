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

  test('a corrupt loop still rolls up one row and keeps one leaf', () {
    // A and B each name the other as parent. Every row is a parent, so a
    // naive reading would roll up everything and leave no leaf; buoyancy
    // would then count no gear at all. The placement walk promotes the
    // first row to a root and nests the other under it instead.
    const loop = [
      GearProvenance(equipmentId: 'a', viaEquipmentId: 'b'),
      GearProvenance(equipmentId: 'b', viaEquipmentId: 'a'),
    ];
    final links = gearLinksFor([
      item('a', EquipmentType.bcd),
      item('b', EquipmentType.wing),
    ], loop);
    expect(GearTree.rolledUpIds(loop), {'a'});
    expect(GearTree.leafItems(links).map((i) => i.id), ['b']);
    final root = GearTree.build(links).single.roots.single;
    expect(root.link.item.id, 'a');
    expect(root.children.single.link.item.id, 'b');
  });

  test('partIds and partCounts follow the placement, not the raw parent', () {
    expect(GearTree.partIds(provenance), {'reg', 'hose', 'fins'});
    expect(GearTree.partCounts(provenance), {'kit': 2, 'reg': 1});
    // An orphan is not a part: its parent is not on the dive, so it is a
    // top-level row that a chip list must still show.
    const orphan = [
      GearProvenance(equipmentId: 'hose', viaEquipmentId: 'missing'),
    ];
    expect(GearTree.partIds(orphan), isEmpty);
    expect(GearTree.partCounts(orphan), isEmpty);
  });

  test('topLevelCount counts what the renderer shows as top-level rows', () {
    // The nominal fixture's provenance rows: kit and cam are top-level (the
    // mask has no provenance row at all and is not in this list).
    expect(GearTree.topLevelCount(provenance), 2);
    // An orphan whose parent is not on the dive is promoted, so it counts
    // even though its viaEquipmentId is set.
    expect(
      GearTree.topLevelCount(const [
        GearProvenance(equipmentId: 'hose', viaEquipmentId: 'missing'),
      ]),
      1,
    );
    // A loop is one promoted root with the other row beneath it.
    expect(
      GearTree.topLevelCount(const [
        GearProvenance(equipmentId: 'a', viaEquipmentId: 'b'),
        GearProvenance(equipmentId: 'b', viaEquipmentId: 'a'),
      ]),
      1,
    );
  });
}
