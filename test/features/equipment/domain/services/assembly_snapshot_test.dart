import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/services/assembly_snapshot.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';

/// A dive keeps the parts an assembly had when it was attached; parts added
/// to the template later never reach it on their own (issue #1988).
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
  GearProvenance part(String id, String parent, {String? set}) =>
      GearProvenance(equipmentId: id, viaEquipmentId: parent, viaSetId: set);

  group('refreshed', () {
    test('adds the parts the dive lacks under the assembly, keeping its '
        'set, after the rows already there', () {
      const rows = [
        GearProvenance(equipmentId: 'mask'),
        GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
        GearProvenance(
          equipmentId: 'hose',
          viaEquipmentId: 'reg',
          viaSetId: 'winter',
        ),
      ];
      final next = AssemblySnapshot.refreshed(
        rows,
        'reg',
        index: index,
        isActive: allActive,
      );
      expect(next, [
        ...rows,
        part('first', 'reg', set: 'winter'),
        part('second', 'reg', set: 'winter'),
      ]);
    });

    test('leaves the rows alone when the assembly is not on the dive', () {
      const rows = [GearProvenance(equipmentId: 'mask')];
      expect(
        AssemblySnapshot.refreshed(
          rows,
          'reg',
          index: index,
          isActive: allActive,
        ),
        same(rows),
      );
    });

    test('a nested assembly keeps its own parent', () {
      final rows = [
        const GearProvenance(equipmentId: 'kit'),
        part('reg', 'kit'),
      ];
      final next = AssemblySnapshot.refreshed(
        rows,
        'reg',
        index: index,
        isActive: allActive,
      );
      expect(next.first, rows.first);
      expect(next[1], rows[1]);
      expect(next.skip(2), [
        part('first', 'reg'),
        part('second', 'reg'),
        part('hose', 'reg'),
      ]);
    });
  });

  group('shortfalls', () {
    test('an assembly missing parts reports what it has and what it would '
        'have', () {
      final rows = [
        const GearProvenance(equipmentId: 'reg'),
        part('hose', 'reg'),
      ];
      expect(
        AssemblySnapshot.shortfalls(rows, index: index, isActive: allActive),
        {'reg': (partsOnDive: 1, partsAvailable: 3)},
      );
    });

    test('an assembly attached before it had any parts is behind too', () {
      const rows = [GearProvenance(equipmentId: 'reg')];
      expect(
        AssemblySnapshot.shortfalls(rows, index: index, isActive: allActive),
        {'reg': (partsOnDive: 0, partsAvailable: 3)},
      );
    });

    test('a dive carrying every part reports nothing', () {
      final rows = [
        const GearProvenance(equipmentId: 'reg'),
        part('first', 'reg'),
        part('second', 'reg'),
        part('hose', 'reg'),
      ];
      expect(
        AssemblySnapshot.shortfalls(rows, index: index, isActive: allActive),
        isEmpty,
      );
    });

    test('a retired or lost part is not missing: attaching would skip it', () {
      final rows = [
        const GearProvenance(equipmentId: 'reg'),
        part('first', 'reg'),
        part('hose', 'reg'),
      ];
      expect(
        AssemblySnapshot.shortfalls(
          rows,
          index: index,
          isActive: (id) => id != 'second',
        ),
        isEmpty,
      );
    });

    test('a loose row of a template part counts as available, since an '
        'update adopts it', () {
      const rows = [
        GearProvenance(equipmentId: 'reg'),
        GearProvenance(equipmentId: 'first'),
        GearProvenance(equipmentId: 'second'),
        GearProvenance(equipmentId: 'hose'),
      ];
      expect(
        AssemblySnapshot.shortfalls(rows, index: index, isActive: allActive),
        {'reg': (partsOnDive: 0, partsAvailable: 3)},
      );
    });

    test('a part hanging under another assembly on the dive stays that '
        'assembly\'s and is not missing', () {
      final rows = [
        const GearProvenance(equipmentId: 'reg'),
        part('first', 'reg'),
        part('second', 'reg'),
        const GearProvenance(equipmentId: 'pony'),
        part('hose', 'pony'),
      ];
      expect(
        AssemblySnapshot.shortfalls(rows, index: index, isActive: allActive),
        isEmpty,
      );
    });

    test('an outer assembly whose own parts are all there is still behind '
        'when a nested one is, so its collapsed row can offer the update', () {
      final rows = [
        const GearProvenance(equipmentId: 'kit'),
        part('reg', 'kit'),
        part('fins', 'kit'),
        part('first', 'reg'),
      ];
      expect(
        AssemblySnapshot.shortfalls(rows, index: index, isActive: allActive),
        {
          'kit': (partsOnDive: 2, partsAvailable: 2),
          'reg': (partsOnDive: 1, partsAvailable: 3),
        },
      );
    });

    test('an item with no template is never reported', () {
      const rows = [GearProvenance(equipmentId: 'mask')];
      expect(
        AssemblySnapshot.shortfalls(rows, index: index, isActive: allActive),
        isEmpty,
      );
    });
  });
}
