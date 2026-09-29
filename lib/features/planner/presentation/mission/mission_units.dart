import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_units.dart';

/// Display and input conversion for a DPV mission's numbers, in the active
/// diver's units. Stored values are metric: metres, m/s and L/min.
///
/// Speeds use the equipment attribute path (m/min or ft/min, following the
/// depth unit), the convention the DPV catalog attributes already use, not
/// the wind and boat speed format.
class MissionUnits {
  MissionUnits(this.units);

  final UnitFormatter units;

  String distance(double meters) => units.formatDistance(meters);
  double distanceDisplay(double meters) => units.convertDepth(meters);
  double distanceMeters(double display) => units.depthToMeters(display);
  String get distanceSymbol => units.depthSymbol;

  double speedDisplay(double mps) =>
      attributeDisplayFromMetric(AttributeDimension.speedMps, units, mps);
  double speedMps(double display) =>
      attributeMetricFromDisplay(AttributeDimension.speedMps, units, display);
  String get speedSymbol =>
      attributeUnitSymbol(AttributeDimension.speedMps, units);
  String speed(double mps) =>
      '${speedDisplay(mps).toStringAsFixed(0)} $speedSymbol';

  double sacDisplay(double litersPerMin) => units.convertRmv(litersPerMin);
  double sacLitersPerMin(double display) => units.volumeToLiters(display);
  String get sacSymbol => units.rmvSymbol;
  int get sacDecimals => units.rmvDecimals;
  String sac(double litersPerMin) => units.formatRmv(litersPerMin);

  String heading(double degrees) => '${degrees.round() % 360}°';
}
