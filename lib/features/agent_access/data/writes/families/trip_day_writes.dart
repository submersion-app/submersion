import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/constants/enums.dart' show DayType, TripType;
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/service_ledger_rules.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart'
    show calendarDaysBetween;
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';

/// The type of trip [tripId] is once the set's earlier changes apply.
Future<String?> _tripType(
  RecordRepositories r,
  WriteCheck check,
  String tripId,
) async =>
    check.soFar.values[('trips', tripId)]?['trip_type'] as String? ??
    (await r.trips.getTripById(tripId))?.tripType.name;

/// A liveaboard's vessel, through the save the trip edit page runs for a
/// liveaboard (createOrUpdate): one per trip, only on a liveaboard. The page
/// writes no embark or disembark position and the save clears them, which
/// the plan lists. The details go with the trip's type, never on their own.
class LiveaboardDetailsWrites extends WritableEntry {
  LiveaboardDetailsWrites(this._r);

  final RecordRepositories _r;

  static const _vesselTypes = {
    'catamaran',
    'motorYacht',
    'sailingYacht',
    'other',
  };
  static const _positions = [
    'embark_latitude',
    'embark_longitude',
    'disembark_latitude',
    'disembark_longitude',
  ];

  @override
  String get name => 'liveaboard_details';

  @override
  String get table => 'liveaboard_detail_records';

  @override
  ChildOf get parent => const ChildOf(entity: 'trips', field: 'trip_id');

  @override
  late final Map<String, FieldCodec> fields = {
    'trip_id': const FieldCodec.reference('trips'),
    'vessel_name': const FieldCodec.text(maxLength: 200, trim: true),
    for (final key in const [
      'operator_name',
      'vessel_type',
      'cabin_type',
      'embark_port',
      'disembark_port',
    ])
      key: const FieldCodec.text(maxLength: 200, nullable: true, trim: true),
    'capacity': const FieldCodec.integer(min: 1, max: 10000, nullable: true),
  };

  @override
  Set<String> get requiredOnCreate => const {'vessel_name'};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'A liveaboard\'s vessel goes when the trip stops being a liveaboard; '
        'change the trip\'s trip_type instead.',
      );
    }
    final type = check.values['vessel_type'];
    if (type is String && !_vesselTypes.contains(type)) {
      return PlanBlock(
        BlockReason.invalidValue,
        'vessel_type: one of ${_vesselTypes.join(', ')}.',
      );
    }
    if (check.kind != ChangeKind.create) return null;
    final tripId = check.values['trip_id']! as String;
    if (await _tripType(_r, check, tripId) != TripType.liveaboard.name) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'trip_id: only a liveaboard trip has a vessel.',
      );
    }
    if (await _r.liveaboard.getByTripId(tripId) != null) {
      return const PlanBlock(
        BlockReason.duplicateRecord,
        'trip_id: this trip has its vessel already; update it.',
      );
    }
    return null;
  }

  @override
  UniqueClaim? uniqueKey(WriteCheck check) => check.kind == ChangeKind.create
      ? UniqueClaim('vessel/${check.values['trip_id']}')
      : null;

  /// The save writes no position, so a stored one is cleared.
  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async => SideEffects(
    fields: {
      for (final key in _positions)
        if (document[key] != null) key: null,
    },
  );

  @override
  Future<String> create(String diverId, Map<String, Object?> values) =>
      _save(null, values);

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final tripId = await _tripOf(id);
    await _save(await _r.liveaboard.getByTripId(tripId), update.values);
  }

  Future<String> _save(
    LiveaboardDetails? current,
    Map<String, Object?> values,
  ) async {
    T? kept<T>(String key, T? held) =>
        values.containsKey(key) ? values[key] as T? : held;
    final now = DateTime.now();
    return (await _r.liveaboard.createOrUpdate(
      LiveaboardDetails(
        id: current?.id ?? '',
        tripId: current?.tripId ?? values['trip_id']! as String,
        vesselName: values['vessel_name'] as String? ?? current!.vesselName,
        operatorName: kept('operator_name', current?.operatorName),
        vesselType: kept('vessel_type', current?.vesselType),
        cabinType: kept('cabin_type', current?.cabinType),
        capacity: kept('capacity', current?.capacity),
        embarkPort: kept('embark_port', current?.embarkPort),
        disembarkPort: kept('disembark_port', current?.disembarkPort),
        createdAt: current?.createdAt ?? now,
        updatedAt: now,
      ),
    )).id;
  }

  Future<String> _tripOf(String id) async {
    final rows = await _r.db
        .customSelect(
          'SELECT trip_id FROM liveaboard_detail_records WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .get();
    if (rows.isEmpty) {
      throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'Vessel details $id no longer exist.',
        details: {'id': id},
      );
    }
    return rows.single.read<String>('trip_id');
  }

  @override
  Future<void> delete(String id, String? ownerId) async {}
}

/// A trip's itinerary days, through the day sheet's save (updateDay) and
/// the forecast strip's planned dives (setPlannedDives). A day is one of the
/// trip's dates, once; liveaboard day types are for a liveaboard; a rest
/// day plans no dives; at most 12 a day. Days go with their trip.
class ItineraryDayWrites extends WritableEntry {
  ItineraryDayWrites(this._r);

  final RecordRepositories _r;

  static const _anyTrip = {DayType.travel, DayType.diveDay, DayType.rest};

  @override
  String get name => 'itinerary_days';

  @override
  String get table => 'trip_itinerary_days';

  @override
  ChildOf get parent => const ChildOf(entity: 'trips', field: 'trip_id');

  @override
  late final Map<String, FieldCodec> fields = {
    'trip_id': const FieldCodec.reference('trips'),
    'day_date': const FieldCodec.calendarDate(),
    'day_type': FieldCodec.enumName(DayType.values),
    'port_name': const FieldCodec.text(
      maxLength: 200,
      nullable: true,
      trim: true,
    ),
    'notes': const FieldCodec.text(allowBlank: true, trim: true),
    // kMaxPlannedDivesPerDay.
    'planned_dives': const FieldCodec.integer(
      min: 0,
      max: kMaxPlannedDivesPerDay,
      nullable: true,
    ),
  };

  @override
  Set<String> get requiredOnCreate => const {'day_date'};

  @override
  UniqueClaim? uniqueKey(WriteCheck check) => check.kind == ChangeKind.create
      ? UniqueClaim('${check.values['trip_id']}/${check.values['day_date']}')
      : null;

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'An itinerary day goes with its trip; change the trip\'s dates or '
        'plan the day at no dives instead.',
      );
    }
    final tripId =
        check.values['trip_id'] as String? ??
        check.document!['trip_id']! as String;
    final type = check.values['day_type'];
    if (type is String &&
        !_anyTrip.contains(DayType.values.byName(type)) &&
        await _tripType(_r, check, tripId) != TripType.liveaboard.name) {
      return PlanBlock(
        BlockReason.invalidValue,
        'day_type: $type is a liveaboard day; this trip takes '
        '${_anyTrip.map((t) => t.name).join(', ')}.',
      );
    }
    if (check.kind == ChangeKind.update) {
      return check.values.containsKey('day_date')
          ? const PlanBlock(
              BlockReason.invalidValue,
              'day_date: a day keeps its date.',
            )
          : null;
    }
    final day = calendarDay(check.values['day_date'])!;
    final trip = await _r.trips.getTripById(tripId);
    if (trip != null &&
        (day.isBefore(tripDay(trip.startDate)) ||
            day.isAfter(tripDay(trip.endDate)))) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'day_date: a day of the trip, from its start to its end.',
      );
    }
    final taken = (await _r.itineraryDays.getByTripId(
      tripId,
    )).any((d) => tripDay(d.date) == day);
    if (taken) {
      return const PlanBlock(
        BlockReason.duplicateRecord,
        'day_date: the trip has a day for that date already; update it.',
      );
    }
    return null;
  }

  /// A rest day plans no dives, as the sheet saves it; the forecast strip's
  /// count retypes a dive day to rest at 0 and back above it.
  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async {
    final next = _next(document, update.values);
    return SideEffects(
      fields: {
        if (!update.values.containsKey('planned_dives') &&
            next.planned != document['planned_dives'])
          'planned_dives': next.planned,
        if (!update.values.containsKey('day_type') &&
            next.type != document['day_type'])
          'day_type': next.type,
      },
    );
  }

  /// The type and plan [values] leave a day of [document] with.
  static ({String type, int? planned}) _next(
    Map<String, Object?> document,
    Map<String, Object?> values,
  ) {
    var type = values['day_type'] as String? ?? document['day_type']! as String;
    var planned = values.containsKey('planned_dives')
        ? values['planned_dives'] as int?
        : document['planned_dives'] as int?;
    if (values.containsKey('day_type')) {
      if (type == DayType.rest.name) planned = 0;
    } else if (values.containsKey('planned_dives')) {
      // setPlannedDives: 0 rests a dive day, a count or none wakes a rest day.
      if (planned == 0 && type == DayType.diveDay.name) {
        type = DayType.rest.name;
      }
      if (planned != 0 && type == DayType.rest.name) {
        type = DayType.diveDay.name;
      }
    }
    return (type: type, planned: planned);
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final tripId = values['trip_id']! as String;
    final trip = (await _r.trips.getTripById(tripId))!;
    final date = calendarDay(values['day_date'])!;
    final type = values['day_type'] as String? ?? DayType.diveDay.name;
    final now = DateTime.now();
    final day = ItineraryDay(
      id: '',
      tripId: tripId,
      // By date, so a day daylight saving shortens still counts as one.
      dayNumber: calendarDaysBetween(tripDay(trip.startDate), date) + 1,
      date: date,
      dayType: DayType.values.byName(type),
      portName: values['port_name'] as String?,
      notes: values['notes'] as String? ?? '',
      plannedDives: type == DayType.rest.name
          ? 0
          : values['planned_dives'] as int?,
      createdAt: now,
      updatedAt: now,
    );
    await _r.itineraryDays.saveAll([day]);
    final saved = (await _r.itineraryDays.getByTripId(
      tripId,
    )).firstWhere((d) => tripDay(d.date) == date);
    return saved.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final days = await _r.db
        .customSelect(
          'SELECT trip_id FROM trip_itinerary_days WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .get();
    final tripId = days.single.read<String>('trip_id');
    final current = (await _r.itineraryDays.getByTripId(
      tripId,
    )).firstWhere((d) => d.id == id);
    final v = update.values;
    if (v.keys.every((k) => k == 'planned_dives')) {
      await _r.itineraryDays.setPlannedDives(
        tripId: tripId,
        date: current.date,
        plannedDives: v['planned_dives'] as int?,
      );
      return;
    }
    final type = v['day_type'] as String?;
    final next = current.copyWith(
      dayType: type == null ? null : DayType.values.byName(type),
      portName: v.containsKey('port_name') ? v['port_name'] : current.portName,
      notes: v['notes'] as String?,
      plannedDives: type == DayType.rest.name
          ? 0
          : v.containsKey('planned_dives')
          ? v['planned_dives']
          : current.plannedDives,
    );
    await _r.itineraryDays.updateDay(next);
  }

  @override
  Future<void> delete(String id, String? ownerId) async {}
}
