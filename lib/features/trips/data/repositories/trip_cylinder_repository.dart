import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/trip_cylinder_links.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart'
    as domain;
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart'
    as domain;
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart'
    show TripCylinderTankUse;

/// Reads and writes the cylinder slots of a trip and their ledger, and reads
/// the lean facts the state fold needs from the dive log.
///
/// Slots and events are their own synced entities (`tripCylinders`,
/// `tripCylinderEvents`). A dive's consumption is the
/// `dive_tanks.trip_cylinder_id` link, which belongs to the dive: this
/// repository only ever clears it, when the slot it points at goes.
class TripCylinderRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(TripCylinderRepository);

  /// Emits when anything the board reads changes: the slots, their ledger,
  /// or the dive tanks and dives that consume them. A sync pull that
  /// rewrites a tank row never touches the dives row, so dive_tanks is
  /// watched on its own.
  Stream<void> watchTripCylinderChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.tripCylinders),
      TableUpdateQuery.onTable(_db.tripCylinderEvents),
      TableUpdateQuery.onTable(_db.diveTanks),
      TableUpdateQuery.onTable(_db.dives),
    ]),
  );

  // ---------------------------------------------------------------- slots

  /// The slots of a trip in board order.
  Future<List<domain.TripCylinder>> getCylindersForTrip(String tripId) async {
    try {
      final rows =
          await (_db.select(_db.tripCylinders)
                ..where((t) => t.tripId.equals(tripId))
                ..orderBy([
                  (t) => OrderingTerm.asc(t.sortOrder),
                  (t) => OrderingTerm.asc(t.createdAt),
                ]))
              .get();
      return rows.map(_mapCylinder).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to read cylinders for trip: $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<domain.TripCylinder?> getCylinderById(String id) async {
    final row = await (_db.select(
      _db.tripCylinders,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _mapCylinder(row);
  }

  /// Inserts a slot. An empty id is minted; timestamps are set here.
  Future<domain.TripCylinder> createCylinder(
    domain.TripCylinder cylinder,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = cylinder.id.isEmpty ? _uuid.v4() : cylinder.id;
      await _db
          .into(_db.tripCylinders)
          .insert(
            TripCylindersCompanion.insert(
              id: id,
              tripId: cylinder.tripId,
              equipmentId: Value(cylinder.equipmentId),
              label: Value(cylinder.label),
              volume: Value(cylinder.volume),
              workingPressure: Value(cylinder.workingPressure),
              material: Value(cylinder.material?.name),
              presetName: Value(cylinder.presetName),
              sortOrder: Value(cylinder.sortOrder),
              notes: Value(cylinder.notes),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'tripCylinders',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      final stamp = DateTime.fromMillisecondsSinceEpoch(now, isUtc: true);
      return cylinder.copyWith(id: id, createdAt: stamp, updatedAt: stamp);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create cylinder for trip: ${cylinder.tripId}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Rewrites the editable columns of a slot. The trip is not one of them.
  Future<void> updateCylinder(domain.TripCylinder cylinder) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.tripCylinders,
      )..where((t) => t.id.equals(cylinder.id))).write(
        TripCylindersCompanion(
          equipmentId: Value(cylinder.equipmentId),
          label: Value(cylinder.label),
          volume: Value(cylinder.volume),
          workingPressure: Value(cylinder.workingPressure),
          material: Value(cylinder.material?.name),
          presetName: Value(cylinder.presetName),
          sortOrder: Value(cylinder.sortOrder),
          notes: Value(cylinder.notes),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'tripCylinders',
        recordId: cylinder.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update cylinder: ${cylinder.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Deletes a slot, its ledger, and the link on every tank that used it.
  /// The tanks keep their copied specs and mix; only the link goes, and they
  /// are staged so a peer learns of it rather than relying on its own
  /// ON DELETE SET NULL. Every removed row is tombstoned.
  Future<void> deleteCylinder(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.transaction(() async {
        await clearTripCylinderLinks(_db, _syncRepository, [id], now: now);
        final events = await (_db.select(
          _db.tripCylinderEvents,
        )..where((t) => t.tripCylinderId.equals(id))).get();
        await (_db.delete(
          _db.tripCylinderEvents,
        )..where((t) => t.tripCylinderId.equals(id))).go();
        for (final event in events) {
          await _syncRepository.logDeletion(
            entityType: 'tripCylinderEvents',
            recordId: event.id,
          );
        }
        await (_db.delete(
          _db.tripCylinders,
        )..where((t) => t.id.equals(id))).go();
        await _syncRepository.logDeletion(
          entityType: 'tripCylinders',
          recordId: id,
        );
      });
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete cylinder: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Every slot of a trip, for `TripRepository.deleteTrip`.
  Future<void> deleteByTripId(String tripId) async {
    final rows = await (_db.select(
      _db.tripCylinders,
    )..where((t) => t.tripId.equals(tripId))).get();
    for (final row in rows) {
      await deleteCylinder(row.id);
    }
    if (rows.isNotEmpty) {
      _log.info('Deleted ${rows.length} cylinders for trip: $tripId');
    }
  }

  // --------------------------------------------------------------- events

  /// The whole ledger of a trip, keyed by slot id, each list in time order.
  Future<Map<String, List<domain.TripCylinderEvent>>> getEventsForTrip(
    String tripId,
  ) async {
    final events = _db.tripCylinderEvents;
    final slots = _db.tripCylinders;
    final rows =
        await (_db.select(events).join([
                innerJoin(slots, slots.id.equalsExp(events.tripCylinderId)),
              ])
              ..where(slots.tripId.equals(tripId))
              ..orderBy([OrderingTerm.asc(events.occurredAt)]))
            .get();
    final out = <String, List<domain.TripCylinderEvent>>{};
    for (final row in rows) {
      final event = _mapEvent(row.readTable(events));
      (out[event.tripCylinderId] ??= []).add(event);
    }
    return out;
  }

  Future<List<domain.TripCylinderEvent>> getEventsForCylinder(
    String cylinderId,
  ) async {
    final rows =
        await (_db.select(_db.tripCylinderEvents)
              ..where((t) => t.tripCylinderId.equals(cylinderId))
              ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
            .get();
    return rows.map(_mapEvent).toList();
  }

  Future<domain.TripCylinderEvent> createEvent(
    domain.TripCylinderEvent event,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = event.id.isEmpty ? _uuid.v4() : event.id;
      await _db
          .into(_db.tripCylinderEvents)
          .insert(
            TripCylinderEventsCompanion.insert(
              id: id,
              tripCylinderId: event.tripCylinderId,
              kind: event.kind.name,
              occurredAt: event.occurredAt.millisecondsSinceEpoch,
              bottleLabel: Value(event.bottleLabel),
              pressure: Value(event.pressure),
              o2Percent: Value(event.o2Percent),
              hePercent: Value(event.hePercent),
              analyzedO2: Value(event.analyzedO2),
              analyzedHe: Value(event.analyzedHe),
              diveCenterId: Value(event.diveCenterId),
              cost: Value(event.cost),
              currency: Value(event.currency),
              isPackage: Value(event.isPackage),
              note: Value(event.note),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'tripCylinderEvents',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      final stamp = DateTime.fromMillisecondsSinceEpoch(now, isUtc: true);
      return event.copyWith(id: id, createdAt: stamp, updatedAt: stamp);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create event for cylinder: ${event.tripCylinderId}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> updateEvent(domain.TripCylinderEvent event) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.tripCylinderEvents,
      )..where((t) => t.id.equals(event.id))).write(
        TripCylinderEventsCompanion(
          kind: Value(event.kind.name),
          occurredAt: Value(event.occurredAt.millisecondsSinceEpoch),
          bottleLabel: Value(event.bottleLabel),
          pressure: Value(event.pressure),
          o2Percent: Value(event.o2Percent),
          hePercent: Value(event.hePercent),
          analyzedO2: Value(event.analyzedO2),
          analyzedHe: Value(event.analyzedHe),
          diveCenterId: Value(event.diveCenterId),
          cost: Value(event.cost),
          currency: Value(event.currency),
          isPackage: Value(event.isPackage),
          note: Value(event.note),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'tripCylinderEvents',
        recordId: event.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update event: ${event.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteEvent(String id) async {
    try {
      await (_db.delete(
        _db.tripCylinderEvents,
      )..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(
        entityType: 'tripCylinderEvents',
        recordId: id,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete event: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ----------------------------------------------------------- tank uses

  /// The dive tanks linked to a trip's slots, as the lean facts the state
  /// fold needs: no profile, no gear, no full dive. Keyed by slot id, each
  /// list in entry order.
  Future<Map<String, List<TripCylinderTankUse>>> getTankUsesForTrip(
    String tripId,
  ) async {
    final rows = await _db
        .customSelect(
          '''
          -- stats-scope-exempt: the board counts every dive on the trip, the
          -- ones excluded from statistics included, as the trip's dive list does
          SELECT t.id AS tank_id, t.dive_id,
                 COALESCE(d.entry_time, d.dive_date_time) AS entry_ms,
                 t.start_pressure, t.end_pressure, t.o2_percent, t.he_percent,
                 t.trip_cylinder_id
          FROM dive_tanks t
          JOIN dives d ON d.id = t.dive_id
          WHERE d.trip_id = ?1
            AND t.trip_cylinder_id IN
                (SELECT id FROM trip_cylinders WHERE trip_id = ?1)
          ORDER BY entry_ms ASC, t.tank_order ASC
          ''',
          variables: [Variable.withString(tripId)],
          readsFrom: {_db.diveTanks, _db.dives, _db.tripCylinders},
        )
        .get();
    final out = <String, List<TripCylinderTankUse>>{};
    for (final r in rows) {
      final use = TripCylinderTankUse(
        tankId: r.read<String>('tank_id'),
        diveId: r.read<String>('dive_id'),
        entryTime: DateTime.fromMillisecondsSinceEpoch(
          r.read<int>('entry_ms'),
          isUtc: true,
        ),
        startPressure: r.readNullable<double>('start_pressure'),
        endPressure: r.readNullable<double>('end_pressure'),
        gasMix: GasMix(
          o2: r.read<double>('o2_percent'),
          he: r.read<double>('he_percent'),
        ),
      );
      (out[r.read<String>('trip_cylinder_id')] ??= []).add(use);
    }
    return out;
  }

  /// Distinct dives that breathed from a slot, for the delete confirmation.
  Future<int> countLinkedDives(String cylinderId) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(DISTINCT dive_id) AS n FROM dive_tanks '
          'WHERE trip_cylinder_id = ?',
          variables: [Variable.withString(cylinderId)],
          readsFrom: {_db.diveTanks},
        )
        .getSingle();
    return row.read<int>('n');
  }

  // -------------------------------------------------------------- mappers

  domain.TripCylinder _mapCylinder(TripCylinderRow r) => domain.TripCylinder(
    id: r.id,
    tripId: r.tripId,
    equipmentId: r.equipmentId,
    label: r.label,
    volume: r.volume,
    workingPressure: r.workingPressure,
    // A material this build does not know reads as unknown, not as a guess.
    material: r.material == null
        ? null
        : TankMaterial.values.where((m) => m.name == r.material).firstOrNull,
    presetName: r.presetName,
    sortOrder: r.sortOrder,
    notes: r.notes,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt, isUtc: true),
  );

  domain.TripCylinderEvent _mapEvent(
    TripCylinderEventRow r,
  ) => domain.TripCylinderEvent(
    id: r.id,
    tripCylinderId: r.tripCylinderId,
    kind: domain.tripCylinderEventKindFromName(r.kind),
    occurredAt: DateTime.fromMillisecondsSinceEpoch(r.occurredAt, isUtc: true),
    bottleLabel: r.bottleLabel,
    pressure: r.pressure,
    o2Percent: r.o2Percent,
    hePercent: r.hePercent,
    analyzedO2: r.analyzedO2,
    analyzedHe: r.analyzedHe,
    diveCenterId: r.diveCenterId,
    cost: r.cost,
    currency: r.currency,
    isPackage: r.isPackage,
    note: r.note,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt, isUtc: true),
  );
}
