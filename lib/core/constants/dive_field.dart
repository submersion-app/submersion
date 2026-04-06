import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';

/// Categories grouping related dive fields together.
enum DiveFieldCategory {
  core,
  environment,
  gas,
  tank,
  weight,
  equipment,
  deco,
  physiology,
  rebreather,
  people,
  location,
  trip,
  rating,
  metadata,
}

/// Enumeration of every field from the Dive entity that can appear in
/// table or card views.
enum DiveField {
  // Core
  diveNumber,
  dateTime,
  siteName,
  maxDepth,
  avgDepth,
  bottomTime,
  runtime,

  // Environment
  waterTemp,
  airTemp,
  visibility,
  currentDirection,
  currentStrength,
  swellHeight,
  entryMethod,
  exitMethod,
  waterType,
  altitude,
  surfacePressure,
  windSpeed,
  cloudCover,
  precipitation,
  humidity,
  weatherDescription,

  // Gas
  primaryGas,
  diluentGas,

  // Tank
  tankCount,
  startPressure,
  endPressure,
  sacRate,
  gasConsumed,

  // Weight
  totalWeight,

  // Equipment
  diveComputerModel,

  // Deco
  gradientFactorLow,
  gradientFactorHigh,
  decoAlgorithm,
  decoConservatism,

  // Physiology
  cnsStart,
  cnsEnd,
  otu,

  // Rebreather
  diveMode,
  setpointLow,
  setpointHigh,
  setpointDeco,

  // People
  buddy,
  diveMaster,

  // Location
  siteLocation,
  diveCenterName,
  siteLatitude,
  siteLongitude,

  // Trip
  tripName,

  // Rating
  ratingStars,
  isFavorite,

  // Metadata
  notes,
  tags,
  importSource,
  diveTypeName,
  surfaceInterval;

  /// Set of fields available on [DiveSummary] (used for optimized list display).
  static const Set<DiveField> summaryFields = {
    DiveField.diveNumber,
    DiveField.dateTime,
    DiveField.siteName,
    DiveField.siteLocation,
    DiveField.maxDepth,
    DiveField.bottomTime,
    DiveField.runtime,
    DiveField.waterTemp,
    DiveField.ratingStars,
    DiveField.isFavorite,
    DiveField.diveTypeName,
    DiveField.tags,
    DiveField.siteLatitude,
    DiveField.siteLongitude,
  };

  /// Returns all [DiveField] values belonging to the given [category].
  static List<DiveField> fieldsForCategory(DiveFieldCategory category) {
    return DiveField.values.where((f) => f.category == category).toList();
  }
}

extension DiveFieldMetadata on DiveField {
  /// The category this field belongs to.
  DiveFieldCategory get category {
    switch (this) {
      case DiveField.diveNumber:
      case DiveField.dateTime:
      case DiveField.siteName:
      case DiveField.maxDepth:
      case DiveField.avgDepth:
      case DiveField.bottomTime:
      case DiveField.runtime:
        return DiveFieldCategory.core;

      case DiveField.waterTemp:
      case DiveField.airTemp:
      case DiveField.visibility:
      case DiveField.currentDirection:
      case DiveField.currentStrength:
      case DiveField.swellHeight:
      case DiveField.entryMethod:
      case DiveField.exitMethod:
      case DiveField.waterType:
      case DiveField.altitude:
      case DiveField.surfacePressure:
      case DiveField.windSpeed:
      case DiveField.cloudCover:
      case DiveField.precipitation:
      case DiveField.humidity:
      case DiveField.weatherDescription:
        return DiveFieldCategory.environment;

      case DiveField.primaryGas:
      case DiveField.diluentGas:
        return DiveFieldCategory.gas;

      case DiveField.tankCount:
      case DiveField.startPressure:
      case DiveField.endPressure:
      case DiveField.sacRate:
      case DiveField.gasConsumed:
        return DiveFieldCategory.tank;

      case DiveField.totalWeight:
        return DiveFieldCategory.weight;

      case DiveField.diveComputerModel:
        return DiveFieldCategory.equipment;

      case DiveField.gradientFactorLow:
      case DiveField.gradientFactorHigh:
      case DiveField.decoAlgorithm:
      case DiveField.decoConservatism:
        return DiveFieldCategory.deco;

      case DiveField.cnsStart:
      case DiveField.cnsEnd:
      case DiveField.otu:
        return DiveFieldCategory.physiology;

      case DiveField.diveMode:
      case DiveField.setpointLow:
      case DiveField.setpointHigh:
      case DiveField.setpointDeco:
        return DiveFieldCategory.rebreather;

      case DiveField.buddy:
      case DiveField.diveMaster:
        return DiveFieldCategory.people;

      case DiveField.siteLocation:
      case DiveField.diveCenterName:
      case DiveField.siteLatitude:
      case DiveField.siteLongitude:
        return DiveFieldCategory.location;

      case DiveField.tripName:
        return DiveFieldCategory.trip;

      case DiveField.ratingStars:
      case DiveField.isFavorite:
        return DiveFieldCategory.rating;

      case DiveField.notes:
      case DiveField.tags:
      case DiveField.importSource:
      case DiveField.diveTypeName:
      case DiveField.surfaceInterval:
        return DiveFieldCategory.metadata;
    }
  }

  /// Full human-readable name for use in settings and picker UIs.
  String get displayName {
    switch (this) {
      case DiveField.diveNumber:
        return 'Dive Number';
      case DiveField.dateTime:
        return 'Date & Time';
      case DiveField.siteName:
        return 'Site Name';
      case DiveField.maxDepth:
        return 'Max Depth';
      case DiveField.avgDepth:
        return 'Average Depth';
      case DiveField.bottomTime:
        return 'Bottom Time';
      case DiveField.runtime:
        return 'Runtime';
      case DiveField.waterTemp:
        return 'Water Temperature';
      case DiveField.airTemp:
        return 'Air Temperature';
      case DiveField.visibility:
        return 'Visibility';
      case DiveField.currentDirection:
        return 'Current Direction';
      case DiveField.currentStrength:
        return 'Current Strength';
      case DiveField.swellHeight:
        return 'Swell Height';
      case DiveField.entryMethod:
        return 'Entry Method';
      case DiveField.exitMethod:
        return 'Exit Method';
      case DiveField.waterType:
        return 'Water Type';
      case DiveField.altitude:
        return 'Altitude';
      case DiveField.surfacePressure:
        return 'Surface Pressure';
      case DiveField.windSpeed:
        return 'Wind Speed';
      case DiveField.cloudCover:
        return 'Cloud Cover';
      case DiveField.precipitation:
        return 'Precipitation';
      case DiveField.humidity:
        return 'Humidity';
      case DiveField.weatherDescription:
        return 'Weather';
      case DiveField.primaryGas:
        return 'Primary Gas';
      case DiveField.diluentGas:
        return 'Diluent Gas';
      case DiveField.tankCount:
        return 'Tank Count';
      case DiveField.startPressure:
        return 'Start Pressure';
      case DiveField.endPressure:
        return 'End Pressure';
      case DiveField.sacRate:
        return 'SAC Rate';
      case DiveField.gasConsumed:
        return 'Gas Consumed';
      case DiveField.totalWeight:
        return 'Total Weight';
      case DiveField.diveComputerModel:
        return 'Dive Computer';
      case DiveField.gradientFactorLow:
        return 'GF Low';
      case DiveField.gradientFactorHigh:
        return 'GF High';
      case DiveField.decoAlgorithm:
        return 'Deco Algorithm';
      case DiveField.decoConservatism:
        return 'Conservatism';
      case DiveField.cnsStart:
        return 'CNS Start';
      case DiveField.cnsEnd:
        return 'CNS End';
      case DiveField.otu:
        return 'OTU';
      case DiveField.diveMode:
        return 'Dive Mode';
      case DiveField.setpointLow:
        return 'Setpoint Low';
      case DiveField.setpointHigh:
        return 'Setpoint High';
      case DiveField.setpointDeco:
        return 'Setpoint Deco';
      case DiveField.buddy:
        return 'Buddy';
      case DiveField.diveMaster:
        return 'Dive Master';
      case DiveField.siteLocation:
        return 'Site Location';
      case DiveField.diveCenterName:
        return 'Dive Center';
      case DiveField.siteLatitude:
        return 'Latitude';
      case DiveField.siteLongitude:
        return 'Longitude';
      case DiveField.tripName:
        return 'Trip';
      case DiveField.ratingStars:
        return 'Rating';
      case DiveField.isFavorite:
        return 'Favorite';
      case DiveField.notes:
        return 'Notes';
      case DiveField.tags:
        return 'Tags';
      case DiveField.importSource:
        return 'Import Source';
      case DiveField.diveTypeName:
        return 'Dive Type';
      case DiveField.surfaceInterval:
        return 'Surface Interval';
    }
  }

  /// Short label for use in column headers and compact displays.
  String get shortLabel {
    switch (this) {
      case DiveField.diveNumber:
        return '#';
      case DiveField.dateTime:
        return 'Date';
      case DiveField.siteName:
        return 'Site';
      case DiveField.maxDepth:
        return 'Max D';
      case DiveField.avgDepth:
        return 'Avg D';
      case DiveField.bottomTime:
        return 'BT';
      case DiveField.runtime:
        return 'RT';
      case DiveField.waterTemp:
        return 'W Temp';
      case DiveField.airTemp:
        return 'A Temp';
      case DiveField.visibility:
        return 'Vis';
      case DiveField.currentDirection:
        return 'Curr Dir';
      case DiveField.currentStrength:
        return 'Curr';
      case DiveField.swellHeight:
        return 'Swell';
      case DiveField.entryMethod:
        return 'Entry';
      case DiveField.exitMethod:
        return 'Exit';
      case DiveField.waterType:
        return 'Water';
      case DiveField.altitude:
        return 'Alt';
      case DiveField.surfacePressure:
        return 'S Press';
      case DiveField.windSpeed:
        return 'Wind';
      case DiveField.cloudCover:
        return 'Cloud';
      case DiveField.precipitation:
        return 'Precip';
      case DiveField.humidity:
        return 'Humid';
      case DiveField.weatherDescription:
        return 'Weather';
      case DiveField.primaryGas:
        return 'Gas';
      case DiveField.diluentGas:
        return 'Dil';
      case DiveField.tankCount:
        return 'Tanks';
      case DiveField.startPressure:
        return 'Start P';
      case DiveField.endPressure:
        return 'End P';
      case DiveField.sacRate:
        return 'SAC';
      case DiveField.gasConsumed:
        return 'Gas Used';
      case DiveField.totalWeight:
        return 'Wt';
      case DiveField.diveComputerModel:
        return 'Computer';
      case DiveField.gradientFactorLow:
        return 'GFL';
      case DiveField.gradientFactorHigh:
        return 'GFH';
      case DiveField.decoAlgorithm:
        return 'Algo';
      case DiveField.decoConservatism:
        return 'Conserv';
      case DiveField.cnsStart:
        return 'CNS Start';
      case DiveField.cnsEnd:
        return 'CNS End';
      case DiveField.otu:
        return 'OTU';
      case DiveField.diveMode:
        return 'Mode';
      case DiveField.setpointLow:
        return 'SP Lo';
      case DiveField.setpointHigh:
        return 'SP Hi';
      case DiveField.setpointDeco:
        return 'SP Deco';
      case DiveField.buddy:
        return 'Buddy';
      case DiveField.diveMaster:
        return 'DM';
      case DiveField.siteLocation:
        return 'Location';
      case DiveField.diveCenterName:
        return 'Dive Ctr';
      case DiveField.siteLatitude:
        return 'Lat';
      case DiveField.siteLongitude:
        return 'Lng';
      case DiveField.tripName:
        return 'Trip';
      case DiveField.ratingStars:
        return 'Rating';
      case DiveField.isFavorite:
        return 'Fav';
      case DiveField.notes:
        return 'Notes';
      case DiveField.tags:
        return 'Tags';
      case DiveField.importSource:
        return 'Source';
      case DiveField.diveTypeName:
        return 'Type';
      case DiveField.surfaceInterval:
        return 'SI';
    }
  }

  /// Optional icon associated with this field.
  IconData? get icon {
    switch (this) {
      case DiveField.diveNumber:
        return Icons.tag;
      case DiveField.dateTime:
        return Icons.calendar_today;
      case DiveField.siteName:
        return Icons.place;
      case DiveField.maxDepth:
        return Icons.arrow_downward;
      case DiveField.avgDepth:
        return Icons.compress;
      case DiveField.bottomTime:
        return Icons.timer;
      case DiveField.runtime:
        return Icons.timer_outlined;
      case DiveField.waterTemp:
        return Icons.thermostat;
      case DiveField.airTemp:
        return Icons.air;
      case DiveField.visibility:
        return Icons.visibility;
      case DiveField.windSpeed:
        return Icons.wind_power;
      case DiveField.buddy:
        return Icons.people;
      case DiveField.diveMaster:
        return Icons.school;
      case DiveField.ratingStars:
        return Icons.star;
      case DiveField.isFavorite:
        return Icons.favorite;
      case DiveField.notes:
        return Icons.notes;
      case DiveField.tags:
        return Icons.label;
      case DiveField.diveMode:
        return Icons.settings;
      case DiveField.siteLocation:
        return Icons.location_on;
      case DiveField.siteLatitude:
        return null;
      case DiveField.siteLongitude:
        return null;
      case DiveField.tripName:
        return Icons.luggage;
      case DiveField.diveTypeName:
        return Icons.category;
      case DiveField.sacRate:
        return null;
      case DiveField.gasConsumed:
        return null;
      case DiveField.gradientFactorLow:
        return null;
      case DiveField.gradientFactorHigh:
        return null;
      case DiveField.decoAlgorithm:
        return null;
      case DiveField.decoConservatism:
        return null;
      case DiveField.cnsStart:
        return null;
      case DiveField.cnsEnd:
        return null;
      case DiveField.otu:
        return null;
      case DiveField.setpointLow:
        return null;
      case DiveField.setpointHigh:
        return null;
      case DiveField.setpointDeco:
        return null;
      case DiveField.primaryGas:
        return null;
      case DiveField.diluentGas:
        return null;
      case DiveField.tankCount:
        return null;
      case DiveField.startPressure:
        return null;
      case DiveField.endPressure:
        return null;
      case DiveField.totalWeight:
        return null;
      case DiveField.diveComputerModel:
        return null;
      case DiveField.diveCenterName:
        return null;
      case DiveField.currentDirection:
        return null;
      case DiveField.currentStrength:
        return null;
      case DiveField.swellHeight:
        return null;
      case DiveField.entryMethod:
        return null;
      case DiveField.exitMethod:
        return null;
      case DiveField.waterType:
        return null;
      case DiveField.altitude:
        return null;
      case DiveField.surfacePressure:
        return null;
      case DiveField.cloudCover:
        return null;
      case DiveField.precipitation:
        return null;
      case DiveField.humidity:
        return null;
      case DiveField.weatherDescription:
        return null;
      case DiveField.importSource:
        return null;
      case DiveField.surfaceInterval:
        return null;
    }
  }

  /// Default column width in logical pixels.
  double get defaultWidth {
    switch (this) {
      case DiveField.diveNumber:
        return 60;
      case DiveField.dateTime:
        return 160;
      case DiveField.siteName:
        return 160;
      case DiveField.maxDepth:
        return 80;
      case DiveField.avgDepth:
        return 80;
      case DiveField.bottomTime:
        return 80;
      case DiveField.runtime:
        return 80;
      case DiveField.waterTemp:
        return 90;
      case DiveField.airTemp:
        return 90;
      case DiveField.visibility:
        return 100;
      case DiveField.currentDirection:
        return 100;
      case DiveField.currentStrength:
        return 100;
      case DiveField.swellHeight:
        return 80;
      case DiveField.entryMethod:
        return 100;
      case DiveField.exitMethod:
        return 100;
      case DiveField.waterType:
        return 90;
      case DiveField.altitude:
        return 90;
      case DiveField.surfacePressure:
        return 90;
      case DiveField.windSpeed:
        return 90;
      case DiveField.cloudCover:
        return 100;
      case DiveField.precipitation:
        return 100;
      case DiveField.humidity:
        return 80;
      case DiveField.weatherDescription:
        return 140;
      case DiveField.primaryGas:
        return 80;
      case DiveField.diluentGas:
        return 80;
      case DiveField.tankCount:
        return 70;
      case DiveField.startPressure:
        return 90;
      case DiveField.endPressure:
        return 90;
      case DiveField.sacRate:
        return 80;
      case DiveField.gasConsumed:
        return 100;
      case DiveField.totalWeight:
        return 80;
      case DiveField.diveComputerModel:
        return 140;
      case DiveField.gradientFactorLow:
        return 70;
      case DiveField.gradientFactorHigh:
        return 70;
      case DiveField.decoAlgorithm:
        return 100;
      case DiveField.decoConservatism:
        return 90;
      case DiveField.cnsStart:
        return 90;
      case DiveField.cnsEnd:
        return 90;
      case DiveField.otu:
        return 70;
      case DiveField.diveMode:
        return 80;
      case DiveField.setpointLow:
        return 80;
      case DiveField.setpointHigh:
        return 80;
      case DiveField.setpointDeco:
        return 90;
      case DiveField.buddy:
        return 120;
      case DiveField.diveMaster:
        return 120;
      case DiveField.siteLocation:
        return 160;
      case DiveField.diveCenterName:
        return 140;
      case DiveField.siteLatitude:
        return 100;
      case DiveField.siteLongitude:
        return 100;
      case DiveField.tripName:
        return 140;
      case DiveField.ratingStars:
        return 80;
      case DiveField.isFavorite:
        return 60;
      case DiveField.notes:
        return 200;
      case DiveField.tags:
        return 160;
      case DiveField.importSource:
        return 100;
      case DiveField.diveTypeName:
        return 100;
      case DiveField.surfaceInterval:
        return 80;
    }
  }

  /// Minimum column width in logical pixels. Always <= defaultWidth.
  double get minWidth {
    switch (this) {
      case DiveField.diveNumber:
        return 40;
      case DiveField.dateTime:
        return 80;
      case DiveField.siteName:
        return 60;
      case DiveField.maxDepth:
        return 60;
      case DiveField.avgDepth:
        return 60;
      case DiveField.bottomTime:
        return 60;
      case DiveField.runtime:
        return 60;
      case DiveField.waterTemp:
        return 60;
      case DiveField.airTemp:
        return 60;
      case DiveField.visibility:
        return 60;
      case DiveField.currentDirection:
        return 60;
      case DiveField.currentStrength:
        return 60;
      case DiveField.swellHeight:
        return 60;
      case DiveField.entryMethod:
        return 60;
      case DiveField.exitMethod:
        return 60;
      case DiveField.waterType:
        return 60;
      case DiveField.altitude:
        return 60;
      case DiveField.surfacePressure:
        return 60;
      case DiveField.windSpeed:
        return 60;
      case DiveField.cloudCover:
        return 60;
      case DiveField.precipitation:
        return 60;
      case DiveField.humidity:
        return 60;
      case DiveField.weatherDescription:
        return 80;
      case DiveField.primaryGas:
        return 60;
      case DiveField.diluentGas:
        return 60;
      case DiveField.tankCount:
        return 50;
      case DiveField.startPressure:
        return 60;
      case DiveField.endPressure:
        return 60;
      case DiveField.sacRate:
        return 60;
      case DiveField.gasConsumed:
        return 60;
      case DiveField.totalWeight:
        return 60;
      case DiveField.diveComputerModel:
        return 80;
      case DiveField.gradientFactorLow:
        return 50;
      case DiveField.gradientFactorHigh:
        return 50;
      case DiveField.decoAlgorithm:
        return 60;
      case DiveField.decoConservatism:
        return 60;
      case DiveField.cnsStart:
        return 60;
      case DiveField.cnsEnd:
        return 60;
      case DiveField.otu:
        return 50;
      case DiveField.diveMode:
        return 60;
      case DiveField.setpointLow:
        return 60;
      case DiveField.setpointHigh:
        return 60;
      case DiveField.setpointDeco:
        return 60;
      case DiveField.buddy:
        return 60;
      case DiveField.diveMaster:
        return 60;
      case DiveField.siteLocation:
        return 80;
      case DiveField.diveCenterName:
        return 80;
      case DiveField.siteLatitude:
        return 60;
      case DiveField.siteLongitude:
        return 60;
      case DiveField.tripName:
        return 60;
      case DiveField.ratingStars:
        return 60;
      case DiveField.isFavorite:
        return 40;
      case DiveField.notes:
        return 80;
      case DiveField.tags:
        return 60;
      case DiveField.importSource:
        return 60;
      case DiveField.diveTypeName:
        return 60;
      case DiveField.surfaceInterval:
        return 60;
    }
  }

  /// Whether this field supports sorting.
  bool get sortable {
    switch (this) {
      case DiveField.notes:
      case DiveField.tags:
      case DiveField.siteLatitude:
      case DiveField.siteLongitude:
      case DiveField.weatherDescription:
        return false;
      default:
        return true;
    }
  }

  /// Extract the raw value for this field from a full [Dive] entity.
  dynamic extractFromDive(Dive dive) {
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
        return _computeSacRate(dive);
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
        return dive.diveTypeName;
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
        final id = summary.diveTypeId;
        if (id.isEmpty) return 'Recreational';
        return id[0].toUpperCase() + id.substring(1).replaceAll('_', ' ');
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

  /// Format a raw value (from [extractFromDive] or [extractFromSummary])
  /// as a display string, applying unit conversions as needed.
  String formatValue(dynamic value, UnitFormatter units) {
    if (value == null) return '--';

    switch (this) {
      case DiveField.maxDepth:
      case DiveField.avgDepth:
      case DiveField.swellHeight:
        return units.formatDepth(value as double?);

      case DiveField.waterTemp:
      case DiveField.airTemp:
        return units.formatTemperature(value as double?);

      case DiveField.altitude:
        return units.formatAltitude(value as double?);

      case DiveField.surfacePressure:
        return units.formatBarometricPressure(value as double?);

      case DiveField.startPressure:
      case DiveField.endPressure:
        return units.formatPressure(value as double?);

      case DiveField.sacRate:
        if (value is double) {
          return '${value.toStringAsFixed(1)} ${units.volumeSymbol}/min';
        }
        return '--';

      case DiveField.gasConsumed:
        return units.formatVolume(value as double?);

      case DiveField.totalWeight:
        return units.formatWeight(value as double?);

      case DiveField.windSpeed:
        return units.formatWindSpeed(value as double?);

      case DiveField.humidity:
        if (value is double) {
          return '${value.toStringAsFixed(0)}%';
        }
        return '--';

      case DiveField.bottomTime:
      case DiveField.runtime:
      case DiveField.surfaceInterval:
        return _formatDuration(value);

      case DiveField.dateTime:
        return units.formatDateTimeBullet(value as DateTime?);

      case DiveField.gradientFactorLow:
      case DiveField.gradientFactorHigh:
        if (value is int) {
          return '$value%';
        }
        return '--';

      case DiveField.setpointLow:
      case DiveField.setpointHigh:
      case DiveField.setpointDeco:
        if (value is double) {
          return '${value.toStringAsFixed(2)} bar';
        }
        return '--';

      case DiveField.cnsStart:
      case DiveField.cnsEnd:
        if (value is double) {
          return '${value.toStringAsFixed(1)}%';
        }
        return '--';

      case DiveField.isFavorite:
        if (value is bool) {
          return value ? 'Yes' : 'No';
        }
        return '--';

      case DiveField.tags:
        if (value is List) {
          return value.isEmpty ? '--' : value.join(', ');
        }
        return '--';

      case DiveField.tankCount:
        return '$value';

      case DiveField.diveNumber:
        return '#$value';

      default:
        return '$value';
    }
  }
}

/// Format a [Duration] value as a human-readable string.
///
/// Produces "Xh Ym" for durations >= 1 hour, or "Xmin" otherwise.
String _formatDuration(dynamic value) {
  if (value == null) return '--';
  if (value is! Duration) return '--';

  final totalMinutes = value.inMinutes;
  if (totalMinutes <= 0) return '--';

  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;

  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '${minutes}min';
}

/// Compute the SAC rate (Surface Air Consumption) in L/min from a [Dive].
///
/// Uses the first tank's gas consumption and effective runtime with average
/// depth to calculate surface-equivalent consumption.
double? _computeSacRate(Dive dive) {
  if (dive.tanks.isEmpty) return null;
  final runtime = dive.effectiveRuntime;
  final avgDepth = dive.avgDepth;
  if (runtime == null || avgDepth == null) return null;

  final minutes = runtime.inSeconds / 60.0;
  if (minutes <= 0) return null;

  final tank = dive.tanks.first;
  if (tank.startPressure == null ||
      tank.endPressure == null ||
      tank.volume == null) {
    return null;
  }

  final pressureUsed = tank.startPressure! - tank.endPressure!;
  if (pressureUsed <= 0) return null;

  final gasLiters = tank.volume! * pressureUsed;
  final avgPressureAtm = (avgDepth / 10.0) + 1.0;

  return gasLiters / minutes / avgPressureAtm;
}

/// Compute the total gas consumed in liters from the first tank of a [Dive].
double? _computeGasConsumed(Dive dive) {
  if (dive.tanks.isEmpty) return null;

  final tank = dive.tanks.first;
  if (tank.startPressure == null ||
      tank.endPressure == null ||
      tank.volume == null) {
    return null;
  }

  final pressureUsed = tank.startPressure! - tank.endPressure!;
  if (pressureUsed <= 0) return null;

  return tank.volume! * pressureUsed;
}
