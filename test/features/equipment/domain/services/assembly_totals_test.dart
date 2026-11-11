import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/assembly_totals.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);

  EquipmentItem item(
    String id, {
    double? buoyancy,
    double? dry,
    EquipmentType type = EquipmentType.weightPocket,
    bool active = true,
  }) => EquipmentItem(
    id: id,
    name: id,
    type: type,
    isActive: active,
    status: active ? EquipmentStatus.active : EquipmentStatus.retired,
    attributes: [
      if (buoyancy != null)
        EquipmentAttribute.curated(
          equipmentId: id,
          key: EquipmentAttrKeys.buoyancyKg,
          valueNum: buoyancy,
        ),
      if (dry != null)
        EquipmentAttribute.curated(
          equipmentId: id,
          key: EquipmentAttrKeys.dryWeightKg,
          valueNum: dry,
        ),
    ],
  );

  EquipmentComponent edge(String parent, String child, [int order = 0]) =>
      EquipmentComponent(
        id: '$parent>$child',
        parentEquipmentId: parent,
        componentEquipmentId: child,
        sortOrder: order,
        createdAt: t0,
        updatedAt: t0,
      );

  AssemblyTotals totals(
    String root,
    List<EquipmentComponent> edges,
    List<EquipmentItem> items,
  ) {
    final byId = {for (final i in items) i.id: i};
    return AssemblyTotals.of(
      root,
      index: ComponentsIndex.fromRows(edges),
      itemFor: (id) => byId[id],
      isActive: (id) => byId[id]?.isActive ?? false,
    );
  }

  test('sums the buoyancy and dry weight of two weight pockets', () {
    final result = totals(
      'harness',
      [edge('harness', 'left'), edge('harness', 'right', 1)],
      [
        item('harness', buoyancy: 1.0, dry: 2.0, type: EquipmentType.weights),
        item('left', buoyancy: -4.0, dry: 0.3),
        item('right', buoyancy: -3.0, dry: 0.3),
      ],
    );

    expect(result.partCount, 2);
    expect(result.buoyancy!.kg, closeTo(-7.0, 1e-9));
    expect(result.buoyancy!.parts, 2);
    expect(result.dryWeight!.kg, closeTo(0.6, 1e-9));
    expect(result.dryWeight!.parts, 2);
  });

  test('a nested assembly counts its parts, not its own values', () {
    // On a dive the nested assembly's parts carry the mass and its own
    // attributes are skipped (GearTree.rolledUpIds); the total must agree.
    final result = totals(
      'rig',
      [
        edge('rig', 'harness'),
        edge('rig', 'plate', 1),
        edge('harness', 'left'),
        edge('harness', 'right', 1),
      ],
      [
        item('rig'),
        item('harness', buoyancy: -50.0, dry: 50.0),
        item('plate', buoyancy: -2.0, dry: 2.5, type: EquipmentType.bcd),
        item('left', buoyancy: -4.0),
        item('right', buoyancy: -3.0),
      ],
    );

    expect(result.partCount, 3);
    expect(result.buoyancy!.kg, closeTo(-9.0, 1e-9));
    expect(result.buoyancy!.parts, 3);
    expect(result.dryWeight!.kg, closeTo(2.5, 1e-9));
    expect(result.dryWeight!.parts, 1);
  });

  test('a retired part and everything below it are left out', () {
    final result = totals(
      'harness',
      [
        edge('harness', 'left'),
        edge('harness', 'old', 1),
        edge('old', 'insert'),
      ],
      [
        item('harness'),
        item('left', buoyancy: -4.0),
        item('old', buoyancy: -6.0, active: false),
        item('insert', buoyancy: -1.0),
      ],
    );

    expect(result.partCount, 1);
    expect(result.buoyancy!.kg, closeTo(-4.0, 1e-9));
  });

  test('a nested assembly with no active parts counts its own values', () {
    final result = totals(
      'rig',
      [edge('rig', 'harness'), edge('harness', 'old')],
      [
        item('rig'),
        item('harness', buoyancy: -5.0),
        item('old', buoyancy: -6.0, active: false),
      ],
    );

    expect(result.partCount, 1);
    expect(result.buoyancy!.kg, closeTo(-5.0, 1e-9));
  });

  test('a part shared by two nested assemblies is counted once', () {
    final result = totals(
      'rig',
      [
        edge('rig', 'a'),
        edge('rig', 'b', 1),
        edge('a', 'shared'),
        edge('b', 'shared'),
        edge('b', 'own'),
      ],
      [
        item('rig'),
        item('a'),
        item('b'),
        item('shared', buoyancy: -2.0),
        item('own', buoyancy: -1.0),
      ],
    );

    expect(result.buoyancy!.kg, closeTo(-3.0, 1e-9));
    expect(result.buoyancy!.parts, 2);
  });

  test('parts without a value are counted but add nothing', () {
    final result = totals(
      'harness',
      [edge('harness', 'left'), edge('harness', 'right', 1)],
      [item('harness'), item('left', buoyancy: -4.0), item('right')],
    );

    expect(result.partCount, 2);
    expect(result.buoyancy!.kg, closeTo(-4.0, 1e-9));
    expect(result.buoyancy!.parts, 1);
    expect(result.dryWeight, isNull);
  });

  test('no values on any part gives no totals', () {
    final result = totals(
      'harness',
      [edge('harness', 'left')],
      [item('harness', buoyancy: -9.0), item('left')],
    );

    expect(result.partCount, 1);
    expect(result.buoyancy, isNull);
    expect(result.dryWeight, isNull);
    expect(result.hasAny, isFalse);
  });

  test('non-finite values are treated as absent', () {
    final result = totals(
      'harness',
      [edge('harness', 'left'), edge('harness', 'right', 1)],
      [
        item('harness'),
        item('left', buoyancy: double.infinity, dry: double.nan),
        item('right', buoyancy: -3.0),
      ],
    );

    expect(result.buoyancy!.kg, closeTo(-3.0, 1e-9));
    expect(result.buoyancy!.parts, 1);
    expect(result.dryWeight, isNull);
  });

  test('a part that is not loaded is skipped', () {
    final result = totals(
      'harness',
      [edge('harness', 'left'), edge('harness', 'ghost', 1)],
      [item('harness'), item('left', buoyancy: -4.0)],
    );

    expect(result.partCount, 1);
    expect(result.buoyancy!.kg, closeTo(-4.0, 1e-9));
  });

  test('a corrupt loop terminates and never counts the assembly', () {
    final result = totals(
      'harness',
      [edge('harness', 'left'), edge('left', 'harness')],
      [item('harness', buoyancy: -9.0), item('left', buoyancy: -4.0)],
    );

    expect(result.buoyancy!.kg, closeTo(-4.0, 1e-9));
    expect(result.buoyancy!.parts, 1);
  });

  test('an item with no parts has no totals', () {
    final result = totals('harness', const [], [item('harness')]);

    expect(result.partCount, 0);
    expect(result.hasAny, isFalse);
  });
}
