import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/data/visibility/visibility_filter.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_parent_links.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/trip_cylinder_links.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/liveaboard_details_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_day_weather_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_equipment_repository.dart';
import 'package:submersion/features/trips/data/repositories/side_trip_links.dart';
import 'package:submersion/features/trips/data/repositories/trip_row_mapper.dart';
import 'package:submersion/features/trips/data/side_trip_sql.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart' as domain;
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

class TripRepository {
  TripRepository({ItineraryDayRepository? itineraryDays})
    : _itineraryDays = itineraryDays ?? ItineraryDayRepository();

  AppDatabase get _db => DatabaseService.instance.database;

  /// The trip's itinerary, which a date change and a delete also touch.
  final ItineraryDayRepository _itineraryDays;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(TripRepository);

  /// Emits whenever the `trips` table, or a profile's hidden or shared
  /// trips, change, so list providers refresh after a sync or any other
  /// write (a hide or a share changes which trips a profile sees, issues
  /// #2594, #2151).
  Stream<void> watchTripsChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.trips),
      TableUpdateQuery.onTable(_db.tripHides),
      TableUpdateQuery.onTable(_db.tripShares),
    ]),
  );

  /// Get all trips ordered by start date (most recent first)
  Future<List<domain.Trip>> getAllTrips({String? diverId}) async {
    try {
      final query = _db.select(_db.trips)
        ..orderBy([(t) => OrderingTerm.desc(t.startDate)]);

      VisibilityFilter.applyToTrips(_db, query, diverId);

      final rows = await query.get();
      return rows.map(tripFromRow).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get all trips', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get trip by ID
  Future<domain.Trip?> getTripById(String id) async {
    try {
      final query = _db.select(_db.trips)..where((t) => t.id.equals(id));

      final row = await query.getSingleOrNull();
      return row != null ? tripFromRow(row) : null;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get trip by id: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Search trips by name or location
  Future<List<domain.Trip>> searchTrips(String query, {String? diverId}) async {
    try {
      final searchTerm = '%${query.toLowerCase()}%';
      final vis = VisibilityFilter.sqlFragment(
        tableAlias: 'trips',
        diverId: diverId,
        conjunction: 'AND',
        kind: SharedItemKind.trip,
      );
      final variables = [
        Variable.withString(searchTerm),
        Variable.withString(searchTerm),
        Variable.withString(searchTerm),
        Variable.withString(searchTerm),
        ...vis.variables,
      ];

      final results = await _db.customSelect('''
        SELECT * FROM trips
        WHERE (unicode_lower(name) LIKE ?
           OR unicode_lower(location) LIKE ?
           OR unicode_lower(resort_name) LIKE ?
           OR unicode_lower(liveaboard_name) LIKE ?)
        ${vis.whereClause}
        ORDER BY start_date DESC
      ''', variables: variables).get();

      return results.map((row) => tripFromData(row.data)).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to search trips', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Create a new trip
  Future<domain.Trip> createTrip(domain.Trip trip) async {
    try {
      _log.info('Creating trip: ${trip.name}');
      final id = trip.id.isEmpty ? _uuid.v4() : trip.id;
      final now = DateTime.now();
      // The link is checked inside the insert's transaction, as updateTrip
      // checks it, so a racing save cannot make the parent a side trip in
      // between (issue #3658).
      final parentTripId = await _db.transaction(() async {
        final parentTripId = await writableParentId(
          _db,
          tripId: id,
          parentId: trip.parentTripId,
        );
        await _db
            .into(_db.trips)
            .insert(
              TripsCompanion(
                id: Value(id),
                diverId: Value(trip.diverId),
                name: Value(trip.name),
                startDate: Value(trip.startDate.millisecondsSinceEpoch),
                endDate: Value(trip.endDate.millisecondsSinceEpoch),
                location: Value(trip.location),
                resortName: Value(trip.resortName),
                liveaboardName: Value(trip.liveaboardName),
                notes: Value(trip.notes),
                tripType: Value(trip.tripType.name),
                isShared: Value(trip.isShared),
                returnFlightAt: Value(
                  trip.returnFlightAt?.millisecondsSinceEpoch,
                ),
                expectedDives: Value(trip.expectedDives),
                expectedRuntimeMinutes: Value(trip.expectedRuntimeMinutes),
                diversSharingCylinders: Value(trip.diversSharingCylinders),
                divesPerDayTarget: Value(trip.divesPerDayTarget),
                parentTripId: Value(parentTripId),
                createdAt: Value(now.millisecondsSinceEpoch),
                updatedAt: Value(now.millisecondsSinceEpoch),
              ),
            );
        return parentTripId;
      });

      await _syncRepository.markRecordPending(
        entityType: 'trips',
        recordId: id,
        localUpdatedAt: now.millisecondsSinceEpoch,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Created trip with id: $id');
      return trip.copyWith(
        id: id,
        parentTripId: parentTripId,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create trip: ${trip.name}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update an existing trip
  Future<void> updateTrip(domain.Trip trip, {String? actingDiverId}) async {
    try {
      _log.info('Updating trip: ${trip.id}');
      final now = DateTime.now().millisecondsSinceEpoch;
      // Only the owner changes sharing (issue #2594): another profile's save
      // keeps the stored flag, whatever its page state says.
      final stored = await (_db.select(
        _db.trips,
      )..where((t) => t.id.equals(trip.id))).getSingleOrNull();
      final maySetSharing =
          stored == null ||
          canDestroySharedItem(
            ownerId: stored.diverId,
            activeDiverId: actingDiverId,
          );

      await _db.transaction(() async {
        // Checked inside the write's transaction, which Drift runs one at a
        // time: two saves racing to link a pair of trips each see the
        // other's link and cannot both write one (issue #3658).
        final parentTripId = await writableParentId(
          _db,
          tripId: trip.id,
          parentId: trip.parentTripId,
        );
        final current = await (_db.select(
          _db.trips,
        )..where((t) => t.id.equals(trip.id))).getSingleOrNull();
        final parentChanged =
            current != null && current.parentTripId != parentTripId;
        await (_db.update(_db.trips)..where((t) => t.id.equals(trip.id))).write(
          TripsCompanion(
            name: Value(trip.name),
            startDate: Value(trip.startDate.millisecondsSinceEpoch),
            endDate: Value(trip.endDate.millisecondsSinceEpoch),
            location: Value(trip.location),
            resortName: Value(trip.resortName),
            liveaboardName: Value(trip.liveaboardName),
            notes: Value(trip.notes),
            tripType: Value(trip.tripType.name),
            isShared: maySetSharing
                ? Value(trip.isShared)
                : const Value.absent(),
            // Value(null) writes SQL NULL, so clearing the flight time works.
            returnFlightAt: Value(trip.returnFlightAt?.millisecondsSinceEpoch),
            expectedDives: Value(trip.expectedDives),
            expectedRuntimeMinutes: Value(trip.expectedRuntimeMinutes),
            diversSharingCylinders: Value(trip.diversSharingCylinders),
            divesPerDayTarget: Value(trip.divesPerDayTarget),
            parentTripId: Value(parentTripId),
            updatedAt: Value(now),
          ),
        );
        // A side trip moved to another larger trip, or made a trip of its
        // own, drops its dives' links to the old larger trip's cylinders
        // (issue #3658). After the write, so the rule reads the new parent.
        if (parentChanged) {
          for (final diveId in await _diveIdsOnTrip(trip.id)) {
            await clearForeignTripCylinderLinks(
              _db,
              _syncRepository,
              diveId,
              tripId: trip.id,
              now: now,
            );
          }
        }
      });
      await _syncRepository.markRecordPending(
        entityType: 'trips',
        recordId: trip.id,
        localUpdatedAt: now,
      );
      // A shortened or moved trip drops the plan-only itinerary days it no
      // longer covers (#2325). Cleanup only: the trip is saved, so a
      // failure here is logged rather than reported as a failed save.
      try {
        await _itineraryDays.deleteBarePlanDaysOutside(
          trip.id,
          trip.startDate,
          trip.endDate,
        );
      } catch (e, stackTrace) {
        _log.error(
          'Failed to drop plan-only itinerary days for trip: ${trip.id}',
          error: e,
          stackTrace: stackTrace,
        );
      }
      SyncEventBus.notifyLocalChange();
      _log.info('Updated trip: ${trip.id}');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update trip: ${trip.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// The ids of the dives whose own trip is [tripId], every profile's.
  Future<List<String>> _diveIdsOnTrip(String tripId) async {
    final rows = await _db
        .customSelect(
          // stats-scope-exempt: tank link cleanup, excluded dives included.
          'SELECT id FROM dives WHERE trip_id = ?',
          variables: [Variable.withString(tripId)],
        )
        .get();
    return [for (final r in rows) r.read<String>('id')];
  }

  /// Delete a trip and all associated child records, when [actingDiverId]
  /// may (issue #2594): its owner, anyone for an ownerless trip, and any
  /// caller that names no profile. Returns false, with nothing changed, for
  /// a trip another profile owns. A trip already gone (deleted on another
  /// device) counts as deleted and returns true.
  ///
  /// Removes liveaboard details, itinerary days and the other children,
  /// tombstones every profile's hide of the trip, and clears the trip from
  /// every profile's dives, stamped and marked pending, before deleting the
  /// trip itself.
  ///
  /// The whole cascade runs in one transaction so a failure partway through
  /// (e.g. a checklist delete throwing) rolls back every prior step instead
  /// of leaving the trip half-deleted. Drift nested transactions join the
  /// parent, so the child repositories' own `markRecordPending`/`logDeletion`
  /// writes are safe inside this wrapper. Those child repos also fire their
  /// own `SyncEventBus.notifyLocalChange()` mid-transaction; that is
  /// pre-existing, debounced-downstream behavior and is left as-is. This
  /// method's own notify is deferred until after the transaction commits so
  /// listeners never observe a rolled-back delete as "changed".
  // stats-scope-exempt: deletion cascade
  Future<bool> deleteTrip(String id, {String? actingDiverId}) async {
    try {
      final row = await (_db.select(
        _db.trips,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) return true;
      if (!canDestroySharedItem(
        ownerId: row.diverId,
        activeDiverId: actingDiverId,
      )) {
        _log.warning('Refused to delete trip $id: another profile owns it');
        return false;
      }
      _log.info('Deleting trip: $id');
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        // Delete child records with non-nullable FKs first
        await LiveaboardDetailsRepository().deleteByTripId(id);
        await _itineraryDays.deleteByTripId(id);
        await TripChecklistRepository().deleteByTripId(id);
        await TripDayWeatherRepository().deleteByTripId(id);
        // Slots, their ledger and the links on the tanks that used them.
        await TripCylinderRepository().deleteByTripId(id);
        // Packed gear (issue #2338): deleted and tombstoned before the trip.
        await TripEquipmentRepository().deleteByTripId(id);

        // Every profile's hide of the trip (issue #2594), tombstoned.
        await ProfileHidesRepository().deleteHides(SharedItemKind.trip, [id]);
        // Every share row of the trip (issue #2151), tombstoned.
        await ItemSharesRepository().deleteShares(SharedItemKind.trip, [id]);
        // A side trip's dives go back to its larger trip, and a larger
        // trip's side trips become trips of their own (issue #3658).
        await detachSideTripsForDelete(_db, _syncRepository, [id], now: now);
        // Every profile's dives lose the trip, stamped and marked pending.
        await clearDiveTripLinks(_db, _syncRepository, [id], now: now);
        // Its documents go with it, tombstoned (issue #2613).
        await DocumentRepository().deleteForOwner(DocumentOwnerKind.trip, id);

        // Delete the trip
        await (_db.delete(_db.trips)..where((t) => t.id.equals(id))).go();
        await _syncRepository.logDeletion(entityType: 'trips', recordId: id);
      });

      SyncEventBus.notifyLocalChange();
      _log.info('Deleted trip: $id');
      return true;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete trip: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get dives for a specific trip, its side trips' dives included (issue
  /// #3658).
  ///
  /// When [diverId] is non-null only dives belonging to that diver are
  /// returned. Pass null to return dives from all divers (import-time use).
  Future<List<String>> getDiveIdsForTrip(
    String tripId, {
    String? diverId,
  }) async {
    try {
      final diverClause = diverId != null ? 'AND diver_id = ?' : '';
      final variables = [
        Variable.withString(tripId),
        if (diverId != null) Variable.withString(diverId),
      ];
      final results = await _db.customSelect('''
        -- stats-scope-exempt: drives the trip's displayed dive list, which
        -- shows excluded dives like the logbook does
        SELECT id FROM dives
        WHERE ${tripDivesScopeSql('dives', '?1')}
        $diverClause
        ORDER BY dive_date_time DESC
      ''', variables: variables).get();

      return results.map((row) => row.data['id'] as String).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive ids for trip: $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get dive count for a trip, its side trips' dives included.
  ///
  /// When [diverId] is non-null only dives belonging to that diver are
  /// counted. Pass null to count dives from all divers (import-time use).
  Future<int> getDiveCountForTrip(String tripId, {String? diverId}) async {
    final diverClause = diverId != null ? 'AND diver_id = ?' : '';
    final variables = [
      Variable.withString(tripId),
      if (diverId != null) Variable.withString(diverId),
    ];
    final result = await _db.customSelect('''
      SELECT COUNT(*) as count
      FROM dives
      WHERE ${tripDivesScopeSql('dives', '?1')}
      $diverClause${DiveStatsScope.and(alias: 'dives')}
    ''', variables: variables).getSingle();

    return result.data['count'] as int? ?? 0;
  }

  /// Assign a dive to a trip
  Future<void> assignDiveToTrip(String diveId, String tripId) async {
    try {
      _log.info('Assigning dive $diveId to trip $tripId');
      // One transaction: a move that fails (an unknown trip id trips the
      // foreign key) must not leave the tank links cleared.
      await _db.transaction(() async {
        await clearForeignTripCylinderLinks(
          _db,
          _syncRepository,
          diveId,
          tripId: tripId,
          now: DateTime.now().millisecondsSinceEpoch,
        );
        await _db.customUpdate(
          'UPDATE dives SET trip_id = ? WHERE id = ?',
          variables: [Variable.withString(tripId), Variable.withString(diveId)],
          updates: {_db.dives},
        );
      });
      // The cleared tank links are staged; tell auto-sync.
      SyncEventBus.notifyLocalChange();
      _log.info('Assigned dive to trip');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to assign dive to trip',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Remove a dive from a trip
  Future<void> removeDiveFromTrip(String diveId) async {
    try {
      _log.info('Removing dive $diveId from trip');
      // One transaction, as in assignDiveToTrip: the links and the dive
      // change together or not at all.
      await _db.transaction(() async {
        await clearForeignTripCylinderLinks(
          _db,
          _syncRepository,
          diveId,
          tripId: null,
          now: DateTime.now().millisecondsSinceEpoch,
        );
        await _db.customUpdate(
          'UPDATE dives SET trip_id = NULL WHERE id = ?',
          variables: [Variable.withString(diveId)],
          updates: {_db.dives},
        );
      });
      // The cleared tank links are staged; tell auto-sync.
      SyncEventBus.notifyLocalChange();
      _log.info('Removed dive from trip');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to remove dive from trip',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Find dives within a trip's date range that are either unassigned
  /// or assigned to a different trip (excludes dives already on this trip).
  // stats-scope-exempt: trip assignment candidates, a list the diver picks from
  Future<List<DiveCandidate>> findCandidateDivesForTrip({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
    required String diverId,
  }) async {
    try {
      _log.info('Scanning for candidate dives: $startDate - $endDate');
      final startMs = startDate.millisecondsSinceEpoch;
      final endMs = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
        999,
      ).millisecondsSinceEpoch;

      final rows = await _db
          .customSelect(
            '''
        SELECT d.id as dive_id, t.id as other_trip_id, t.name as other_trip_name
        FROM dives d
        LEFT JOIN trips t ON d.trip_id = t.id AND d.trip_id != ?
        WHERE d.dive_date_time >= ? AND d.dive_date_time <= ?
          AND d.diver_id = ?
          AND (d.trip_id IS NULL OR d.trip_id != ?)
          -- A side trip's dives are already the larger trip's (#3658).
          AND (d.trip_id IS NULL OR d.trip_id NOT IN (${sideTripIdsSql('?')}))
        ORDER BY d.dive_date_time ASC
      ''',
            variables: [
              Variable.withString(tripId),
              Variable.withInt(startMs),
              Variable.withInt(endMs),
              Variable.withString(diverId),
              Variable.withString(tripId),
              Variable.withString(tripId),
            ],
          )
          .get();

      if (rows.isEmpty) return [];

      // Load full dive objects
      final diveRepository = DiveRepository();
      final diveIds = rows.map((r) => r.data['dive_id'] as String).toList();
      final dives = await diveRepository.getDivesByIds(diveIds);

      // Build a map for quick lookup
      final diveMap = {for (final d in dives) d.id: d};

      // Build candidates, preserving order from query
      final candidates = <DiveCandidate>[];
      for (final row in rows) {
        final diveId = row.data['dive_id'] as String;
        final dive = diveMap[diveId];
        if (dive == null) continue;

        candidates.add(
          DiveCandidate(
            dive: dive,
            currentTripId: row.data['other_trip_id'] as String?,
            currentTripName: row.data['other_trip_name'] as String?,
          ),
        );
      }

      _log.info('Found ${candidates.length} candidate dives');
      return candidates;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to find candidate dives',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Batch assign multiple dives to a trip in a single transaction.
  Future<void> assignDivesToTrip(List<String> diveIds, String tripId) async {
    if (diveIds.isEmpty) return;

    try {
      _log.info('Batch assigning ${diveIds.length} dives to trip $tripId');
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        for (final diveId in diveIds) {
          await clearForeignTripCylinderLinks(
            _db,
            _syncRepository,
            diveId,
            tripId: tripId,
            now: now,
          );
          await _db.customUpdate(
            'UPDATE dives SET trip_id = ?, updated_at = ? WHERE id = ?',
            variables: [
              Variable.withString(tripId),
              Variable.withInt(now),
              Variable.withString(diveId),
            ],
            updates: {_db.dives},
          );
        }
      });

      // Mark dives as pending sync
      for (final diveId in diveIds) {
        await _syncRepository.markRecordPending(
          entityType: 'dives',
          recordId: diveId,
          localUpdatedAt: now,
        );
      }
      SyncEventBus.notifyLocalChange();

      _log.info('Batch assigned ${diveIds.length} dives to trip $tripId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to batch assign dives to trip',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get trip statistics.
  ///
  /// When [diverId] is non-null the aggregate stats (dive count, bottom time,
  /// depths) are computed only from dives belonging to that diver.
  /// Pass null to aggregate dives from all divers (import-time use).
  Future<domain.TripWithStats> getTripWithStats(
    String tripId, {
    String? diverId,
  }) async {
    final trip = await getTripById(tripId);
    if (trip == null) {
      throw Exception('Trip not found');
    }

    final diverClause = diverId != null ? 'AND diver_id = ?' : '';
    final variables = [
      Variable.withString(tripId),
      if (diverId != null) Variable.withString(diverId),
    ];
    final QueryRow statsResult;
    try {
      statsResult = await _db.customSelect('''
        SELECT
          COUNT(*) as dive_count,
          COALESCE(SUM(COALESCE(runtime, bottom_time)), 0) as total_runtime,
          MAX(max_depth) as max_depth,
          AVG(max_depth) as avg_depth
        FROM dives
        WHERE ${tripDivesScopeSql('dives', '?1')}
        $diverClause${DiveStatsScope.and(alias: 'dives')}
      ''', variables: variables).getSingle();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get stats for trip: $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }

    return domain.TripWithStats(
      trip: trip,
      diveCount: statsResult.data['dive_count'] as int? ?? 0,
      totalRuntime: statsResult.data['total_runtime'] as int? ?? 0,
      maxDepth: statsResult.data['max_depth'] as double?,
      avgDepth: statsResult.data['avg_depth'] as double?,
    );
  }

  /// Find the trip whose dates cover [date]'s calendar day; when trips
  /// overlap, the one that started last.
  ///
  /// Days are compared, not instants, as in `tripForDiveDate`: a trip ends
  /// at midnight of its last day, so comparing the instant missed a dive made
  /// later that day, and a start carrying a time of day missed a dive made
  /// earlier on the first (#2618). The day is read from [date]'s own
  /// components, which are the wall clock both for the dive editor's local
  /// time and for a dive's wall-clock-as-UTC time.
  Future<domain.Trip?> findTripForDate(DateTime date, {String? diverId}) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final nextDay = DateTime(date.year, date.month, date.day + 1);
    final vis = VisibilityFilter.sqlFragment(
      tableAlias: 'trips',
      diverId: diverId,
      conjunction: 'AND',
      kind: SharedItemKind.trip,
    );
    final variables = [
      Variable.withInt(nextDay.millisecondsSinceEpoch - 1),
      Variable.withInt(dayStart.millisecondsSinceEpoch),
      ...vis.variables,
    ];

    final result = await _db.customSelect('''
      SELECT * FROM trips
      WHERE start_date <= ? AND end_date >= ?
      ${vis.whereClause}
      ORDER BY start_date DESC
      LIMIT 1
    ''', variables: variables).getSingleOrNull();

    if (result == null) return null;

    return tripFromData(result.data);
  }

  /// Get all trips with their statistics.
  ///
  /// When [diverId] is non-null:
  ///   - The trip visibility predicate restricts which trips are returned
  ///     (owned by the diver or shared).
  ///   - The dive JOIN is scoped to that diver so stats reflect only their
  ///     dives on shared trips.
  /// Pass null to return all trips with unfiltered stats.
  Future<List<domain.TripWithStats>> getAllTripsWithStats({
    String? diverId,
  }) async {
    try {
      final vis = VisibilityFilter.sqlFragment(
        tableAlias: 't',
        diverId: diverId,
        conjunction: 'WHERE',
        kind: SharedItemKind.trip,
      );

      // Build the JOIN condition: always match trip_id, and also match
      // diver_id when a specific diver is requested so that stats on shared
      // trips reflect only that diver's dives.
      // The statistics scope goes in the ON clause, not a WHERE: this is a
      // LEFT JOIN and a WHERE would turn it inner, dropping every trip that
      // has no in-scope dives instead of showing it with a zero count.
      final scope = DiveStatsScope.and(alias: 'd');
      // A trip counts its side trips' dives too (issue #3658).
      final joinClause = tripDivesJoinSql(
        tripAlias: 't',
        diveAlias: 'd',
        extraOn: diverId != null ? ' AND d.diver_id = ?$scope' : scope,
      );

      // When diverId is provided, prepend its variable before the visibility
      // filter variables so the positional binding lines up with joinClause.
      final variables = [
        if (diverId != null) Variable.withString(diverId),
        ...vis.variables,
      ];

      final rows = await _db.customSelect('''
        SELECT
          t.*,
          COUNT(DISTINCT d.id) AS dive_count,
          COALESCE(SUM(COALESCE(d.runtime, d.bottom_time)), 0) AS total_runtime,
          MAX(d.max_depth) AS max_depth,
          AVG(d.avg_depth) AS avg_depth
        FROM trips t
        $joinClause
        ${vis.whereClause}
        GROUP BY t.id
        ORDER BY t.start_date DESC
      ''', variables: variables).get();

      return rows.map((row) {
        final trip = tripFromData(row.data);
        return domain.TripWithStats(
          trip: trip,
          diveCount: row.data['dive_count'] as int,
          totalRuntime: row.data['total_runtime'] as int,
          maxDepth: row.data['max_depth'] as double?,
          avgDepth: row.data['avg_depth'] as double?,
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get all trips with stats',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
