import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_pairing.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_share.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

/// The agent-facing document for a piece of gear. Metric, unit-named keys;
/// money is a bare number beside its currency.
Map<String, Object?> equipmentDocument(EquipmentItem e) => {
  'id': e.id,
  'diver_id': e.diverId,
  'name': e.name,
  'type': e.type.name,
  'brand': e.brand,
  'model': e.model,
  'serial_number': e.serialNumber,
  'status': e.status.name,
  'purchase_date': calendarDate(e.purchaseDate),
  'purchase_price': e.purchasePrice,
  'purchase_currency': e.purchaseCurrency,
  'last_service_date': calendarDate(e.lastServiceDate),
  'service_interval_days': e.serviceIntervalDays,
  'notes': e.notes,
  'is_active': e.isActive,
  'custom_reminder_enabled': e.customReminderEnabled,
  'custom_reminder_days': e.customReminderDays,
  'parent_equipment_id': e.parentEquipmentId,
  'cover_media_id': e.coverMediaId,
  'attributes': [for (final a in e.attributes) _attributeDocument(a)],
  // The tag id the passport and gear tag cards link, a system attribute.
  'passport_id': [
    for (final a in e.attributes)
      if (!a.isCustom && a.key == 'passport_id') a.valueText,
  ].firstOrNull,
};

Map<String, Object?> _attributeDocument(EquipmentAttribute a) => {
  'id': a.id,
  'key': a.key,
  'is_custom': a.isCustom,
  'value_text': a.valueText,
  'value_num': a.valueNum,
  'sort_order': a.sortOrder,
};

Map<String, Object?> serviceRecordDocument(ServiceRecord r) => {
  'id': r.id,
  'equipment_id': r.equipmentId,
  'category': r.serviceCategory.name,
  'service_kind_id': r.serviceKindId,
  'service_date': calendarDate(r.serviceDate),
  'next_service_due_date': calendarDate(r.nextServiceDue),
  'provider': r.provider,
  'cost': r.cost,
  'currency': r.currency,
  'notes': r.notes,
};

Map<String, Object?> _exposureIntervals(Map<ExposureUnit, double> intervals) =>
    {for (final e in intervals.entries) e.key.name: e.value};

Map<String, Object?> serviceScheduleDocument(ServiceSchedule s) => {
  'id': s.id,
  'equipment_id': s.equipmentId,
  'service_kind_id': s.serviceKindId,
  'interval_days': s.intervalDays,
  'interval_dives': s.intervalDives,
  'interval_hours': s.intervalHours,
  'exposure_intervals': _exposureIntervals(s.exposureIntervals),
  'default_cost': s.defaultCost,
  'default_currency': s.defaultCurrency,
  'anchor_date': calendarDate(s.anchorDate),
  'enabled': s.enabled,
};

Map<String, Object?> serviceKindDocument(ServiceKind k) => {
  'id': k.id,
  'diver_id': k.diverId,
  'name': k.name,
  'applicable_types': [for (final t in k.applicableTypes) t.name],
  'default_interval_days': k.defaultIntervalDays,
  'default_interval_dives': k.defaultIntervalDives,
  'default_interval_hours': k.defaultIntervalHours,
  'exposure_intervals': _exposureIntervals(k.exposureIntervals),
  'default_cost': k.defaultCost,
  'default_currency': k.defaultCurrency,
  'default_category': k.defaultCategory?.name,
  'auto_attach': k.autoAttach,
  'is_built_in': k.isBuiltIn,
};

Map<String, Object?> equipmentComponentDocument(EquipmentComponent c) => {
  'id': c.id,
  'parent_equipment_id': c.parentEquipmentId,
  'component_equipment_id': c.componentEquipmentId,
  'role': c.role,
  'sort_order': c.sortOrder,
};

Map<String, Object?> cylinderPairingDocument(CylinderPairing p) => {
  'id': p.id,
  'cylinder_a_id': p.cylinderAId,
  'cylinder_b_id': p.cylinderBId,
  'paired_on': calendarDate(p.pairedOn),
  'unpaired_on': calendarDate(p.unpairedOn),
};

Map<String, Object?> equipmentShareDocument(EquipmentShare s) => {
  'id': s.id,
  'equipment_id': s.equipmentId,
  'diver_id': s.diverId,
};

Map<String, Object?> equipmentSetDocument(EquipmentSet s) => {
  'id': s.id,
  'diver_id': s.diverId,
  'name': s.name,
  'description': s.description,
  'equipment_ids': s.equipmentIds,
  // What the set applies besides its own gear (issue #4525), in order.
  'included_set_ids': s.includedSetIds,
  'weight_preset_ids': s.weightPresetIds,
  'cylinder_config_ids': s.cylinderConfigIds,
  'is_default': s.isDefault,
  'auto_apply_on_computer_import': s.autoApplyOnComputerImport,
  'show_figure': s.showFigure,
};

Map<String, Object?> equipmentSetGeofenceDocument(EquipmentSetGeofence g) => {
  'id': g.id,
  'set_id': g.setId,
  'label': g.label,
  'latitude': g.latitude,
  'longitude': g.longitude,
  'radius_m': g.radiusMeters,
};

Map<String, Object?> equipmentLocationDocument(EquipmentLocation l) => {
  'id': l.id,
  'diver_id': l.diverId,
  'name': l.name,
  'kind': l.kind.name,
  'dive_center_id': l.diveCenterId,
  'buddy_id': l.buddyId,
  'notes': l.notes,
  'is_archived': l.isArchived,
};

Map<String, Object?> equipmentLocationMoveDocument(EquipmentLocationMove m) => {
  'id': m.id,
  'equipment_id': m.equipmentId,
  'location_id': m.locationId,
  'moved_at': instant(m.movedAt),
  'note': m.note,
};

Map<String, Object?> equipmentObservationDocument(EquipmentObservation o) => {
  'id': o.id,
  'diver_id': o.diverId,
  'equipment_id': o.equipmentId,
  'dive_id': o.diveId,
  'observed_time': wallClock(o.observedAt),
  'status': o.status.name,
  'issue_tags': [for (final t in o.issueTags) t.name],
  'unrecognized_tags': o.unrecognizedTags,
  'note': o.note,
};

Map<String, Object?> cylinderFillDocument(CylinderFill f) => {
  'id': f.id,
  'diver_id': f.diverId,
  'passport_id': f.passportId,
  'equipment_id': f.equipmentId,
  'filled_at': instant(f.filledAt),
  'o2_fraction': f.o2Percent / 100,
  'he_fraction': f.hePercent / 100,
  'pressure_bar': f.pressureBar,
  'temperature_c': f.temperatureC,
  'analyzer': f.analyzer,
  'station_name': f.stationName,
  'station_key': f.stationKey,
  'signed_record': f.signedRecord,
  'source': f.source.name,
  'notes': f.notes,
  'filled_together_id': f.filledTogetherId,
};

Map<String, Object?> transmitterDocument(Transmitter x) => {
  'id': x.id,
  'diver_id': x.diverId,
  'transmitter_serial': x.transmitterSerial,
  'dive_computer_id': x.diveComputerId,
  'channel_index': x.channelIndex,
  'label': x.label,
  'role': x.role.name,
  'volume_l': x.volumeL,
  'working_pressure_bar': x.workingPressureBar,
  'material': x.material?.name,
  'preset_name': x.presetName,
  'equipment_id': x.equipmentId,
  'transmitter_equipment_id': x.transmitterEquipmentId,
  'is_configured': x.isConfigured,
};

Map<String, Object?> cylinderConfigDocument(CylinderConfig c) => {
  'id': c.id,
  'diver_id': c.diverId,
  'equipment_id': c.equipmentId,
  'name': c.name,
  'description': c.description,
  'sort_order': c.sortOrder,
};

Map<String, Object?> cylinderConfigItemDocument(CylinderConfigItem i) => {
  'id': i.id,
  'config_id': i.configId,
  'sort_order': i.sortOrder,
  'label': i.label,
  'role': i.tankRole.name,
  'volume_l': i.volumeL,
  'working_pressure_bar': i.workingPressureBar,
  'material': i.tankMaterial?.name,
  'o2_fraction': i.o2Percent / 100,
  'he_fraction': i.hePercent / 100,
  'default_start_pressure_bar': i.defaultStartPressureBar,
  'deco_switch_depth_m': i.decoSwitchDepth,
};
