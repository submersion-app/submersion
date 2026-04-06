import 'package:flutter/material.dart';

export 'package:submersion/core/constants/dive_field_column_sizing.dart';
export 'package:submersion/core/constants/dive_field_extractor.dart';
export 'package:submersion/core/constants/dive_field_formatter.dart';

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
}
