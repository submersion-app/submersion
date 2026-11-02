import 'package:submersion/features/agent_access/data/documents/dive_document.dart';
import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_section.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';

/// The agent-facing document for a trip. Metric, unit-named keys.
Map<String, Object?> tripDocument(Trip t) => {
  'id': t.id,
  'diver_id': t.diverId,
  'name': t.name,
  'start_date': calendarDate(t.startDate),
  'end_date': calendarDate(t.endDate),
  'location': t.location,
  'resort_name': t.resortName,
  'liveaboard_name': t.liveaboardName,
  'trip_type': t.tripType.name,
  'notes': t.notes,
  'is_shared': t.isShared,
  'return_flight_time': wallClockOrNull(t.returnFlightAt),
  'expected_dives': t.expectedDives,
  'expected_runtime_minutes': t.expectedRuntimeMinutes,
  'divers_sharing_cylinders': t.diversSharingCylinders,
  'dives_per_day_target': t.divesPerDayTarget,
  'parent_trip_id': t.parentTripId,
};

Map<String, Object?> itineraryDayDocument(ItineraryDay d) => {
  'id': d.id,
  'trip_id': d.tripId,
  'day_number': d.dayNumber,
  'day_date': calendarDate(d.date),
  'day_type': d.dayType.name,
  'port_name': d.portName,
  'latitude': d.latitude,
  'longitude': d.longitude,
  'notes': d.notes,
  'planned_dives': d.plannedDives,
};

Map<String, Object?> liveaboardDetailsDocument(LiveaboardDetails l) => {
  'id': l.id,
  'trip_id': l.tripId,
  'vessel_name': l.vesselName,
  'operator_name': l.operatorName,
  'vessel_type': l.vesselType,
  'cabin_type': l.cabinType,
  'capacity': l.capacity,
  'embark_port': l.embarkPort,
  'embark_latitude': l.embarkLatitude,
  'embark_longitude': l.embarkLongitude,
  'disembark_port': l.disembarkPort,
  'disembark_latitude': l.disembarkLatitude,
  'disembark_longitude': l.disembarkLongitude,
};

Map<String, Object?> tripCylinderDocument(TripCylinder c) => {
  'id': c.id,
  'trip_id': c.tripId,
  'equipment_id': c.equipmentId,
  'label': c.label,
  'volume_l': c.volume,
  'working_pressure_bar': c.workingPressure,
  'material': c.material?.name,
  'preset_name': c.presetName,
  'sort_order': c.sortOrder,
  'notes': c.notes,
};

Map<String, Object?> tripCylinderEventDocument(TripCylinderEvent e) => {
  'id': e.id,
  'trip_cylinder_id': e.tripCylinderId,
  'kind': e.kind.name,
  'occurred_time': wallClock(e.occurredAt),
  'bottle_label': e.bottleLabel,
  'pressure_bar': e.pressure,
  'o2_fraction': gasFraction(e.o2Percent),
  'he_fraction': gasFraction(e.hePercent),
  'analyzed_o2_fraction': gasFraction(e.analyzedO2),
  'analyzed_he_fraction': gasFraction(e.analyzedHe),
  'dive_center_id': e.diveCenterId,
  'cost': e.cost,
  'currency': e.currency,
  'is_package': e.isPackage,
  'note': e.note,
};

Map<String, Object?> tripChecklistSectionDocument(TripChecklistSection s) => {
  'id': s.id,
  'trip_id': s.tripId,
  'title': s.title,
  'sort_order': s.sortOrder,
};

Map<String, Object?> tripChecklistItemDocument(TripChecklistItem i) => {
  'id': i.id,
  'trip_id': i.tripId,
  'section_id': i.sectionId,
  'title': i.title,
  'notes': i.notes,
  'due_date': calendarDate(i.dueDate),
  'is_done': i.isDone,
  'completed_at': instant(i.completedAt),
  'sort_order': i.sortOrder,
};
