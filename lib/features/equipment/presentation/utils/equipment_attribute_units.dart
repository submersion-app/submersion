import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Canonical metric -> diver's display units. thicknessMm and none are
/// identity (mm is the industry convention in every market).
double attributeDisplayFromMetric(
  AttributeDimension d,
  UnitFormatter units,
  double metric,
) => switch (d) {
  AttributeDimension.massKg => units.convertWeight(metric),
  AttributeDimension.volumeL => units.convertVolume(metric),
  AttributeDimension.pressureBar => units.convertPressure(metric),
  AttributeDimension.lengthM ||
  AttributeDimension.depthM => units.convertDepth(metric),
  // Stored in m/s (see AttributeDimension.speedMps), read as distance per
  // minute: m/s -> m/min is x60, then the depth conversion carries it to
  // ft/min for an imperial diver. Same shape as the ascent-rate axis, which
  // is the app's other distance-per-minute readout.
  AttributeDimension.speedMps => units.convertDepth(metric * 60),
  // Stored in hours, read in minutes; a minute is a minute in every market.
  AttributeDimension.durationH => metric * 60,
  AttributeDimension.thicknessMm || AttributeDimension.none => metric,
};

/// Diver's display units -> canonical metric (storage).
double attributeMetricFromDisplay(
  AttributeDimension d,
  UnitFormatter units,
  double display,
) => switch (d) {
  AttributeDimension.massKg => units.weightToKg(display),
  AttributeDimension.volumeL => units.volumeToLiters(display),
  AttributeDimension.pressureBar => units.pressureToBar(display),
  AttributeDimension.lengthM ||
  AttributeDimension.depthM => units.depthToMeters(display),
  AttributeDimension.speedMps => units.depthToMeters(display) / 60,
  AttributeDimension.durationH => display / 60,
  AttributeDimension.thicknessMm || AttributeDimension.none => display,
};

String attributeUnitSymbol(AttributeDimension d, UnitFormatter units) =>
    switch (d) {
      AttributeDimension.massKg => units.weightSymbol,
      AttributeDimension.volumeL => units.volumeSymbol,
      AttributeDimension.pressureBar => units.pressureSymbol,
      AttributeDimension.lengthM ||
      AttributeDimension.depthM => units.depthSymbol,
      AttributeDimension.speedMps => '${units.depthSymbol}/min',
      AttributeDimension.durationH => 'min',
      AttributeDimension.thicknessMm => 'mm',
      AttributeDimension.none => '',
    };

/// The display value of a metric-stored number formatted for a text field or
/// label, with no unit symbol: integers render without decimals, otherwise one
/// decimal place. Keeps edit fields readable after a unit conversion (e.g.
/// kg->lbs) instead of leaking full floating-point precision.
///
/// Rendered in the diver's locale, matching how the field is read back with
/// [parseUserDecimal]. Seeding "7.5" where ',' is the decimal separator and '.'
/// groups thousands would make an untouched re-save store 75 (#1091).
String formatAttributeNumberForEditing(
  AttributeDimension dimension,
  UnitFormatter units,
  double metricValue,
) {
  final display = attributeDisplayFromMetric(dimension, units, metricValue);
  // Rounds to the one decimal place actually rendered BEFORE deciding whether
  // the value is whole, then drops a trailing zero. A per-time round trip
  // (100 min -> 1.666..h -> 100.000...1) is binary noise, not a fraction the
  // diver typed, and must still read as "100" rather than "100.0".
  return formatRoundedForInput(display, 1);
}

/// Display string for a stored attribute value (detail page, CSV).
String formatAttributeValue(
  EquipmentAttribute attr,
  EquipmentAttributeDef? def,
  UnitFormatter units,
  AppLocalizations l10n,
) {
  if (def == null) return attr.valueText ?? attr.valueNum?.toString() ?? '';
  switch (def.kind) {
    case AttributeKind.text:
      return attr.valueText ?? '';
    case AttributeKind.thickness:
      if (attr.valueText == null) return '';
      // Strip any unit the stored designation already carries (legacy values
      // like "6mm" that the v124 migration preserved verbatim) so the unit is
      // appended exactly once.
      final raw = attr.valueText!.trim();
      final base = raw.toLowerCase().endsWith('mm')
          ? raw.substring(0, raw.length - 2).trim()
          : raw;
      return base.isEmpty ? '' : '$base mm';
    case AttributeKind.number:
      if (attr.valueNum == null) return '';
      final text = formatAttributeNumberForEditing(
        def.dimension,
        units,
        attr.valueNum!,
      );
      final symbol = attributeUnitSymbol(def.dimension, units);
      return symbol.isEmpty ? text : '$text $symbol';
    case AttributeKind.choice:
      return attr.valueText == null
          ? ''
          : attributeChoiceLabel(l10n, def.key, attr.valueText!);
    case AttributeKind.flag:
      // Unset (null) renders empty like the other kinds; only an explicit 0/1
      // maps to No/Yes.
      if (attr.valueNum == null) return '';
      return attr.valueNum == 1 ? l10n.attr_flagYes : l10n.attr_flagNo;
    case AttributeKind.date:
      return attr.valueNum == null
          ? ''
          : units.formatDate(
              DateTime.fromMillisecondsSinceEpoch(attr.valueNum!.toInt()),
            );
  }
}
