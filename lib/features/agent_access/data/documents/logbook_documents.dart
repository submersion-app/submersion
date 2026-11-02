import 'dart:convert';

import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/connections/domain/entities/saved_connection_map.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/divers/domain/entities/diver_weight_entry.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/media/domain/entities/media_smart_album.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/safety/domain/entities/emergency_info.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';

/// Stored JSON as a value. An empty column is null, and text this build cannot
/// parse comes back as text, so one bad row never fails a whole read.
Object? _storedJson(String text) {
  if (text.isEmpty) return null;
  try {
    return jsonDecode(text);
  } on FormatException {
    return text;
  }
}

Map<String, Object?> incidentDocument(Incident i) => {
  'id': i.id,
  'diver_id': i.diverId,
  'dive_id': i.diveId,
  'equipment_id': i.equipmentId,
  'occurred_time': wallClock(i.occurredAt),
  'category': i.category.name,
  'severity': i.severity.name,
  'narrative': i.narrative,
  'contributing_factors': i.contributingFactors,
  'lessons_learned': i.lessonsLearned,
};

Map<String, Object?> emergencyChamberDocument(EmergencyChamber c) => {
  'id': c.id,
  'name': c.name,
  'country': c.country,
  'city': c.city,
  'phone': c.phone,
  'emergency_phone': c.emergencyPhone,
  'latitude': c.latitude,
  'longitude': c.longitude,
  'notes': c.notes,
  'capability': c.capability.name,
  'availability': c.availability.name,
  'last_verified_date': calendarDate(c.lastVerified),
  'verified_via': c.verifiedVia.name,
  'verified_url': c.verifiedUrl,
};

/// A document's details; its pages are metadata only, because page content
/// is bytes.
Map<String, Object?> documentDocument(Document d) => {
  'id': d.id,
  'diver_id': d.diverId,
  'owner_kind': d.owner.kind.name,
  'owner_id': d.owner.id,
  'type': d.type.name,
  'title': d.title,
  'issuer': d.issuer,
  'reference_number': d.referenceNumber,
  'issue_date': calendarDate(d.issueDate),
  'expiry_date': calendarDate(d.expiryDate),
  'reminder_lead_days': d.reminderLeadDays,
  'emergency_phone': d.emergencyPhone,
  'phone': d.phone,
  'is_primary': d.isPrimary,
  'notes': d.notes,
};

Map<String, Object?> documentPageDocument(DocumentPage p) => {
  'id': p.id,
  'document_id': p.documentId,
  'page_index': p.pageIndex,
  'side': p.side?.name,
  'file_name': p.fileName,
  'mime_type': p.mimeType,
  'size_bytes': p.sizeBytes,
};

Map<String, Object?> savedQueryDocument(SavedQuery q) => {
  'id': q.id,
  'diver_id': q.diverId,
  'subject': q.subject,
  'name': q.name,
  'query': _storedJson(q.queryJson),
  'sort_order': q.sortOrder,
};

Map<String, Object?> ruleDocument(Rule r) => {
  'id': r.id,
  'diver_id': r.diverId,
  'subject': r.subject.name,
  'name': r.name,
  'enabled': r.enabled,
  'triggers': [for (final t in r.triggers) t.name],
  'condition': _storedJson(r.conditionJson),
  'actions': _storedJson(r.actionsJson),
  'sort_order': r.sortOrder,
};

Map<String, Object?> smartAlbumDocument(MediaSmartAlbum a) => {
  'id': a.id,
  'name': a.name,
  'filter': a.filter.toJson(),
  'sort_order': a.sortOrder,
};

Map<String, Object?> connectionMapDocument(SavedConnectionMap m) => {
  'id': m.id,
  'diver_id': m.diverId,
  'name': m.name,
  'spec': m.spec.toJson(),
  'sort_order': m.sortOrder,
};

Map<String, Object?> csvPresetDocument(CsvPreset p) => {
  'id': p.id,
  'name': p.name,
  'preset': jsonDecode(p.toJson()),
};

/// A computer's hardware identity. The Bluetooth address is this host's and
/// the fingerprint is a download cursor, so neither is the agent's business.
Map<String, Object?> diveComputerDocument(DiveComputer c) => {
  'id': c.id,
  'diver_id': c.diverId,
  'name': c.name,
  'manufacturer': c.manufacturer,
  'model': c.model,
  'serial_number': c.serialNumber,
  'firmware_version': c.firmwareVersion,
  'connection_type': c.connectionType,
  'last_download_at': instant(c.lastDownload),
  'dive_count': c.diveCount,
  'is_favorite': c.isFavorite,
  'notes': c.notes,
  'equipment_id': c.equipmentId,
};

Map<String, Object?> weightEntryDocument(DiverWeightEntry e) => {
  'id': e.id,
  'diver_id': e.diverId,
  'measured_at': instant(e.measuredAt),
  'weight_kg': e.weightKg,
  'height_cm': e.heightCm,
};

Map<String, Object?> preDiveSessionDocument(PreDiveSession s) => {
  'id': s.id,
  'diver_id': s.diverId,
  'template_id': s.templateId,
  'template_name': s.templateName,
  'strict_order': s.strictOrder,
  'dive_id': s.diveId,
  'trip_id': s.tripId,
  'started_at': instant(s.startedAt),
  'completed_at': instant(s.completedAt),
  'status': s.status.name,
  'equipment_set_id': s.equipmentSetId,
  'equipment_set_name': s.equipmentSetName,
  'notes': s.notes,
};

Map<String, Object?> preDiveSessionSectionDocument(PreDiveSessionSection s) => {
  'id': s.id,
  'session_id': s.sessionId,
  'title': s.title,
  'sort_order': s.sortOrder,
};

/// Item values stay bare because the unit is stored with them, in
/// `value_unit`.
Map<String, Object?> preDiveSessionItemDocument(PreDiveSessionItem i) => {
  'id': i.id,
  'session_id': i.sessionId,
  'section_id': i.sectionId,
  'title': i.title,
  'notes': i.notes,
  'sort_order': i.sortOrder,
  'item_type': i.itemType.name,
  'value_label': i.valueLabel,
  'value_unit': i.valueUnit,
  'value_min': i.valueMin,
  'value_max': i.valueMax,
  'is_required': i.isRequired,
  'state': i.state.name,
  'value_number': i.valueNumber,
  'value_text': i.valueText,
  'note': i.note,
  'completed_at': instant(i.completedAt),
  'equipment_id': i.equipmentId,
};
