import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';
import 'package:submersion/features/equipment/domain/services/gear_expander.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);
  var seq = 0;
  EquipmentComponent edge(String parent, String child, {int order = 0}) =>
      EquipmentComponent(
        id: 'c${seq++}',
        parentEquipmentId: parent,
        componentEquipmentId: child,
        sortOrder: order,
        createdAt: t0,
        updatedAt: t0,
      );
  // reg > first, second, hose (in that order); kit > reg, fins.
  final index = ComponentsIndex.fromRows([
    edge('reg', 'first', order: 0),
    edge('reg', 'second', order: 1),
    edge('reg', 'hose', order: 2),
    edge('kit', 'reg', order: 0),
    edge('kit', 'fins', order: 1),
  ]);
  bool allActive(String _) => true;
  List<String> ids(List<GearProvenance> rows) =>
      rows.map((r) => r.equipmentId).toList();

  test('adding an assembly writes it and its parts, parts tagged with it', () {
    final rows = GearExpander.expand(
      additions: const [(equipmentId: 'reg', viaSetId: null)],
      index: index,
      existing: const [],
      isActive: allActive,
    );
    expect(ids(rows), ['reg', 'first', 'second', 'hose']);
    expect(rows[0].viaEquipmentId, isNull);
    expect(rows.skip(1).map((r) => r.viaEquipmentId), everyElement('reg'));
  });

  test('nesting expands recursively with the immediate parent on each row', () {
    final rows = GearExpander.expand(
      additions: const [(equipmentId: 'kit', viaSetId: 'winter')],
      index: index,
      existing: const [],
      isActive: allActive,
    );
    expect(ids(rows), ['kit', 'reg', 'first', 'second', 'hose', 'fins']);
    expect(
      rows.firstWhere((r) => r.equipmentId == 'hose').viaEquipmentId,
      'reg',
    );
    expect(
      rows.firstWhere((r) => r.equipmentId == 'reg').viaEquipmentId,
      'kit',
    );
    expect(rows.map((r) => r.viaSetId), everyElement('winter'));
  });

  test('a retired part is skipped', () {
    final rows = GearExpander.expand(
      additions: const [(equipmentId: 'reg', viaSetId: null)],
      index: index,
      existing: const [],
      isActive: (id) => id != 'second',
    );
    expect(ids(rows), ['reg', 'first', 'hose']);
  });

  test('an item already on the dive as loose gear adopts the assembly', () {
    final rows = GearExpander.expand(
      additions: const [(equipmentId: 'reg', viaSetId: 'winter')],
      index: index,
      existing: const [GearProvenance(equipmentId: 'hose')],
      isActive: allActive,
    );
    final hose = rows.firstWhere((r) => r.equipmentId == 'hose');
    expect(hose.viaEquipmentId, 'reg');
    expect(hose.viaSetId, 'winter');
    expect(ids(rows).where((id) => id == 'hose').length, 1);
  });

  test('an item already under another parent is left alone', () {
    final rows = GearExpander.expand(
      additions: const [(equipmentId: 'reg', viaSetId: null)],
      index: index,
      existing: const [
        GearProvenance(equipmentId: 'hose', viaEquipmentId: 'other'),
      ],
      isActive: allActive,
    );
    expect(
      rows.firstWhere((r) => r.equipmentId == 'hose').viaEquipmentId,
      'other',
    );
  });

  test('a top-level item already present gains the set when it had none', () {
    final rows = GearExpander.expand(
      additions: const [(equipmentId: 'fins', viaSetId: 'winter')],
      index: index,
      existing: const [GearProvenance(equipmentId: 'fins')],
      isActive: allActive,
    );
    expect(rows.single.viaSetId, 'winter');
  });

  test('a corrupt cycle terminates', () {
    final loop = ComponentsIndex.fromRows([edge('a', 'b'), edge('b', 'a')]);
    final rows = GearExpander.expand(
      additions: const [(equipmentId: 'a', viaSetId: null)],
      index: loop,
      existing: const [],
      isActive: allActive,
    );
    expect(ids(rows), ['a', 'b']);
  });

  group('removal', () {
    const onDive = [
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
      GearProvenance(equipmentId: 'mask'),
    ];

    test('removeSubtree drops the row and everything under it', () {
      expect(ids(GearExpander.removeSubtree(onDive, 'reg')), [
        'kit',
        'fins',
        'mask',
      ]);
      expect(ids(GearExpander.removeSubtree(onDive, 'kit')), ['mask']);
    });

    test('removeSet drops every row carrying the set', () {
      expect(ids(GearExpander.removeSet(onDive, 'winter')), ['mask']);
    });

    test('removePart drops one leaf, and a row with children as a subtree', () {
      expect(ids(GearExpander.removePart(onDive, 'hose')), [
        'kit',
        'reg',
        'fins',
        'mask',
      ]);
      expect(ids(GearExpander.removePart(onDive, 'reg')), [
        'kit',
        'fins',
        'mask',
      ]);
    });
  });
}
