import 'package:submersion/features/equipment/domain/constants/equipment_field.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_enum_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';

/// Conflict labels and value kinds for equipment, cylinders, dive computers and service records (#694). Generated from a
/// reviewed column list; the coverage guard in
/// test/features/settings/presentation/conflicts/ keeps it complete.
final Map<String, ConflictField> equipmentFields = {
  'analyzer': ConflictField(
    (l) => l.settings_conflict_field_analyzer,
    FieldKind.shortText,
  ),
  'anchorDate': ConflictField(
    (l) => l.settings_conflict_field_anchorDate,
    FieldKind.date,
  ),
  'anchorSetAt': ConflictField(
    (l) => l.settings_conflict_field_anchorSetAt,
    FieldKind.dateTime,
  ),
  'applicableTypes': ConflictField(
    (l) => l.settings_conflict_field_applicableTypes,
    FieldKind.opaque,
  ),
  'attrKey': ConflictField(
    (l) => l.settings_conflict_field_attrKey,
    FieldKind.shortText,
  ),
  'autoApplyOnComputerImport': ConflictField(
    (l) => l.settings_conflict_field_autoApplyOnComputerImport,
    FieldKind.boolean,
  ),
  'autoAttach': ConflictField(
    (l) => l.settings_conflict_field_autoAttach,
    FieldKind.boolean,
  ),
  'bluetoothAddress': ConflictField(
    (l) => l.settings_conflict_field_bluetoothAddress,
    FieldKind.shortText,
  ),
  'brand': ConflictField(
    (l) => EquipmentField.brand.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'buoyancyKg': ConflictField(
    (l) => l.settings_conflict_field_buoyancyKg,
    FieldKind.weight,
  ),
  'channelIndex': ConflictField(
    (l) => l.settings_conflict_field_channelIndex,
    FieldKind.number,
  ),
  'connectionType': ConflictField(
    (l) => l.settings_conflict_field_connectionType,
    FieldKind.shortText,
  ),
  'customReminderDays': ConflictField(
    (l) => l.settings_conflict_field_customReminderDays,
    FieldKind.opaque,
  ),
  'customReminderEnabled': ConflictField(
    (l) => l.settings_conflict_field_customReminderEnabled,
    FieldKind.boolean,
  ),
  'defaultCategory': ConflictField(
    (l) => l.settings_conflict_field_defaultCategory,
    FieldKind.enumValue,
    enumLabel: serviceCategoryLabeler,
  ),
  'defaultCost': ConflictField(
    (l) => l.settings_conflict_field_defaultCost,
    FieldKind.number,
  ),
  'defaultCurrency': ConflictField(
    (l) => l.settings_conflict_field_defaultCurrency,
    FieldKind.shortText,
  ),
  'defaultIntervalDays': ConflictField(
    (l) => l.settings_conflict_field_defaultIntervalDays,
    FieldKind.number,
  ),
  'defaultIntervalDives': ConflictField(
    (l) => l.settings_conflict_field_defaultIntervalDives,
    FieldKind.number,
  ),
  'defaultIntervalHours': ConflictField(
    (l) => l.settings_conflict_field_defaultIntervalHours,
    FieldKind.number,
  ),
  'defaultStartPressureBar': ConflictField(
    (l) => l.settings_conflict_field_defaultStartPressureBar,
    FieldKind.pressure,
  ),
  'displayName': ConflictField(
    (l) => l.settings_conflict_field_displayName,
    FieldKind.shortText,
  ),
  'diveCount': ConflictField(
    (l) => l.settings_conflict_field_diveCount,
    FieldKind.number,
  ),
  'enabled': ConflictField(
    (l) => l.settings_conflict_field_enabled,
    FieldKind.boolean,
  ),
  'evidence': ConflictField(
    (l) => l.settings_conflict_field_evidence,
    FieldKind.opaque,
  ),
  'evidenceFingerprint': ConflictField(
    (l) => l.settings_conflict_field_evidenceFingerprint,
    FieldKind.opaque,
  ),
  'exposureIntervals': ConflictField(
    (l) => l.settings_conflict_field_exposureIntervals,
    FieldKind.opaque,
  ),
  'filledAt': ConflictField(
    (l) => l.settings_conflict_field_filledAt,
    FieldKind.dateTime,
  ),
  'firmwareVersion': ConflictField(
    (l) => l.settings_conflict_field_firmwareVersion,
    FieldKind.shortText,
  ),
  'intervalDays': ConflictField(
    (l) => l.settings_conflict_field_intervalDays,
    FieldKind.number,
  ),
  'intervalDives': ConflictField(
    (l) => l.settings_conflict_field_intervalDives,
    FieldKind.number,
  ),
  'intervalHours': ConflictField(
    (l) => l.settings_conflict_field_intervalHours,
    FieldKind.number,
  ),
  'isActive': ConflictField(
    (l) => EquipmentField.isActive.localizedDisplayName(l),
    FieldKind.boolean,
  ),
  'isCustom': ConflictField(
    (l) => l.settings_conflict_field_isCustom,
    FieldKind.boolean,
  ),
  'isDefault': ConflictField(
    (l) => l.settings_conflict_field_isDefault,
    FieldKind.boolean,
  ),
  'issueTags': ConflictField(
    (l) => l.settings_conflict_field_issueTags,
    FieldKind.opaque,
  ),
  'lastDiveFingerprint': ConflictField(
    (l) => l.settings_conflict_field_lastDiveFingerprint,
    FieldKind.opaque,
  ),
  'lastDownloadTimestamp': ConflictField(
    (l) => l.settings_conflict_field_lastDownloadTimestamp,
    FieldKind.dateTime,
  ),
  'lastServiceDate': ConflictField(
    (l) => EquipmentField.lastServiceDate.localizedDisplayName(l),
    FieldKind.date,
  ),
  'manufacturer': ConflictField(
    (l) => l.settings_conflict_field_manufacturer,
    FieldKind.shortText,
  ),
  'model': ConflictField(
    (l) => EquipmentField.model.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'nextServiceDue': ConflictField(
    (l) => EquipmentField.nextServiceDue.localizedDisplayName(l),
    FieldKind.date,
  ),
  'observedAt': ConflictField(
    (l) => l.settings_conflict_field_observedAt,
    FieldKind.dateTime,
  ),
  'passportId': ConflictField(
    (l) => l.settings_conflict_field_passportId,
    FieldKind.shortText,
  ),
  'pressureBar': ConflictField(
    (l) => l.settings_conflict_field_pressureBar,
    FieldKind.pressure,
  ),
  'provider': ConflictField(
    (l) => l.settings_conflict_field_provider,
    FieldKind.shortText,
  ),
  'purchaseCurrency': ConflictField(
    (l) => l.settings_conflict_field_purchaseCurrency,
    FieldKind.shortText,
  ),
  'purchaseDate': ConflictField(
    (l) => EquipmentField.purchaseDate.localizedDisplayName(l),
    FieldKind.date,
  ),
  'purchasePrice': ConflictField(
    (l) => EquipmentField.purchasePrice.localizedDisplayName(l),
    FieldKind.number,
  ),
  'radiusMeters': ConflictField(
    (l) => l.settings_conflict_field_radiusMeters,
    FieldKind.distance,
  ),
  'serialNumber': ConflictField(
    (l) => EquipmentField.serialNumber.localizedDisplayName(l),
    FieldKind.shortText,
  ),
  'serviceCategory': ConflictField(
    (l) => l.settings_conflict_field_serviceCategory,
    FieldKind.enumValue,
    enumLabel: serviceCategoryLabeler,
  ),
  'serviceDate': ConflictField(
    (l) => l.settings_conflict_field_serviceDate,
    FieldKind.date,
  ),
  'serviceIntervalDays': ConflictField(
    (l) => EquipmentField.serviceIntervalDays.localizedDisplayName(l),
    FieldKind.number,
  ),
  'showFigure': ConflictField(
    (l) => l.settings_conflict_field_showFigure,
    FieldKind.boolean,
  ),
  'signedRecord': ConflictField(
    (l) => l.settings_conflict_field_signedRecord,
    FieldKind.opaque,
  ),
  'stationKey': ConflictField(
    (l) => l.settings_conflict_field_stationKey,
    FieldKind.opaque,
  ),
  'stationName': ConflictField(
    (l) => l.settings_conflict_field_stationName,
    FieldKind.shortText,
  ),
  'temperatureC': ConflictField(
    (l) => l.settings_conflict_field_temperatureC,
    FieldKind.temperature,
  ),
  'thickness': ConflictField(
    (l) => l.settings_conflict_field_thickness,
    FieldKind.shortText,
  ),
  'valueNum': ConflictField(
    (l) => l.settings_conflict_field_valueNum,
    FieldKind.number,
  ),
  'valueText': ConflictField(
    (l) => l.settings_conflict_field_valueText,
    FieldKind.shortText,
  ),
  'volumeL': ConflictField(
    (l) => l.settings_conflict_field_volumeL,
    FieldKind.volume,
  ),
  'weightKg': ConflictField(
    (l) => l.settings_conflict_field_weightKg,
    FieldKind.weight,
  ),
  'workingPressureBar': ConflictField(
    (l) => l.settings_conflict_field_workingPressureBar,
    FieldKind.pressure,
  ),
};

/// Columns whose meaning depends on the entity, keyed `entity.column`.
final Map<String, ConflictField> equipmentOverrides = {
  'cylinderFills.source': ConflictField(
    (l) => l.settings_conflict_field_cylinderFills_source,
    FieldKind.enumValue,
    enumLabel: fillSourceLabeler,
  ),
  'equipment.status': ConflictField(
    (l) => EquipmentField.status.localizedDisplayName(l),
    FieldKind.enumValue,
    enumLabel: equipmentStatusLabeler,
  ),
  'equipment.type': ConflictField(
    (l) => EquipmentField.type.localizedDisplayName(l),
    FieldKind.enumValue,
    enumLabel: equipmentTypeLabeler,
  ),
  'equipmentComponents.role': ConflictField(
    (l) => l.settings_conflict_field_equipmentComponents_role,
    FieldKind.shortText,
  ),
  'equipmentFindings.severity': ConflictField(
    (l) => l.settings_conflict_field_equipmentFindings_severity,
    FieldKind.enumValue,
    enumLabel: conditionSeverityLabeler,
  ),
  'equipmentObservations.status': ConflictField(
    (l) => l.settings_conflict_field_equipmentObservations_status,
    FieldKind.enumValue,
    enumLabel: observationStatusLabeler,
  ),
  'equipmentOwnershipEvents.kind': ConflictField(
    (l) => l.settings_conflict_field_equipmentOwnershipEvents_kind,
    FieldKind.enumValue,
    enumLabel: ownershipEventKindLabeler,
  ),
};
