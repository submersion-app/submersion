import 'package:submersion/features/dive_centers/domain/constants/dive_center_field.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/features/trips/domain/constants/trip_field.dart';

/// Conflict labels and value kinds for dive sites, trips, dive centers, tracks, species and tags (#694). Generated from a
/// reviewed column list; the coverage guard in
/// test/features/settings/presentation/conflicts/ keeps it complete.
final Map<String, ConflictField> siteTripFields = {
  'accessNotes': ConflictField(
    (l) => l.settings_conflict_field_accessNotes,
    FieldKind.longText,
  ),
  'affiliations': ConflictField(
    (l) => DiveCenterField.affiliations.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'analyzedHe': ConflictField(
    (l) => l.settings_conflict_field_analyzedHe,
    FieldKind.percent,
  ),
  'analyzedO2': ConflictField(
    (l) => l.settings_conflict_field_analyzedO2,
    FieldKind.percent,
  ),
  'anchorLatitude': ConflictField(
    (l) => l.settings_conflict_field_anchorLatitude,
    FieldKind.latitude,
  ),
  'anchorLongitude': ConflictField(
    (l) => l.settings_conflict_field_anchorLongitude,
    FieldKind.longitude,
  ),
  'appliesToDives': ConflictField(
    (l) => l.settings_conflict_field_appliesToDives,
    FieldKind.boolean,
  ),
  'appliesToEquipment': ConflictField(
    (l) => l.settings_conflict_field_appliesToEquipment,
    FieldKind.boolean,
  ),
  'appliesToSites': ConflictField(
    (l) => l.settings_conflict_field_appliesToSites,
    FieldKind.boolean,
  ),
  'avgSpeed': ConflictField(
    (l) => l.settings_conflict_field_avgSpeed,
    FieldKind.speed,
  ),
  'bearingDeg': ConflictField(
    (l) => l.settings_conflict_field_bearingDeg,
    FieldKind.number,
  ),
  'bodyOfWater': ConflictField(
    (l) => SiteField.bodyOfWater.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'bottleLabel': ConflictField(
    (l) => l.settings_conflict_field_bottleLabel,
    FieldKind.shortText,
  ),
  'cabinType': ConflictField(
    (l) => l.settings_conflict_field_cabinType,
    FieldKind.shortText,
  ),
  'capacity': ConflictField(
    (l) => l.settings_conflict_field_capacity,
    FieldKind.number,
  ),
  'color': ConflictField(
    (l) => l.settings_conflict_field_color,
    FieldKind.shortText,
  ),
  'commonName': ConflictField(
    (l) => l.settings_conflict_field_commonName,
    FieldKind.shortText,
  ),
  'completedAt': ConflictField(
    (l) => l.settings_conflict_field_completedAt,
    FieldKind.dateTime,
  ),
  'cost': ConflictField(
    (l) => l.settings_conflict_field_cost,
    FieldKind.number,
  ),
  'currency': ConflictField(
    (l) => l.settings_conflict_field_currency,
    FieldKind.shortText,
  ),
  'date': ConflictField((l) => l.settings_conflict_field_date, FieldKind.date),
  'dayNumber': ConflictField(
    (l) => l.settings_conflict_field_dayNumber,
    FieldKind.number,
  ),
  'dayType': ConflictField(
    (l) => l.settings_conflict_field_dayType,
    FieldKind.enumValue,
    enumLabel: dayTypeLabeler,
  ),
  'depthMeters': ConflictField(
    (l) => l.settings_conflict_field_depthMeters,
    FieldKind.depth,
  ),
  'deviceName': ConflictField(
    (l) => l.settings_conflict_field_deviceName,
    FieldKind.shortText,
  ),
  'difficulty': ConflictField(
    (l) => SiteField.difficulty.localizedDisplayName(l),
    FieldKind.enumValue,
    enumLabel: siteDifficultyLabeler,
  ),
  'disembarkLatitude': ConflictField(
    (l) => l.settings_conflict_field_disembarkLatitude,
    FieldKind.latitude,
  ),
  'disembarkLongitude': ConflictField(
    (l) => l.settings_conflict_field_disembarkLongitude,
    FieldKind.longitude,
  ),
  'disembarkPort': ConflictField(
    (l) => l.settings_conflict_field_disembarkPort,
    FieldKind.shortText,
  ),
  'diversSharingCylinders': ConflictField(
    (l) => l.settings_conflict_field_diversSharingCylinders,
    FieldKind.number,
  ),
  'divesPerDayTarget': ConflictField(
    (l) => l.settings_conflict_field_divesPerDayTarget,
    FieldKind.number,
  ),
  'dueDate': ConflictField(
    (l) => l.settings_conflict_field_dueDate,
    FieldKind.date,
  ),
  'dueOffsetDays': ConflictField(
    (l) => l.settings_conflict_field_dueOffsetDays,
    FieldKind.number,
  ),
  'durationSeconds': ConflictField(
    (l) => l.settings_conflict_field_durationSeconds,
    FieldKind.durationSeconds,
  ),
  'email': ConflictField(
    (l) => DiveCenterField.email.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'embarkLatitude': ConflictField(
    (l) => l.settings_conflict_field_embarkLatitude,
    FieldKind.latitude,
  ),
  'embarkLongitude': ConflictField(
    (l) => l.settings_conflict_field_embarkLongitude,
    FieldKind.longitude,
  ),
  'embarkPort': ConflictField(
    (l) => l.settings_conflict_field_embarkPort,
    FieldKind.shortText,
  ),
  'endDate': ConflictField(
    (l) => TripField.endDate.localizedDisplayName(l),
    FieldKind.date,
  ),
  'endLatitude': ConflictField(
    (l) => l.settings_conflict_field_endLatitude,
    FieldKind.latitude,
  ),
  'endLongitude': ConflictField(
    (l) => l.settings_conflict_field_endLongitude,
    FieldKind.longitude,
  ),
  'endMode': ConflictField(
    (l) => l.settings_conflict_field_endMode,
    FieldKind.shortText,
  ),
  'endTime': ConflictField(
    (l) => l.settings_conflict_field_endTime,
    FieldKind.wallClock,
  ),
  'expectedDives': ConflictField(
    (l) => l.settings_conflict_field_expectedDives,
    FieldKind.number,
  ),
  'expectedRuntimeMinutes': ConflictField(
    (l) => l.settings_conflict_field_expectedRuntimeMinutes,
    FieldKind.durationMinutes,
  ),
  'fetchedAt': ConflictField(
    (l) => l.settings_conflict_field_fetchedAt,
    FieldKind.dateTime,
  ),
  'fillClosesAt': ConflictField(
    (l) => l.settings_conflict_field_fillClosesAt,
    FieldKind.timeOfDay,
  ),
  'fillOpensAt': ConflictField(
    (l) => l.settings_conflict_field_fillOpensAt,
    FieldKind.timeOfDay,
  ),
  'gearType': ConflictField(
    (l) => l.settings_conflict_field_gearType,
    FieldKind.enumValue,
    enumLabel: equipmentTypeLabeler,
  ),
  'hazards': ConflictField(
    (l) => SiteField.hazards.localizedDisplayName(l),
    FieldKind.longText,
  ),
  'headingOffsetDeg': ConflictField(
    (l) => l.settings_conflict_field_headingOffsetDeg,
    FieldKind.number,
  ),
  'heightMeters': ConflictField(
    (l) => l.settings_conflict_field_heightMeters,
    FieldKind.depth,
  ),
  'highTideHeight': ConflictField(
    (l) => l.settings_conflict_field_highTideHeight,
    FieldKind.depth,
  ),
  'highTideTime': ConflictField(
    (l) => l.settings_conflict_field_highTideTime,
    FieldKind.dateTime,
  ),
  'isDone': ConflictField(
    (l) => l.settings_conflict_field_isDone,
    FieldKind.boolean,
  ),
  'isPackage': ConflictField(
    (l) => l.settings_conflict_field_isPackage,
    FieldKind.boolean,
  ),
  'isShared': ConflictField(
    (l) => l.settings_conflict_field_isShared,
    FieldKind.boolean,
  ),
  'island': ConflictField(
    (l) => SiteField.island.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'label': ConflictField(
    (l) => l.settings_conflict_field_label,
    FieldKind.shortText,
  ),
  'leadAdjustmentKg': ConflictField(
    (l) => l.settings_conflict_field_leadAdjustmentKg,
    FieldKind.weight,
  ),
  'linkMode': ConflictField(
    (l) => l.settings_conflict_field_linkMode,
    FieldKind.shortText,
  ),
  'liveaboardName': ConflictField(
    (l) => TripField.liveaboardName.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'location': ConflictField(
    (l) => TripField.location.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'lowTideHeight': ConflictField(
    (l) => l.settings_conflict_field_lowTideHeight,
    FieldKind.depth,
  ),
  'lowTideTime': ConflictField(
    (l) => l.settings_conflict_field_lowTideTime,
    FieldKind.dateTime,
  ),
  'material': ConflictField(
    (l) => l.settings_conflict_field_material,
    FieldKind.enumValue,
    enumLabel: tankMaterialLabeler,
  ),
  'maxSpeed': ConflictField(
    (l) => l.settings_conflict_field_maxSpeed,
    FieldKind.speed,
  ),
  'minDepth': ConflictField(
    (l) => SiteField.minDepth.localizedDisplayName(l),
    FieldKind.depth,
  ),
  'mooringNumber': ConflictField(
    (l) => SiteField.mooringNumber.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'note': ConflictField(
    (l) => l.settings_conflict_field_note,
    FieldKind.longText,
  ),
  'notedAt': ConflictField(
    (l) => l.settings_conflict_field_notedAt,
    FieldKind.dateTime,
  ),
  'operatorName': ConflictField(
    (l) => l.settings_conflict_field_operatorName,
    FieldKind.shortText,
  ),
  'parkingInfo': ConflictField(
    (l) => l.settings_conflict_field_parkingInfo,
    FieldKind.longText,
  ),
  'photoPath': ConflictField(
    (l) => l.settings_conflict_field_photoPath,
    FieldKind.opaque,
  ),
  'plannedDives': ConflictField(
    (l) => l.settings_conflict_field_plannedDives,
    FieldKind.number,
  ),
  'pointCount': ConflictField(
    (l) => l.settings_conflict_field_pointCount,
    FieldKind.number,
  ),
  'points': ConflictField(
    (l) => l.settings_conflict_field_points,
    FieldKind.opaque,
  ),
  'portName': ConflictField(
    (l) => l.settings_conflict_field_portName,
    FieldKind.shortText,
  ),
  'postalCode': ConflictField(
    (l) => DiveCenterField.postalCode.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'pressure': ConflictField(
    (l) => l.settings_conflict_field_pressure,
    FieldKind.pressure,
  ),
  'rateOfChange': ConflictField(
    (l) => l.settings_conflict_field_rateOfChange,
    FieldKind.number,
  ),
  'region': ConflictField(
    (l) => SiteField.region.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'resortName': ConflictField(
    (l) => TripField.resortName.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'returnFlightAt': ConflictField(
    (l) => l.settings_conflict_field_returnFlightAt,
    FieldKind.wallClock,
  ),
  'scientificName': ConflictField(
    (l) => l.settings_conflict_field_scientificName,
    FieldKind.shortText,
  ),
  'size': ConflictField(
    (l) => l.settings_conflict_field_size,
    FieldKind.shortText,
  ),
  'source': ConflictField(
    (l) => l.settings_conflict_field_source,
    FieldKind.shortText,
  ),
  'sourceRef': ConflictField(
    (l) => l.settings_conflict_field_sourceRef,
    FieldKind.shortText,
  ),
  'startDate': ConflictField(
    (l) => TripField.startDate.localizedDisplayName(l),
    FieldKind.date,
  ),
  'startTime': ConflictField(
    (l) => l.settings_conflict_field_startTime,
    FieldKind.wallClock,
  ),
  'stateProvince': ConflictField(
    (l) => DiveCenterField.stateProvince.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'street': ConflictField(
    (l) => DiveCenterField.street.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'taxonomyClass': ConflictField(
    (l) => l.settings_conflict_field_taxonomyClass,
    FieldKind.shortText,
  ),
  'tideState': ConflictField(
    (l) => l.settings_conflict_field_tideState,
    FieldKind.enumValue,
    enumLabel: tideStateLabeler,
  ),
  'title': ConflictField(
    (l) => l.settings_conflict_field_title,
    FieldKind.shortText,
  ),
  'totalDistance': ConflictField(
    (l) => l.settings_conflict_field_totalDistance,
    FieldKind.geoDistance,
  ),
  'trimEndTime': ConflictField(
    (l) => l.settings_conflict_field_trimEndTime,
    FieldKind.wallClock,
  ),
  'trimStartTime': ConflictField(
    (l) => l.settings_conflict_field_trimStartTime,
    FieldKind.wallClock,
  ),
  'tripType': ConflictField(
    (l) => TripField.tripType.localizedDisplayName(l),
    FieldKind.enumValue,
    enumLabel: tripTypeLabeler,
  ),
  'trustFraction': ConflictField(
    (l) => l.settings_conflict_field_trustFraction,
    FieldKind.fraction,
  ),
  'tzOffsetMinutes': ConflictField(
    (l) => l.settings_conflict_field_tzOffsetMinutes,
    FieldKind.number,
  ),
  'verdict': ConflictField(
    (l) => l.settings_conflict_field_verdict,
    FieldKind.enumValue,
    enumLabel: rentalVerdictLabeler,
  ),
  'vesselName': ConflictField(
    (l) => l.settings_conflict_field_vesselName,
    FieldKind.shortText,
  ),
  'vesselType': ConflictField(
    (l) => l.settings_conflict_field_vesselType,
    FieldKind.shortText,
  ),
  'volumeLiters': ConflictField(
    (l) => l.settings_conflict_field_volumeLiters,
    FieldKind.volume,
  ),
  'website': ConflictField(
    (l) => DiveCenterField.website.localizedDisplayName(l),
    FieldKind.shortText,
  ),
};

/// Columns whose meaning depends on the entity, keyed `entity.column`.
final Map<String, ConflictField> siteTripOverrides = {
  'checklistTemplateItems.category': ConflictField(
    (l) => l.settings_conflict_field_checklistTemplateItems_category,
    FieldKind.shortText,
  ),
  'siteFeatures.type': ConflictField(
    (l) => l.settings_conflict_field_siteFeatures_type,
    FieldKind.enumValue,
    enumLabel: siteFeatureTypeLabeler,
  ),
  'species.category': ConflictField(
    (l) => l.settings_conflict_field_species_category,
    FieldKind.enumValue,
    enumLabel: speciesCategoryLabeler,
  ),
  'tripChecklistItems.category': ConflictField(
    (l) => l.settings_conflict_field_tripChecklistItems_category,
    FieldKind.shortText,
  ),
  'tripCylinderEvents.kind': ConflictField(
    (l) => l.settings_conflict_field_tripCylinderEvents_kind,
    FieldKind.enumValue,
    enumLabel: tripCylinderEventKindLabeler,
  ),
  'tripCylinderEvents.occurredAt': ConflictField(
    (l) => l.settings_conflict_field_occurredAt,
    FieldKind.wallClock,
  ),
  'tripDayWeather.date': ConflictField(
    (l) => l.settings_conflict_field_date,
    FieldKind.utcDate,
  ),
};
