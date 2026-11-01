import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/agent_access/data/documents/trip_documents.dart';
import 'package:submersion/features/agent_access/data/records/record_entity.dart';
import 'package:submersion/features/agent_access/data/records/record_reader.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/records/record_scope.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_section.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';

final _tripScope = rootScope(QuerySubject.trips);
final _viaTrip = viaParent('trips', 'trip_id', _tripScope);

/// Trips and everything planned or recorded against them.
List<RecordEntry> tripEntries(RecordRepositories r) => [
  RecordEntity<Trip>(
    name: 'trips',
    table: 'trips',
    scope: _tripScope,
    orderBy: 'r0.start_date DESC',
    load: (ids, _) => loadEach(ids, r.trips.getTripById),
    document: tripDocument,
    summaryKeys: const ['name', 'start_date', 'end_date', 'location'],
    blocks: {
      'itinerary': (trip, _) async => [
        for (final d in await r.itineraryDays.getByTripId(trip.id))
          itineraryDayDocument(d),
      ],
      'liveaboard': (trip, _) async {
        final details = await r.liveaboard.getByTripId(trip.id);
        return details == null ? null : liveaboardDetailsDocument(details);
      },
      'cylinders': (trip, _) async => [
        for (final c in await r.tripCylinders.getCylindersForTrip(trip.id))
          tripCylinderDocument(c),
      ],
      'checklist': (trip, _) async => {
        'sections': [
          for (final s in await r.tripChecklists.getSectionsForTrip(trip.id))
            tripChecklistSectionDocument(s),
        ],
        'items': [
          for (final i in await r.tripChecklists.getByTripId(trip.id))
            tripChecklistItemDocument(i),
        ],
      },
      'dive_ids': (trip, load) =>
          r.trips.getDiveIdsForTrip(trip.id, diverId: load.diverId),
      'equipment_ids': (trip, load) async => RecordReader(r.db).visibleRows(
        'equipment',
        rootScope(QuerySubject.equipment),
        await r.tripEquipment.equipmentIdsForTrip(trip.id),
        load.diverId,
      ),
      'side_trips': (trip, load) async => [
        for (final side in await r.sideTrips.getSideTrips(
          trip.id,
          diverId: load.diverId,
        ))
          {
            'id': side.id,
            'name': side.name,
            'start_date': calendarDate(side.startDate),
            'end_date': calendarDate(side.endDate),
          },
      ],
      'shares': (trip, _) async => (await r.itemShares.storedProfileIds(
        SharedItemKind.trip,
        trip.id,
      )).toList(),
    },
  ),
  RecordEntity<ItineraryDay>(
    name: 'itinerary_days',
    table: 'trip_itinerary_days',
    scope: _viaTrip,
    parentColumn: 'trip_id',
    orderBy: 'r0.trip_id, r0.day_number',
    load: (ids, _) => loadChildren(
      r.db,
      table: 'trip_itinerary_days',
      parentColumn: 'trip_id',
      ids: ids,
      idOf: (d) => d.id,
      byParents: (trips) => eachParent(trips, r.itineraryDays.getByTripId),
    ),
    document: itineraryDayDocument,
    summaryKeys: const ['trip_id', 'day_number', 'day_date', 'day_type'],
  ),
  RecordEntity<LiveaboardDetails>(
    name: 'liveaboard_details',
    table: 'liveaboard_detail_records',
    scope: _viaTrip,
    parentColumn: 'trip_id',
    load: (ids, _) => loadChildren(
      r.db,
      table: 'liveaboard_detail_records',
      parentColumn: 'trip_id',
      ids: ids,
      idOf: (l) => l.id,
      byParents: (trips) async => {
        for (final id in trips)
          if (await r.liveaboard.getByTripId(id) case final details?)
            id: [details],
      },
    ),
    document: liveaboardDetailsDocument,
    summaryKeys: const ['trip_id', 'vessel_name', 'embark_port'],
  ),
  RecordEntity<TripCylinder>(
    name: 'trip_cylinders',
    table: 'trip_cylinders',
    scope: _viaTrip,
    parentColumn: 'trip_id',
    orderBy: 'r0.trip_id, r0.sort_order',
    load: (ids, _) => loadEach(ids, r.tripCylinders.getCylinderById),
    document: tripCylinderDocument,
    summaryKeys: const ['trip_id', 'label', 'volume_l'],
  ),
  RecordEntity<TripCylinderEvent>(
    name: 'trip_cylinder_events',
    table: 'trip_cylinder_events',
    scope: viaParent('trip_cylinders', 'trip_cylinder_id', _viaTrip),
    parentColumn: 'trip_cylinder_id',
    orderBy: 'r0.trip_cylinder_id, r0.occurred_at',
    load: (ids, _) => loadChildren(
      r.db,
      table: 'trip_cylinder_events',
      parentColumn: 'trip_cylinder_id',
      ids: ids,
      idOf: (e) => e.id,
      byParents: (cylinders) =>
          eachParent(cylinders, r.tripCylinders.getEventsForCylinder),
    ),
    document: tripCylinderEventDocument,
    summaryKeys: const ['trip_cylinder_id', 'kind', 'occurred_time'],
  ),
  RecordEntity<TripChecklistSection>(
    name: 'trip_checklist_sections',
    table: 'trip_checklist_sections',
    scope: _viaTrip,
    parentColumn: 'trip_id',
    orderBy: 'r0.trip_id, r0.sort_order',
    load: (ids, _) => loadChildren(
      r.db,
      table: 'trip_checklist_sections',
      parentColumn: 'trip_id',
      ids: ids,
      idOf: (s) => s.id,
      byParents: (trips) =>
          eachParent(trips, r.tripChecklists.getSectionsForTrip),
    ),
    document: tripChecklistSectionDocument,
    summaryKeys: const ['trip_id', 'title'],
  ),
  RecordEntity<TripChecklistItem>(
    name: 'trip_checklist_items',
    table: 'trip_checklist_items',
    scope: _viaTrip,
    parentColumn: 'trip_id',
    orderBy: 'r0.trip_id, r0.sort_order',
    load: (ids, _) => loadChildren(
      r.db,
      table: 'trip_checklist_items',
      parentColumn: 'trip_id',
      ids: ids,
      idOf: (i) => i.id,
      byParents: (trips) => eachParent(trips, r.tripChecklists.getByTripId),
    ),
    document: tripChecklistItemDocument,
    summaryKeys: const ['trip_id', 'title', 'is_done', 'due_date'],
  ),
];
