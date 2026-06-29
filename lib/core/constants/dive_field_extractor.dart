import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';

/// Extension providing raw value extraction from [Dive] and [DiveSummary]
/// entities for each [DiveField].
extension DiveFieldExtractor on DiveField {
  /// Extract the raw value for this field from a full [Dive] entity.
  ///
  /// [sacUnit] selects which base value [DiveField.sacRate] yields: volume-based
  /// L/min ([Dive.sac]) or pressure-based bar/min ([Dive.sacPressure]). It must
  /// match the [UnitFormatter] later used to format the value so the unit suffix
  /// is correct. Defaults to [SacUnit.pressurePerMin] to match the AppSettings
  /// default, so an omitted argument stays consistent with default settings.
  /// Other fields ignore it.
  dynamic extractFromDive(
    Dive dive, {
    SacUnit sacUnit = SacUnit.pressurePerMin,
  }) {
    switch (this) {
      case DiveField.diveNumber:
        return dive.diveNumber;
      case DiveField.dateTime:
        return dive.effectiveEntryTime;
      case DiveField.siteName:
        return dive.site?.name;
      case DiveField.maxDepth:
        return dive.maxDepth;
      case DiveField.avgDepth:
        return dive.avgDepth;
      case DiveField.bottomTime:
        return dive.bottomTime;
      case DiveField.runtime:
        return dive.effectiveRuntime;
      case DiveField.waterTemp:
        return dive.waterTemp;
      case DiveField.airTemp:
        return dive.airTemp;
      case DiveField.visibility:
        return dive.visibility?.displayName;
      case DiveField.currentDirection:
        return dive.currentDirection?.displayName;
      case DiveField.currentStrength:
        return dive.currentStrength?.displayName;
      case DiveField.swellHeight:
        return dive.swellHeight;
      case DiveField.entryMethod:
        return dive.entryMethod?.displayName;
      case DiveField.exitMethod:
        return dive.exitMethod?.displayName;
      case DiveField.waterType:
        return dive.waterType?.displayName;
      case DiveField.altitude:
        return dive.altitude;
      case DiveField.surfacePressure:
        return dive.surfacePressure;
      case DiveField.windSpeed:
        return dive.windSpeed;
      case DiveField.cloudCover:
        return dive.cloudCover?.displayName;
      case DiveField.precipitation:
        return dive.precipitation?.displayName;
      case DiveField.humidity:
        return dive.humidity;
      case DiveField.weatherDescription:
        return dive.weatherDescription;
      case DiveField.primaryGas:
        return dive.tanks.isNotEmpty ? dive.tanks.first.gasMix.name : null;
      case DiveField.diluentGas:
        return dive.diluentGas?.name;
      case DiveField.tankCount:
        return dive.tanks.length;
      case DiveField.startPressure:
        return dive.tanks.isNotEmpty ? dive.tanks.first.startPressure : null;
      case DiveField.endPressure:
        return dive.tanks.isNotEmpty ? dive.tanks.first.endPressure : null;
      case DiveField.sacRate:
        return _computeSacRate(dive, sacUnit);
      case DiveField.gasConsumed:
        return _computeGasConsumed(dive);
      case DiveField.totalWeight:
        return dive.totalWeight > 0 ? dive.totalWeight : null;
      case DiveField.diveComputerModel:
        return dive.diveComputerModel;
      case DiveField.gradientFactorLow:
        return dive.gradientFactorLow;
      case DiveField.gradientFactorHigh:
        return dive.gradientFactorHigh;
      case DiveField.decoAlgorithm:
        return dive.decoAlgorithm;
      case DiveField.decoConservatism:
        return dive.decoConservatism;
      case DiveField.cnsStart:
        return null;
      case DiveField.cnsEnd:
        return null;
      case DiveField.otu:
        return null;
      case DiveField.diveMode:
        return dive.diveMode.name.toUpperCase();
      case DiveField.setpointLow:
        return dive.setpointLow;
      case DiveField.setpointHigh:
        return dive.setpointHigh;
      case DiveField.setpointDeco:
        return dive.setpointDeco;
      case DiveField.buddy:
        return dive.buddy;
      case DiveField.diveMaster:
        return dive.diveMaster;
      case DiveField.siteLocation:
        return dive.site?.locationString;
      case DiveField.diveCenterName:
        return dive.diveCenter?.name;
      case DiveField.siteLatitude:
        return dive.site?.location?.latitude;
      case DiveField.siteLongitude:
        return dive.site?.location?.longitude;
      case DiveField.tripName:
        return dive.trip?.name;
      case DiveField.ratingStars:
        return dive.rating;
      case DiveField.isFavorite:
        return dive.isFavorite;
      case DiveField.notes:
        return dive.notes.isNotEmpty ? dive.notes : null;
      case DiveField.tags:
        return dive.tags.map((t) => t.name).toList();
      case DiveField.importSource:
        return dive.importSource;
      case DiveField.diveTypeName:
        return dive.diveTypeNames.join(', ');
      case DiveField.surfaceInterval:
        return dive.surfaceInterval;
    }
  }

  /// Extract the raw value for this field from a [DiveSummary].
  ///
  /// Returns null for fields not available on [DiveSummary].
  dynamic extractFromSummary(DiveSummary summary) {
    switch (this) {
      case DiveField.diveNumber:
        return summary.diveNumber;
      case DiveField.dateTime:
        return summary.entryTime ?? summary.dateTime;
      case DiveField.siteName:
        return summary.siteName;
      case DiveField.maxDepth:
        return summary.maxDepth;
      case DiveField.avgDepth:
        return null;
      case DiveField.bottomTime:
        return summary.bottomTime;
      case DiveField.runtime:
        return summary.runtime;
      case DiveField.waterTemp:
        return summary.waterTemp;
      case DiveField.ratingStars:
        return summary.rating;
      case DiveField.isFavorite:
        return summary.isFavorite;
      case DiveField.diveTypeName:
        return summary.diveTypeIds.map(Dive.diveTypeDisplayName).join(', ');
      case DiveField.tags:
        return summary.tags.map((t) => t.name).toList();
      case DiveField.siteLocation:
        return summary.siteLocation;
      case DiveField.siteLatitude:
        return summary.siteLatitude;
      case DiveField.siteLongitude:
        return summary.siteLongitude;
      default:
        return null;
    }
  }
}

/// Compute the SAC rate (Surface Air Consumption) for a [Dive].
///
/// Returns the base value matching [sacUnit]:
/// - [SacUnit.litersPerMin]: volume-based L/min from [Dive.sac] (sums gas across
///   all tanks with volume data).
/// - [SacUnit.pressurePerMin]: pressure-based bar/min from [Dive.sacPressure]
///   (back gas tank pressure drop; no tank volume required).
double? _computeSacRate(Dive dive, SacUnit sacUnit) =>
    sacUnit == SacUnit.litersPerMin ? dive.sac : dive.sacPressure;

/// Compute the total gas consumed in liters across all tanks of a [Dive].
double? _computeGasConsumed(Dive dive) {
  if (dive.tanks.isEmpty) return null;
  double total = 0;
  for (final tank in dive.tanks) {
    if (tank.startPressure == null ||
        tank.endPressure == null ||
        tank.volume == null) {
      continue;
    }
    final used = tank.startPressure! - tank.endPressure!;
    if (used <= 0) continue;
    total += tank.volume! * used;
  }
  return total > 0 ? total : null;
}
