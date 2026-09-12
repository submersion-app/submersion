import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const units = UnitFormatter(AppSettings());
  // Imperial formatter to prove the conversion arms are unit-aware, not
  // hard-coded to the metric identity.
  const imperial = UnitFormatter(
    AppSettings(
      depthUnit: DepthUnit.feet,
      pressureUnit: PressureUnit.psi,
      volumeUnit: VolumeUnit.cubicFeet,
      weightUnit: WeightUnit.pounds,
    ),
  );

  EquipmentAttribute thickness(String valueText) => EquipmentAttribute.curated(
    equipmentId: 'e1',
    key: EquipmentAttrKeys.thicknessMm,
    valueText: valueText,
    valueNum: parsePrimaryThickness(valueText),
  );

  final def = EquipmentAttributeCatalog.defFor(EquipmentAttrKeys.thicknessMm);

  test('thickness value appends the unit exactly once', () {
    // Multi-panel designation with no unit -> single " mm".
    expect(
      formatAttributeValue(thickness('5/4/3'), def, units, l10n),
      '5/4/3 mm',
    );
    // Bare number -> single " mm".
    expect(formatAttributeValue(thickness('5'), def, units, l10n), '5 mm');
  });

  test('legacy value that already carries the unit is not doubled', () {
    // The v124 migration preserves "6mm" verbatim in valueText; the formatter
    // must not render "6mm mm".
    expect(formatAttributeValue(thickness('6mm'), def, units, l10n), '6 mm');
    expect(formatAttributeValue(thickness('6 mm'), def, units, l10n), '6 mm');
    expect(
      formatAttributeValue(thickness('8/7/6mm'), def, units, l10n),
      '8/7/6 mm',
    );
  });

  test('number attribute renders value with its unit symbol', () {
    final buoyancy = EquipmentAttribute.curated(
      equipmentId: 'e1',
      key: EquipmentAttrKeys.buoyancyKg,
      valueNum: 2.5,
    );
    final buoyancyDef = EquipmentAttributeCatalog.defFor(
      EquipmentAttrKeys.buoyancyKg,
    );
    expect(formatAttributeValue(buoyancy, buoyancyDef, units, l10n), '2.5 kg');
  });

  group('attributeDisplayFromMetric', () {
    test('metric formatter is identity for every same-unit dimension', () {
      // Every dimension whose canonical storage unit is also its metric
      // display unit: kg, L, bar, m, mm. speedMps (stored m/s, shown m/min),
      // durationH (stored hours, shown minutes) and shortLengthM (stored m,
      // shown cm) are the deliberate exceptions and are asserted on their
      // own below.
      const rescaled = {
        AttributeDimension.speedMps,
        AttributeDimension.durationH,
        AttributeDimension.shortLengthM,
      };
      for (final d in AttributeDimension.values) {
        if (rescaled.contains(d)) continue;
        expect(
          attributeDisplayFromMetric(d, units, 10),
          closeTo(10, 1e-9),
          reason: 'metric $d should not scale',
        );
      }
    });

    test('speed converts out of canonical m/s in both unit systems', () {
      // Stored in m/s, but a DPV is specced in distance per minute on every
      // manufacturer's sheet: m/min metric, ft/min imperial (issue #1096).
      expect(
        attributeDisplayFromMetric(AttributeDimension.speedMps, units, 1),
        closeTo(60, 1e-6),
      );
      expect(
        attributeDisplayFromMetric(AttributeDimension.speedMps, imperial, 1),
        closeTo(196.85, 1e-2),
      );
    });

    test('duration converts hours to minutes in both unit systems', () {
      // Minutes are minutes in every market, so both formatters agree.
      expect(
        attributeDisplayFromMetric(AttributeDimension.durationH, units, 1.5),
        closeTo(90, 1e-9),
      );
      expect(
        attributeDisplayFromMetric(AttributeDimension.durationH, imperial, 1.5),
        closeTo(90, 1e-9),
      );
    });

    test('short length converts metres to cm or inches (issue #1804)', () {
      expect(
        attributeDisplayFromMetric(AttributeDimension.shortLengthM, units, 1),
        closeTo(100, 1e-9),
      );
      expect(
        attributeDisplayFromMetric(
          AttributeDimension.shortLengthM,
          imperial,
          0.0254,
        ),
        closeTo(1, 1e-9),
      );
    });

    test('imperial formatter converts each scaled dimension', () {
      expect(
        attributeDisplayFromMetric(AttributeDimension.massKg, imperial, 1),
        closeTo(2.20462, 1e-4),
      );
      expect(
        attributeDisplayFromMetric(AttributeDimension.volumeL, imperial, 1),
        closeTo(0.0353147, 1e-6),
      );
      expect(
        attributeDisplayFromMetric(AttributeDimension.pressureBar, imperial, 1),
        closeTo(14.5038, 1e-3),
      );
      expect(
        attributeDisplayFromMetric(AttributeDimension.lengthM, imperial, 1),
        closeTo(3.28084, 1e-4),
      );
      expect(
        attributeDisplayFromMetric(AttributeDimension.depthM, imperial, 1),
        closeTo(3.28084, 1e-4),
      );
      // thicknessMm and none stay in mm regardless of the diver's units.
      expect(
        attributeDisplayFromMetric(AttributeDimension.thicknessMm, imperial, 5),
        5,
      );
      expect(
        attributeDisplayFromMetric(AttributeDimension.none, imperial, 5),
        5,
      );
    });
  });

  test('attributeMetricFromDisplay round-trips every dimension', () {
    for (final d in AttributeDimension.values) {
      final display = attributeDisplayFromMetric(d, imperial, 7);
      expect(
        attributeMetricFromDisplay(d, imperial, display),
        closeTo(7, 1e-6),
        reason: '$d display->metric should invert metric->display',
      );
    }
  });

  test('attributeUnitSymbol returns the diver-facing symbol per dimension', () {
    expect(attributeUnitSymbol(AttributeDimension.massKg, imperial), 'lbs');
    expect(attributeUnitSymbol(AttributeDimension.volumeL, imperial), 'cuft');
    expect(
      attributeUnitSymbol(AttributeDimension.pressureBar, imperial),
      'psi',
    );
    expect(attributeUnitSymbol(AttributeDimension.lengthM, imperial), 'ft');
    expect(attributeUnitSymbol(AttributeDimension.depthM, imperial), 'ft');
    expect(attributeUnitSymbol(AttributeDimension.thicknessMm, imperial), 'mm');
    expect(
      attributeUnitSymbol(AttributeDimension.speedMps, imperial),
      'ft/min',
    );
    expect(attributeUnitSymbol(AttributeDimension.speedMps, units), 'm/min');
    expect(attributeUnitSymbol(AttributeDimension.durationH, imperial), 'min');
    expect(attributeUnitSymbol(AttributeDimension.durationH, units), 'min');
    expect(
      attributeUnitSymbol(AttributeDimension.shortLengthM, imperial),
      'in',
    );
    expect(attributeUnitSymbol(AttributeDimension.shortLengthM, units), 'cm');
    expect(attributeUnitSymbol(AttributeDimension.none, imperial), '');
  });

  group('formatAttributeValue', () {
    EquipmentAttribute attr({String? text, double? num}) => EquipmentAttribute(
      id: 'a1',
      equipmentId: 'e1',
      key: 'k',
      valueText: text,
      valueNum: num,
    );

    test('null def falls back to text, then num, then empty', () {
      expect(
        formatAttributeValue(attr(text: 'freeform'), null, units, l10n),
        'freeform',
      );
      expect(formatAttributeValue(attr(num: 3), null, units, l10n), '3.0');
      expect(formatAttributeValue(attr(), null, units, l10n), '');
    });

    test('text kind returns the stored text (empty when unset)', () {
      final def = EquipmentAttributeCatalog.defFor('tank_identifier');
      expect(
        formatAttributeValue(attr(text: 'DIN-42'), def, units, l10n),
        'DIN-42',
      );
      expect(formatAttributeValue(attr(), def, units, l10n), '');
    });

    test('thickness kind is empty when unset or unit-only', () {
      final def = EquipmentAttributeCatalog.defFor(
        EquipmentAttrKeys.thicknessMm,
      );
      expect(formatAttributeValue(attr(), def, units, l10n), '');
      // A stored value of just "mm" strips to an empty base -> empty string.
      expect(formatAttributeValue(attr(text: 'mm'), def, units, l10n), '');
    });

    test('number kind: empty when unset, integers drop the decimal', () {
      final def = EquipmentAttributeCatalog.defFor(
        EquipmentAttrKeys.buoyancyKg,
      );
      expect(formatAttributeValue(attr(), def, units, l10n), '');
      // 3.0 kg is a whole number -> "3 kg", not "3.0 kg".
      expect(formatAttributeValue(attr(num: 3), def, units, l10n), '3 kg');
    });

    test('number kind with no dimension omits the symbol', () {
      final def = EquipmentAttributeCatalog.defFor('lumens');
      expect(def!.dimension, AttributeDimension.none);
      expect(formatAttributeValue(attr(num: 800), def, units, l10n), '800');
    });

    test('formatAttributeNumberForEditing trims converted precision', () {
      final def = EquipmentAttributeCatalog.defFor(
        EquipmentAttrKeys.buoyancyKg,
      );
      // 2.5 kg -> pounds is a long decimal; the editable value must stay
      // readable (at most one decimal place, no leaked precision).
      final text = formatAttributeNumberForEditing(
        def!.dimension,
        imperial,
        2.5,
      );
      expect(text, matches(r'^\d+(\.\d)?$'));
      // A whole-number display drops the decimal entirely.
      expect(formatAttributeNumberForEditing(def.dimension, units, 3.0), '3');
    });

    test('a display value whole to one decimal drops the decimal', () {
      // 100 minutes round-trips through hours as 1.6666...h, which multiplies
      // back to 100.00000000000001 -- binary noise, not a real fraction. The
      // edit field must show "100", never "100.0".
      expect(
        formatAttributeNumberForEditing(
          AttributeDimension.durationH,
          units,
          100 / 60,
        ),
        '100',
      );
    });

    group('dpv (issue #1096)', () {
      test('burn time renders stored hours as minutes', () {
        final def = EquipmentAttributeCatalog.defFor('burn_time_h');
        // 1.5 stored hours is what a pre-#1096 diver entered under the
        // "Burn time (h)" label; it must now read as 90 min, not 1.5.
        expect(
          formatAttributeValue(attr(num: 1.5), def, units, l10n),
          '90 min',
        );
        expect(
          formatAttributeValue(attr(num: 1.5), def, imperial, l10n),
          '90 min',
        );
      });

      test('top speed renders in distance per minute, not km/h', () {
        final def = EquipmentAttributeCatalog.defFor('speed_mps');
        // 55 m/min is a typical tow-behind scooter's rated speed.
        final metricValue = attributeMetricFromDisplay(
          def!.dimension,
          units,
          55,
        );
        expect(
          formatAttributeValue(attr(num: metricValue), def, units, l10n),
          '55 m/min',
        );
        expect(
          formatAttributeValue(attr(num: metricValue), def, imperial, l10n),
          '180.4 ft/min',
        );
      });
    });

    group('hose and SMB length (issue #1804)', () {
      test('a hose typed in inches reads back in inches, not feet', () {
        final def = EquipmentAttributeCatalog.defFor('hose_length_m')!;
        // Hoses are sold by the inch: a 15" hose must not read as 1.3 ft.
        final stored = attributeMetricFromDisplay(def.dimension, imperial, 15);
        expect(
          formatAttributeValue(attr(num: stored), def, imperial, l10n),
          '15 in',
        );
        // Re-seeding the edit field must give back exactly what was typed.
        expect(
          formatAttributeNumberForEditing(def.dimension, imperial, stored),
          '15',
        );
      });

      test('a metric diver reads the same hose in centimetres', () {
        final def = EquipmentAttributeCatalog.defFor('hose_length_m')!;
        // 22" is 55.88 cm; one decimal place keeps the fraction visible.
        expect(
          formatAttributeValue(attr(num: 0.5588), def, units, l10n),
          '55.9 cm',
        );
        expect(
          formatAttributeValue(attr(num: 0.56), def, units, l10n),
          '56 cm',
        );
      });

      test('an SMB length shares the cm / in display', () {
        final def = EquipmentAttributeCatalog.defFor('length_m')!;
        expect(
          formatAttributeValue(attr(num: 1.4), def, units, l10n),
          '140 cm',
        );
        expect(
          formatAttributeValue(attr(num: 1.4), def, imperial, l10n),
          '55.1 in',
        );
      });
    });

    test('choice kind resolves the localized option label', () {
      final def = EquipmentAttributeCatalog.defFor('suit_style');
      expect(formatAttributeValue(attr(), def, units, l10n), '');
      expect(
        formatAttributeValue(attr(text: 'full'), def, units, l10n),
        attributeChoiceLabel(l10n, 'suit_style', 'full'),
      );
    });

    test('flag kind maps 1/0 to the yes/no labels, empty when unset', () {
      final def = EquipmentAttributeCatalog.defFor('cold_water_rated');
      expect(
        formatAttributeValue(attr(num: 1), def, units, l10n),
        l10n.attr_flagYes,
      );
      expect(
        formatAttributeValue(attr(num: 0), def, units, l10n),
        l10n.attr_flagNo,
      );
      // Unset renders empty rather than an explicit "No".
      expect(formatAttributeValue(attr(), def, units, l10n), '');
    });

    test('date kind formats the stored epoch millis, empty when unset', () {
      final def = EquipmentAttributeCatalog.defFor('last_hydro_test');
      expect(formatAttributeValue(attr(), def, units, l10n), '');
      final ms = DateTime(2026, 3, 14).millisecondsSinceEpoch.toDouble();
      expect(
        formatAttributeValue(attr(num: ms), def, units, l10n),
        units.formatDate(DateTime(2026, 3, 14)),
      );
    });
  });
}
