import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/features/certifications/domain/constants/certification_field.dart';
import 'package:submersion/features/courses/domain/constants/course_field.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';

/// Conflict labels and value kinds for divers, buddies, certifications, courses, dive plans and pre-dive checklists (#694). Generated from a
/// reviewed column list; the coverage guard in
/// test/features/settings/presentation/conflicts/ keeps it complete.
final Map<String, ConflictField> peoplePlanningFields = {
  'additionalCredentials': ConflictField(
    (l) => l.settings_conflict_field_additionalCredentials,
    FieldKind.opaque,
  ),
  'agency': ConflictField(
    (l) => CourseField.agency.localizedDisplayName(l),
    FieldKind.enumValue,
    enumLabel: certificationAgencyLabeler,
  ),
  'airBreakBreakSeconds': ConflictField(
    (l) => l.settings_conflict_field_airBreakBreakSeconds,
    FieldKind.durationSeconds,
  ),
  'airBreakO2Seconds': ConflictField(
    (l) => l.settings_conflict_field_airBreakO2Seconds,
    FieldKind.durationSeconds,
  ),
  'allergies': ConflictField(
    (l) => l.settings_conflict_field_allergies,
    FieldKind.longText,
  ),
  'ascentRate': ConflictField(
    (l) => l.settings_conflict_field_ascentRate,
    FieldKind.ascentRate,
  ),
  'batteryReserveFraction': ConflictField(
    (l) => l.settings_conflict_field_batteryReserveFraction,
    FieldKind.fraction,
  ),
  'bestMixEndMeters': ConflictField(
    (l) => l.settings_conflict_field_bestMixEndMeters,
    FieldKind.depth,
  ),
  'bloodType': ConflictField(
    (l) => l.settings_conflict_field_bloodType,
    FieldKind.shortText,
  ),
  'builtinKey': ConflictField(
    (l) => l.settings_conflict_field_builtinKey,
    FieldKind.shortText,
  ),
  'cardNumber': ConflictField(
    (l) => CertificationField.cardNumber.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'completionDate': ConflictField(
    (l) => CourseField.completionDate.localizedDisplayName(l),
    FieldKind.date,
  ),
  'currentSetsTowardDeg': ConflictField(
    (l) => l.settings_conflict_field_currentSetsTowardDeg,
    FieldKind.number,
  ),
  'currentSpeedMps': ConflictField(
    (l) => l.settings_conflict_field_currentSpeedMps,
    FieldKind.speed,
  ),
  'decoSwitchDepth': ConflictField(
    (l) => l.settings_conflict_field_decoSwitchDepth,
    FieldKind.depth,
  ),
  'defaultCurrentSetsTowardDeg': ConflictField(
    (l) => l.settings_conflict_field_defaultCurrentSetsTowardDeg,
    FieldKind.number,
  ),
  'defaultCurrentSpeedMps': ConflictField(
    (l) => l.settings_conflict_field_defaultCurrentSpeedMps,
    FieldKind.speed,
  ),
  'depthM': ConflictField(
    (l) => l.settings_conflict_field_depthM,
    FieldKind.depth,
  ),
  'descentRate': ConflictField(
    (l) => l.settings_conflict_field_descentRate,
    FieldKind.ascentRate,
  ),
  'deviationDepthDelta': ConflictField(
    (l) => l.settings_conflict_field_deviationDepthDelta,
    FieldKind.depth,
  ),
  'deviationTimeMinutes': ConflictField(
    (l) => l.settings_conflict_field_deviationTimeMinutes,
    FieldKind.durationMinutes,
  ),
  'distanceM': ConflictField(
    (l) => l.settings_conflict_field_distanceM,
    FieldKind.distance,
  ),
  'diveModeOverride': ConflictField(
    (l) => l.settings_conflict_field_diveModeOverride,
    FieldKind.enumValue,
    enumLabel: planModeLabeler,
  ),
  'divingSince': ConflictField(
    (l) => l.settings_conflict_field_divingSince,
    FieldKind.number,
  ),
  'emergencyContact2Name': ConflictField(
    (l) => l.settings_conflict_field_emergencyContact2Name,
    FieldKind.shortText,
  ),
  'emergencyContact2Phone': ConflictField(
    (l) => l.settings_conflict_field_emergencyContact2Phone,
    FieldKind.shortText,
  ),
  'emergencyContact2Relation': ConflictField(
    (l) => l.settings_conflict_field_emergencyContact2Relation,
    FieldKind.shortText,
  ),
  'emergencyContactName': ConflictField(
    (l) => l.settings_conflict_field_emergencyContactName,
    FieldKind.shortText,
  ),
  'emergencyContactPhone': ConflictField(
    (l) => l.settings_conflict_field_emergencyContactPhone,
    FieldKind.shortText,
  ),
  'emergencyContactRelation': ConflictField(
    (l) => l.settings_conflict_field_emergencyContactRelation,
    FieldKind.shortText,
  ),
  'endDepth': ConflictField(
    (l) => l.settings_conflict_field_endDepth,
    FieldKind.depth,
  ),
  'environment': ConflictField(
    (l) => l.settings_conflict_field_environment,
    FieldKind.enumValue,
    enumLabel: missionEnvironmentLabeler,
  ),
  'equipmentSetName': ConflictField(
    (l) => l.settings_conflict_field_equipmentSetName,
    FieldKind.shortText,
  ),
  'expiryDate': ConflictField(
    (l) => CertificationField.expiryDate.localizedDisplayName(l),
    FieldKind.date,
  ),
  'finalAscentRate': ConflictField(
    (l) => l.settings_conflict_field_finalAscentRate,
    FieldKind.ascentRate,
  ),
  'gasHe': ConflictField(
    (l) => l.settings_conflict_field_gasHe,
    FieldKind.percent,
  ),
  'gasO2': ConflictField(
    (l) => l.settings_conflict_field_gasO2,
    FieldKind.percent,
  ),
  'gasSwitchStopSeconds': ConflictField(
    (l) => l.settings_conflict_field_gasSwitchStopSeconds,
    FieldKind.durationSeconds,
  ),
  'gfHigh': ConflictField(
    (l) => DiveField.gradientFactorHigh.localizedDisplayName(l),
    FieldKind.percent,
  ),
  'gfLow': ConflictField(
    (l) => DiveField.gradientFactorLow.localizedDisplayName(l),
    FieldKind.percent,
  ),
  'headingDeg': ConflictField(
    (l) => l.settings_conflict_field_headingDeg,
    FieldKind.number,
  ),
  'heightCm': ConflictField(
    (l) => l.settings_conflict_field_heightCm,
    FieldKind.heightCm,
  ),
  'instructorName': ConflictField(
    (l) => CourseField.instructorName.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'instructorNumber': ConflictField(
    (l) => CourseField.instructorNumber.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'insuranceEmergencyPhone': ConflictField(
    (l) => l.settings_conflict_field_insuranceEmergencyPhone,
    FieldKind.shortText,
  ),
  'insuranceExpiryDate': ConflictField(
    (l) => l.settings_conflict_field_insuranceExpiryDate,
    FieldKind.date,
  ),
  'insurancePhone': ConflictField(
    (l) => l.settings_conflict_field_insurancePhone,
    FieldKind.shortText,
  ),
  'insurancePolicyNumber': ConflictField(
    (l) => l.settings_conflict_field_insurancePolicyNumber,
    FieldKind.shortText,
  ),
  'insuranceProvider': ConflictField(
    (l) => l.settings_conflict_field_insuranceProvider,
    FieldKind.shortText,
  ),
  'intermediateAscentRate': ConflictField(
    (l) => l.settings_conflict_field_intermediateAscentRate,
    FieldKind.ascentRate,
  ),
  'isRequired': ConflictField(
    (l) => l.settings_conflict_field_isRequired,
    FieldKind.boolean,
  ),
  'isTravelGas': ConflictField(
    (l) => l.settings_conflict_field_isTravelGas,
    FieldKind.boolean,
  ),
  'issueDate': ConflictField(
    (l) => CertificationField.issueDate.localizedDisplayName(l),
    FieldKind.date,
  ),
  'itemType': ConflictField(
    (l) => l.settings_conflict_field_itemType,
    FieldKind.enumValue,
    enumLabel: preDiveItemTypeLabeler,
  ),
  'lastStopDepth': ConflictField(
    (l) => l.settings_conflict_field_lastStopDepth,
    FieldKind.depth,
  ),
  'level': ConflictField(
    (l) => CertificationField.level.localizedDisplayName(l),
    FieldKind.enumValue,
    enumLabel: certificationLevelLabeler,
  ),
  'measuredAt': ConflictField(
    (l) => l.settings_conflict_field_measuredAt,
    FieldKind.dateTime,
  ),
  'medicalClearanceExpiryDate': ConflictField(
    (l) => l.settings_conflict_field_medicalClearanceExpiryDate,
    FieldKind.date,
  ),
  'medicalNotes': ConflictField(
    (l) => l.settings_conflict_field_medicalNotes,
    FieldKind.longText,
  ),
  'medications': ConflictField(
    (l) => l.settings_conflict_field_medications,
    FieldKind.longText,
  ),
  'mode': ConflictField(
    (l) => l.settings_conflict_field_mode,
    FieldKind.enumValue,
    enumLabel: planModeLabeler,
  ),
  'o2Narcotic': ConflictField(
    (l) => l.settings_conflict_field_o2Narcotic,
    FieldKind.boolean,
  ),
  'overdueServices': ConflictField(
    (l) => l.settings_conflict_field_overdueServices,
    FieldKind.opaque,
  ),
  'photo': ConflictField(
    (l) => l.settings_conflict_field_photo,
    FieldKind.opaque,
  ),
  'photoBack': ConflictField(
    (l) => l.settings_conflict_field_photoBack,
    FieldKind.opaque,
  ),
  'photoBackPath': ConflictField(
    (l) => l.settings_conflict_field_photoBackPath,
    FieldKind.opaque,
  ),
  'photoFront': ConflictField(
    (l) => l.settings_conflict_field_photoFront,
    FieldKind.opaque,
  ),
  'photoFrontPath': ConflictField(
    (l) => l.settings_conflict_field_photoFrontPath,
    FieldKind.opaque,
  ),
  'plannedWeightKg': ConflictField(
    (l) => l.settings_conflict_field_plannedWeightKg,
    FieldKind.weight,
  ),
  'plannedWeightPlacement': ConflictField(
    (l) => l.settings_conflict_field_plannedWeightPlacement,
    FieldKind.opaque,
  ),
  'ppO2Bottom': ConflictField(
    (l) => l.settings_conflict_field_ppO2Bottom,
    FieldKind.partialPressure,
  ),
  'ppO2Deco': ConflictField(
    (l) => l.settings_conflict_field_ppO2Deco,
    FieldKind.partialPressure,
  ),
  'priorDiveCount': ConflictField(
    (l) => l.settings_conflict_field_priorDiveCount,
    FieldKind.number,
  ),
  'priorDiveTimeSeconds': ConflictField(
    (l) => l.settings_conflict_field_priorDiveTimeSeconds,
    FieldKind.durationSeconds,
  ),
  'problemSolvingMinutes': ConflictField(
    (l) => l.settings_conflict_field_problemSolvingMinutes,
    FieldKind.durationMinutes,
  ),
  'rate': ConflictField(
    (l) => l.settings_conflict_field_rate,
    FieldKind.ascentRate,
  ),
  'reservePressure': ConflictField(
    (l) => l.settings_conflict_field_reservePressure,
    FieldKind.pressure,
  ),
  'sacBottom': ConflictField(
    (l) => l.settings_conflict_field_sacBottom,
    FieldKind.rmv,
  ),
  'sacDeco': ConflictField(
    (l) => l.settings_conflict_field_sacDeco,
    FieldKind.rmv,
  ),
  'sacFactor': ConflictField(
    (l) => l.settings_conflict_field_sacFactor,
    FieldKind.number,
  ),
  'sacStressed': ConflictField(
    (l) => l.settings_conflict_field_sacStressed,
    FieldKind.rmv,
  ),
  'salinityPpt': ConflictField(
    (l) => l.settings_conflict_field_salinityPpt,
    FieldKind.number,
  ),
  'scooterBurnSeconds': ConflictField(
    (l) => l.settings_conflict_field_scooterBurnSeconds,
    FieldKind.durationSeconds,
  ),
  'scooterName': ConflictField(
    (l) => l.settings_conflict_field_scooterName,
    FieldKind.shortText,
  ),
  'scooterSpeedMps': ConflictField(
    (l) => l.settings_conflict_field_scooterSpeedMps,
    FieldKind.speed,
  ),
  'section': ConflictField(
    (l) => l.settings_conflict_field_section,
    FieldKind.shortText,
  ),
  'setpointBar': ConflictField(
    (l) => l.settings_conflict_field_setpointBar,
    FieldKind.partialPressure,
  ),
  'setpointSwitchDepth': ConflictField(
    (l) => l.settings_conflict_field_setpointSwitchDepth,
    FieldKind.depth,
  ),
  'shallowAscentRate': ConflictField(
    (l) => l.settings_conflict_field_shallowAscentRate,
    FieldKind.ascentRate,
  ),
  'shoreSwimM': ConflictField(
    (l) => l.settings_conflict_field_shoreSwimM,
    FieldKind.distance,
  ),
  'shoreWalkM': ConflictField(
    (l) => l.settings_conflict_field_shoreWalkM,
    FieldKind.distance,
  ),
  'sourceItemId': ConflictField(
    (l) => l.settings_conflict_field_sourceItemId,
    FieldKind.opaque,
  ),
  'sourceValueNumber': ConflictField(
    (l) => l.settings_conflict_field_sourceValueNumber,
    FieldKind.number,
  ),
  'startDateTime': ConflictField(
    (l) => l.settings_conflict_field_startDateTime,
    FieldKind.epochSeconds,
  ),
  'startDepth': ConflictField(
    (l) => l.settings_conflict_field_startDepth,
    FieldKind.depth,
  ),
  'startedAt': ConflictField(
    (l) => l.settings_conflict_field_startedAt,
    FieldKind.dateTime,
  ),
  'state': ConflictField(
    (l) => l.settings_conflict_field_state,
    FieldKind.enumValue,
    enumLabel: preDiveItemStateLabeler,
  ),
  'stopMinimumsJson': ConflictField(
    (l) => l.settings_conflict_field_stopMinimumsJson,
    FieldKind.opaque,
  ),
  'strictOrder': ConflictField(
    (l) => l.settings_conflict_field_strictOrder,
    FieldKind.boolean,
  ),
  'summaryMaxDepth': ConflictField(
    (l) => l.settings_conflict_field_summaryMaxDepth,
    FieldKind.depth,
  ),
  'summaryRuntimeSeconds': ConflictField(
    (l) => l.settings_conflict_field_summaryRuntimeSeconds,
    FieldKind.durationSeconds,
  ),
  'summaryTtsSeconds': ConflictField(
    (l) => l.settings_conflict_field_summaryTtsSeconds,
    FieldKind.durationSeconds,
  ),
  'surfaceSwimLimitM': ConflictField(
    (l) => l.settings_conflict_field_surfaceSwimLimitM,
    FieldKind.distance,
  ),
  'swimSpeedMps': ConflictField(
    (l) => l.settings_conflict_field_swimSpeedMps,
    FieldKind.speed,
  ),
  'targetCount': ConflictField(
    (l) => l.settings_conflict_field_targetCount,
    FieldKind.number,
  ),
  'templateName': ConflictField(
    (l) => l.settings_conflict_field_templateName,
    FieldKind.shortText,
  ),
  'towBurnFactor': ConflictField(
    (l) => l.settings_conflict_field_towBurnFactor,
    FieldKind.number,
  ),
  'towSpeedFactor': ConflictField(
    (l) => l.settings_conflict_field_towSpeedFactor,
    FieldKind.number,
  ),
  'turnPressureFraction': ConflictField(
    (l) => l.settings_conflict_field_turnPressureFraction,
    FieldKind.fraction,
  ),
  'turnPressureRule': ConflictField(
    (l) => l.settings_conflict_field_turnPressureRule,
    FieldKind.enumValue,
    enumLabel: turnPressureRuleLabeler,
  ),
  'valueLabel': ConflictField(
    (l) => l.settings_conflict_field_valueLabel,
    FieldKind.shortText,
  ),
  'valueMax': ConflictField(
    (l) => l.settings_conflict_field_valueMax,
    FieldKind.number,
  ),
  'valueMin': ConflictField(
    (l) => l.settings_conflict_field_valueMin,
    FieldKind.number,
  ),
  'valueNumber': ConflictField(
    (l) => l.settings_conflict_field_valueNumber,
    FieldKind.number,
  ),
  'valueUnit': ConflictField(
    (l) => l.settings_conflict_field_valueUnit,
    FieldKind.shortText,
  ),
  'walkSpeedMps': ConflictField(
    (l) => l.settings_conflict_field_walkSpeedMps,
    FieldKind.speed,
  ),
};

/// Columns whose meaning depends on the entity, keyed `entity.column`.
final Map<String, ConflictField> peoplePlanningOverrides = {
  'courseRequirements.kind': ConflictField(
    (l) => l.settings_conflict_field_courseRequirements_kind,
    FieldKind.enumValue,
    enumLabel: requirementKindLabeler,
  ),
  'divePlanSegments.type': ConflictField(
    (l) => l.settings_conflict_field_divePlanSegments_type,
    FieldKind.shortText,
  ),
  'divePlanTanks.role': ConflictField(
    (l) => l.settings_conflict_field_divePlanTanks_role,
    FieldKind.enumValue,
    enumLabel: tankRoleLabeler,
  ),
  'preDiveChecklistTemplates.category': ConflictField(
    (l) => l.settings_conflict_field_preDiveChecklistTemplates_category,
    FieldKind.shortText,
  ),
  'preDiveSessions.status': ConflictField(
    (l) => l.settings_conflict_field_preDiveSessions_status,
    FieldKind.enumValue,
    enumLabel: preDiveSessionStatusLabeler,
  ),
};
