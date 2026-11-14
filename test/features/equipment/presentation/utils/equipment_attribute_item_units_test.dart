import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_item_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Per-item units for equipment numbers (issue #4534).
void main() {
  EquipmentAttributeDef def(String key) =>
      EquipmentAttributeCatalog.defFor(key)!;

  final gauge = def('gauge_max_pressure_bar');
  final workingPressure = def(EquipmentAttrKeys.workingPressureBar);
  final tankVolume = def(EquipmentAttrKeys.volumeL);
  final diluent = def('diluent_cylinder_l');
  final dryWeight = def(EquipmentAttrKeys.dryWeightKg);
  final hoseLength = def('hose_length_m');
  final speed = def('speed_mps');

  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(
    AppSettings(
      depthUnit: DepthUnit.feet,
      pressureUnit: PressureUnit.psi,
      volumeUnit: VolumeUnit.cubicFeet,
      weightUnit: WeightUnit.pounds,
    ),
  );

  EquipmentAttribute attr(EquipmentAttributeDef d, {String? unit}) =>
      EquipmentAttribute.curated(
        equipmentId: 'e1',
        key: d.key,
        valueNum: 1,
        valueUnit: unit,
      );

  group('attributeUnitChoices', () {
    test('the gauge range offers bar, psi and Both', () {
      expect(attributeUnitChoices(gauge), [
        AttributeUnit.bar,
        AttributeUnit.psi,
        AttributeUnit.dual,
      ]);
    });

    test('other pressures offer bar and psi only', () {
      expect(attributeUnitChoices(workingPressure), [
        AttributeUnit.bar,
        AttributeUnit.psi,
      ]);
    });

    test('mass, volume and length families offer their two units', () {
      expect(attributeUnitChoices(dryWeight), [
        AttributeUnit.kilograms,
        AttributeUnit.pounds,
      ]);
      expect(attributeUnitChoices(tankVolume), [
        AttributeUnit.liters,
        AttributeUnit.cubicFeet,
      ]);
      expect(attributeUnitChoices(hoseLength), [
        AttributeUnit.meters,
        AttributeUnit.feet,
      ]);
      expect(attributeUnitChoices(speed), [
        AttributeUnit.meters,
        AttributeUnit.feet,
      ]);
    });

    test('rebreather cylinders, thickness and burn time offer nothing', () {
      expect(attributeUnitChoices(diluent), isEmpty);
      expect(attributeUnitChoices(def('o2_cylinder_l')), isEmpty);
      expect(attributeUnitChoices(def(EquipmentAttrKeys.thicknessMm)), isEmpty);
      expect(attributeUnitChoices(def('burn_time_h')), isEmpty);
    });
  });

  group('parseAttributeUnit', () {
    test('reads a unit the field offers', () {
      expect(parseAttributeUnit(gauge, 'psi'), AttributeUnit.psi);
      expect(parseAttributeUnit(gauge, 'dual'), AttributeUnit.dual);
    });

    test('reads a unit the field does not offer as unset', () {
      expect(parseAttributeUnit(workingPressure, 'dual'), isNull);
      expect(parseAttributeUnit(dryWeight, 'psi'), isNull);
      expect(parseAttributeUnit(gauge, 'furlongs'), isNull);
      expect(parseAttributeUnit(gauge, null), isNull);
    });
  });

  group('attributeUnitInForce', () {
    test('a picked unit holds whatever the diver uses', () {
      expect(
        attributeUnitInForce(gauge, attr(gauge, unit: 'bar'), imperial),
        AttributeUnit.bar,
      );
      expect(
        attributeUnitInForce(gauge, attr(gauge, unit: 'psi'), metric),
        AttributeUnit.psi,
      );
    });

    test('an unset field follows the diver', () {
      expect(
        attributeUnitInForce(gauge, attr(gauge), imperial),
        AttributeUnit.psi,
      );
      expect(attributeUnitInForce(gauge, null, metric), AttributeUnit.bar);
      expect(
        attributeUnitInForce(hoseLength, null, imperial),
        AttributeUnit.feet,
      );
    });

    test('rebreather cylinders always read litres', () {
      expect(
        attributeUnitInForce(diluent, null, imperial),
        AttributeUnit.liters,
      );
      expect(
        attributeUnitInForce(diluent, attr(diluent, unit: 'cubicFeet'), metric),
        AttributeUnit.liters,
      );
    });
  });

  test('Both is typed in the diver\'s own pressure unit', () {
    expect(attributeTypingUnit(AttributeUnit.dual, metric), AttributeUnit.bar);
    expect(
      attributeTypingUnit(AttributeUnit.dual, imperial),
      AttributeUnit.psi,
    );
    expect(attributeTypingUnit(AttributeUnit.psi, metric), AttributeUnit.psi);
  });

  group('conversion', () {
    test('a psi gauge reads and stores through bar', () {
      expect(
        attributeValueIn(gauge, AttributeUnit.psi, 275.79),
        closeTo(4000, 0.1),
      );
      expect(
        attributeMetricFromValue(gauge, AttributeUnit.psi, 4000),
        closeTo(275.79, 0.01),
      );
    });

    test('cylinder cubic feet are gas capacity at working pressure', () {
      // The AL80 preset is rated at 77.4 cu ft at 3000 psi.
      final al80 = TankPresets.matchByCapacity(77.4, 206.8)!;
      expect(al80.volumeLiters, 11.1);
      expect(
        attributeMetricFromValue(
          tankVolume,
          AttributeUnit.cubicFeet,
          77.4,
          workingPressureBar: 206.8,
        ),
        al80.volumeLiters,
      );
      expect(
        attributeValueIn(
          tankVolume,
          AttributeUnit.cubicFeet,
          al80.volumeLiters,
          workingPressureBar: 206.8,
        ),
        77.4,
      );
    });

    test('with no working pressure the app assumes 200 bar', () {
      expect(
        attributeMetricFromValue(tankVolume, AttributeUnit.cubicFeet, 80),
        closeTo(80 * 28.3168 / 200, 1e-9),
      );
    });

    test('a bag volume in cubic feet is plain volume', () {
      final bag = def('capacity_l');
      expect(
        attributeValueIn(bag, AttributeUnit.cubicFeet, 28.3168),
        closeTo(1, 0.001),
      );
    });

    test('a short length in feet reads inches', () {
      expect(
        attributeValueIn(hoseLength, AttributeUnit.feet, 0.9144),
        closeTo(36, 0.01),
      );
      expect(
        attributeMetricFromValue(hoseLength, AttributeUnit.meters, 90),
        closeTo(0.9, 1e-9),
      );
    });

    test('a speed reads per minute', () {
      expect(
        attributeValueIn(speed, AttributeUnit.meters, 1),
        closeTo(60, 1e-9),
      );
      expect(
        attributeMetricFromValue(speed, AttributeUnit.feet, 196.85),
        closeTo(1, 0.001),
      );
    });

    test('pounds read and store through kilograms', () {
      expect(
        attributeMetricFromValue(dryWeight, AttributeUnit.pounds, 10),
        closeTo(4.5359, 0.001),
      );
    });
  });

  group('attributeUnitLabel', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('names each unit by its symbol', () {
      expect(attributeUnitLabel(gauge, AttributeUnit.psi, l10n), 'psi');
      expect(attributeUnitLabel(dryWeight, AttributeUnit.pounds, l10n), 'lbs');
      expect(
        attributeUnitLabel(tankVolume, AttributeUnit.cubicFeet, l10n),
        'cuft',
      );
      expect(attributeUnitLabel(hoseLength, AttributeUnit.feet, l10n), 'in');
      expect(attributeUnitLabel(hoseLength, AttributeUnit.meters, l10n), 'cm');
      expect(attributeUnitLabel(speed, AttributeUnit.feet, l10n), 'ft/min');
      expect(
        attributeUnitLabel(def('depth_rating_m'), AttributeUnit.meters, l10n),
        'm',
      );
    });

    test('names Both in words', () {
      expect(attributeUnitLabel(gauge, AttributeUnit.dual, l10n), 'Both');
    });
  });
}
