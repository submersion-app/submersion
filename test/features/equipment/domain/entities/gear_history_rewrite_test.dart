import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/gear_history_rewrite.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';

/// The pure rule behind "also update N past dives" (issue #1487): one
/// template change replayed on one dive's provenance rows.
void main() {
  const onDive = [
    GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
    GearProvenance(
      equipmentId: 'hose',
      viaEquipmentId: 'reg',
      viaSetId: 'winter',
    ),
    GearProvenance(equipmentId: 'mask'),
  ];
  List<String> ids(List<GearProvenance> rows) =>
      rows.map((r) => r.equipmentId).toList();
  GearProvenance row(List<GearProvenance> rows, String id) =>
      rows.firstWhere((r) => r.equipmentId == id);

  group('GearPartAdded', () {
    test('appends the part under the assembly with the assembly set', () {
      final next = const GearPartAdded('first').applyTo(onDive, 'reg');
      expect(ids(next), ['reg', 'hose', 'mask', 'first']);
      expect(row(next, 'first').viaEquipmentId, 'reg');
      expect(row(next, 'first').viaSetId, 'winter');
    });

    test('a loose row already on the dive adopts the assembly', () {
      final next = const GearPartAdded('mask').applyTo(onDive, 'reg');
      expect(ids(next), ['reg', 'hose', 'mask']);
      expect(row(next, 'mask').viaEquipmentId, 'reg');
      expect(row(next, 'mask').viaSetId, 'winter');
    });

    test('a row under another parent is left alone', () {
      const rows = [
        GearProvenance(equipmentId: 'reg'),
        GearProvenance(equipmentId: 'hose', viaEquipmentId: 'other'),
      ];
      expect(const GearPartAdded('hose').applyTo(rows, 'reg'), rows);
    });

    test('a dive without the assembly is unchanged', () {
      expect(const GearPartAdded('first').applyTo(onDive, 'kit'), onDive);
    });
  });

  group('GearPartRemoved', () {
    test('drops the row under the assembly and its subtree', () {
      const rows = [
        GearProvenance(equipmentId: 'reg'),
        GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg'),
        GearProvenance(equipmentId: 'clip', viaEquipmentId: 'hose'),
        GearProvenance(equipmentId: 'mask'),
      ];
      expect(ids(const GearPartRemoved('hose').applyTo(rows, 'reg')), [
        'reg',
        'mask',
      ]);
    });

    test('a same item under another parent is left alone', () {
      const rows = [
        GearProvenance(equipmentId: 'reg'),
        GearProvenance(equipmentId: 'hose', viaEquipmentId: 'other'),
      ];
      expect(const GearPartRemoved('hose').applyTo(rows, 'reg'), rows);
    });
  });

  group('GearPartReplaced', () {
    test('re-keys the row in place, keeping provenance and children', () {
      const rows = [
        GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
        GearProvenance(
          equipmentId: 'hose',
          viaEquipmentId: 'reg',
          viaSetId: 'winter',
        ),
        GearProvenance(equipmentId: 'clip', viaEquipmentId: 'hose'),
      ];
      final next = const GearPartReplaced(
        oldPartId: 'hose',
        newPartId: 'newhose',
      ).applyTo(rows, 'reg');
      expect(ids(next), ['reg', 'newhose', 'clip']);
      expect(row(next, 'newhose').viaEquipmentId, 'reg');
      expect(row(next, 'newhose').viaSetId, 'winter');
      expect(row(next, 'clip').viaEquipmentId, 'newhose');
    });

    test(
      'a new part already on the dive adopts the assembly and the old row goes',
      () {
        const rows = [
          GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
          GearProvenance(
            equipmentId: 'hose',
            viaEquipmentId: 'reg',
            viaSetId: 'winter',
          ),
          GearProvenance(equipmentId: 'newhose'),
        ];
        final next = const GearPartReplaced(
          oldPartId: 'hose',
          newPartId: 'newhose',
        ).applyTo(rows, 'reg');
        expect(ids(next), ['reg', 'newhose']);
        expect(row(next, 'newhose').viaEquipmentId, 'reg');
        expect(row(next, 'newhose').viaSetId, 'winter');
      },
    );

    test('a new part under another assembly is left alone', () {
      // One item sits in one place, and the row belongs to the other
      // assembly: adopting it here would silently take a component off
      // that assembly on this dive.
      const rows = [
        GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
        GearProvenance(
          equipmentId: 'hose',
          viaEquipmentId: 'reg',
          viaSetId: 'winter',
        ),
        GearProvenance(equipmentId: 'kit'),
        GearProvenance(equipmentId: 'newhose', viaEquipmentId: 'kit'),
      ];
      expect(
        const GearPartReplaced(
          oldPartId: 'hose',
          newPartId: 'newhose',
        ).applyTo(rows, 'reg'),
        rows,
      );
    });

    test('a new part already under this assembly leaves the dive alone', () {
      // The template refuses this pair anyway (unique parent+component),
      // so the conservative answer is to change nothing.
      const rows = [
        GearProvenance(equipmentId: 'reg'),
        GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg'),
        GearProvenance(equipmentId: 'fins', viaEquipmentId: 'reg'),
      ];
      expect(
        const GearPartReplaced(
          oldPartId: 'hose',
          newPartId: 'fins',
        ).applyTo(rows, 'reg'),
        rows,
      );
    });

    test('without the old row under the assembly nothing changes', () {
      expect(
        const GearPartReplaced(
          oldPartId: 'first',
          newPartId: 'x',
        ).applyTo(onDive, 'reg'),
        onDive,
      );
    });
  });
}
