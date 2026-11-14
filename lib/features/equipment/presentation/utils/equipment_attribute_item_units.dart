import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/tank_capacity.dart';
import 'package:submersion/core/utils/per_minute.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/utils/unit_formatter_settings.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A unit one equipment number can be read and typed in (issue #4534).
///
/// Stored by [name] in `equipment_attributes.value_unit`. The length family
/// ([meters], [feet]) also covers short lengths (cm or in) and speeds (per
/// minute), the way the diver's own depth unit does. [dual] is a dual-scale
/// gauge: typed in the diver's pressure unit, shown in both.
enum AttributeUnit {
  bar,
  psi,
  dual,
  kilograms,
  pounds,
  liters,
  cubicFeet,
  meters,
  feet,
}

/// The units [def]'s picker offers, or none when it has no picker.
List<AttributeUnit> attributeUnitChoices(EquipmentAttributeDef def) {
  if (def.kind != AttributeKind.number || def.metricOnly) {
    return const [];
  }
  return switch (def.dimension) {
    AttributeDimension.pressureBar =>
      def.dualScale
          ? const [AttributeUnit.bar, AttributeUnit.psi, AttributeUnit.dual]
          : const [AttributeUnit.bar, AttributeUnit.psi],
    AttributeDimension.massKg => const [
      AttributeUnit.kilograms,
      AttributeUnit.pounds,
    ],
    AttributeDimension.volumeL => const [
      AttributeUnit.liters,
      AttributeUnit.cubicFeet,
    ],
    AttributeDimension.lengthM ||
    AttributeDimension.depthM ||
    AttributeDimension.shortLengthM ||
    AttributeDimension.speedMps => const [
      AttributeUnit.meters,
      AttributeUnit.feet,
    ],
    AttributeDimension.thicknessMm ||
    AttributeDimension.durationH ||
    AttributeDimension.none => const [],
  };
}

/// The unit [stored] names, when [def]'s picker offers it; anything else
/// (a future unit, a value from another field) reads as unset.
AttributeUnit? parseAttributeUnit(EquipmentAttributeDef def, String? stored) {
  if (stored == null) return null;
  for (final unit in attributeUnitChoices(def)) {
    if (unit.name == stored) return unit;
  }
  return null;
}

/// [dimension]'s canonical metric unit.
AttributeUnit? _metricUnit(AttributeDimension dimension) => switch (dimension) {
  AttributeDimension.pressureBar => AttributeUnit.bar,
  AttributeDimension.massKg => AttributeUnit.kilograms,
  AttributeDimension.volumeL => AttributeUnit.liters,
  AttributeDimension.lengthM ||
  AttributeDimension.depthM ||
  AttributeDimension.shortLengthM ||
  AttributeDimension.speedMps => AttributeUnit.meters,
  AttributeDimension.thicknessMm ||
  AttributeDimension.durationH ||
  AttributeDimension.none => null,
};

/// The diver's own unit for [dimension]. Lengths of every size and speeds
/// all follow the depth unit, as [UnitFormatter] reads them.
AttributeUnit? _diverUnit(AttributeDimension dimension, UnitFormatter units) {
  final metricLength = units.settings.depthUnit == DepthUnit.meters;
  return switch (dimension) {
    AttributeDimension.pressureBar =>
      units.settings.pressureUnit == PressureUnit.bar
          ? AttributeUnit.bar
          : AttributeUnit.psi,
    AttributeDimension.massKg =>
      units.settings.weightUnit == WeightUnit.kilograms
          ? AttributeUnit.kilograms
          : AttributeUnit.pounds,
    AttributeDimension.volumeL =>
      units.settings.volumeUnit == VolumeUnit.liters
          ? AttributeUnit.liters
          : AttributeUnit.cubicFeet,
    AttributeDimension.lengthM ||
    AttributeDimension.depthM ||
    AttributeDimension.shortLengthM ||
    AttributeDimension.speedMps =>
      metricLength ? AttributeUnit.meters : AttributeUnit.feet,
    AttributeDimension.thicknessMm ||
    AttributeDimension.durationH ||
    AttributeDimension.none => null,
  };
}

/// The unit [attr] of [def] is read in: its metric unit when the catalog
/// marks it metric-only (a rebreather cylinder), else the unit picked for
/// this item, else the diver's own.
///
/// Null for a field with no alternative unit (thickness, burn time, a plain
/// number), which keeps its existing fixed display.
AttributeUnit? attributeUnitInForce(
  EquipmentAttributeDef def,
  EquipmentAttribute? attr,
  UnitFormatter units,
) {
  if (def.metricOnly) return _metricUnit(def.dimension);
  return parseAttributeUnit(def, attr?.valueUnit) ??
      _diverUnit(def.dimension, units);
}

/// The unit a figure is typed in: Both types in the diver's pressure unit.
AttributeUnit attributeTypingUnit(AttributeUnit inForce, UnitFormatter units) {
  if (inForce != AttributeUnit.dual) return inForce;
  return units.settings.pressureUnit == PressureUnit.bar
      ? AttributeUnit.bar
      : AttributeUnit.psi;
}

/// A cylinder's volume in cubic feet, which is rated gas capacity at its
/// working pressure, not water volume.
bool isCylinderGasVolume(EquipmentAttributeDef def, AttributeUnit unit) =>
    def.key == EquipmentAttrKeys.volumeL && unit == AttributeUnit.cubicFeet;

const _cmPerInch = 2.54;

/// Canonical [metric] read in [unit]. [workingPressureBar] is the cylinder's,
/// for [isCylinderGasVolume]; without one the app assumes 200 bar.
double attributeValueIn(
  EquipmentAttributeDef def,
  AttributeUnit unit,
  double metric, {
  double? workingPressureBar,
}) {
  if (isCylinderGasVolume(def, unit)) {
    return ratedCapacityCuft(metric, workingPressureBar);
  }
  final imperial = unit == AttributeUnit.feet;
  return switch (def.dimension) {
    AttributeDimension.pressureBar =>
      unit == AttributeUnit.psi
          ? PressureUnit.bar.convert(metric, PressureUnit.psi)
          : metric,
    AttributeDimension.massKg =>
      unit == AttributeUnit.pounds
          ? WeightUnit.kilograms.convert(metric, WeightUnit.pounds)
          : metric,
    AttributeDimension.volumeL =>
      unit == AttributeUnit.cubicFeet
          ? VolumeUnit.liters.convert(metric, VolumeUnit.cubicFeet)
          : metric,
    AttributeDimension.shortLengthM =>
      imperial ? metric * 100 / _cmPerInch : metric * 100,
    AttributeDimension.speedMps => DepthUnit.meters.convert(
      metric * 60,
      _depth(unit),
    ),
    AttributeDimension.lengthM ||
    AttributeDimension.depthM => DepthUnit.meters.convert(metric, _depth(unit)),
    AttributeDimension.thicknessMm ||
    AttributeDimension.durationH ||
    AttributeDimension.none => metric,
  };
}

/// [value] read in [unit] back to canonical metric; the inverse of
/// [attributeValueIn].
double attributeMetricFromValue(
  EquipmentAttributeDef def,
  AttributeUnit unit,
  double value, {
  double? workingPressureBar,
}) {
  if (isCylinderGasVolume(def, unit)) {
    return volumeLitersFromCapacity(value, workingPressureBar);
  }
  final imperial = unit == AttributeUnit.feet;
  return switch (def.dimension) {
    AttributeDimension.pressureBar =>
      unit == AttributeUnit.psi
          ? PressureUnit.psi.convert(value, PressureUnit.bar)
          : value,
    AttributeDimension.massKg =>
      unit == AttributeUnit.pounds
          ? WeightUnit.pounds.convert(value, WeightUnit.kilograms)
          : value,
    AttributeDimension.volumeL =>
      unit == AttributeUnit.cubicFeet
          ? VolumeUnit.cubicFeet.convert(value, VolumeUnit.liters)
          : value,
    AttributeDimension.shortLengthM =>
      imperial ? value * _cmPerInch / 100 : value / 100,
    AttributeDimension.speedMps =>
      _depth(unit).convert(value, DepthUnit.meters) / 60,
    AttributeDimension.lengthM ||
    AttributeDimension.depthM => _depth(unit).convert(value, DepthUnit.meters),
    AttributeDimension.thicknessMm ||
    AttributeDimension.durationH ||
    AttributeDimension.none => value,
  };
}

DepthUnit _depth(AttributeUnit unit) =>
    unit == AttributeUnit.feet ? DepthUnit.feet : DepthUnit.meters;

/// How [unit] is named on [def]'s picker and beside its value.
String attributeUnitLabel(
  EquipmentAttributeDef def,
  AttributeUnit unit,
  AppLocalizations l10n,
) {
  final depth = _depth(unit).symbol;
  return switch (unit) {
    AttributeUnit.dual => l10n.attr_unitDual,
    AttributeUnit.bar => PressureUnit.bar.symbol,
    AttributeUnit.psi => PressureUnit.psi.symbol,
    AttributeUnit.kilograms => WeightUnit.kilograms.symbol,
    AttributeUnit.pounds => WeightUnit.pounds.symbol,
    AttributeUnit.liters => VolumeUnit.liters.symbol,
    AttributeUnit.cubicFeet => VolumeUnit.cubicFeet.symbol,
    AttributeUnit.meters || AttributeUnit.feet => switch (def.dimension) {
      AttributeDimension.shortLengthM =>
        unit == AttributeUnit.feet ? 'in' : 'cm',
      AttributeDimension.speedMps => perMinute(depth),
      _ => depth,
    },
  };
}

/// [units] reading volume and pressure the way [item]'s own cylinder spec
/// does, for readers that format a cylinder's volume and working pressure
/// through [UnitFormatter] (the passport card and printed labels). Anything
/// else they show keeps the diver's units.
UnitFormatter cylinderSpecUnits(EquipmentItem item, UnitFormatter units) {
  final volumeDef = EquipmentAttributeCatalog.defFor(EquipmentAttrKeys.volumeL);
  final pressureDef = EquipmentAttributeCatalog.defFor(
    EquipmentAttrKeys.workingPressureBar,
  );
  final volume = volumeDef == null
      ? null
      : parseAttributeUnit(volumeDef, item.attr(volumeDef.key)?.valueUnit);
  final pressure = pressureDef == null
      ? null
      : parseAttributeUnit(pressureDef, item.attr(pressureDef.key)?.valueUnit);
  if (volume == null && pressure == null) return units;
  return UnitFormatter(
    UnitFormatterSettingsOverride(
      units.settings,
      volumeUnit: switch (volume) {
        AttributeUnit.liters => VolumeUnit.liters,
        AttributeUnit.cubicFeet => VolumeUnit.cubicFeet,
        _ => null,
      },
      pressureUnit: switch (pressure) {
        AttributeUnit.bar => PressureUnit.bar,
        AttributeUnit.psi => PressureUnit.psi,
        _ => null,
      },
    ),
  );
}
