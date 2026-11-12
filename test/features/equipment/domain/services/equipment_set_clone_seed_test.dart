import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/domain/services/equipment_set_clone_seed.dart';

void main() {
  final source = EquipmentSet(
    id: 'set-1',
    diverId: 'diver-1',
    name: 'Cold Water',
    description: 'Drysuit rig',
    equipmentIds: const ['bcd', 'mask', 'boots'],
    isDefault: true,
    autoApplyOnComputerImport: true,
    showFigure: false,
    geofences: [
      EquipmentSetGeofence(
        id: 'fence-1',
        setId: 'set-1',
        latitude: 36.6,
        longitude: -121.9,
        radiusMeters: 500,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ],
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025, 6),
  );

  EquipmentSet seed() =>
      equipmentSetCloneSeed(source, copyName: (name) => '$name (copy)');

  test('takes the copy name', () {
    expect(seed().name, 'Cold Water (copy)');
  });

  test('keeps the description, members and figure preference', () {
    final clone = seed();
    expect(clone.description, 'Drysuit rig');
    expect(clone.equipmentIds, ['bcd', 'mask', 'boots']);
    expect(clone.showFigure, isFalse);
  });

  test('leaves default, computer auto-apply and geofences behind', () {
    final clone = seed();
    expect(clone.isDefault, isFalse);
    expect(clone.autoApplyOnComputerImport, isFalse);
    expect(clone.geofences, isEmpty);
  });

  test('has no id or owner, so the save assigns them', () {
    final clone = seed();
    expect(clone.id, isEmpty);
    expect(clone.diverId, isNull);
  });

  test('does not share the source member list', () {
    final clone = seed();
    expect(identical(clone.equipmentIds, source.equipmentIds), isFalse);
  });
}
