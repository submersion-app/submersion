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
/// An update named a trip cylinder event that no longer exists.
class TripCylinderEventMissing implements Exception {
  const TripCylinderEventMissing(this.id);

  final String id;

  @override
  String toString() => 'TripCylinderEventMissing($id)';
}

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
      // Tank uses carry the dive's site name.
      TableUpdateQuery.onTable(_db.diveSites),
    ]),
  );

  /// Changes to the slots or the ledger only. The ledger reads neither
  /// dives, tanks nor sites, so it need not refetch when those change.
  Stream<void> watchLedgerChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.tripCylinders),
      TableUpdateQuery.onTable(_db.tripCylinderEvents),
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
  /// Inserts and stages one slot stamped [now], in one transaction: a
  /// failed stage must not leave a row that never syncs and that a retry
  /// would double. Callers notify sync once they are done.
  Future<domain.TripCylinder> _insertCylinder(
    domain.TripCylinder cylinder,
    int now,
  ) async {
    final id = cylinder.id.isEmpty ? _uuid.v4() : cylinder.id;
    await _db.transaction(() async {
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
    });
    final stamp = DateTime.fromMillisecondsSinceEpoch(now, isUtc: true);
    return cylinder.copyWith(id: id, createdAt: stamp, updatedAt: stamp);
  }

  Future<domain.TripCylinder> createCylinder(
    domain.TripCylinder cylinder,
  ) async {
    try {
      final created = await _insertCylinder(
        cylinder,
        DateTime.now().millisecondsSinceEpoch,
      );
      SyncEventBus.notifyLocalChange();
      return created;
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
      // Write and stage in one transaction, as the creates do: a failed
      // stage must not leave a local edit that never syncs. Board order is
      // left to reorderCylinders: the editor's copy of it may be stale.
      await _db.transaction(() async {
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
            notes: Value(cylinder.notes),
            updatedAt: Value(now),
          ),
        );
        await _syncRepository.markRecordPending(
          entityType: 'tripCylinders',
          recordId: cylinder.id,
          localUpdatedAt: now,
        );
      });
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

  /// Inserts every slot in [cylinders] in one transaction: a failure part
  /// way leaves none of them, so a retry never doubles the batch. They share
  /// one creation time and one sync notice, as [createEvents] does.
  Future<List<domain.TripCylinder>> createCylinders(
    List<domain.TripCylinder> cylinders,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final created = await _db.transaction(
        () async => [for (final c in cylinders) await _insertCylinder(c, now)],
      );
      SyncEventBus.notifyLocalChange();
      return created;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create cylinders',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Inserts every event in [events] in one transaction, so one save of
  /// several fills commits once (one refresh) and a failure adds none. They
  /// share one creation time, so the ledger can order them by the board.
  Future<List<domain.TripCylinderEvent>> createEvents(
    List<domain.TripCylinderEvent> events,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final created = await _db.transaction(
        () async => [for (final e in events) await _insertEvent(e, now)],
      );
      SyncEventBus.notifyLocalChange();
      return created;
    } catch (e, stackTrace) {
      _log.error('Failed to create events', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Rewrites board order to match [orderedIds]. Only rows whose position
  /// changed are written and staged, so a no-op reorder syncs nothing.
  Future<void> reorderCylinders(List<String> orderedIds) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.transaction(() async {
        for (var i = 0; i < orderedIds.length; i++) {
          final id = orderedIds[i];
          final changed =
              await (_db.update(_db.tripCylinders)..where(
                    (t) => t.id.equals(id) & t.sortOrder.equals(i).not(),
                  ))
                  .write(
                    TripCylindersCompanion(
                      sortOrder: Value(i),
                      updatedAt: Value(now),
                    ),
                  );
          if (changed > 0) {
            await _syncRepository.markRecordPending(
              entityType: 'tripCylinders',
              recordId: id,
              localUpdatedAt: now,
            );
          }
        }
      });
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to reorder cylinders',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
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

  /// Inserts and stages one event stamped [now], in one transaction: a
  /// failed stage must not leave a row that never syncs and that a retry
  /// would double. Callers notify sync once they are done.
  Future<domain.TripCylinderEvent> _insertEvent(
    domain.TripCylinderEvent event,
    int now,
  ) async {
    final id = event.id.isEmpty ? _uuid.v4() : event.id;
    await _db.transaction(() async {
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
    });
    final stamp = DateTime.fromMillisecondsSinceEpoch(now, isUtc: true);
    return event.copyWith(id: id, createdAt: stamp, updatedAt: stamp);
  }

  Future<domain.TripCylinderEvent> createEvent(
    domain.TripCylinderEvent event,
  ) async {
    try {
      final created = await _insertEvent(
        event,
        DateTime.now().millisecondsSinceEpoch,
      );
      SyncEventBus.notifyLocalChange();
      return created;
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
      // Write and stage in one transaction, as the creates do: a failed
      // stage must not leave a local edit that never syncs.
      await _db.transaction(() async {
        final changed =
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
        // Gone (a sync deleted it, say): staging it would queue a record
        // for a row that no longer exists.
        if (changed == 0) throw TripCylinderEventMissing(event.id);
        await _syncRepository.markRecordPending(
          entityType: 'tripCylinderEvents',
          recordId: event.id,
          localUpdatedAt: now,
        );
      });
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

  /// Deletes an event and logs its tombstone. [alongside] runs first in the
  /// same transaction (the fill's passport copy), so the two commit or fail
  /// together and a failed delete leaves both records for a retry.
  Future<void> deleteEvent(
    String id, {
    Future<void> Function()? alongside,
  }) async {
    try {
      // Delete and log the tombstone together: a failed log must not drop
      // the event here while other devices keep it.
      await _db.transaction(() async {
        if (alongside != null) await alongside();
        await (_db.delete(
          _db.tripCylinderEvents,
        )..where((t) => t.id.equals(id))).go();
        await _syncRepository.logDeletion(
          entityType: 'tripCylinderEvents',
          recordId: id,
        );
      });
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
                 t.trip_cylinder_id, s.name AS site_name
          FROM dive_tanks t
          JOIN dives d ON d.id = t.dive_id
          LEFT JOIN dive_sites s ON s.id = d.site_id
          WHERE d.trip_id = ?1
            AND t.trip_cylinder_id IN
                (SELECT id FROM trip_cylinders WHERE trip_id = ?1)
          ORDER BY entry_ms ASC, t.tank_order ASC
          ''',
          variables: [Variable.withString(tripId)],
          readsFrom: {
            _db.diveTanks,
            _db.dives,
            _db.tripCylinders,
            _db.diveSites,
          },
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
        siteName: r.readNullable<String>('site_name'),
      );
      (out[r.read<String>('trip_cylinder_id')] ??= []).add(use);
    }
    return out;
  }

  /// Rounds of dives logged on the trip on [day]'s calendar date, in the
  /// wall-clock frame every dive time is stored in: the fill forecast's
  /// "dives already logged today". A shared trip carries each diver
  /// profile's own log of the same dive, so this is the most any one diver
  /// logged that day, not the row count.
  Future<int> countTripDivesOn(String tripId, DateTime day) async {
    final from = DateTime.utc(day.year, day.month, day.day);
    final to = DateTime.utc(day.year, day.month, day.day + 1);
    final row = await _db
        .customSelect(
          '''
          -- stats-scope-exempt: the forecast counts every dive on the trip,
          -- as the board does
          SELECT COALESCE(MAX(n), 0) AS n FROM (
            SELECT COUNT(*) AS n FROM dives
            WHERE trip_id = ?1
              AND COALESCE(entry_time, dive_date_time) >= ?2
              AND COALESCE(entry_time, dive_date_time) < ?3
            GROUP BY diver_id
          )
          ''',
          variables: [
            Variable.withString(tripId),
            Variable.withInt(from.millisecondsSinceEpoch),
            Variable.withInt(to.millisecondsSinceEpoch),
          ],
          readsFrom: {_db.dives},
        )
        .getSingle();
    return row.read<int>('n');
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
