import 'package:flutter/material.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

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
  diveName,
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
    DiveField.diveName,
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
      case DiveField.diveName:
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
      case DiveField.diveName:
        return 'Dive Name';
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
      case DiveField.diveName:
        return 'Name';
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

  /// Localized full name for settings and picker UIs.
  String localizedDisplayName(AppLocalizations l10n) => switch (this) {
    DiveField.diveNumber => l10n.enum_diveField_diveNumber,
    DiveField.dateTime => l10n.enum_diveField_dateTime,
    DiveField.siteName => l10n.enum_diveField_siteName,
    DiveField.diveName => l10n.enum_diveField_diveName,
    DiveField.maxDepth => l10n.enum_diveField_maxDepth,
    DiveField.avgDepth => l10n.enum_diveField_avgDepth,
    DiveField.bottomTime => l10n.enum_diveField_bottomTime,
    DiveField.runtime => l10n.enum_diveField_runtime,
    DiveField.waterTemp => l10n.enum_diveField_waterTemp,
    DiveField.airTemp => l10n.enum_diveField_airTemp,
    DiveField.visibility => l10n.enum_diveField_visibility,
    DiveField.currentDirection => l10n.enum_diveField_currentDirection,
    DiveField.currentStrength => l10n.enum_diveField_currentStrength,
    DiveField.swellHeight => l10n.enum_diveField_swellHeight,
    DiveField.entryMethod => l10n.enum_diveField_entryMethod,
    DiveField.exitMethod => l10n.enum_diveField_exitMethod,
    DiveField.waterType => l10n.enum_diveField_waterType,
    DiveField.altitude => l10n.enum_diveField_altitude,
    DiveField.surfacePressure => l10n.enum_diveField_surfacePressure,
    DiveField.windSpeed => l10n.enum_diveField_windSpeed,
    DiveField.cloudCover => l10n.enum_diveField_cloudCover,
    DiveField.precipitation => l10n.enum_diveField_precipitation,
    DiveField.humidity => l10n.enum_diveField_humidity,
    DiveField.weatherDescription => l10n.enum_diveField_weatherDescription,
    DiveField.primaryGas => l10n.enum_diveField_primaryGas,
    DiveField.diluentGas => l10n.enum_diveField_diluentGas,
    DiveField.tankCount => l10n.enum_diveField_tankCount,
    DiveField.startPressure => l10n.enum_diveField_startPressure,
    DiveField.endPressure => l10n.enum_diveField_endPressure,
    DiveField.sacRate => l10n.enum_diveField_sacRate,
    DiveField.gasConsumed => l10n.enum_diveField_gasConsumed,
    DiveField.totalWeight => l10n.enum_diveField_totalWeight,
    DiveField.diveComputerModel => l10n.enum_diveField_diveComputerModel,
    DiveField.gradientFactorLow => l10n.enum_diveField_gradientFactorLow,
    DiveField.gradientFactorHigh => l10n.enum_diveField_gradientFactorHigh,
    DiveField.decoAlgorithm => l10n.enum_diveField_decoAlgorithm,
    DiveField.decoConservatism => l10n.enum_diveField_decoConservatism,
    DiveField.cnsStart => l10n.enum_diveField_cnsStart,
    DiveField.cnsEnd => l10n.enum_diveField_cnsEnd,
    DiveField.otu => l10n.enum_diveField_otu,
    DiveField.diveMode => l10n.enum_diveField_diveMode,
    DiveField.setpointLow => l10n.enum_diveField_setpointLow,
    DiveField.setpointHigh => l10n.enum_diveField_setpointHigh,
    DiveField.setpointDeco => l10n.enum_diveField_setpointDeco,
    DiveField.buddy => l10n.enum_diveField_buddy,
    DiveField.diveMaster => l10n.enum_diveField_diveMaster,
    DiveField.siteLocation => l10n.enum_diveField_siteLocation,
    DiveField.diveCenterName => l10n.enum_diveField_diveCenterName,
    DiveField.siteLatitude => l10n.enum_diveField_siteLatitude,
    DiveField.siteLongitude => l10n.enum_diveField_siteLongitude,
    DiveField.tripName => l10n.enum_diveField_tripName,
    DiveField.ratingStars => l10n.enum_diveField_ratingStars,
    DiveField.isFavorite => l10n.enum_diveField_isFavorite,
    DiveField.notes => l10n.enum_diveField_notes,
    DiveField.tags => l10n.enum_diveField_tags,
    DiveField.importSource => l10n.enum_diveField_importSource,
    DiveField.diveTypeName => l10n.enum_diveField_diveTypeName,
    DiveField.surfaceInterval => l10n.enum_diveField_surfaceInterval,
  };

  /// Localized compact label for table column headers.
  String localizedShortLabel(AppLocalizations l10n) => switch (this) {
    DiveField.diveNumber => l10n.enum_diveField_diveNumber_short,
    DiveField.dateTime => l10n.enum_diveField_dateTime_short,
    DiveField.siteName => l10n.enum_diveField_siteName_short,
    DiveField.diveName => l10n.enum_diveField_diveName_short,
    DiveField.maxDepth => l10n.enum_diveField_maxDepth_short,
    DiveField.avgDepth => l10n.enum_diveField_avgDepth_short,
    DiveField.bottomTime => l10n.enum_diveField_bottomTime_short,
    DiveField.runtime => l10n.enum_diveField_runtime_short,
    DiveField.waterTemp => l10n.enum_diveField_waterTemp_short,
    DiveField.airTemp => l10n.enum_diveField_airTemp_short,
    DiveField.visibility => l10n.enum_diveField_visibility_short,
    DiveField.currentDirection => l10n.enum_diveField_currentDirection_short,
    DiveField.currentStrength => l10n.enum_diveField_currentStrength_short,
    DiveField.swellHeight => l10n.enum_diveField_swellHeight_short,
    DiveField.entryMethod => l10n.enum_diveField_entryMethod_short,
    DiveField.exitMethod => l10n.enum_diveField_exitMethod_short,
    DiveField.waterType => l10n.enum_diveField_waterType_short,
    DiveField.altitude => l10n.enum_diveField_altitude_short,
    DiveField.surfacePressure => l10n.enum_diveField_surfacePressure_short,
    DiveField.windSpeed => l10n.enum_diveField_windSpeed_short,
    DiveField.cloudCover => l10n.enum_diveField_cloudCover_short,
    DiveField.precipitation => l10n.enum_diveField_precipitation_short,
    DiveField.humidity => l10n.enum_diveField_humidity_short,
    DiveField.weatherDescription =>
      l10n.enum_diveField_weatherDescription_short,
    DiveField.primaryGas => l10n.enum_diveField_primaryGas_short,
    DiveField.diluentGas => l10n.enum_diveField_diluentGas_short,
    DiveField.tankCount => l10n.enum_diveField_tankCount_short,
    DiveField.startPressure => l10n.enum_diveField_startPressure_short,
    DiveField.endPressure => l10n.enum_diveField_endPressure_short,
    DiveField.sacRate => l10n.enum_diveField_sacRate_short,
    DiveField.gasConsumed => l10n.enum_diveField_gasConsumed_short,
    DiveField.totalWeight => l10n.enum_diveField_totalWeight_short,
    DiveField.diveComputerModel => l10n.enum_diveField_diveComputerModel_short,
    DiveField.gradientFactorLow => l10n.enum_diveField_gradientFactorLow_short,
    DiveField.gradientFactorHigh =>
      l10n.enum_diveField_gradientFactorHigh_short,
    DiveField.decoAlgorithm => l10n.enum_diveField_decoAlgorithm_short,
    DiveField.decoConservatism => l10n.enum_diveField_decoConservatism_short,
    DiveField.cnsStart => l10n.enum_diveField_cnsStart_short,
    DiveField.cnsEnd => l10n.enum_diveField_cnsEnd_short,
    DiveField.otu => l10n.enum_diveField_otu_short,
    DiveField.diveMode => l10n.enum_diveField_diveMode_short,
    DiveField.setpointLow => l10n.enum_diveField_setpointLow_short,
    DiveField.setpointHigh => l10n.enum_diveField_setpointHigh_short,
    DiveField.setpointDeco => l10n.enum_diveField_setpointDeco_short,
    DiveField.buddy => l10n.enum_diveField_buddy_short,
    DiveField.diveMaster => l10n.enum_diveField_diveMaster_short,
    DiveField.siteLocation => l10n.enum_diveField_siteLocation_short,
    DiveField.diveCenterName => l10n.enum_diveField_diveCenterName_short,
    DiveField.siteLatitude => l10n.enum_diveField_siteLatitude_short,
    DiveField.siteLongitude => l10n.enum_diveField_siteLongitude_short,
    DiveField.tripName => l10n.enum_diveField_tripName_short,
    DiveField.ratingStars => l10n.enum_diveField_ratingStars_short,
    DiveField.isFavorite => l10n.enum_diveField_isFavorite_short,
    DiveField.notes => l10n.enum_diveField_notes_short,
    DiveField.tags => l10n.enum_diveField_tags_short,
    DiveField.importSource => l10n.enum_diveField_importSource_short,
    DiveField.diveTypeName => l10n.enum_diveField_diveTypeName_short,
    DiveField.surfaceInterval => l10n.enum_diveField_surfaceInterval_short,
  };

  /// Optional icon associated with this field.
  IconData? get icon {
    switch (this) {
      case DiveField.diveNumber:
        return Icons.tag;
      case DiveField.dateTime:
        return Icons.calendar_today;
      case DiveField.siteName:
        return Icons.place;
      case DiveField.diveName:
        return Icons.drive_file_rename_outline;
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
      case DiveField.diveName:
        return false;
      default:
        return true;
    }
  }
}
