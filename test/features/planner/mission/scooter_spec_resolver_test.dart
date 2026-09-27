import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/scooter_spec_resolver.dart';

EquipmentItem _dpv({
  double? speedMps = 0.9,
  double? burnHours = 1.5,
  double? towSpeed,
  double? towBurn,
}) {
  EquipmentAttribute num(String key, double value) =>
      EquipmentAttribute.curated(
        equipmentId: 'dpv-1',
        key: key,
        valueNum: value,
      );
  return EquipmentItem(
    id: 'dpv-1',
    name: 'Blacktip',
    type: EquipmentType.dpv,
    attributes: [
      if (speedMps != null) num('speed_mps', speedMps),
      if (burnHours != null) num('burn_time_h', burnHours),
      if (towSpeed != null) num('tow_speed_factor', towSpeed),
      if (towBurn != null) num('tow_burn_factor', towBurn),
    ],
  );
}

void main() {
  const resolver = ScooterSpecResolver();

  group('fromEquipment', () {
    test('copies speed, burn time in seconds and the item id and name', () {
      final spec = resolver.fromEquipment(_dpv())!;
      expect(spec.equipmentId, 'dpv-1');
      expect(spec.name, 'Blacktip');
      expect(spec.ratedSpeedMps, 0.9);
      expect(spec.burnTimeSeconds, 5400);
      expect(spec.towSpeedFactor, kDefaultTowSpeedFactor);
      expect(spec.towBurnFactor, kDefaultTowBurnFactor);
    });

    test('uses the item tow factors when present', () {
      final spec = resolver.fromEquipment(_dpv(towSpeed: 0.5, towBurn: 2.0))!;
      expect(spec.towSpeedFactor, 0.5);
      expect(spec.towBurnFactor, 2.0);
    });

    test('is null without a speed or without a burn time', () {
      expect(resolver.fromEquipment(_dpv(speedMps: null)), isNull);
      expect(resolver.fromEquipment(_dpv(burnHours: null)), isNull);
    });
  });

  group('overlay', () {
    const stored = ScooterSpec(
      equipmentId: 'dpv-1',
      name: 'Old name',
      ratedSpeedMps: 0.7,
      burnTimeSeconds: 3600,
      towSpeedFactor: 0.55,
      towBurnFactor: 1.4,
    );

    test('live attributes win over the snapshot, absent ones keep it', () {
      final spec = resolver.overlay(stored, _dpv(towBurn: 2.0));
      expect(spec.name, 'Blacktip');
      expect(spec.ratedSpeedMps, 0.9);
      expect(spec.burnTimeSeconds, 5400);
      expect(spec.towBurnFactor, 2.0);
      expect(spec.towSpeedFactor, 0.55, reason: 'not on the item');
    });

    test('a deleted item leaves the snapshot untouched', () {
      expect(resolver.overlay(stored, null), stored);
    });

    test('a manual scooter is never overlaid', () {
      const manual = ScooterSpec(
        name: 'Manual',
        ratedSpeedMps: 0.6,
        burnTimeSeconds: 1800,
      );
      expect(resolver.overlay(manual, _dpv()), manual);
    });
  });
}
