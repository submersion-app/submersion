import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';

void main() {
  test('a row with no parent is top-level', () {
    const loose = GearProvenance(equipmentId: 'reg');
    const part = GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg');
    expect(loose.isTopLevel, isTrue);
    expect(part.isTopLevel, isFalse);
    expect(loose.viaSetId, isNull);
  });

  test('copyWith sets and clears each pointer independently', () {
    const p = GearProvenance(
      equipmentId: 'hose',
      viaEquipmentId: 'reg',
      viaSetId: 'winter',
    );
    expect(p.copyWith(clearViaEquipmentId: true).viaEquipmentId, isNull);
    expect(p.copyWith(clearViaEquipmentId: true).viaSetId, 'winter');
    expect(p.copyWith(viaSetId: 'summer').viaSetId, 'summer');
    expect(p.copyWith(clearViaSetId: true).viaSetId, isNull);
  });

  test('equality is by value', () {
    expect(
      const GearProvenance(equipmentId: 'a', viaSetId: 's'),
      const GearProvenance(equipmentId: 'a', viaSetId: 's'),
    );
  });
}
