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
  AttributeDimension.thicknessMm || AttributeDimension.none => display,
};

String attributeUnitSymbol(AttributeDimension d, UnitFormatter units) =>
    switch (d) {
      AttributeDimension.massKg => units.weightSymbol,
      AttributeDimension.volumeL => units.volumeSymbol,
      AttributeDimension.pressureBar => units.pressureSymbol,
      AttributeDimension.lengthM ||
      AttributeDimension.depthM => units.depthSymbol,
      AttributeDimension.thicknessMm => 'mm',
      AttributeDimension.none => '',
    };

/// The display value of a metric-stored number formatted for a text field or
/// label, with no unit symbol: integers render without decimals, otherwise one
/// decimal place. Keeps edit fields readable after a unit conversion (e.g.
/// kg->lbs) instead of leaking full floating-point precision.
String formatAttributeNumberForEditing(
  AttributeDimension dimension,
  UnitFormatter units,
  double metricValue,
) {
  final display = attributeDisplayFromMetric(dimension, units, metricValue);
  return display == display.roundToDouble()
      ? display.toStringAsFixed(0)
      : display.toStringAsFixed(1);
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
