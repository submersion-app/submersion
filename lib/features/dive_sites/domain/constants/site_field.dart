import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/constants/entity_field.dart';

export 'package:submersion/features/dive_sites/domain/constants/site_field_adapter.dart';

/// Entity handed to [SiteFieldAdapter]. An alias of the repository's class so
/// the table view and the list cards share one type with no conversion.
typedef SiteWithCount = SiteWithDiveCount;

/// Whether a card slot showing [field] names the site's place, so a country
/// flag belongs beside it (issue #4426).
bool showsPlace(SiteField field) =>
    field == SiteField.location || field == SiteField.country;

/// Categories grouping related site fields together.
enum SiteFieldCategory {
  core,
  depth,
  conditions,
  details,
  coordinates,
  statistics,
}

/// Enumeration of every field from the DiveSite entity (plus dive count)
/// that can appear in table views. Each value implements [EntityField] directly
/// with all getters defined inline.
///
/// Note: [EntityField.name] is satisfied by the built-in enum [name] getter,
/// which returns the enum value's identifier as a string.
enum SiteField implements EntityField {
  // Core
  siteName,
  location,
  country,
  region,
  city,
  island,
  bodyOfWater,
  diveCount,

  // Depth
  maxDepth,
  minDepth,
  altitude,

  // Conditions
  waterType,
  typicalVisibility,
  typicalCurrent,
  difficulty,
  // Named entryType for historical reasons; it reads DiveSite.entryMethod.
  // Renaming it would throw on users' saved table layouts, which store these
  // members by name.
  entryType,
  exitMethod,
  bestSeason,

  // Details
  mooringNumber,
  hazards,
  rating,
  notes,

  // Coordinates
  latitude,
  longitude,

  // Statistics (aggregated over the dives logged at the site)
  //
  // Appended, never reordered or renamed: saved table and card layouts store
  // these members by name.
  depthRange,
  lastDived,
  maxDepthReached,
  firstDived,
  averageDepthReached,
  longestDive,
  averageDuration,

  // Classification (issue #1765). Appended, never reordered or renamed.
  siteTypes,
  tags;

  @override
  String get name => toString().split('.').last;

  @override
  String get displayName {
    switch (this) {
      case SiteField.siteName:
        return 'Name';
      case SiteField.location:
        return 'Location';
      case SiteField.country:
        return 'Country';
      case SiteField.region:
        return 'Region';
      case SiteField.city:
        return 'City';
      case SiteField.island:
        return 'Island';
      case SiteField.bodyOfWater:
        return 'Body of Water';
      case SiteField.diveCount:
        return 'Dive Count';
      case SiteField.maxDepth:
        return 'Max Depth';
      case SiteField.minDepth:
        return 'Min Depth';
      case SiteField.altitude:
        return 'Altitude';
      case SiteField.waterType:
        return 'Water Type';
      case SiteField.typicalVisibility:
        return 'Typical Visibility';
      case SiteField.typicalCurrent:
        return 'Typical Current';
      case SiteField.difficulty:
        return 'Difficulty';
      case SiteField.entryType:
        return 'Entry Type';
      case SiteField.exitMethod:
        return 'Exit Method';
      case SiteField.bestSeason:
        return 'Best Season';
      case SiteField.mooringNumber:
        return 'Mooring Number';
      case SiteField.hazards:
        return 'Hazards';
      case SiteField.rating:
        return 'Rating';
      case SiteField.notes:
        return 'Notes';
      case SiteField.latitude:
        return 'Latitude';
      case SiteField.longitude:
        return 'Longitude';
      case SiteField.depthRange:
        return 'Depth Range';
      case SiteField.lastDived:
        return 'Last Dived';
      case SiteField.maxDepthReached:
        return 'Your Max Depth';
      case SiteField.firstDived:
        return 'First Dived';
      case SiteField.averageDepthReached:
        return 'Your Avg Depth';
      case SiteField.longestDive:
        return 'Longest Dive';
      case SiteField.averageDuration:
        return 'Avg Duration';
      case SiteField.siteTypes:
        return 'Site Types';
      case SiteField.tags:
        return 'Tags';
    }
  }

  @override
  String get shortLabel {
    switch (this) {
      case SiteField.siteName:
        return 'Name';
      case SiteField.location:
        return 'Location';
      case SiteField.country:
        return 'Country';
      case SiteField.region:
        return 'Region';
      case SiteField.city:
        return 'City';
      case SiteField.island:
        return 'Island';
      case SiteField.bodyOfWater:
        return 'Water Body';
      case SiteField.diveCount:
        return 'Dives';
      case SiteField.maxDepth:
        return 'Max D';
      case SiteField.minDepth:
        return 'Min D';
      case SiteField.altitude:
        return 'Alt';
      case SiteField.waterType:
        return 'Water';
      case SiteField.typicalVisibility:
        return 'Vis';
      case SiteField.typicalCurrent:
        return 'Current';
      case SiteField.difficulty:
        return 'Diff';
      case SiteField.entryType:
        return 'Entry';
      case SiteField.exitMethod:
        return 'Exit';
      case SiteField.bestSeason:
        return 'Season';
      case SiteField.mooringNumber:
        return 'Mooring';
      case SiteField.hazards:
        return 'Hazards';
      case SiteField.rating:
        return 'Rating';
      case SiteField.notes:
        return 'Notes';
      case SiteField.latitude:
        return 'Lat';
      case SiteField.longitude:
        return 'Lon';
      case SiteField.depthRange:
        return 'Depth';
      case SiteField.lastDived:
        return 'Last dived';
      case SiteField.maxDepthReached:
        return 'Your max';
      case SiteField.firstDived:
        return 'First dived';
      case SiteField.averageDepthReached:
        return 'Your avg';
      case SiteField.longestDive:
        return 'Longest';
      case SiteField.averageDuration:
        return 'Avg time';
      case SiteField.siteTypes:
        return 'Types';
      case SiteField.tags:
        return 'Tags';
    }
  }

  @override
  String localizedDisplayName(AppLocalizations l10n) => switch (this) {
    SiteField.siteName => l10n.enum_siteField_siteName,
    SiteField.location => l10n.enum_siteField_location,
    SiteField.country => l10n.enum_siteField_country,
    SiteField.region => l10n.enum_siteField_region,
    SiteField.city => l10n.enum_siteField_city,
    SiteField.island => l10n.enum_siteField_island,
    SiteField.bodyOfWater => l10n.enum_siteField_bodyOfWater,
    SiteField.diveCount => l10n.enum_siteField_diveCount,
    SiteField.maxDepth => l10n.enum_siteField_maxDepth,
    SiteField.minDepth => l10n.enum_siteField_minDepth,
    SiteField.altitude => l10n.enum_siteField_altitude,
    SiteField.waterType => l10n.enum_siteField_waterType,
    SiteField.typicalVisibility => l10n.enum_siteField_typicalVisibility,
    SiteField.typicalCurrent => l10n.enum_siteField_typicalCurrent,
    SiteField.difficulty => l10n.enum_siteField_difficulty,
    SiteField.entryType => l10n.enum_siteField_entryType,
    SiteField.exitMethod => l10n.enum_siteField_exitMethod,
    SiteField.bestSeason => l10n.enum_siteField_bestSeason,
    SiteField.mooringNumber => l10n.enum_siteField_mooringNumber,
    SiteField.hazards => l10n.enum_siteField_hazards,
    SiteField.rating => l10n.enum_siteField_rating,
    SiteField.notes => l10n.enum_siteField_notes,
    SiteField.latitude => l10n.enum_siteField_latitude,
    SiteField.longitude => l10n.enum_siteField_longitude,
    SiteField.depthRange => l10n.enum_siteField_depthRange,
    SiteField.lastDived => l10n.enum_siteField_lastDived,
    SiteField.maxDepthReached => l10n.enum_siteField_maxDepthReached,
    SiteField.firstDived => l10n.enum_siteField_firstDived,
    SiteField.averageDepthReached => l10n.enum_siteField_averageDepthReached,
    SiteField.longestDive => l10n.enum_siteField_longestDive,
    SiteField.averageDuration => l10n.enum_siteField_averageDuration,
    SiteField.siteTypes => l10n.enum_siteField_siteTypes,
    SiteField.tags => l10n.enum_siteField_tags,
  };

  @override
  String localizedShortLabel(AppLocalizations l10n) => switch (this) {
    SiteField.siteName => l10n.enum_siteField_siteName_short,
    SiteField.location => l10n.enum_siteField_location_short,
    SiteField.country => l10n.enum_siteField_country_short,
    SiteField.region => l10n.enum_siteField_region_short,
    SiteField.city => l10n.enum_siteField_city_short,
    SiteField.island => l10n.enum_siteField_island_short,
    SiteField.bodyOfWater => l10n.enum_siteField_bodyOfWater_short,
    SiteField.diveCount => l10n.enum_siteField_diveCount_short,
    SiteField.maxDepth => l10n.enum_siteField_maxDepth_short,
    SiteField.minDepth => l10n.enum_siteField_minDepth_short,
    SiteField.altitude => l10n.enum_siteField_altitude_short,
    SiteField.waterType => l10n.enum_siteField_waterType_short,
    SiteField.typicalVisibility => l10n.enum_siteField_typicalVisibility_short,
    SiteField.typicalCurrent => l10n.enum_siteField_typicalCurrent_short,
    SiteField.difficulty => l10n.enum_siteField_difficulty_short,
    SiteField.entryType => l10n.enum_siteField_entryType_short,
    SiteField.exitMethod => l10n.enum_siteField_exitMethod_short,
    SiteField.bestSeason => l10n.enum_siteField_bestSeason_short,
    SiteField.mooringNumber => l10n.enum_siteField_mooringNumber_short,
    SiteField.hazards => l10n.enum_siteField_hazards_short,
    SiteField.rating => l10n.enum_siteField_rating_short,
    SiteField.notes => l10n.enum_siteField_notes_short,
    SiteField.latitude => l10n.enum_siteField_latitude_short,
    SiteField.longitude => l10n.enum_siteField_longitude_short,
    SiteField.depthRange => l10n.enum_siteField_depthRange_short,
    SiteField.lastDived => l10n.enum_siteField_lastDived_short,
    SiteField.maxDepthReached => l10n.enum_siteField_maxDepthReached_short,
    SiteField.firstDived => l10n.enum_siteField_firstDived_short,
    SiteField.averageDepthReached =>
      l10n.enum_siteField_averageDepthReached_short,
    SiteField.longestDive => l10n.enum_siteField_longestDive_short,
    SiteField.averageDuration => l10n.enum_siteField_averageDuration_short,
    SiteField.siteTypes => l10n.enum_siteField_siteTypes_short,
    SiteField.tags => l10n.enum_siteField_tags_short,
  };

  @override
  IconData? get icon {
    switch (this) {
      case SiteField.siteName:
        return Icons.place;
      case SiteField.location:
        return Icons.location_on;
      case SiteField.country:
        return Icons.flag;
      case SiteField.region:
        return Icons.map;
      case SiteField.city:
        return Icons.location_city;
      case SiteField.island:
        return Icons.landscape;
      case SiteField.bodyOfWater:
        return Icons.waves;
      case SiteField.diveCount:
        return Icons.water;
      case SiteField.maxDepth:
        return Icons.vertical_align_bottom;
      case SiteField.minDepth:
        return Icons.vertical_align_top;
      case SiteField.altitude:
        return Icons.terrain;
      case SiteField.waterType:
        return Icons.water_drop;
      case SiteField.typicalVisibility:
        return Icons.visibility;
      case SiteField.typicalCurrent:
        return Icons.air;
      case SiteField.difficulty:
        return Icons.signal_cellular_alt;
      case SiteField.entryType:
        return Icons.login;
      case SiteField.exitMethod:
        return Icons.logout;
      case SiteField.bestSeason:
        return Icons.calendar_month;
      case SiteField.mooringNumber:
        return Icons.anchor;
      case SiteField.hazards:
        return Icons.warning;
      case SiteField.rating:
        return Icons.star;
      case SiteField.notes:
        return Icons.notes;
      case SiteField.latitude:
        return Icons.my_location;
      case SiteField.longitude:
        return Icons.my_location;
      case SiteField.depthRange:
        return Icons.straighten;
      case SiteField.lastDived:
        return Icons.history;
      case SiteField.maxDepthReached:
        return Icons.vertical_align_bottom;
      case SiteField.firstDived:
        return Icons.event;
      case SiteField.averageDepthReached:
        return Icons.straighten;
      case SiteField.longestDive:
        return Icons.timer;
      case SiteField.averageDuration:
        return Icons.hourglass_bottom;
      case SiteField.siteTypes:
        return Icons.category_outlined;
      case SiteField.tags:
        return Icons.sell_outlined;
    }
  }

  @override
  double get defaultWidth {
    switch (this) {
      case SiteField.siteName:
        return 150;
      case SiteField.location:
        return 120;
      case SiteField.country:
        return 100;
      case SiteField.region:
        return 100;
      case SiteField.city:
        return 110;
      case SiteField.island:
        return 110;
      case SiteField.bodyOfWater:
        return 130;
      case SiteField.diveCount:
        return 80;
      case SiteField.maxDepth:
        return 80;
      case SiteField.minDepth:
        return 80;
      case SiteField.altitude:
        return 80;
      case SiteField.waterType:
        return 90;
      case SiteField.typicalVisibility:
        return 100;
      case SiteField.typicalCurrent:
        return 100;
      case SiteField.difficulty:
        return 90;
      case SiteField.entryType:
        return 90;
      case SiteField.exitMethod:
        return 90;
      case SiteField.bestSeason:
        return 100;
      case SiteField.mooringNumber:
        return 100;
      case SiteField.hazards:
        return 120;
      case SiteField.rating:
        return 70;
      case SiteField.notes:
        return 150;
      case SiteField.latitude:
        return 90;
      case SiteField.longitude:
        return 90;
      case SiteField.depthRange:
        return 100;
      case SiteField.lastDived:
        return 110;
      case SiteField.maxDepthReached:
        return 90;
      case SiteField.firstDived:
        return 110;
      case SiteField.averageDepthReached:
        return 90;
      case SiteField.longestDive:
        return 100;
      case SiteField.averageDuration:
        return 100;
      case SiteField.siteTypes:
      case SiteField.tags:
        return 160;
    }
  }

  @override
  double get minWidth {
    switch (this) {
      case SiteField.siteName:
        return 80;
      case SiteField.location:
        return 70;
      case SiteField.country:
        return 60;
      case SiteField.region:
        return 60;
      case SiteField.city:
        return 60;
      case SiteField.island:
        return 60;
      case SiteField.bodyOfWater:
        return 70;
      case SiteField.diveCount:
        return 50;
      case SiteField.maxDepth:
        return 50;
      case SiteField.minDepth:
        return 50;
      case SiteField.altitude:
        return 50;
      case SiteField.waterType:
        return 60;
      case SiteField.typicalVisibility:
        return 60;
      case SiteField.typicalCurrent:
        return 60;
      case SiteField.difficulty:
        return 60;
      case SiteField.entryType:
        return 60;
      case SiteField.exitMethod:
        return 60;
      case SiteField.bestSeason:
        return 60;
      case SiteField.mooringNumber:
        return 60;
      case SiteField.hazards:
        return 70;
      case SiteField.rating:
        return 50;
      case SiteField.notes:
        return 80;
      case SiteField.latitude:
        return 60;
      case SiteField.longitude:
        return 60;
      case SiteField.depthRange:
        return 60;
      case SiteField.lastDived:
        return 70;
      case SiteField.maxDepthReached:
        return 50;
      case SiteField.firstDived:
        return 70;
      case SiteField.averageDepthReached:
        return 50;
      case SiteField.longestDive:
        return 60;
      case SiteField.averageDuration:
        return 60;
      case SiteField.siteTypes:
      case SiteField.tags:
        return 80;
    }
  }

  @override
  bool get sortable {
    switch (this) {
      case SiteField.siteName:
      case SiteField.country:
      case SiteField.region:
      case SiteField.city:
      case SiteField.island:
      case SiteField.bodyOfWater:
      case SiteField.diveCount:
      case SiteField.maxDepth:
      case SiteField.minDepth:
      case SiteField.altitude:
      case SiteField.difficulty:
      case SiteField.rating:
      case SiteField.latitude:
      case SiteField.longitude:
      case SiteField.lastDived:
      case SiteField.maxDepthReached:
      case SiteField.firstDived:
      case SiteField.averageDepthReached:
      case SiteField.longestDive:
      case SiteField.averageDuration:
        return true;
      case SiteField.siteTypes:
      case SiteField.tags:
      case SiteField.location:
      case SiteField.waterType:
      case SiteField.typicalVisibility:
      case SiteField.typicalCurrent:
      case SiteField.entryType:
      case SiteField.exitMethod:
      case SiteField.bestSeason:
      case SiteField.mooringNumber:
      case SiteField.hazards:
      case SiteField.notes:
      case SiteField.depthRange:
        return false;
    }
  }

  @override
  String get categoryName {
    switch (this) {
      case SiteField.siteName:
      case SiteField.location:
      case SiteField.country:
      case SiteField.region:
      case SiteField.city:
      case SiteField.island:
      case SiteField.bodyOfWater:
      case SiteField.diveCount:
        return SiteFieldCategory.core.name;
      case SiteField.maxDepth:
      case SiteField.minDepth:
      case SiteField.altitude:
        return SiteFieldCategory.depth.name;
      case SiteField.waterType:
      case SiteField.typicalVisibility:
      case SiteField.typicalCurrent:
      case SiteField.difficulty:
      case SiteField.entryType:
      case SiteField.exitMethod:
      case SiteField.bestSeason:
        return SiteFieldCategory.conditions.name;
      case SiteField.mooringNumber:
      case SiteField.hazards:
      case SiteField.rating:
      case SiteField.notes:
        return SiteFieldCategory.details.name;
      case SiteField.latitude:
      case SiteField.longitude:
        return SiteFieldCategory.coordinates.name;
      case SiteField.depthRange:
      case SiteField.lastDived:
      case SiteField.maxDepthReached:
      case SiteField.firstDived:
      case SiteField.averageDepthReached:
      case SiteField.longestDive:
      case SiteField.averageDuration:
        return SiteFieldCategory.statistics.name;
      case SiteField.siteTypes:
      case SiteField.tags:
        return SiteFieldCategory.details.name;
    }
  }

  @override
  bool get isRightAligned {
    switch (this) {
      case SiteField.diveCount:
      case SiteField.maxDepth:
      case SiteField.minDepth:
      case SiteField.altitude:
      case SiteField.rating:
      case SiteField.latitude:
      case SiteField.longitude:
      case SiteField.maxDepthReached:
      case SiteField.averageDepthReached:
      case SiteField.longestDive:
      case SiteField.averageDuration:
        return true;
      case SiteField.siteTypes:
      case SiteField.tags:
      case SiteField.siteName:
      case SiteField.location:
      case SiteField.country:
      case SiteField.region:
      case SiteField.city:
      case SiteField.island:
      case SiteField.bodyOfWater:
      case SiteField.waterType:
      case SiteField.typicalVisibility:
      case SiteField.typicalCurrent:
      case SiteField.difficulty:
      case SiteField.entryType:
      case SiteField.exitMethod:
      case SiteField.bestSeason:
      case SiteField.mooringNumber:
      case SiteField.hazards:
      case SiteField.notes:
      case SiteField.depthRange:
      case SiteField.lastDived:
      case SiteField.firstDived:
        return false;
    }
  }
}
