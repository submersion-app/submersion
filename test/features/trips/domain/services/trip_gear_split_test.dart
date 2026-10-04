import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/services/trip_gear_split.dart';

const _bcd = EquipmentItem(id: 'bcd', name: 'Wing', type: EquipmentType.bcd);
const _tank = EquipmentItem(id: 'tk', name: 'Faber', type: EquipmentType.tank);
const _tank2 = EquipmentItem(id: 'tk2', name: 'Al80', type: EquipmentType.tank);

TripCylinder _slot(String id, {String? equipmentId}) {
  final at = DateTime.utc(2026, 1, 1);
  return TripCylinder(
    id: id,
    tripId: 't1',
    equipmentId: equipmentId,
    label: id,
    createdAt: at,
    updatedAt: at,
  );
}

void main() {
  test('non-tank gear is packed', () {
    final split = splitTripGear(const [_bcd], const []);
    expect(split.packed, [_bcd]);
    expect(split.unslottedTanks, isEmpty);
  });

  test('a tank on the board is listed by its slot alone', () {
    final split = splitTripGear(
      const [_tank, _bcd],
      [_slot('A1', equipmentId: 'tk')],
    );
    expect(split.packed, [_bcd]);
    expect(split.unslottedTanks, isEmpty);
  });

  test('a packed tank with no slot is a cylinder to put on the board '
      '(#2873)', () {
    final split = splitTripGear(
      const [_bcd, _tank, _tank2],
      [_slot('A1', equipmentId: 'tk'), _slot('Rental')],
    );
    expect(split.packed, [_bcd]);
    expect(split.unslottedTanks, [_tank2]);
  });
}
