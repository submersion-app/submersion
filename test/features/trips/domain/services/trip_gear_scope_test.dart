import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/services/trip_gear_scope.dart';

/// Which of the diver's gear goes on a trip (issue #2727).
void main() {
  EquipmentItem item(String id, {String? parent}) => EquipmentItem(
    id: id,
    name: id,
    type: EquipmentType.regulator,
    parentEquipmentId: parent,
  );

  final regSet = item('regSet');
  final firstStage = item('firstStage', parent: 'regSet');
  final hose = item('hose', parent: 'firstStage');
  final tank = item('tank');
  final bcd = item('bcd');

  test('nothing on the trip means no gear goes', () {
    expect(gearOnTrip([regSet, tank, bcd], const {}), isEmpty);
  });

  test('only the listed items go, in the order given', () {
    expect(gearOnTrip([regSet, tank, bcd], {'bcd', 'tank'}), [tank, bcd]);
  });

  test('parts installed in a listed assembly go with it, at any depth', () {
    expect(gearOnTrip([hose, tank, firstStage, regSet], {'regSet'}), [
      hose,
      firstStage,
      regSet,
    ]);
  });

  test('a listed part does not take its assembly along', () {
    expect(gearOnTrip([regSet, firstStage, hose], {'firstStage'}), [
      firstStage,
      hose,
    ]);
  });

  test('a parent missing from the list ends the walk', () {
    // A part whose assembly is retired (not among the active items) goes
    // only when it is listed itself.
    final orphan = item('orphan', parent: 'retired');
    expect(gearOnTrip([orphan], {'retired'}), isEmpty);
    expect(gearOnTrip([orphan], {'orphan'}), [orphan]);
  });

  test('a parent cycle in bad data does not loop forever', () {
    final a = item('a', parent: 'b');
    final b = item('b', parent: 'a');
    expect(gearOnTrip([a, b], {'c'}), isEmpty);
    expect(gearOnTrip([a, b], {'a'}), [a, b]);
  });

  group('packedOffBoard (#2874)', () {
    TripCylinder slot(String id, {String? equipmentId}) => TripCylinder(
      id: id,
      tripId: 't1',
      label: id,
      equipmentId: equipmentId,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('with no slots every packed item is listed', () {
      expect(packedOffBoard([regSet, tank, bcd], const []), [
        regSet,
        tank,
        bcd,
      ]);
    });

    test('an owned tank on a slot is left out, in order otherwise', () {
      expect(
        packedOffBoard(
          [regSet, tank, bcd],
          [slot('s1', equipmentId: 'tank'), slot('s2')],
        ),
        [regSet, bcd],
      );
    });
  });
}
