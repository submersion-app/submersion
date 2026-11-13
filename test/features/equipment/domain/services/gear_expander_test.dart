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

  test('the walk stops below a row that is under another parent', () {
    // reg is the other assembly's, so the parts it lacks on this dive (one
    // the diver took off, say) are not hung under it for kit.
    final rows = GearExpander.expand(
      additions: const [(equipmentId: 'kit', viaSetId: 'winter')],
      index: index,
      existing: const [
        GearProvenance(equipmentId: 'reg', viaEquipmentId: 'other'),
      ],
      isActive: allActive,
    );
    expect(ids(rows), ['reg', 'kit', 'fins']);
    expect(rows.first.viaEquipmentId, 'other');
    expect(rows.first.viaSetId, isNull);
  });

  test('a row already under the same parent still has its parts walked', () {
    final rows = GearExpander.expand(
      additions: const [(equipmentId: 'kit', viaSetId: null)],
      index: index,
      existing: const [
        GearProvenance(equipmentId: 'kit'),
        GearProvenance(equipmentId: 'reg', viaEquipmentId: 'kit'),
      ],
      isActive: allActive,
    );
    expect(ids(rows), ['kit', 'reg', 'first', 'second', 'hose', 'fins']);
    expect(
      rows.firstWhere((r) => r.equipmentId == 'hose').viaEquipmentId,
      'reg',
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

    test('unlinkSet keeps every row and only forgets the set (#4500)', () {
      final rows = GearExpander.unlinkSet([
        ...onDive,
        const GearProvenance(equipmentId: 'wing', viaSetId: 'summer'),
      ], 'winter');
      expect(ids(rows), ['kit', 'reg', 'hose', 'fins', 'mask', 'wing']);
      expect(rows.where((r) => r.viaSetId == 'winter'), isEmpty);
      // The assembly links stay, and another set keeps its own rows.
      expect(rows[2].viaEquipmentId, 'reg');
      expect(rows.last.viaSetId, 'summer');
    });

    test('unlinkSet leaves rows alone when the set is not on them', () {
      expect(GearExpander.unlinkSet(onDive, 'summer'), onDive);
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
