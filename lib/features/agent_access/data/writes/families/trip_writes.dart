import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/constants/enums.dart' show TripType;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/service_ledger_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/trip_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/documents/domain/entities/document.dart'
    show DocumentOwner, DocumentOwnerKind;
import 'package:submersion/features/trips/data/repositories/liveaboard_details_repository.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

/// Trips, through the repository the trip edit page saves through. A trip is
/// a range of days; a side trip hangs off one trip, one level deep; the
/// dives the diver assigns stretch it to cover them; packed gear is a list.
/// A new liveaboard trip gets its itinerary days, and a trip that stops
/// being a liveaboard loses its vessel details, as the page's save does.
class TripWrites extends WritableEntry {
  TripWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'trips';

  @override
  String get table => 'trips';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 200, trim: true),
    'trip_type': FieldCodec.enumName(TripType.values),
    'start_date': const FieldCodec.calendarDate(),
    'end_date': const FieldCodec.calendarDate(),
    for (final key in const ['location', 'resort_name', 'liveaboard_name'])
      key: const FieldCodec.text(maxLength: 200, nullable: true, trim: true),
    'notes': const FieldCodec.text(allowBlank: true, trim: true),
    'is_shared': const FieldCodec.flag(),
    // A wall clock, as the page stores the flight's local time.
    'return_flight_time': const FieldCodec.wallClock(nullable: true),
    for (final key in const [
      'expected_dives',
      'expected_runtime_minutes',
      'dives_per_day_target',
    ])
      key: const FieldCodec.integer(min: 1, max: 100000, nullable: true),
    'divers_sharing_cylinders': const FieldCodec.integer(min: 1, max: 100),
    'parent_trip_id': const FieldCodec.reference('trips', nullable: true),
  };

  @override
  Set<String> get requiredOnCreate => const {'name', 'start_date', 'end_date'};

  @override
  final Map<String, RelationSpec> relations = const {
    'dive_ids': RelationSpec(refEntity: 'dives'),
    'equipment_ids': RelationSpec(refEntity: 'equipment'),
  };

  @override
  Future<Set<String>> currentRelation(String id, String relation) async {
    final (table, column, key) = relation == 'dive_ids'
        ? ('dives', 'id', 'trip_id')
        : ('trip_equipment', 'equipment_id', 'trip_id');
    final rows = await DatabaseService.instance.database
        .customSelect(
          'SELECT "$column" AS linked FROM "$table" WHERE "$key" = ?',
          variables: [Variable.withString(id)],
        )
        .get();
    return {for (final row in rows) row.read<String>('linked')};
  }

  @override
  String? titleOf(Map<String, Object?> document) => document['name'] as String?;

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    return tripProblem(check);
  }

  /// What the page starts a new trip with: one diver to a cylinder, a shore
  /// trip.
  @override
  Future<Map<String, Object?>> createDefaults(
    String diverId,
    Map<String, Object?> values,
  ) async => const {'divers_sharing_cylinders': 1, 'trip_type': 'shore'};

  /// A new liveaboard trip gets a day for every day of the trip.
  @override
  Future<Map<String, int>> alsoCreates(
    String diverId,
    Map<String, Object?> values,
  ) async {
    if (values['trip_type'] != TripType.liveaboard.name) return const {};
    return {'itinerary_days': _generated('', values).length};
  }

  static List<ItineraryDay> _generated(
    String tripId,
    Map<String, Object?> values,
  ) => ItineraryDay.generateForTrip(
    tripId: tripId,
    startDate: calendarDay(values['start_date'])!,
    endDate: calendarDay(values['end_date'])!,
  );

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async {
    final current = await _r.trips.getTripById(id);
    if (current == null) return const SideEffects();
    final next = _applied(current, update.values);
    final details =
        current.tripType == TripType.liveaboard &&
            next.tripType != TripType.liveaboard &&
            await LiveaboardDetailsRepository().getByTripId(id) != null
        ? 1
        : 0;
    final bare = await bareDaysOutside(_r, id, next);
    final assigned = await assignTouched(
      _r,
      next,
      update.relations['dive_ids']?.add ?? const <String>{},
    );
    return SideEffects(
      touched: {
        ...assigned,
        if (details > 0) 'liveaboard_details': details,
        if (bare > 0) 'itinerary_days': bare,
      },
    );
  }

  @override
  Future<List<DocumentOwner>> deletedDocumentOwners(String id) async => [
    DocumentOwner(DocumentOwnerKind.trip, id),
  ];

  /// The trip's children cascade or are deleted with it, its dives and side
  /// trips stay and lose the link, as `deleteTrip` runs.
  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async {
    final documents = await countDocuments(await deletedDocumentOwners(id));
    return DeleteReach(
      records: {if (documents > 0) 'documents': documents},
      parts: await countCascaded('trips', id, except: const {'documents'}),
      unlinked: await countUnlinked('trips', id, except: const {'documents'}),
    );
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final now = DateTime.now();
    final blank = Trip(
      id: '',
      diverId: diverId,
      name: values['name']! as String,
      startDate: calendarDay(values['start_date'])!,
      endDate: calendarDay(values['end_date'])!,
      createdAt: now,
      updatedAt: now,
    );
    final saved = await _r.trips.createTrip(_applied(blank, values));
    if (saved.tripType == TripType.liveaboard) {
      await _r.itineraryDays.saveAll(_generated(saved.id, values));
    }
    return saved.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current =
        await _r.trips.getTripById(id) ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Trip $id no longer exists.',
          details: {'id': id},
        ));
    if (update.values.isNotEmpty) {
      final next = _applied(current, update.values);
      await _r.trips.updateTrip(next, actingDiverId: ownerId);
      if (current.tripType == TripType.liveaboard &&
          next.tripType != TripType.liveaboard) {
        await LiveaboardDetailsRepository().deleteByTripId(id);
      }
    }
    if (update.relations['dive_ids']?.add case final add? when add.isNotEmpty) {
      await _r.trips.assignDivesToTrip(add.toList(), id);
    }
    if (update.relations['equipment_ids'] case final gear?) {
      if (gear.add.isNotEmpty) await _r.tripEquipment.pack(id, gear.add);
      for (final itemId in gear.remove) {
        await _r.tripEquipment.unpack(id, itemId);
      }
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) async {
    final deleted = await _r.trips.deleteTrip(id, actingDiverId: ownerId);
    if (!deleted) {
      throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'Trip $id belongs to another profile.',
        details: {'id': id},
      );
    }
  }

  /// [trip] with [values] applied, a named null clearing its field.
  static Trip _applied(Trip trip, Map<String, Object?> values) {
    T? kept<T>(String key, T? held) =>
        values.containsKey(key) ? values[key] as T? : held;
    final type = values['trip_type'] as String?;
    return trip.copyWith(
      name: values['name'] as String?,
      tripType: type == null ? null : TripType.values.byName(type),
      startDate: calendarDay(values['start_date']),
      endDate: calendarDay(values['end_date']),
      location: kept('location', trip.location),
      resortName: kept('resort_name', trip.resortName),
      liveaboardName: kept('liveaboard_name', trip.liveaboardName),
      notes: values['notes'] as String?,
      isShared: values['is_shared'] as bool?,
      returnFlightAt: kept('return_flight_time', trip.returnFlightAt),
      expectedDives: kept('expected_dives', trip.expectedDives),
      expectedRuntimeMinutes: kept(
        'expected_runtime_minutes',
        trip.expectedRuntimeMinutes,
      ),
      diversSharingCylinders: values['divers_sharing_cylinders'] as int?,
      divesPerDayTarget: kept('dives_per_day_target', trip.divesPerDayTarget),
      parentTripId: kept('parent_trip_id', trip.parentTripId),
    );
  }
}
