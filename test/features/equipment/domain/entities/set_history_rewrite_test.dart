import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/entities/set_history_rewrite.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';

/// The pure rule behind "also update N dives" for an equipment set
/// (issue #4283): one change to the set's members replayed on one dive's
/// provenance rows.
void main() {
  final epoch = DateTime(2026);
  EquipmentComponent edge(String parent, String child, int order) =>
      EquipmentComponent(
        id: '$parent-$child',
        parentEquipmentId: parent,
        componentEquipmentId: child,
        role: '',
        sortOrder: order,
        createdAt: epoch,
        updatedAt: epoch,
      );
  // reg is an assembly of hose and (retired) octo.
  final index = ComponentsIndex.fromRows([
    edge('reg', 'hose', 0),
    edge('reg', 'octo', 1),
  ]);
  bool active(String id) => id != 'octo' && id != 'retired';
  bool usable(String id) => id != 'foreign';

  const onDive = [
    GearProvenance(equipmentId: 'bcd', viaSetId: 'winter'),
    GearProvenance(equipmentId: 'mask'),
  ];
  List<String> ids(List<GearProvenance> rows) =>
      rows.map((r) => r.equipmentId).toList();
  GearProvenance row(List<GearProvenance> rows, String id) =>
      rows.firstWhere((r) => r.equipmentId == id);

  List<GearProvenance> apply(
    SetHistoryRewrite rewrite,
    List<GearProvenance> rows,
  ) => rewrite.applyTo(
    rows,
    'winter',
    index: index,
    isActive: active,
    isUsable: usable,
  );

  group('SetItemAdded', () {
    test('adds a missing item with its active parts, tagged with the set', () {
      final next = apply(const SetItemAdded('reg'), onDive);
      expect(ids(next), ['bcd', 'mask', 'reg', 'hose']);
      expect(row(next, 'reg').viaSetId, 'winter');
      expect(row(next, 'reg').isTopLevel, isTrue);
      expect(row(next, 'hose').viaEquipmentId, 'reg');
      expect(row(next, 'hose').viaSetId, 'winter');
    });

    test('adopts a loose row added by hand', () {
      final next = apply(const SetItemAdded('mask'), onDive);
      expect(ids(next), ['bcd', 'mask']);
      expect(row(next, 'mask').viaSetId, 'winter');
      expect(row(next, 'mask').isTopLevel, isTrue);
    });

    test('leaves a row under another assembly alone', () {
      const rows = [
        GearProvenance(equipmentId: 'bcd', viaSetId: 'winter'),
        GearProvenance(equipmentId: 'kit'),
        GearProvenance(equipmentId: 'reg', viaEquipmentId: 'kit'),
      ];
      expect(apply(const SetItemAdded('reg'), rows), rows);
    });

    test('a row another set put there is left alone', () {
      const rows = [
        GearProvenance(equipmentId: 'bcd', viaSetId: 'winter'),
        GearProvenance(equipmentId: 'mask', viaSetId: 'summer'),
      ];
      expect(apply(const SetItemAdded('mask'), rows), rows);
    });

    test('a part another set put there stays with that set', () {
      // Removing reg from winter later must not take summer's hose along.
      const rows = [
        GearProvenance(equipmentId: 'bcd', viaSetId: 'winter'),
        GearProvenance(equipmentId: 'hose', viaSetId: 'summer'),
      ];
      final next = apply(const SetItemAdded('reg'), rows);
      expect(ids(next), ['bcd', 'hose', 'reg']);
      expect(row(next, 'hose'), rows[1]);
      expect(row(next, 'reg').viaSetId, 'winter');
    });

    test('an inactive item is not put on the dive', () {
      expect(apply(const SetItemAdded('retired'), onDive), onDive);
    });

    test('an item the dive diver may not use is not put on the dive', () {
      expect(apply(const SetItemAdded('foreign'), onDive), onDive);
    });

    test('a part the dive diver may not use stays off', () {
      final next = const SetItemAdded('reg').applyTo(
        onDive,
        'winter',
        index: index,
        isActive: active,
        isUsable: (id) => id != 'hose',
      );
      expect(ids(next), ['bcd', 'mask', 'reg']);
    });

    test('a dive without the set is unchanged', () {
      const rows = [GearProvenance(equipmentId: 'mask')];
      expect(apply(const SetItemAdded('reg'), rows), rows);
    });
  });

  group('SetItemRemoved', () {
    test('removes the row the set put there, with its parts', () {
      const rows = [
        GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
        GearProvenance(
          equipmentId: 'hose',
          viaEquipmentId: 'reg',
          viaSetId: 'winter',
        ),
        GearProvenance(equipmentId: 'mask'),
      ];
      expect(ids(apply(const SetItemRemoved('reg'), rows)), ['mask']);
    });

    test('a part still in the set stays, moved to the top level', () {
      const rows = [
        GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
        GearProvenance(
          equipmentId: 'hose',
          viaEquipmentId: 'reg',
          viaSetId: 'winter',
        ),
        GearProvenance(
          equipmentId: 'clip',
          viaEquipmentId: 'hose',
          viaSetId: 'winter',
        ),
      ];
      final next = const SetItemRemoved('reg').applyTo(
        rows,
        'winter',
        index: index,
        isActive: active,
        isUsable: usable,
        isMember: (id) => id == 'hose',
      );
      expect(ids(next), ['hose', 'clip']);
      expect(row(next, 'hose').isTopLevel, isTrue);
      expect(row(next, 'hose').viaSetId, 'winter');
      expect(row(next, 'clip').viaEquipmentId, 'hose');
    });

    test('a row hung under it by hand or another set stays', () {
      const rows = [
        GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
        GearProvenance(
          equipmentId: 'hose',
          viaEquipmentId: 'reg',
          viaSetId: 'winter',
        ),
        GearProvenance(equipmentId: 'clip', viaEquipmentId: 'reg'),
        GearProvenance(
          equipmentId: 'octo',
          viaEquipmentId: 'reg',
          viaSetId: 'summer',
        ),
      ];
      final next = apply(const SetItemRemoved('reg'), rows);
      expect(ids(next), ['clip', 'octo']);
      expect(row(next, 'clip').isTopLevel, isTrue);
      expect(row(next, 'clip').viaSetId, isNull);
      expect(row(next, 'octo').isTopLevel, isTrue);
      expect(row(next, 'octo').viaSetId, 'summer');
    });

    test('keeps a row added by hand', () {
      expect(apply(const SetItemRemoved('mask'), onDive), onDive);
    });

    test('keeps a row under an assembly, even one the set put there', () {
      const rows = [
        GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
        GearProvenance(
          equipmentId: 'hose',
          viaEquipmentId: 'reg',
          viaSetId: 'winter',
        ),
      ];
      expect(apply(const SetItemRemoved('hose'), rows), rows);
    });

    test('keeps a row another set put there', () {
      const rows = [
        GearProvenance(equipmentId: 'bcd', viaSetId: 'winter'),
        GearProvenance(equipmentId: 'mask', viaSetId: 'summer'),
      ];
      expect(apply(const SetItemRemoved('mask'), rows), rows);
    });
  });

  test('value equality', () {
    expect(const SetItemAdded('a'), const SetItemAdded('a'));
    expect(const SetItemRemoved('a'), isNot(const SetItemAdded('a')));
  });
}
