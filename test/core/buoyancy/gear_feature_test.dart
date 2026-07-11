import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/gear_feature.dart';
import 'package:submersion/core/constants/enums.dart';

void main() {
  GearFeature feature({
    EquipmentType type = EquipmentType.wetsuit,
    String name = 'Suit',
    String? size,
    double? buoyancyKg,
    double? weightKg,
  }) => GearFeature.fromEquipment(
    id: 'e1',
    type: type,
    name: name,
    size: size,
    buoyancyKg: buoyancyKg,
    weightKg: weightKg,
  );

  test(
    'user-entered buoyancy is a strong prior and wins over type default',
    () {
      final f = feature(buoyancyKg: -2.0);
      expect(f.priorKg, -2.0);
      expect(f.priorStrength, 8.0);
      expect(f.hasUserSpec, isTrue);
    },
  );

  test('wetsuit thickness parsed from the name drives the prior', () {
    expect(feature(name: '7mm Farmer John').priorKg, closeTo(7.0, 0.001));
    expect(feature(name: 'Fusion 3 mm shorty').priorKg, closeTo(3.0, 0.001));
    expect(feature(name: 'Steamer', size: '5mm').priorKg, closeTo(5.0, 0.001));
  });

  test('wetsuit thickness clamps to 8 kg', () {
    expect(feature(name: '12mm monster').priorKg, 8.0);
  });

  test('wetsuit without thickness defaults to 4.0', () {
    expect(feature(name: 'Old faithful').priorKg, 4.0);
    expect(feature(name: 'Old faithful').priorStrength, 2.0);
    expect(feature(name: 'Old faithful').hasUserSpec, isFalse);
  });

  test('type defaults: drysuit, bcd, hood, gloves, boots, other', () {
    expect(feature(type: EquipmentType.drysuit, name: 'DS').priorKg, 10.0);
    expect(feature(type: EquipmentType.bcd, name: 'Wing').priorKg, -0.5);
    expect(feature(type: EquipmentType.hood, name: 'H').priorKg, 0.3);
    expect(feature(type: EquipmentType.gloves, name: 'G').priorKg, 0.2);
    expect(feature(type: EquipmentType.boots, name: 'B').priorKg, 0.4);
    expect(feature(type: EquipmentType.fins, name: 'F').priorKg, 0.0);
    expect(feature(type: EquipmentType.regulator, name: 'R').priorKg, 0.0);
  });

  test('dry mass uses metadata, else type default', () {
    expect(feature(weightKg: 2.6).dryMassKg, 2.6);
    expect(feature(name: 'no meta').dryMassKg, 2.0); // wetsuit default
    expect(feature(type: EquipmentType.bcd, name: 'W').dryMassKg, 3.5);
    expect(feature(type: EquipmentType.drysuit, name: 'D').dryMassKg, 3.0);
    expect(feature(type: EquipmentType.mask, name: 'M').dryMassKg, 0.5);
  });

  test('weights and tank types are rejected as gear features', () {
    expect(
      () => feature(type: EquipmentType.weights, name: 'Lead'),
      throwsArgumentError,
    );
    expect(
      () => feature(type: EquipmentType.tank, name: 'AL80'),
      throwsArgumentError,
    );
  });
}
