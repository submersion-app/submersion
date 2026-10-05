import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';

/// Conflict labels and value kinds for the dive log's synced columns (#694). Generated from a
/// reviewed column list; the coverage guard in
/// test/features/settings/presentation/conflicts/ keeps it complete.
final Map<String, ConflictField> diveLogFields = {
  'airTemp': ConflictField(
    (l) => DiveField.airTemp.localizedDisplayName(l),
    FieldKind.temperature,
  ),
  'altitude': ConflictField(
    (l) => DiveField.altitude.localizedDisplayName(l),
    FieldKind.altitude,
  ),
  'amountKg': ConflictField(
    (l) => l.settings_conflict_field_amountKg,
    FieldKind.weight,
  ),
  'assumedVo2': ConflictField(
    (l) => l.settings_conflict_field_assumedVo2,
    FieldKind.number,
  ),
  'avgDepth': ConflictField(
    (l) => DiveField.avgDepth.localizedDisplayName(l),
    FieldKind.depth,
  ),
  'boatCaptain': ConflictField(
    (l) => l.settings_conflict_field_boatCaptain,
    FieldKind.shortText,
  ),
  'boatName': ConflictField(
    (l) => l.settings_conflict_field_boatName,
    FieldKind.shortText,
  ),
  'bottomTime': ConflictField(
    (l) => DiveField.bottomTime.localizedDisplayName(l),
    FieldKind.durationSeconds,
  ),
  'buddy': ConflictField(
    (l) => DiveField.buddy.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'byteCount': ConflictField(
    (l) => l.settings_conflict_field_byteCount,
    FieldKind.number,
  ),
  'bytes': ConflictField(
    (l) => l.settings_conflict_field_bytes,
    FieldKind.opaque,
  ),
  'city': ConflictField(
    (l) => l.settings_conflict_field_city,
    FieldKind.shortText,
  ),
  'cloudCover': ConflictField(
    (l) => DiveField.cloudCover.localizedDisplayName(l),
    FieldKind.enumValue,
    enumLabel: cloudCoverLabeler,
  ),
  'cns': ConflictField((l) => l.settings_conflict_field_cns, FieldKind.percent),
  'cnsEnd': ConflictField(
    (l) => DiveField.cnsEnd.localizedDisplayName(l),
    FieldKind.percent,
  ),
  'cnsStart': ConflictField(
    (l) => DiveField.cnsStart.localizedDisplayName(l),
    FieldKind.percent,
  ),
  'codecVersion': ConflictField(
    (l) => l.settings_conflict_field_codecVersion,
    FieldKind.number,
  ),
  'computerModel': ConflictField(
    (l) => l.settings_conflict_field_computerModel,
    FieldKind.shortText,
  ),
  'computerSerial': ConflictField(
    (l) => l.settings_conflict_field_computerSerial,
    FieldKind.shortText,
  ),
  'computerTissueJson': ConflictField(
    (l) => l.settings_conflict_field_computerTissueJson,
    FieldKind.opaque,
  ),
  'contributingFactors': ConflictField(
    (l) => l.settings_conflict_field_contributingFactors,
    FieldKind.longText,
  ),
  'count': ConflictField(
    (l) => l.settings_conflict_field_count,
    FieldKind.number,
  ),
  'country': ConflictField(
    (l) => l.settings_conflict_field_country,
    FieldKind.shortText,
  ),
  'currentDirection': ConflictField(
    (l) => DiveField.currentDirection.localizedDisplayName(l),
    FieldKind.enumValue,
    enumLabel: currentDirectionLabeler,
  ),
  'currentStrength': ConflictField(
    (l) => DiveField.currentStrength.localizedDisplayName(l),
    FieldKind.enumValue,
    enumLabel: currentStrengthLabeler,
  ),
  'decoAlgorithm': ConflictField(
    (l) => DiveField.decoAlgorithm.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'decoConservatism': ConflictField(
    (l) => DiveField.decoConservatism.localizedDisplayName(l),
    FieldKind.number,
  ),
  'depth': ConflictField(
    (l) => l.settings_conflict_field_depth,
    FieldKind.depth,
  ),
  'description': ConflictField(
    (l) => l.settings_conflict_field_description,
    FieldKind.longText,
  ),
  'descriptorModel': ConflictField(
    (l) => l.settings_conflict_field_descriptorModel,
    FieldKind.number,
  ),
  'descriptorProduct': ConflictField(
    (l) => l.settings_conflict_field_descriptorProduct,
    FieldKind.shortText,
  ),
  'descriptorVendor': ConflictField(
    (l) => l.settings_conflict_field_descriptorVendor,
    FieldKind.shortText,
  ),
  'detectorId': ConflictField(
    (l) => l.settings_conflict_field_detectorId,
    FieldKind.shortText,
  ),
  'detectorVersion': ConflictField(
    (l) => l.settings_conflict_field_detectorVersion,
    FieldKind.number,
  ),
  'diluentHe': ConflictField(
    (l) => l.settings_conflict_field_diluentHe,
    FieldKind.percent,
  ),
  'diluentO2': ConflictField(
    (l) => l.settings_conflict_field_diluentO2,
    FieldKind.percent,
  ),
  'dismissedAt': ConflictField(
    (l) => l.settings_conflict_field_dismissedAt,
    FieldKind.dateTime,
  ),
  'diveComputerFirmware': ConflictField(
    (l) => l.settings_conflict_field_diveComputerFirmware,
    FieldKind.shortText,
  ),
  'diveComputerModel': ConflictField(
    (l) => DiveField.diveComputerModel.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'diveComputerSerial': ConflictField(
    (l) => l.settings_conflict_field_diveComputerSerial,
    FieldKind.shortText,
  ),
  'diveDateTime': ConflictField(
    (l) => DiveField.dateTime.localizedDisplayName(l),
    FieldKind.wallClock,
  ),
  'diveMaster': ConflictField(
    (l) => DiveField.diveMaster.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'diveMode': ConflictField(
    (l) => DiveField.diveMode.localizedDisplayName(l),
    FieldKind.enumValue,
    enumLabel: diveModeLabeler,
  ),
  'diveNumber': ConflictField(
    (l) => DiveField.diveNumber.localizedDisplayName(l),
    FieldKind.number,
  ),
  'diveOperator': ConflictField(
    (l) => l.settings_conflict_field_diveOperator,
    FieldKind.shortText,
  ),
  'duration': ConflictField(
    (l) => l.settings_conflict_field_duration,
    FieldKind.durationSeconds,
  ),
  'endPressure': ConflictField(
    (l) => DiveField.endPressure.localizedDisplayName(l),
    FieldKind.pressure,
  ),
  'endTimestamp': ConflictField(
    (l) => l.settings_conflict_field_endTimestamp,
    FieldKind.durationSeconds,
  ),
  'engineVersion': ConflictField(
    (l) => l.settings_conflict_field_engineVersion,
    FieldKind.number,
  ),
  'entryLatitude': ConflictField(
    (l) => l.settings_conflict_field_entryLatitude,
    FieldKind.latitude,
  ),
  'entryLongitude': ConflictField(
    (l) => l.settings_conflict_field_entryLongitude,
    FieldKind.longitude,
  ),
  'entryMethod': ConflictField(
    (l) => DiveField.entryMethod.localizedDisplayName(l),
    FieldKind.enumValue,
    enumLabel: entryMethodLabeler,
  ),
  'entryTime': ConflictField(
    (l) => l.settings_conflict_field_entryTime,
    FieldKind.wallClock,
  ),
  'eventType': ConflictField(
    (l) => l.settings_conflict_field_eventType,
    FieldKind.enumValue,
    enumLabel: profileEventTypeLabeler,
  ),
  'excludedFromGasStats': ConflictField(
    (l) => l.settings_conflict_field_excludedFromGasStats,
    FieldKind.boolean,
  ),
  'excludedFromStats': ConflictField(
    (l) => l.settings_conflict_field_excludedFromStats,
    FieldKind.boolean,
  ),
  'exitLatitude': ConflictField(
    (l) => l.settings_conflict_field_exitLatitude,
    FieldKind.latitude,
  ),
  'exitLongitude': ConflictField(
    (l) => l.settings_conflict_field_exitLongitude,
    FieldKind.longitude,
  ),
  'exitMethod': ConflictField(
    (l) => DiveField.exitMethod.localizedDisplayName(l),
    FieldKind.enumValue,
    enumLabel: entryMethodLabeler,
  ),
  'exitTime': ConflictField(
    (l) => l.settings_conflict_field_exitTime,
    FieldKind.wallClock,
  ),
  'fieldKey': ConflictField(
    (l) => l.settings_conflict_field_fieldKey,
    FieldKind.shortText,
  ),
  'fieldValue': ConflictField(
    (l) => l.settings_conflict_field_fieldValue,
    FieldKind.shortText,
  ),
  'fileName': ConflictField(
    (l) => l.settings_conflict_field_fileName,
    FieldKind.shortText,
  ),
  'firstDepth': ConflictField(
    (l) => l.settings_conflict_field_firstDepth,
    FieldKind.depth,
  ),
  'gradientFactorHigh': ConflictField(
    (l) => DiveField.gradientFactorHigh.localizedDisplayName(l),
    FieldKind.percent,
  ),
  'gradientFactorLow': ConflictField(
    (l) => DiveField.gradientFactorLow.localizedDisplayName(l),
    FieldKind.percent,
  ),
  'hasDecoStop': ConflictField(
    (l) => l.settings_conflict_field_hasDecoStop,
    FieldKind.boolean,
  ),
  'hasDecoType': ConflictField(
    (l) => l.settings_conflict_field_hasDecoType,
    FieldKind.boolean,
  ),
  'hasPositiveCeiling': ConflictField(
    (l) => l.settings_conflict_field_hasPositiveCeiling,
    FieldKind.boolean,
  ),
  'hePercent': ConflictField(
    (l) => l.settings_conflict_field_hePercent,
    FieldKind.percent,
  ),
  'humidity': ConflictField(
    (l) => DiveField.humidity.localizedDisplayName(l),
    FieldKind.percent,
  ),
  'importId': ConflictField(
    (l) => l.settings_conflict_field_importId,
    FieldKind.shortText,
  ),
  'importSource': ConflictField(
    (l) => DiveField.importSource.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'importVersion': ConflictField(
    (l) => l.settings_conflict_field_importVersion,
    FieldKind.number,
  ),
  'importedAt': ConflictField(
    (l) => l.settings_conflict_field_importedAt,
    FieldKind.dateTime,
  ),
  'inputsHash': ConflictField(
    (l) => l.settings_conflict_field_inputsHash,
    FieldKind.opaque,
  ),
  'isBuiltIn': ConflictField(
    (l) => l.settings_conflict_field_isBuiltIn,
    FieldKind.boolean,
  ),
  'isFavorite': ConflictField(
    (l) => DiveField.isFavorite.localizedDisplayName(l),
    FieldKind.boolean,
  ),
  'isPlanned': ConflictField(
    (l) => l.settings_conflict_field_isPlanned,
    FieldKind.boolean,
  ),
  'isPrimary': ConflictField(
    (l) => l.settings_conflict_field_isPrimary,
    FieldKind.boolean,
  ),
  'lastDepth': ConflictField(
    (l) => l.settings_conflict_field_lastDepth,
    FieldKind.depth,
  ),
  'lastParsedAt': ConflictField(
    (l) => l.settings_conflict_field_lastParsedAt,
    FieldKind.dateTime,
  ),
  'latitude': ConflictField(
    (l) => l.settings_conflict_field_latitude,
    FieldKind.latitude,
  ),
  'lessonsLearned': ConflictField(
    (l) => l.settings_conflict_field_lessonsLearned,
    FieldKind.longText,
  ),
  'libdivecomputerVersion': ConflictField(
    (l) => l.settings_conflict_field_libdivecomputerVersion,
    FieldKind.shortText,
  ),
  'longitude': ConflictField(
    (l) => l.settings_conflict_field_longitude,
    FieldKind.longitude,
  ),
  'loopO2Avg': ConflictField(
    (l) => l.settings_conflict_field_loopO2Avg,
    FieldKind.partialPressure,
  ),
  'loopO2Max': ConflictField(
    (l) => l.settings_conflict_field_loopO2Max,
    FieldKind.partialPressure,
  ),
  'loopO2Min': ConflictField(
    (l) => l.settings_conflict_field_loopO2Min,
    FieldKind.partialPressure,
  ),
  'loopVolume': ConflictField(
    (l) => l.settings_conflict_field_loopVolume,
    FieldKind.volume,
  ),
  'maxAscentRate': ConflictField(
    (l) => l.settings_conflict_field_maxAscentRate,
    FieldKind.ascentRate,
  ),
  'maxDepth': ConflictField(
    (l) => DiveField.maxDepth.localizedDisplayName(l),
    FieldKind.depth,
  ),
  'maxDescentRate': ConflictField(
    (l) => l.settings_conflict_field_maxDescentRate,
    FieldKind.ascentRate,
  ),
  'mergeSourceSlot': ConflictField(
    (l) => l.settings_conflict_field_mergeSourceSlot,
    FieldKind.number,
  ),
  'name': ConflictField(
    (l) => l.settings_conflict_field_name,
    FieldKind.shortText,
  ),
  'narrative': ConflictField(
    (l) => l.settings_conflict_field_narrative,
    FieldKind.longText,
  ),
  'notes': ConflictField(
    (l) => DiveField.notes.localizedDisplayName(l),
    FieldKind.longText,
  ),
  'o2Percent': ConflictField(
    (l) => l.settings_conflict_field_o2Percent,
    FieldKind.percent,
  ),
  'occurredAt': ConflictField(
    (l) => l.settings_conflict_field_occurredAt,
    FieldKind.dateTime,
  ),
  'otu': ConflictField(
    (l) => DiveField.otu.localizedDisplayName(l),
    FieldKind.number,
  ),
  'outingId': ConflictField(
    (l) => l.settings_conflict_field_outingId,
    FieldKind.opaque,
  ),
  'params': ConflictField(
    (l) => l.settings_conflict_field_params,
    FieldKind.opaque,
  ),
  'phone': ConflictField(
    (l) => l.settings_conflict_field_phone,
    FieldKind.shortText,
  ),
  'precipitation': ConflictField(
    (l) => DiveField.precipitation.localizedDisplayName(l),
    FieldKind.enumValue,
    enumLabel: precipitationLabeler,
  ),
  'presetName': ConflictField(
    (l) => l.settings_conflict_field_presetName,
    FieldKind.shortText,
  ),
  'rating': ConflictField(
    (l) => DiveField.ratingStars.localizedDisplayName(l),
    FieldKind.number,
  ),
  'rawData': ConflictField(
    (l) => l.settings_conflict_field_rawData,
    FieldKind.opaque,
  ),
  'rawFingerprint': ConflictField(
    (l) => l.settings_conflict_field_rawFingerprint,
    FieldKind.opaque,
  ),
  'reviewedAt': ConflictField(
    (l) => l.settings_conflict_field_reviewedAt,
    FieldKind.dateTime,
  ),
  'roleSource': ConflictField(
    (l) => l.settings_conflict_field_roleSource,
    FieldKind.enumValue,
    enumLabel: tankRoleSourceLabeler,
  ),
  'ruleId': ConflictField(
    (l) => l.settings_conflict_field_ruleId,
    FieldKind.shortText,
  ),
  'runtime': ConflictField(
    (l) => DiveField.runtime.localizedDisplayName(l),
    FieldKind.durationSeconds,
  ),
  'sampleCount': ConflictField(
    (l) => l.settings_conflict_field_sampleCount,
    FieldKind.number,
  ),
  'samples': ConflictField(
    (l) => l.settings_conflict_field_samples,
    FieldKind.opaque,
  ),
  'scrAdditionRatio': ConflictField(
    (l) => l.settings_conflict_field_scrAdditionRatio,
    FieldKind.number,
  ),
  'scrInjectionRate': ConflictField(
    (l) => l.settings_conflict_field_scrInjectionRate,
    FieldKind.rmv,
  ),
  'scrOrificeSize': ConflictField(
    (l) => l.settings_conflict_field_scrOrificeSize,
    FieldKind.shortText,
  ),
  'scrType': ConflictField(
    (l) => l.settings_conflict_field_scrType,
    FieldKind.enumValue,
    enumLabel: scrTypeLabeler,
  ),
  'scrubberDurationMinutes': ConflictField(
    (l) => l.settings_conflict_field_scrubberDurationMinutes,
    FieldKind.durationMinutes,
  ),
  'scrubberRemainingMinutes': ConflictField(
    (l) => l.settings_conflict_field_scrubberRemainingMinutes,
    FieldKind.durationMinutes,
  ),
  'scrubberType': ConflictField(
    (l) => l.settings_conflict_field_scrubberType,
    FieldKind.shortText,
  ),
  'setpointDeco': ConflictField(
    (l) => DiveField.setpointDeco.localizedDisplayName(l),
    FieldKind.partialPressure,
  ),
  'setpointHigh': ConflictField(
    (l) => DiveField.setpointHigh.localizedDisplayName(l),
    FieldKind.partialPressure,
  ),
  'setpointLow': ConflictField(
    (l) => DiveField.setpointLow.localizedDisplayName(l),
    FieldKind.partialPressure,
  ),
  'sharedComputerIds': ConflictField(
    (l) => l.settings_conflict_field_sharedComputerIds,
    FieldKind.opaque,
  ),
  'shortName': ConflictField(
    (l) => l.settings_conflict_field_shortName,
    FieldKind.shortText,
  ),
  'showInDetailHeader': ConflictField(
    (l) => l.settings_conflict_field_showInDetailHeader,
    FieldKind.boolean,
  ),
  'showInListView': ConflictField(
    (l) => l.settings_conflict_field_showInListView,
    FieldKind.boolean,
  ),
  'siteSuggestionDismissedAt': ConflictField(
    (l) => l.settings_conflict_field_siteSuggestionDismissedAt,
    FieldKind.dateTime,
  ),
  'sortOrder': ConflictField(
    (l) => l.settings_conflict_field_sortOrder,
    FieldKind.number,
  ),
  'sourceDiverKey': ConflictField(
    (l) => l.settings_conflict_field_sourceDiverKey,
    FieldKind.shortText,
  ),
  'sourceFileFormat': ConflictField(
    (l) => l.settings_conflict_field_sourceFileFormat,
    FieldKind.shortText,
  ),
  'sourceFileName': ConflictField(
    (l) => l.settings_conflict_field_sourceFileName,
    FieldKind.shortText,
  ),
  'sourceFormat': ConflictField(
    (l) => l.settings_conflict_field_sourceFormat,
    FieldKind.shortText,
  ),
  'sourceTankIndex': ConflictField(
    (l) => l.settings_conflict_field_sourceTankIndex,
    FieldKind.number,
  ),
  'sourceUuid': ConflictField(
    (l) => l.settings_conflict_field_sourceUuid,
    FieldKind.shortText,
  ),
  'startPressure': ConflictField(
    (l) => DiveField.startPressure.localizedDisplayName(l),
    FieldKind.pressure,
  ),
  'startTimestamp': ConflictField(
    (l) => l.settings_conflict_field_startTimestamp,
    FieldKind.durationSeconds,
  ),
  'surfaceConditions': ConflictField(
    (l) => l.settings_conflict_field_surfaceConditions,
    FieldKind.shortText,
  ),
  'surfaceInterval': ConflictField(
    (l) => DiveField.surfaceInterval.localizedDisplayName(l),
    FieldKind.durationSeconds,
  ),
  'surfaceIntervalSeconds': ConflictField(
    (l) => DiveField.surfaceInterval.localizedDisplayName(l),
    FieldKind.durationSeconds,
  ),
  'surfacePressure': ConflictField(
    (l) => DiveField.surfacePressure.localizedDisplayName(l),
    FieldKind.surfacePressure,
  ),
  'swellHeight': ConflictField(
    (l) => DiveField.swellHeight.localizedDisplayName(l),
    FieldKind.depth,
  ),
  'tankMaterial': ConflictField(
    (l) => l.settings_conflict_field_tankMaterial,
    FieldKind.enumValue,
    enumLabel: tankMaterialLabeler,
  ),
  'tankName': ConflictField(
    (l) => l.settings_conflict_field_tankName,
    FieldKind.shortText,
  ),
  'tankOrder': ConflictField(
    (l) => l.settings_conflict_field_tankOrder,
    FieldKind.number,
  ),
  'tankRole': ConflictField(
    (l) => l.settings_conflict_field_tankRole,
    FieldKind.enumValue,
    enumLabel: tankRoleLabeler,
  ),
  'timeOffsetSeconds': ConflictField(
    (l) => l.settings_conflict_field_timeOffsetSeconds,
    FieldKind.durationSeconds,
  ),
  'timestamp': ConflictField(
    (l) => l.settings_conflict_field_timestamp,
    FieldKind.durationSeconds,
  ),
  'transmitterSerial': ConflictField(
    (l) => l.settings_conflict_field_transmitterSerial,
    FieldKind.shortText,
  ),
  'usageDuration': ConflictField(
    (l) => l.settings_conflict_field_usageDuration,
    FieldKind.durationSeconds,
  ),
  'value': ConflictField(
    (l) => l.settings_conflict_field_value,
    FieldKind.number,
  ),
  'visibility': ConflictField(
    (l) => DiveField.visibility.localizedDisplayName(l),
    FieldKind.enumValue,
    enumLabel: visibilityLabeler,
  ),
  'visibilityMeters': ConflictField(
    (l) => DiveField.visibility.localizedDisplayName(l),
    FieldKind.distance,
  ),
  'volume': ConflictField(
    (l) => l.settings_conflict_field_volume,
    FieldKind.volume,
  ),
  'waterTemp': ConflictField(
    (l) => DiveField.waterTemp.localizedDisplayName(l),
    FieldKind.temperature,
  ),
  'waterType': ConflictField(
    (l) => DiveField.waterType.localizedDisplayName(l),
    FieldKind.enumValue,
    enumLabel: waterTypeLabeler,
  ),
  'weatherCode': ConflictField(
    (l) => l.settings_conflict_field_weatherCode,
    FieldKind.number,
  ),
  'weatherDescription': ConflictField(
    (l) => DiveField.weatherDescription.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'weatherFetchedAt': ConflictField(
    (l) => l.settings_conflict_field_weatherFetchedAt,
    FieldKind.dateTime,
  ),
  'weatherSource': ConflictField(
    (l) => l.settings_conflict_field_weatherSource,
    FieldKind.enumValue,
    enumLabel: weatherSourceLabeler,
  ),
  'weightAmount': ConflictField(
    (l) => l.settings_conflict_field_weightAmount,
    FieldKind.weight,
  ),
  'weightType': ConflictField(
    (l) => l.settings_conflict_field_weightType,
    FieldKind.enumValue,
    enumLabel: weightTypeLabeler,
  ),
  'weightingFeedback': ConflictField(
    (l) => l.settings_conflict_field_weightingFeedback,
    FieldKind.enumValue,
    enumLabel: weightingFeedbackLabeler,
  ),
  'weightingFeedbackKg': ConflictField(
    (l) => l.settings_conflict_field_weightingFeedbackKg,
    FieldKind.weight,
  ),
  'windDirection': ConflictField(
    (l) => l.settings_conflict_field_windDirection,
    FieldKind.enumValue,
    enumLabel: currentDirectionLabeler,
  ),
  'windSpeed': ConflictField(
    (l) => DiveField.windSpeed.localizedDisplayName(l),
    FieldKind.windSpeed,
  ),
  'workingPressure': ConflictField(
    (l) => l.settings_conflict_field_workingPressure,
    FieldKind.pressure,
  ),
};

/// Columns whose meaning depends on the entity, keyed `entity.column`.
final Map<String, ConflictField> diveLogOverrides = {
  'diveProfileEvents.severity': ConflictField(
    (l) => l.settings_conflict_field_diveProfileEvents_severity,
    FieldKind.enumValue,
    enumLabel: eventSeverityLabeler,
  ),
  'diveProfileEvents.source': ConflictField(
    (l) => l.settings_conflict_field_diveProfileEvents_source,
    FieldKind.enumValue,
    enumLabel: eventSourceLabeler,
  ),
  'diveSafetyFindings.severity': ConflictField(
    (l) => l.settings_conflict_field_diveSafetyFindings_severity,
    FieldKind.enumValue,
    enumLabel: safetySeverityLabeler,
  ),
  'incidents.category': ConflictField(
    (l) => l.settings_conflict_field_incidents_category,
    FieldKind.enumValue,
    enumLabel: incidentCategoryLabeler,
  ),
  'incidents.occurredAt': ConflictField(
    (l) => l.settings_conflict_field_occurredAt,
    FieldKind.utcDate,
  ),
  'incidents.severity': ConflictField(
    (l) => l.settings_conflict_field_incidents_severity,
    FieldKind.enumValue,
    enumLabel: incidentSeverityLabeler,
  ),
  'qualityFindings.category': ConflictField(
    (l) => l.settings_conflict_field_qualityFindings_category,
    FieldKind.enumValue,
    enumLabel: qualityCategoryLabeler,
  ),
  'qualityFindings.severity': ConflictField(
    (l) => l.settings_conflict_field_qualityFindings_severity,
    FieldKind.enumValue,
    enumLabel: qualitySeverityLabeler,
  ),
  'qualityFindings.status': ConflictField(
    (l) => l.settings_conflict_field_qualityFindings_status,
    FieldKind.enumValue,
    enumLabel: qualityStatusLabeler,
  ),
};
