import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_attribute_codec.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const _imperial = AppSettings(
  depthUnit: DepthUnit.feet,
  temperatureUnit: TemperatureUnit.fahrenheit,
  pressureUnit: PressureUnit.psi,
  volumeUnit: VolumeUnit.cubicFeet,
  weightUnit: WeightUnit.pounds,
  dateFormat: DateFormatPreference.mmddyyyy,
);
const _metricDiver = AppSettings(dateFormat: DateFormatPreference.ddmmyyyy);

EquipmentAttribute _num(String key, double n) =>
    EquipmentAttribute.curated(equipmentId: 'e', key: key, valueNum: n);

/// Every curated number attribute whose dimension carries a unit.
List<EquipmentAttributeDef> _unitDefs() {
  final seen = <String, EquipmentAttributeDef>{};
  for (final type in EquipmentType.values) {
    for (final def in EquipmentAttributeCatalog.attributesFor(type)) {
      if (myUnitsKeyFor(def.key) != null) seen[def.key] = def;
    }
  }
  return seen.values.toList();
}

void main() {
  test('Metric mode writes the stored key and raw value', () {
    expect(
      formatAttributePair(_num('hose_length_m', 0.5588), CsvExportUnits.metric),
      'hose_length_m=0.5588',
    );
  });

  test('My units drops the metric suffix and names the unit', () {
    final imperial = CsvExportUnits.fromSettings(_imperial);
    expect(
      formatAttributePair(_num('hose_length_m', 0.5588), imperial),
      'hose_length=22 in',
    );
    expect(
      formatAttributePair(_num('burn_time_h', 1.5), imperial),
      'burn_time=90 min',
    );
    expect(
      formatAttributePair(_num('volume_l', 11.1), imperial),
      'volume=0.392 cuft',
    );
    final metric = CsvExportUnits.fromSettings(_metricDiver);
    expect(
      formatAttributePair(_num('hose_length_m', 0.5588), metric),
      'hose_length=55.9 cm',
    );
  });

  test('no My units pair ever uses a metric-suffixed key', () {
    final imperial = CsvExportUnits.fromSettings(_imperial);
    final defs = _unitDefs();
    expect(defs, isNotEmpty);
    for (final def in defs) {
      final pair = formatAttributePair(_num(def.key, 12.34), imperial);
      expect(pair.startsWith('${def.key}='), isFalse, reason: pair);
    }
  });

  test('stripped keys are unique across the catalog', () {
    final bases = _unitDefs().map((d) => myUnitsKeyFor(d.key)).toList();
    expect(bases.toSet().length, bases.length);
  });

  test('every unit attribute round trips in both unit systems', () {
    for (final settings in [_imperial, _metricDiver]) {
      final units = CsvExportUnits.fromSettings(settings);
      for (final def in _unitDefs()) {
        final pair = formatAttributePair(_num(def.key, 12.34), units);
        final back = parseAttributePair(pair)!;
        expect(back.key, def.key, reason: pair);
        expect(back.isCustom, isFalse);
        expect(back.valueNum, closeTo(12.34, 12.34 * 0.01), reason: pair);
      }
    }
  });

  test('Metric pairs read back exactly', () {
    expect(parseAttributePair('hose_length_m=0.5588'), (
      key: 'hose_length_m',
      isCustom: false,
      valueText: null,
      valueNum: 0.5588,
    ));
    expect(parseAttributePair('tank_material=aluminum'), (
      key: 'tank_material',
      isCustom: false,
      valueText: 'aluminum',
      valueNum: null,
    ));
    expect(
      parseAttributePair('installed_date=1741996800000.0')!.valueNum,
      1741996800000,
    );
  });

  test('a My units date reads with the file date format as local midnight', () {
    final units = CsvExportUnits.fromSettings(_imperial);
    final ms = DateTime(2025, 3, 15).millisecondsSinceEpoch.toDouble();
    final pair = formatAttributePair(_num('installed_date', ms), units);
    expect(pair, 'installed_date=03/15/2025');
    expect(
      parseAttributePair(
        pair,
        dateFormat: DateFormatPreference.mmddyyyy,
      )!.valueNum,
      ms,
    );
  });

  test(
    'unknown keys become custom text; unreadable curated values are null',
    () {
      expect(parseAttributePair('Batch=B-77'), (
        key: 'Batch',
        isCustom: true,
        valueText: 'B-77',
        valueNum: null,
      ));
      expect(parseAttributePair('hose_length_m=long'), isNull);
      expect(parseAttributePair('no equals sign'), isNull);
    },
  );

  test('splitting keeps a "; " that is inside a text value', () {
    expect(splitAttributePairs('retailer=A; B; sku=9'), [
      'retailer=A; B',
      'sku=9',
    ]);
    expect(splitAttributePairs(''), isEmpty);
  });

  test('a custom key that collides with a curated one is marked', () {
    const custom = EquipmentAttribute(
      id: 'c',
      equipmentId: 'e',
      key: 'size',
      isCustom: true,
      valueText: 'XL',
    );
    for (final units in [
      CsvExportUnits.metric,
      CsvExportUnits.fromSettings(_imperial),
    ]) {
      final pair = formatAttributePair(custom, units);
      expect(pair, 'custom:size=XL');
      expect(parseAttributePair(pair), (
        key: 'size',
        isCustom: true,
        valueText: 'XL',
        valueNum: null,
      ));
    }
    // A stripped My units key collides too.
    const hose = EquipmentAttribute(
      id: 'h',
      equipmentId: 'e',
      key: 'hose_length',
      isCustom: true,
      valueText: 'long',
    );
    expect(
      formatAttributePair(hose, CsvExportUnits.metric),
      'custom:hose_length=long',
    );
  });

  test('a custom key that collides with nothing is written as before', () {
    const custom = EquipmentAttribute(
      id: 'c',
      equipmentId: 'e',
      key: 'Batch',
      isCustom: true,
      valueText: 'B-77',
    );
    expect(formatAttributePair(custom, CsvExportUnits.metric), 'Batch=B-77');
  });

  test('a new file escapes "; " inside a value so it cannot split', () {
    final cell = joinAttributePairs(['retailer=A; sku=9', 'sku=7']);
    expect(cell, r'retailer=A\; sku=9; sku=7');
    expect(splitAttributePairs(cell), ['retailer=A; sku=9', 'sku=7']);
  });

  group('color', () {
    test('a colour code reads back as the item colour, uppercase', () {
      expect(parseAttributePair('color=#ef4444'), (
        key: 'color',
        isCustom: false,
        valueText: '#EF4444',
        valueNum: null,
      ));
    });

    test('an older file\'s custom "color" field stays a custom field', () {
      expect(parseAttributePair('color=Red'), (
        key: 'color',
        isCustom: true,
        valueText: 'Red',
        valueNum: null,
      ));
    });

    test('a colour code on a type that takes one is the item colour', () {
      expect(parseAttributePair('color=#ef4444', type: EquipmentType.fins), (
        key: 'color',
        isCustom: false,
        valueText: '#EF4444',
        valueNum: null,
      ));
    });

    // Issue #2520: a battery, O2 cell or Other item has no colour, so the
    // value stays the diver's own field instead of a colour the form drops.
    for (final type in [
      EquipmentType.battery,
      EquipmentType.o2Cell,
      EquipmentType.other,
    ]) {
      test('a colour code on ${type.name} stays a custom field', () {
        expect(parseAttributePair('color=#ef4444', type: type), (
          key: 'color',
          isCustom: true,
          valueText: '#ef4444',
          valueNum: null,
        ));
      });
    }
  });

  group('focal length (#3050)', () {
    EquipmentAttribute focal({String? text, double? num}) =>
        EquipmentAttribute.curated(
          equipmentId: 'e',
          key: 'focal_length_mm',
          valueText: text,
          valueNum: num,
        );

    test('a zoom writes and reads back its range', () {
      final pair = formatAttributePair(
        focal(text: '15-45', num: 15),
        CsvExportUnits.metric,
      );
      expect(pair, 'focal_length_mm=15-45');
      expect(parseAttributePair(pair), (
        key: 'focal_length_mm',
        isCustom: false,
        valueText: '15-45',
        valueNum: 15.0,
      ));
    });

    test('My units writes the range unchanged under the same key', () {
      // Quoted in mm in every unit system, so nothing converts or renames.
      expect(
        formatAttributePair(
          focal(text: '15-45', num: 15),
          CsvExportUnits.fromSettings(_imperial),
        ),
        'focal_length_mm=15-45',
      );
    });

    test('a lens saved as a single number reads back unchanged', () {
      // Files written before #3050 carry the number alone, as "60.0".
      final pair = formatAttributePair(focal(num: 60), CsvExportUnits.metric);
      expect(pair, 'focal_length_mm=60.0');
      expect(parseAttributePair(pair), (
        key: 'focal_length_mm',
        isCustom: false,
        valueText: null,
        valueNum: 60.0,
      ));
    });

    test('a non-finite number is not read as a focal length', () {
      expect(parseAttributePair('focal_length_mm=Infinity'), (
        key: 'focal_length_mm',
        isCustom: false,
        valueText: 'Infinity',
        valueNum: null,
      ));
    });

    test('a value that is not a focal length keeps its text', () {
      expect(parseAttributePair('focal_length_mm=wide'), (
        key: 'focal_length_mm',
        isCustom: false,
        valueText: 'wide',
        valueNum: null,
      ));
    });
  });
}
