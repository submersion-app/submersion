import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// Wrapper pairing a [DiveSite] with its computed dive count.
typedef SiteWithCount = ({DiveSite site, int diveCount});

/// Categories grouping related site fields together.
enum SiteFieldCategory { core, depth, conditions, details, coordinates }

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
  entryType,
  bestSeason,

  // Details
  mooringNumber,
  hazards,
  rating,
  notes,

  // Coordinates
  latitude,
  longitude;

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
    }
  }

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
    }
  }

  @override
  bool get sortable {
    switch (this) {
      case SiteField.siteName:
      case SiteField.country:
      case SiteField.region:
      case SiteField.diveCount:
      case SiteField.maxDepth:
      case SiteField.minDepth:
      case SiteField.altitude:
      case SiteField.difficulty:
      case SiteField.rating:
      case SiteField.latitude:
      case SiteField.longitude:
        return true;
      case SiteField.location:
      case SiteField.waterType:
      case SiteField.typicalVisibility:
      case SiteField.typicalCurrent:
      case SiteField.entryType:
      case SiteField.bestSeason:
      case SiteField.mooringNumber:
      case SiteField.hazards:
      case SiteField.notes:
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
        return true;
      case SiteField.siteName:
      case SiteField.location:
      case SiteField.country:
      case SiteField.region:
      case SiteField.waterType:
      case SiteField.typicalVisibility:
      case SiteField.typicalCurrent:
      case SiteField.difficulty:
      case SiteField.entryType:
      case SiteField.bestSeason:
      case SiteField.mooringNumber:
      case SiteField.hazards:
      case SiteField.notes:
        return false;
    }
  }
}

/// Adapter bridging [SiteWithCount] entities with [SiteField] for the generic
/// table infrastructure.
class SiteFieldAdapter extends EntityFieldAdapter<SiteWithCount, SiteField> {
  static final SiteFieldAdapter instance = SiteFieldAdapter._();
  SiteFieldAdapter._();

  static final Map<String, List<SiteField>> _fieldsByCategory = () {
    final map = <String, List<SiteField>>{};
    for (final f in SiteField.values) {
      map.putIfAbsent(f.categoryName, () => []).add(f);
    }
    return map;
  }();

  @override
  List<SiteField> get allFields => SiteField.values;

  @override
  Map<String, List<SiteField>> get fieldsByCategory => _fieldsByCategory;

  @override
  dynamic extractValue(SiteField field, SiteWithCount entity) {
    final site = entity.site;
    switch (field) {
      case SiteField.siteName:
        return site.name;
      case SiteField.location:
        return site.locationString;
      case SiteField.country:
        return site.country;
      case SiteField.region:
        return site.region;
      case SiteField.diveCount:
        return entity.diveCount;
      case SiteField.maxDepth:
        return site.maxDepth;
      case SiteField.minDepth:
        return site.minDepth;
      case SiteField.altitude:
        return site.altitude;
      case SiteField.waterType:
        return site.conditions?.waterType;
      case SiteField.typicalVisibility:
        return site.conditions?.typicalVisibility;
      case SiteField.typicalCurrent:
        return site.conditions?.typicalCurrent;
      case SiteField.difficulty:
        return site.difficulty;
      case SiteField.entryType:
        return site.conditions?.entryType;
      case SiteField.bestSeason:
        return site.conditions?.bestSeason;
      case SiteField.mooringNumber:
        return site.mooringNumber;
      case SiteField.hazards:
        return site.hazards;
      case SiteField.rating:
        return site.rating;
      case SiteField.notes:
        return site.notes.isEmpty ? null : site.notes;
      case SiteField.latitude:
        return site.location?.latitude;
      case SiteField.longitude:
        return site.location?.longitude;
    }
  }

  @override
  String formatValue(SiteField field, dynamic value, UnitFormatter units) {
    if (value == null) return '--';
    switch (field) {
      case SiteField.siteName:
      case SiteField.location:
      case SiteField.country:
      case SiteField.region:
      case SiteField.waterType:
      case SiteField.typicalVisibility:
      case SiteField.typicalCurrent:
      case SiteField.entryType:
      case SiteField.bestSeason:
      case SiteField.mooringNumber:
      case SiteField.hazards:
      case SiteField.notes:
        return value as String;
      case SiteField.diveCount:
        return (value as int).toString();
      case SiteField.maxDepth:
      case SiteField.minDepth:
        return units.formatDepth(value as double, decimals: 0);
      case SiteField.altitude:
        return units.formatAltitude(value as double);
      case SiteField.difficulty:
        return (value as SiteDifficulty).displayName;
      case SiteField.rating:
        return (value as double).toStringAsFixed(1);
      case SiteField.latitude:
      case SiteField.longitude:
        return (value as double).toStringAsFixed(5);
    }
  }

  @override
  SiteField fieldFromName(String name) {
    return SiteField.values.firstWhere((e) => e.name == name);
  }
}
