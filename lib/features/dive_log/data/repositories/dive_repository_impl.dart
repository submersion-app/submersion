import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/dive_search.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/performance/perf_timer.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_times_sql.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/data_source_strand.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample_point.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_times.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_sites/data/mappers/dive_site_row_mapper.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/services/profile_event_mapper.dart';
import 'package:submersion/features/dive_log/domain/services/profile_series_merge.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart'
    as domain;
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    as domain;
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart'
    as domain;
import 'package:submersion/features/dive_log/data/repositories/dive_custom_field_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart' as domain;
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    as domain;
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';

/// A dive that a conditions fetch can still do something for: its site carries
/// coordinates and at least one weather column is empty.
///
/// [dateTime] is the dive's wall clock (entry time when recorded, otherwise the
/// dive date), used to pick the hour to sample from the archive response.
typedef ConditionsCandidate = ({
  String id,
  DateTime dateTime,
  double latitude,
  double longitude,
});

class DiveRepository {
  /// The media dependencies drive the dive-deletion cascade
  /// (orphan-prevention spec 4.2); injectable for tests, self-constructed
  /// otherwise so every existing zero-arg construction site cascades too.
  ///
  /// A factory rather than a generative constructor so the default
  /// [MediaRepository] is built ONCE and shared with the coordinator: an
  /// initializer list cannot bind a local, so the obvious
  /// `mediaRepository ?? MediaRepository()` written twice would hand the
  /// cascade a different instance than the one this repository partitions
  /// with.
  factory DiveRepository({
    MediaRepository? mediaRepository,
    MediaDeletionCoordinator? mediaDeletionCoordinator,
  }) {
    final media = mediaRepository ?? MediaRepository();
    return DiveRepository._(
      media,
      mediaDeletionCoordinator ??
          MediaDeletionCoordinator(
            mediaRepository: media,
            queue: () => MediaTransferQueueRepository(),
            // No worker kick from the data layer (provider cycles):
            // queued intents drain on the next connectivity event, app
            // start, or any other kick; the Verify Library sweep is the
            // backstop.
          ),
    );
  }

  DiveRepository._(this._mediaRepository, this._mediaDeletionCoordinator);

  final MediaRepository _mediaRepository;
  final MediaDeletionCoordinator _mediaDeletionCoordinator;
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final ProfileSeriesRepository _profileSeries = ProfileSeriesRepository();
  final TankPressureSeriesRepository _tankSeries =
      TankPressureSeriesRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(DiveRepository);
  final TagRepository _tagRepository = TagRepository();
  final BuddyRepository _buddyRepository = BuddyRepository();
  late final DiveCustomFieldRepository _customFieldRepository =
      DiveCustomFieldRepository(_db);

  // ============================================================================
  // CRUD Operations
  // ============================================================================

  /// Trailing-debounce window applied to the table-change tick streams
  /// ([watchDivesChanges] and [watchDiveDetailChanges]).
  ///
  /// A sync applies remote changes as many per-changeset transactions, each
  /// committing separately and firing its own Drift table-update tick (see
  /// `ChangesetReader.pull`). Un-coalesced, every tick re-invalidates every
  /// provider listening for a change -- the list, stats, dashboard, sites,
  /// trips, buddies, and (most expensively) the per-dive detail providers that
  /// re-run the Buhlmann analysis in [profileAnalysisProvider]. That is 20-30s
  /// of UI stutter and, while `dive_profile_series` rows are mid-rewrite,
  /// transiently blanks the deco/tissue/O2 cards. Debouncing collapses a write burst into a
  /// single tick that fires only once writes go quiet, so listeners refresh once
  /// on the SETTLED DB state instead of once per intermediate commit.
  static const changeTickDebounce = Duration(milliseconds: 300);

  /// Emits whenever the `dives` table changes so the list, stats, dashboard and
  /// other cross-feature providers can refresh after a sync or any other write.
  /// [changeTickDebounce]-debounced so a multi-changeset sync coalesces into a
  /// single refresh instead of re-querying on every intermediate commit.
  Stream<void> watchDivesChanges() => _db
      .tableUpdates(TableUpdateQuery.onTable(_db.dives))
      .debounce(changeTickDebounce);

  /// Aggregate change-tick for the dive DETAIL page: fires when ANY table that
  /// feeds a dive's detail view is written -- including a sync applying remote
  /// changes directly to the DB (which bypasses the notifier paths that
  /// invalidate per-dive providers on local edits). Every per-dive detail
  /// provider subscribes to this (via [diveRepositoryProvider], the shared
  /// cross-feature tick source) and self-invalidates, so the whole detail page
  /// refreshes after a sync the same way the dive list already does.
  ///
  /// Ticks are [changeTickDebounce]-debounced so a multi-changeset sync
  /// refreshes the detail page once on the settled state instead of flickering
  /// and re-running the Buhlmann analysis on every intermediate commit.
  ///
  /// Broader than [watchDivesChanges] because a single `Dive` entity hydrates
  /// tanks, tank pressures, profile, and equipment (see [_mapRowToDive]) and the
  /// detail page also renders gas switches, data sources, buddies, marine-life
  /// sightings, media, and tide records. Watches BOTH the link tables and the
  /// base-entity tables they join against (dive_tags + tags, dive_buddies +
  /// buddies, sightings + species, dive_equipment + equipment, dive_data_sources
  /// + dive_computers, plus dive_sites/dive_centers/trips/courses) so a synced
  /// edit to a tag/buddy/species/equipment/site/center/trip/computer NAME also
  /// refreshes the rendered detail, not just changes to the link rows.
  ///
  /// Also watches the two post-dive safety-review tables (dive_safety_reviews +
  /// dive_safety_findings). They carry no HLC of their own, so a sync imports
  /// them with a raw insertOnConflictUpdate straight into the tables; the one-
  /// shot safetyReviewProvider self-invalidates on this stream so a freshly
  /// synced (or batch-analyzed) review becomes visible without an app restart.
  Stream<void> watchDiveDetailChanges() => _db
      .tableUpdates(
        TableUpdateQuery.allOf([
          TableUpdateQuery.onTable(_db.dives),
          TableUpdateQuery.onTable(_db.diveProfileSeries),
          TableUpdateQuery.onTable(_db.diveTanks),
          TableUpdateQuery.onTable(_db.tankPressureSeries),
          TableUpdateQuery.onTable(_db.diveEquipment),
          TableUpdateQuery.onTable(_db.equipment),
          TableUpdateQuery.onTable(_db.gasSwitches),
          TableUpdateQuery.onTable(_db.diveDataSources),
          TableUpdateQuery.onTable(_db.diveComputers),
          TableUpdateQuery.onTable(_db.diveTags),
          TableUpdateQuery.onTable(_db.tags),
          TableUpdateQuery.onTable(_db.diveSites),
          TableUpdateQuery.onTable(_db.diveCenters),
          TableUpdateQuery.onTable(_db.trips),
          TableUpdateQuery.onTable(_db.courses),
          TableUpdateQuery.onTable(_db.diveBuddies),
          TableUpdateQuery.onTable(_db.buddies),
          TableUpdateQuery.onTable(_db.sightings),
          TableUpdateQuery.onTable(_db.species),
          TableUpdateQuery.onTable(_db.media),
          TableUpdateQuery.onTable(_db.tideRecords),
          TableUpdateQuery.onTable(_db.diveSafetyReviews),
          TableUpdateQuery.onTable(_db.diveSafetyFindings),
        ]),
      )
      .debounce(changeTickDebounce);

  /// Change tick for the Buhlmann analysis chain and its input providers:
  /// exactly the tables the pipeline reads, nothing else.
  ///
  /// The analysis providers used to subscribe to [watchDiveDetailChanges],
  /// which includes `media`. Viewing a photo writes media rows (orphan
  /// reconciliation, enrichment backfill), so every cached analysis in the
  /// app was discarded and recomputed on the UI isolate -- the recursive
  /// residual-CNS/tissue lookback across a whole trip included. That
  /// recompute wave is the "20-30s of UI stutter" [changeTickDebounce]
  /// documents, and it fired for writes the analysis never reads.
  ///
  /// Table set = the reads of [getDiveForAnalysis] (dives,
  /// dive_profile_series, dive_tanks, plus dive_data_sources/dive_computers
  /// for primary-source resolution in [getMergedProfile]), the pipeline's
  /// direct queries (gas_switches, tank_pressure_series), and
  /// dive_profile_events, which the detail tick never covered at all,
  /// leaving `diveComputerEventsProvider` blind to writes of its own table.
  ///
  /// `dives` also covers FK cascades: SQLite performs a cascade delete of
  /// child rows without Drift seeing a write on the child tables, so the
  /// parent tick is what keeps child readers from going stale.
  Stream<void> watchAnalysisInputChanges() => _db
      .tableUpdates(
        TableUpdateQuery.allOf([
          TableUpdateQuery.onTable(_db.dives),
          TableUpdateQuery.onTable(_db.diveProfileSeries),
          TableUpdateQuery.onTable(_db.diveTanks),
          TableUpdateQuery.onTable(_db.tankPressureSeries),
          TableUpdateQuery.onTable(_db.gasSwitches),
          TableUpdateQuery.onTable(_db.diveDataSources),
          TableUpdateQuery.onTable(_db.diveComputers),
          TableUpdateQuery.onTable(_db.diveProfileEvents),
        ]),
      )
      .debounce(changeTickDebounce);

  /// Get all dives, ordered by date (newest first)
  /// This method is optimized to avoid N+1 queries by batch loading related data
  /// Optionally filter by [diverId] for multi-diver support
  Future<List<domain.Dive>> getAllDives({String? diverId}) async {
    try {
      return await PerfTimer.measure('getAllDives', () async {
        final query = _db.select(_db.dives)
          ..orderBy([
            // Order by entry time (preferred), falling back to dive date time
            (t) => OrderingTerm.desc(coalesce([t.entryTime, t.diveDateTime])),
            // Use dive number as secondary sort for dives with same timestamp
            (t) => OrderingTerm.desc(t.diveNumber),
          ]);

        if (diverId != null) {
          query.where((t) => t.diverId.equals(diverId));
        }

        final rows = await query.get();
        if (rows.isEmpty) return [];

        // Batch load all related data to avoid N+1 queries
        final diveIds = rows.map((r) => r.id).toList();

        // Load all tanks for these dives in one query
        final allTanks =
            await (_db.select(_db.diveTanks)
                  ..where((t) => t.diveId.isIn(diveIds))
                  ..orderBy([(t) => OrderingTerm.asc(t.tankOrder)]))
                .get();
        final tanksByDive = <String, List<DiveTank>>{};
        for (final tank in allTanks) {
          tanksByDive.putIfAbsent(tank.diveId, () => []).add(tank);
        }

        // Load all sites for these dives in one query
        final siteIds = rows
            .where((r) => r.siteId != null)
            .map((r) => r.siteId!)
            .toSet()
            .toList();
        final allSites = siteIds.isNotEmpty
            ? await (_db.select(
                _db.diveSites,
              )..where((t) => t.id.isIn(siteIds))).get()
            : <DiveSite>[];
        final sitesById = {for (final s in allSites) s.id: s};

        // Load all dive centers for these dives in one query
        final centerIds = rows
            .where((r) => r.diveCenterId != null)
            .map((r) => r.diveCenterId!)
            .toSet()
            .toList();
        final allCenters = centerIds.isNotEmpty
            ? await (_db.select(
                _db.diveCenters,
              )..where((t) => t.id.isIn(centerIds))).get()
            : <DiveCenter>[];
        final centersById = {for (final c in allCenters) c.id: c};

        // Load all trips for these dives in one query
        final tripIds = rows
            .where((r) => r.tripId != null)
            .map((r) => r.tripId!)
            .toSet()
            .toList();
        final allTrips = tripIds.isNotEmpty
            ? await (_db.select(
                _db.trips,
              )..where((t) => t.id.isIn(tripIds))).get()
            : <Trip>[];
        final tripsById = {for (final t in allTrips) t.id: t};

        // Load all equipment for these dives in one query
        final allDiveEquipment = await (_db.select(_db.diveEquipment).join([
          innerJoin(
            _db.equipment,
            _db.equipment.id.equalsExp(_db.diveEquipment.equipmentId),
          ),
        ])..where(_db.diveEquipment.diveId.isIn(diveIds))).get();
        final equipmentByDive = <String, List<EquipmentItem>>{};
        for (final joinRow in allDiveEquipment) {
          final diveId = joinRow.readTable(_db.diveEquipment).diveId;
          final e = joinRow.readTable(_db.equipment);
          equipmentByDive
              .putIfAbsent(diveId, () => [])
              .add(
                EquipmentItem(
                  id: e.id,
                  name: e.name,
                  type: EquipmentType.values.firstWhere(
                    (t) => t.name == e.type,
                    orElse: () => EquipmentType.other,
                  ),
                  brand: e.brand,
                  model: e.model,
                  serialNumber: e.serialNumber,
                  status: EquipmentStatus.values.firstWhere(
                    (s) => s.name == e.status,
                    orElse: () => EquipmentStatus.active,
                  ),
                  purchaseDate: e.purchaseDate != null
                      ? DateTime.fromMillisecondsSinceEpoch(e.purchaseDate!)
                      : null,
                  purchasePrice: e.purchasePrice,
                  purchaseCurrency: e.purchaseCurrency,
                  lastServiceDate: e.lastServiceDate != null
                      ? DateTime.fromMillisecondsSinceEpoch(e.lastServiceDate!)
                      : null,
                  serviceIntervalDays: e.serviceIntervalDays,
                  notes: e.notes,
                  isActive: e.isActive,
                ),
              );
        }
        final equipmentAttrs = await _equipmentAttributesFor(
          equipmentByDive.values.expand((list) => list).map((e) => e.id),
        );
        for (final entry in equipmentByDive.entries.toList()) {
          equipmentByDive[entry.key] = entry.value
              .map(
                (i) => i.copyWith(attributes: equipmentAttrs[i.id] ?? const []),
              )
              .toList();
        }

        // Note: Profile data is NOT loaded for list views to improve performance
        // Profile data should only be loaded for individual dive detail views

        // Load all tags for these dives in one query
        final tagsByDive = await _tagRepository.getTagsForDives(diveIds);
        final diveTypesByDive = await _diveTypesForDives(diveIds);

        // Load all custom fields for these dives in one query
        final customFieldsByDive = await _customFieldRepository
            .getFieldsForDiveIds(diveIds);

        // Load all buddies (junction) for these dives in one query so the
        // table view's Buddy / Dive Master columns render recorded people
        // (issue #626). Scalar buddy/diveMaster remain the fallback.
        final buddiesByDive = await _buddyRepository.getBuddiesForDives(
          diveIds,
        );

        return rows
            .map(
              (row) => _mapRowToDiveWithPreloadedData(
                row,
                tanks: tanksByDive[row.id] ?? [],
                equipment: equipmentByDive[row.id] ?? [],
                site: row.siteId != null ? sitesById[row.siteId] : null,
                center: row.diveCenterId != null
                    ? centersById[row.diveCenterId]
                    : null,
                trip: row.tripId != null ? tripsById[row.tripId] : null,
                tags: tagsByDive[row.id] ?? [],
                diveTypeIds: diveTypesByDive[row.id],
                customFields: customFieldsByDive[row.id] ?? [],
                buddies: buddiesByDive[row.id] ?? const [],
              ),
            )
            .toList();
      });
    } catch (e, stackTrace) {
      _log.error('Failed to get all dives', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get a single dive by ID
  Future<domain.Dive?> getDiveById(String id) async {
    try {
      return await PerfTimer.measure('getDiveById', () async {
        final query = _db.select(_db.dives)..where((t) => t.id.equals(id));

        final row = await query.getSingleOrNull();
        if (row == null) return null;

        return _mapRowToDive(row);
      });
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive by id: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Sets (or clears, when [siteId] is null) only the site association of a
  /// dive. Single-column update — does not rewrite the whole row.
  Future<void> setSite(String diveId, String? siteId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        DivesCompanion(siteId: Value(siteId), updatedAt: Value(now)),
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set site on dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Records (or clears, when [dismissed] is false) the diver's dismissal of
  /// the site suggestion for this dive. Single-column update; the dive row
  /// carries its own HLC, so marking it pending is what syncs the flag.
  Future<void> setSiteSuggestionDismissed(String diveId, bool dismissed) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        DivesCompanion(
          siteSuggestionDismissedAt: Value(dismissed ? now : null),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set site suggestion dismissal on dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Dives lacking an entry GPS position, as (id, start, end) timestamps for
  /// GPS-track matching. Times are wall-clock-as-UTC epoch milliseconds.
  Future<List<({String id, int startMs, int? endMs})>> getDivesMissingEntryGps({
    List<String>? limitToIds,
  }) async {
    // An explicit empty id set means "match nothing" — skip the query.
    if (limitToIds != null && limitToIds.isEmpty) return [];
    try {
      final query = _db.select(_db.dives)
        ..where((t) {
          var cond = t.entryLatitude.isNull() & t.entryLongitude.isNull();
          if (limitToIds != null) cond = cond & t.id.isIn(limitToIds);
          return cond;
        });
      final rows = await query.get();
      return [
        for (final r in rows)
          (
            id: r.id,
            startMs: r.entryTime ?? r.diveDateTime,
            endMs:
                r.exitTime ??
                (r.runtime != null
                    ? (r.entryTime ?? r.diveDateTime) + r.runtime! * 1000
                    : null),
          ),
      ];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dives missing entry GPS',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Stamps GPS coordinates onto a dive (GPS-track matching). Fills only
  /// columns that are currently NULL: a dive selected for its missing entry
  /// GPS may still carry a computer-provided exit fix, which must never be
  /// overwritten. No-ops entirely when nothing is fillable.
  Future<void> setDiveGps(
    String diveId, {
    double? entryLatitude,
    double? entryLongitude,
    double? exitLatitude,
    double? exitLongitude,
  }) async {
    try {
      final row = await (_db.select(
        _db.dives,
      )..where((t) => t.id.equals(diveId))).getSingleOrNull();
      if (row == null) return;

      Value<double> fill(double? current, double? incoming) =>
          current == null && incoming != null
          ? Value(incoming)
          : const Value.absent();

      final entryLat = fill(row.entryLatitude, entryLatitude);
      final entryLon = fill(row.entryLongitude, entryLongitude);
      final exitLat = fill(row.exitLatitude, exitLatitude);
      final exitLon = fill(row.exitLongitude, exitLongitude);
      if (!entryLat.present &&
          !entryLon.present &&
          !exitLat.present &&
          !exitLon.present) {
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        DivesCompanion(
          entryLatitude: entryLat,
          entryLongitude: entryLon,
          exitLatitude: exitLat,
          exitLongitude: exitLon,
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set GPS on dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// The weather columns a conditions fetch is allowed to fill.
  ///
  /// `weatherDescription` is deliberately absent: the provider returns no
  /// prose, and the column holds the diver's own words when it holds anything.
  static Expression<bool> _hasConditionsGap(Dives t) =>
      t.windSpeed.isNull() |
      t.windDirection.isNull() |
      t.cloudCover.isNull() |
      t.precipitation.isNull() |
      t.humidity.isNull() |
      t.weatherCode.isNull() |
      t.airTemp.isNull() |
      t.surfacePressure.isNull();

  /// Restricts a conditions query to dives that can still be filled: the dive
  /// has a site with coordinates and at least one empty weather column.
  ///
  /// Shared by the candidate list and its count so the two can never disagree
  /// about what "needs conditions" means.
  Expression<bool> _needsConditions($DiveSitesTable sites, {String? diverId}) {
    var condition =
        sites.latitude.isNotNull() &
        sites.longitude.isNotNull() &
        _hasConditionsGap(_db.dives);
    if (diverId != null) {
      condition = condition & _db.dives.diverId.equals(diverId);
    }
    return condition;
  }

  /// How many dives a conditions fetch could still fill something in for.
  ///
  /// A COUNT rather than `getDivesNeedingConditions().length`: the confirm
  /// dialog only needs the number, and a large logbook should not be
  /// materialised to produce it.
  Future<int> countDivesNeedingConditions({String? diverId}) async {
    try {
      final sites = _db.diveSites;
      final countExpr = _db.dives.id.count();
      final query = _db.selectOnly(_db.dives)
        ..addColumns([countExpr])
        ..where(_needsConditions(sites, diverId: diverId));
      query.join([innerJoin(sites, sites.id.equalsExp(_db.dives.siteId))]);

      final row = await query.getSingle();
      final int total = row.read(countExpr) ?? 0;
      return total;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to count dives needing conditions',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Dives a conditions fetch can still fill something in for: the dive has a
  /// site with coordinates and at least one empty weather column.
  ///
  /// Projects only the id, sample time and coordinates rather than selecting
  /// whole `dives` and `dive_sites` rows, so scanning a large logbook neither
  /// transfers nor deserialises columns nobody reads.
  Future<List<ConditionsCandidate>> getDivesNeedingConditions({
    String? diverId,
  }) async {
    try {
      final sites = _db.diveSites;
      final query = _db.selectOnly(_db.dives)
        ..addColumns([
          _db.dives.id,
          _db.dives.entryTime,
          _db.dives.diveDateTime,
          sites.latitude,
          sites.longitude,
        ])
        ..where(_needsConditions(sites, diverId: diverId))
        ..orderBy([OrderingTerm.desc(_db.dives.diveDateTime)]);
      query.join([innerJoin(sites, sites.id.equalsExp(_db.dives.siteId))]);

      final rows = await query.get();
      final candidates = <ConditionsCandidate>[];
      for (final row in rows) {
        final id = row.read(_db.dives.id);
        final diveDateTime = row.read(_db.dives.diveDateTime);
        final latitude = row.read(sites.latitude);
        final longitude = row.read(sites.longitude);
        if (id == null ||
            diveDateTime == null ||
            latitude == null ||
            longitude == null) {
          continue;
        }
        candidates.add((
          id: id,
          dateTime: DateTime.fromMillisecondsSinceEpoch(
            row.read(_db.dives.entryTime) ?? diveDateTime,
            isUtc: true,
          ),
          latitude: latitude,
          longitude: longitude,
        ));
      }
      return candidates;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dives needing conditions',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Stamps fetched conditions onto a dive, filling only columns that are
  /// currently NULL. Anything the diver already recorded survives untouched:
  /// an absent [Value] is left out of the UPDATE entirely rather than rewritten.
  ///
  /// The read and the write run in one transaction. Deciding what to fill needs
  /// the current row, so without it another write landing in the await gap
  /// could fill a column between the two and have this update overwrite it.
  ///
  /// The provenance stamp is only applied when the dive carries no
  /// [WeatherSource] yet, so hand-entered weather is never relabelled as
  /// provider data. Returns whether anything was written.
  Future<bool> fillDiveConditions(
    String diveId, {
    double? windSpeed,
    CurrentDirection? windDirection,
    CloudCover? cloudCover,
    Precipitation? precipitation,
    double? humidity,
    int? weatherCode,
    double? airTemp,
    double? surfacePressure,
    required WeatherSource source,
    required DateTime fetchedAt,
  }) async {
    try {
      final wrote = await _db.transaction(() async {
        final row = await (_db.select(
          _db.dives,
        )..where((t) => t.id.equals(diveId))).getSingleOrNull();
        if (row == null) return false;

        Value<T> fill<T extends Object>(T? current, T? incoming) =>
            current == null && incoming != null
            ? Value(incoming)
            : const Value.absent();

        final wind = fill(row.windSpeed, windSpeed);
        final windDir = fill(row.windDirection, windDirection?.name);
        final cloud = fill(row.cloudCover, cloudCover?.name);
        final precip = fill(row.precipitation, precipitation?.name);
        final hum = fill(row.humidity, humidity);
        final code = fill(row.weatherCode, weatherCode);
        final air = fill(row.airTemp, airTemp);
        final pressure = fill(row.surfacePressure, surfacePressure);

        final filledAny = [
          wind,
          windDir,
          cloud,
          precip,
          hum,
          code,
          air,
          pressure,
        ].any((value) => value.present);
        if (!filledAny) return false;

        final stampProvenance = row.weatherSource == null;
        final now = DateTime.now().millisecondsSinceEpoch;
        await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
          DivesCompanion(
            windSpeed: wind,
            windDirection: windDir,
            cloudCover: cloud,
            precipitation: precip,
            humidity: hum,
            weatherCode: code,
            airTemp: air,
            surfacePressure: pressure,
            weatherSource: stampProvenance
                ? Value(source.name)
                : const Value.absent(),
            weatherFetchedAt: stampProvenance
                ? Value(fetchedAt.millisecondsSinceEpoch)
                : const Value.absent(),
            updatedAt: Value(now),
          ),
        );
        // Inside the transaction so the row and its pending marker either both
        // land or neither does.
        await _syncRepository.markRecordPending(
          entityType: 'dives',
          recordId: diveId,
          localUpdatedAt: now,
        );
        return true;
      });

      // In-memory notification: only meaningful once the write has committed.
      if (wrote) SyncEventBus.notifyLocalChange();
      return wrote;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to fill conditions on dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Dives that could be given a site from a GPS point (dive-computer entry
  /// or exit fix, or a GPS-tagged photo) and still need one: no site, or a
  /// site without coordinates. Dives whose suggestion was dismissed are
  /// excluded. When [limitToIds] is provided, restricts to that id set.
  Future<List<domain.Dive>> getDivesNeedingSiteMatch({
    String? diverId,
    List<String>? limitToIds,
  }) async {
    // An explicit empty id set means "match nothing"; skip the query.
    if (limitToIds != null && limitToIds.isEmpty) return [];
    try {
      final query = _db.select(_db.dives)
        ..where((t) {
          final hasDiveGps =
              (t.entryLatitude.isNotNull() & t.entryLongitude.isNotNull()) |
              (t.exitLatitude.isNotNull() & t.exitLongitude.isNotNull());
          // Mirrors MediaRepository.getBestPhotoGpsForDives exactly, taken_at
          // included: that query picks the photo nearest the dive's entry
          // time, so a row without one yields no point. Counting it here
          // would inflate the post-import offer and then hand the review
          // page a dive it cannot place.
          final hasPhotoGps = existsQuery(
            _db.select(_db.media)..where(
              (m) =>
                  m.diveId.equalsExp(t.id) &
                  m.latitude.isNotNull() &
                  m.longitude.isNotNull() &
                  m.takenAt.isNotNull() &
                  (m.latitude.equals(0) & m.longitude.equals(0)).not(),
            ),
          );
          final siteLacksCoordinates = existsQuery(
            _db.select(_db.diveSites)..where(
              (s) =>
                  s.id.equalsExp(t.siteId) &
                  (s.latitude.isNull() | s.longitude.isNull()),
            ),
          );
          var cond =
              (t.siteId.isNull() | siteLacksCoordinates) &
              (hasDiveGps | hasPhotoGps) &
              t.siteSuggestionDismissedAt.isNull();
          if (diverId != null) cond = cond & t.diverId.equals(diverId);
          if (limitToIds != null) cond = cond & t.id.isIn(limitToIds);
          return cond;
        })
        ..orderBy([(t) => OrderingTerm.desc(t.diveDateTime)]);

      final rows = await query.get();
      if (rows.isEmpty) return [];
      return await Future.wait(rows.map(_mapRowToDive));
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dives needing site match',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get profile data for a single dive (for lazy loading in list views).
  ///
  /// Reads the dive's primary series only, interleaved by timestamp; a dive
  /// with no series returns an empty list.
  Future<List<domain.DiveProfilePoint>> getDiveProfile(String diveId) async {
    return await PerfTimer.measure('getDiveProfile', () async {
      try {
        // primaryOnly in SQL, not a filter here: the rows this drops are
        // packed blobs, and an edited two-computer dive carries three
        // demoted ones that were being inflated and decoded only to be
        // thrown away on the next line. This runs on the dive-detail tick
        // and on the dashboard's first frame.
        final List<ProfileSeries> series = await _profileSeries
            .getSeriesForDive(diveId, primaryOnly: true);
        return mergeSeriesPoints(series);
      } catch (e, stackTrace) {
        _log.error(
          'Failed to get profile for dive: $diveId',
          error: e,
          stackTrace: stackTrace,
        );
        return [];
      }
    });
  }

  /// Save an edited profile for a dive.
  ///
  /// Demotes all existing profiles to non-primary, then inserts
  /// the edited points as the new primary profile with null computerId.
  Future<void> saveEditedProfile(
    String diveId,
    List<domain.DiveProfilePoint> editedPoints,
  ) async {
    try {
      _log.info('Saving edited profile for dive: $diveId');
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        // The edit belongs to whichever source is primary right now: it is a
        // correction of that source's samples, not a new source. Read the id
        // before the demote so setPrimaryDataSource can later promote the
        // edit by identity (issue #1149).
        final primarySource =
            await (_db.select(_db.diveDataSources)
                  ..where(
                    (t) => t.diveId.equals(diveId) & t.isPrimary.equals(true),
                  )
                  ..limit(1))
                .getSingleOrNull();

        // Demote every series, then the edit becomes the one primary series
        // of the dive: no computer (a manual correction), owned by the source
        // that was primary at the time (issue #1149).
        await _profileSeries.demoteAll(diveId, now: now);
        if (editedPoints.isNotEmpty) {
          await _profileSeries.insertSeries(
            diveId: diveId,
            sourceId: primarySource?.id,
            isPrimary: true,
            samples: [
              for (final point in editedPoints) profileSampleFromPoint(point),
            ],
            now: now,
          );
        }

        // Recalculate dive stats from edited profile
        if (editedPoints.isNotEmpty) {
          double maxDepth = 0;
          double depthSum = 0;
          for (final point in editedPoints) {
            if (point.depth > maxDepth) maxDepth = point.depth;
            depthSum += point.depth;
          }
          final avgDepth = depthSum / editedPoints.length;

          await (_db.update(
            _db.dives,
          )..where((t) => t.id.equals(diveId))).write(
            DivesCompanion(
              maxDepth: Value(maxDepth),
              avgDepth: Value(avgDepth),
              updatedAt: Value(now),
            ),
          );
        }
      });

      // Profile changed: drop the stored safety review so it recomputes.
      await SafetyFindingsRepository.clearReviewForDive(
        _db,
        _syncRepository,
        diveId,
      );

      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Saved edited profile for dive: $diveId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save edited profile for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Collapses [rows] so at most one dive_data_sources row survives per
  /// strand, keeping the first row encountered -- since every caller queries
  /// in `desc(isPrimary), asc(createdAt)` order, that's the primary if one
  /// exists, else the earliest-created.
  ///
  /// A row's strand is its computerId when it has one, else its
  /// mergeSourceSlot when a sequential Combine carried it here, else nothing
  /// at all: a manual entry or an edited profile has neither, so there is
  /// nothing for it to collide on and it always survives.
  ///
  /// A sequential merge (DiveMergeService.apply, step 10) carries over every
  /// original dive's data source row as provenance, so a merged dive holds
  /// one row per combined segment. When both originals were logged by the
  /// same physical computer those rows share a computerId; without this,
  /// getProfilesByDataSource's computerId -> sourceId lookup collides and
  /// silently misroutes every profile point to whichever row is iterated
  /// last, and getDataSources shows a second, empty, selectable chip for the
  /// row that lost the collision.
  ///
  /// Segments imported from a file or a cloud service carry no computerId at
  /// all, so before v184 nothing collapsed them: the merged dive reported two
  /// sources, and the detail chart's multi-source branch drew only the active
  /// half of the dive (issue #1451). mergeSourceSlot closes that gap. It is
  /// the row's position among its own segment's sources, so two segments each
  /// contributing one source share slot 0 and collapse, while a dive that was
  /// consolidated before it was combined keeps one surviving row per computer.
  ///
  /// Canonicalizing on READ is deliberate, not a stopgap for a bad write
  /// (#1045): the row that loses here still owns the only copy of its half's
  /// rawData/rawFingerprint/sourceUuid, which reparse and the import
  /// duplicate checker (getSourceKeysByDiveId) both read directly. It must
  /// stay in the table -- only the display collapses it.
  List<DiveDataSourcesData> _canonicalDataSourceRows(
    List<DiveDataSourcesData> rows,
  ) {
    final seenStrands = <String>{};
    final result = <DiveDataSourcesData>[];
    for (final row in rows) {
      final strand = dataSourceStrandKey(
        rowId: row.id,
        computerId: row.computerId,
        mergeSourceSlot: row.mergeSourceSlot,
      );
      if (seenStrands.add(strand)) result.add(row);
    }
    return result;
  }

  /// Get profile samples grouped by owning data source.
  ///
  /// Keys are dive_data_sources ids, primary source first. Rows with a null
  /// computerId belong to the primary source (schema convention). Rows whose
  /// computerId matches no source also fall back to the primary source so no
  /// data is ever dropped or bucketed under an invented key. When an edited
  /// profile exists, the primary source carries only the edited rows
  /// (isEdited: true).
  ///
  /// A dive with no dive_data_sources row and no primary series returns an
  /// empty map; one with sources but no series returns one entry per source,
  /// each with an empty points list.
  Future<Map<String, domain.SourceProfile>> getProfilesByDataSource(
    String diveId,
  ) async {
    try {
      final series = await _profileSeries.getSeriesForDive(diveId);
      final sourceRows = _canonicalDataSourceRows(
        await (_db.select(_db.diveDataSources)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([
                (t) => OrderingTerm.desc(t.isPrimary),
                (t) => OrderingTerm.asc(t.createdAt),
              ]))
            .get(),
      );
      if (sourceRows.isEmpty) {
        // Dives with series but no dive_data_sources row (older imports
        // predate that table): synthesize the primary source.
        final primary = [
          for (final s in series)
            if (s.isPrimary) s,
        ];
        if (primary.isEmpty) return {};
        final syntheticSourceId = legacyDataSourceId(diveId);
        return {
          syntheticSourceId: domain.SourceProfile(
            sourceId: syntheticSourceId,
            computerId: primary.first.computerId,
            isEdited: series.any((s) => !s.isPrimary),
            points: mergeSeriesPoints(primary),
          ),
        };
      }

      final primary = sourceRows.first;
      final sourceIdByComputer = <String, String>{
        for (final s in sourceRows)
          if (s.computerId != null) s.computerId!: s.id,
      };
      final sourceIds = {for (final s in sourceRows) s.id};
      // The FK is authoritative; a series without one follows the pre-v154
      // computer convention (issue #1149).
      bool isPrimaryFamily(ProfileSeries s) => sourceIds.contains(s.sourceId)
          ? s.sourceId == primary.id
          : s.computerId == null || s.computerId == primary.computerId;
      final family = series.where(isPrimaryFamily);
      final hasEditedProfile =
          family.any((s) => s.isPrimary) && family.any((s) => !s.isPrimary);

      final grouped = <String, List<ProfileSeries>>{
        for (final s in sourceRows) s.id: [],
      };
      var primaryIsEdited = false;
      for (final s in series) {
        final owner = sourceIds.contains(s.sourceId)
            ? s.sourceId!
            : s.computerId == null
            ? primary.id
            : (sourceIdByComputer[s.computerId!] ?? primary.id);
        if (hasEditedProfile && isPrimaryFamily(s)) {
          if (!s.isPrimary) continue;
          primaryIsEdited = true;
        }
        grouped[owner]!.add(s);
      }
      return {
        for (final s in sourceRows)
          s.id: domain.SourceProfile(
            sourceId: s.id,
            computerId: s.computerId,
            isEdited: s.id == primary.id && primaryIsEdited,
            points: mergeSeriesPoints(grouped[s.id]!),
          ),
      };
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get profiles by data source for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      return {};
    }
  }

  /// Restore the original profile as primary.
  ///
  /// Deletes the edited (currently primary, computerId=null) profiles and
  /// promotes the original profiles back to primary.
  ///
  /// For multi-computer dives the primary [DiveDataSources] row identifies
  /// which computer was the original primary source.  Only that computer's
  /// profile rows are restored to isPrimary=true; the other computers' rows
  /// remain demoted so the profile chart continues to show a single trace.
  ///
  /// For single-computer dives (or when no primary computer reading exists)
  /// all remaining profile rows are promoted to primary as before.
  Future<void> restoreOriginalProfile(String diveId) async {
    try {
      _log.info('Restoring original profile for dive: $diveId');

      await _db.transaction(() async {
        // Delete user-edited series (isPrimary=true, computerId=null).
        // The computerId null filter is critical: without it, computer-
        // sourced series that were promoted to isPrimary=true by
        // setPrimaryDataSource would be permanently deleted.
        await _profileSeries.deleteEditedSeries(diveId);

        // Find the primary computer from dive_data_sources
        final primaryReading =
            await (_db.select(_db.diveDataSources)
                  ..where((t) => t.diveId.equals(diveId))
                  ..where((t) => t.isPrimary.equals(true))
                  ..limit(1))
                .getSingleOrNull();

        final primaryComputerId = primaryReading?.computerId;

        // Take the by-computer branch only when that computer actually owns a
        // series. Deleting the edit and then promoting nothing leaves the
        // dive with zero primary series: it keeps rendering, because
        // getDiveById and getMergedProfile ignore the flag, while
        // getDiveProfile, getAscentDescentRates, getTimeAtDepthRanges and the
        // data-quality prefilters all silently skip it. That is reachable
        // whenever the primary source names a computer that owns no samples
        // (a metadata-only source, or one whose samples a consolidation
        // re-stamped onto a different computer). setPrimaryDataSource and
        // DiveComputerRepository.setPrimaryProfile guard their own
        // demote-then-promote pairs the same way (issue #1149).
        if (primaryComputerId != null &&
            await _profileSeries.ownsComputer(diveId, primaryComputerId)) {
          // Multi-computer dive: only the previously-primary computer's
          // series come back.
          await _profileSeries.promoteByComputer(diveId, primaryComputerId);
        } else {
          // Single-computer dive (or no computer reading, or a primary
          // computer that owns nothing): everything left is the live profile.
          await _profileSeries.promoteAll(diveId);
        }
      });

      SyncEventBus.notifyLocalChange();
      _log.info('Restored original profile for dive: $diveId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to restore original profile for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Load downsampled profile points for multiple dives in a single query.
  ///
  /// Returns a map of `diveId` to `List<DiveProfilePoint>` where each profile
  /// is downsampled to at most [maxSamples] evenly-spaced points. This is
  /// used for mini-charts in the dive list to avoid N+1 queries.
  ///
  /// The mini chart is up to 120 logical pixels wide, so 120 samples lands at
  /// roughly one point per pixel — enough resolution to render the dive's
  /// shape (descents, safety stops, multilevel profiles) without spline
  /// smoothing flattening short features.
  ///
  /// Summarises a dive's primary series only when it has any, every series
  /// otherwise ([_sparklineSeries]); a dive with no series is absent from
  /// the result.
  Future<Map<String, List<domain.DiveProfilePoint>>> getBatchProfileSummaries(
    List<String> diveIds, {
    int maxSamples = 120,
  }) async {
    if (diveIds.isEmpty) return {};
    try {
      return await PerfTimer.measure('batchProfileSummaries', () async {
        final byDive = await _profileSeries.getSeriesForDives(diveIds);
        final result = <String, List<domain.DiveProfilePoint>>{
          for (final entry in byDive.entries)
            entry.key: _downsample([
              for (final p in mergeSeriesPoints(_sparklineSeries(entry.value)))
                domain.DiveProfilePoint(timestamp: p.timestamp, depth: p.depth),
            ], maxSamples),
        };
        return result;
      });
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get batch profiles',
        error: e,
        stackTrace: stackTrace,
      );
      return {};
    }
  }

  /// The series a sparkline summarises: the primary ones when the dive has
  /// any, every series otherwise.
  ///
  /// A demoted series is either a consolidated secondary computer's copy of
  /// the dive or the originals a saved edit superseded. Interleaving either
  /// with the primary drew the mini chart as a sawtooth between two
  /// computers' depths (#543). With a primary present this matches
  /// [getDiveProfile]'s `primaryOnly` read, so the mini chart and the lazily
  /// loaded list profile show the same shape. The two deliberately differ
  /// when NO series is primary (none promoted yet): that read returns an
  /// empty list, while a sparkline is better drawn from whatever exists
  /// than left blank, so every series contributes here.
  static List<ProfileSeries> _sparklineSeries(List<ProfileSeries> series) {
    final primary = [
      for (final s in series)
        if (s.isPrimary) s,
    ];
    return primary.isEmpty ? series : primary;
  }

  /// Evenly spaces [points] down to at most [maxSamples], keeping the first
  /// and last point. Returns [points] unchanged when already short enough.
  static List<domain.DiveProfilePoint> _downsample(
    List<domain.DiveProfilePoint> points,
    int maxSamples,
  ) {
    if (points.length <= maxSamples) return points;
    return [
      for (var i = 0; i < maxSamples; i++)
        points[(i * (points.length - 1)) ~/ (maxSamples - 1)],
    ];
  }

  /// Create a new dive
  Future<domain.Dive> createDive(domain.Dive dive) async {
    try {
      _log.info('Creating dive: ${dive.diveNumber ?? "new"}');
      final id = dive.id.isEmpty ? _uuid.v4() : dive.id;
      final now = DateTime.now().millisecondsSinceEpoch;

      // One transaction for the dive and every child it owns. The profile
      // used to be written inside the child batch below and is now a
      // separate series insert, so without this a failing profile write
      // would leave the dive committed with its tanks and weights and no
      // samples, while createDive rethrows and the caller reports that
      // nothing was saved.
      await _db.transaction(() async {
        await _db
            .into(_db.dives)
            .insert(
              DivesCompanion(
                id: Value(id),
                diverId: Value(dive.diverId),
                diveNumber: Value(dive.diveNumber),
                diveDateTime: Value(dive.dateTime.millisecondsSinceEpoch),
                entryTime: Value(dive.entryTime?.millisecondsSinceEpoch),
                exitTime: Value(dive.exitTime?.millisecondsSinceEpoch),
                bottomTime: Value(dive.bottomTime?.inSeconds),
                runtime: Value(dive.runtime?.inSeconds),
                maxDepth: Value(dive.maxDepth),
                avgDepth: Value(dive.avgDepth),
                waterTemp: Value(dive.waterTemp),
                airTemp: Value(dive.airTemp),
                visibilityMeters: Value(dive.visibilityMeters),
                // A measured distance supersedes the legacy bucket. Value(null)
                // rather than Value.absent(): absent() preserves the existing
                // column on a companion write, which would leave the dive
                // carrying both a measurement and a contradicting bucket.
                visibility: dive.visibilityMeters != null
                    ? const Value(null)
                    : Value(dive.visibility?.name),
                diveType: Value(dive.diveTypeId),
                buddy: Value(dive.buddy),
                diveMaster: Value(dive.diveMaster),
                diverRole: Value(dive.diverRoleId),
                notes: Value(dive.notes),
                name: Value(dive.name),
                siteId: Value(dive.site?.id),
                diveCenterId: Value(dive.diveCenter?.id),
                tripId: Value(dive.tripId ?? dive.trip?.id),
                rating: Value(dive.rating),
                // Conditions fields
                currentDirection: Value(dive.currentDirection?.name),
                currentStrength: Value(dive.currentStrength?.name),
                swellHeight: Value(dive.swellHeight),
                entryMethod: Value(dive.entryMethod?.name),
                exitMethod: Value(dive.exitMethod?.name),
                waterType: Value(dive.waterType?.name),
                altitude: Value(dive.altitude),
                surfacePressure: Value(dive.surfacePressure),
                // Entry/exit GPS (previously dropped on create, so file-imported
                // dives never became eligible for site matching).
                entryLatitude: Value(dive.entryLocation?.latitude),
                entryLongitude: Value(dive.entryLocation?.longitude),
                exitLatitude: Value(dive.exitLocation?.latitude),
                exitLongitude: Value(dive.exitLocation?.longitude),
                // Weather conditions
                windSpeed: Value(dive.windSpeed),
                windDirection: Value(dive.windDirection?.name),
                cloudCover: Value(dive.cloudCover?.name),
                precipitation: Value(dive.precipitation?.name),
                humidity: Value(dive.humidity),
                weatherDescription: Value(dive.weatherDescription),
                weatherCode: Value(dive.weatherCode),
                weatherSource: Value(dive.weatherSource?.name),
                weatherFetchedAt: Value(
                  dive.weatherFetchedAt != null
                      ? dive.weatherFetchedAt!.millisecondsSinceEpoch ~/ 1000
                      : null,
                ),
                // Surface interval and deco settings
                surfaceIntervalSeconds: Value(dive.surfaceInterval?.inSeconds),
                gradientFactorLow: Value(dive.gradientFactorLow),
                gradientFactorHigh: Value(dive.gradientFactorHigh),
                decoAlgorithm: Value(dive.decoAlgorithm),
                decoConservatism: Value(dive.decoConservatism),
                diveComputerModel: Value(dive.diveComputerModel),
                diveComputerSerial: Value(dive.diveComputerSerial),
                diveComputerFirmware: Value(dive.diveComputerFirmware),
                // Weight system fields
                weightAmount: Value(dive.weightAmount),
                weightType: Value(dive.weightType?.name),
                weightingFeedback: Value(dive.weightingFeedback?.name),
                weightingFeedbackKg: Value(dive.weightingFeedbackKg),
                // Favorite flag
                isFavorite: Value(dive.isFavorite),
                excludedFromStats: Value(dive.excludedFromStats),
                excludedFromGasStats: Value(dive.excludedFromGasStats),
                // CCR/SCR rebreather fields (v1.5)
                diveMode: Value(dive.diveMode.code),
                setpointLow: Value(dive.setpointLow),
                setpointHigh: Value(dive.setpointHigh),
                setpointDeco: Value(dive.setpointDeco),
                scrType: Value(dive.scrType?.code),
                scrInjectionRate: Value(dive.scrInjectionRate),
                scrAdditionRatio: Value(dive.scrAdditionRatio),
                scrOrificeSize: Value(dive.scrOrificeSize),
                assumedVo2: Value(dive.assumedVo2),
                diluentO2: Value(dive.diluentGas?.o2),
                diluentHe: Value(dive.diluentGas?.he),
                loopO2Min: Value(dive.loopO2Min),
                loopO2Max: Value(dive.loopO2Max),
                loopO2Avg: Value(dive.loopO2Avg),
                loopVolume: Value(dive.loopVolume),
                scrubberType: Value(dive.scrubber?.type),
                scrubberDurationMinutes: Value(dive.scrubber?.ratedMinutes),
                scrubberRemainingMinutes: Value(
                  dive.scrubber?.remainingMinutes,
                ),
                // Dive planner (v1.5)
                isPlanned: Value(dive.isPlanned),
                // Training course (v1.5)
                courseId: Value(dive.courseId),
                // Import source tracking
                importSource: Value(dive.importSource),
                importId: Value(dive.importId),
                importVersion: const Value(1),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        await _syncRepository.markRecordPending(
          entityType: 'dives',
          recordId: id,
          localUpdatedAt: now,
        );
        await _replaceDiveTypeRows(id, dive.diveTypeIds, now);

        // Batch insert all child records for performance
        // Profile points, tanks, weights, and equipment are inserted in a single
        // transaction, which is ~100x faster than individual inserts.
        await _db.batch((batch) {
          // Insert tanks (preserve provided IDs if not empty, otherwise generate)
          for (final tank in dive.tanks) {
            final tankId = tank.id.isNotEmpty ? tank.id : _uuid.v4();
            batch.insert(
              _db.diveTanks,
              DiveTanksCompanion(
                id: Value(tankId),
                diveId: Value(id),
                volume: Value(tank.volume),
                workingPressure: Value(tank.workingPressure),
                startPressure: Value(tank.startPressure),
                endPressure: Value(tank.endPressure),
                o2Percent: Value(tank.gasMix.o2),
                hePercent: Value(tank.gasMix.he),
                tankOrder: Value(tank.order),
                tankRole: Value(tank.role.name),
                tankMaterial: Value(tank.material?.name),
                tankName: Value(tank.name),
                presetName: Value(tank.presetName),
                computerId: Value(tank.computerId),
              ),
            );
          }

          // Insert weights
          for (final weight in dive.weights) {
            final weightId = weight.id.isNotEmpty ? weight.id : _uuid.v4();
            batch.insert(
              _db.diveWeights,
              DiveWeightsCompanion(
                id: Value(weightId),
                diveId: Value(id),
                weightType: Value(weight.weightType.name),
                amountKg: Value(weight.amountKg),
                notes: Value(weight.notes),
                createdAt: Value(now),
              ),
            );
          }

          // Insert custom fields
          for (final field in dive.customFields) {
            final fieldId = field.id.isNotEmpty ? field.id : _uuid.v4();
            batch.insert(
              _db.diveCustomFields,
              DiveCustomFieldsCompanion(
                id: Value(fieldId),
                diveId: Value(id),
                fieldKey: Value(field.key),
                fieldValue: Value(field.value),
                sortOrder: Value(field.sortOrder),
                createdAt: Value(now),
              ),
            );
          }

          // Insert equipment associations
          for (final item in dive.equipment) {
            batch.insert(
              _db.diveEquipment,
              DiveEquipmentCompanion(
                diveId: Value(id),
                equipmentId: Value(item.id),
              ),
            );
          }
        });

        // Profile samples: one packed primary series with no computer and no
        // source, the same identity the legacy rows carried for a manual dive.
        if (dive.profile.isNotEmpty) {
          await _profileSeries.insertSeries(
            diveId: id,
            samples: [
              for (final point in dive.profile) profileSampleFromPoint(point),
            ],
            now: now,
          );
        }

        // Insert tag associations
        if (dive.tags.isNotEmpty) {
          await _tagRepository.setTagsForDive(id, dive.tags);
        }
      });

      SyncEventBus.notifyLocalChange();
      _log.info('Created dive with id: $id');
      return dive.copyWith(id: id);
    } catch (e, stackTrace) {
      _log.error('Failed to create dive', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Update an existing dive
  Future<void> updateDive(domain.Dive dive) async {
    try {
      _log.info('Updating dive: ${dive.id}');

      // Validate that all tanks have non-empty IDs on update to prevent data loss
      // (If a tank ID is empty, it would generate a new UUID and cause the old tank to be deleted)
      final emptyTankIndices = dive.tanks
          .asMap()
          .entries
          .where((e) => e.value.id.isEmpty)
          .map((e) => e.key);
      if (emptyTankIndices.isNotEmpty) {
        throw ArgumentError(
          'Cannot update dive: tank(s) at index(es) ${emptyTankIndices.join(', ')} '
          'have empty IDs. All tanks must have valid IDs when updating a dive.',
        );
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(_db.dives)..where((t) => t.id.equals(dive.id))).write(
        DivesCompanion(
          diverId: Value(dive.diverId),
          diveNumber: Value(dive.diveNumber),
          diveDateTime: Value(dive.dateTime.millisecondsSinceEpoch),
          entryTime: Value(dive.entryTime?.millisecondsSinceEpoch),
          exitTime: Value(dive.exitTime?.millisecondsSinceEpoch),
          bottomTime: Value(dive.bottomTime?.inSeconds),
          runtime: Value(dive.runtime?.inSeconds),
          maxDepth: Value(dive.maxDepth),
          avgDepth: Value(dive.avgDepth),
          waterTemp: Value(dive.waterTemp),
          airTemp: Value(dive.airTemp),
          visibilityMeters: Value(dive.visibilityMeters),
          // A measured distance supersedes the legacy bucket. Value(null)
          // rather than Value.absent(): absent() preserves the existing column
          // on a companion write, which would leave the dive carrying both a
          // measurement and a contradicting bucket.
          visibility: dive.visibilityMeters != null
              ? const Value(null)
              : Value(dive.visibility?.name),
          diveType: Value(dive.diveTypeId),
          buddy: Value(dive.buddy),
          diveMaster: Value(dive.diveMaster),
          diverRole: Value(dive.diverRoleId),
          notes: Value(dive.notes),
          name: Value(dive.name),
          siteId: Value(dive.site?.id),
          diveCenterId: Value(dive.diveCenter?.id),
          tripId: Value(dive.tripId ?? dive.trip?.id),
          rating: Value(dive.rating),
          // Conditions fields
          currentDirection: Value(dive.currentDirection?.name),
          currentStrength: Value(dive.currentStrength?.name),
          swellHeight: Value(dive.swellHeight),
          entryMethod: Value(dive.entryMethod?.name),
          exitMethod: Value(dive.exitMethod?.name),
          waterType: Value(dive.waterType?.name),
          altitude: Value(dive.altitude),
          surfacePressure: Value(dive.surfacePressure),
          // Weather conditions
          windSpeed: Value(dive.windSpeed),
          windDirection: Value(dive.windDirection?.name),
          cloudCover: Value(dive.cloudCover?.name),
          precipitation: Value(dive.precipitation?.name),
          humidity: Value(dive.humidity),
          weatherDescription: Value(dive.weatherDescription),
          weatherCode: Value(dive.weatherCode),
          weatherSource: Value(dive.weatherSource?.name),
          weatherFetchedAt: Value(
            dive.weatherFetchedAt != null
                ? dive.weatherFetchedAt!.millisecondsSinceEpoch ~/ 1000
                : null,
          ),
          // Surface interval and deco settings
          surfaceIntervalSeconds: Value(dive.surfaceInterval?.inSeconds),
          gradientFactorLow: Value(dive.gradientFactorLow),
          gradientFactorHigh: Value(dive.gradientFactorHigh),
          decoAlgorithm: Value(dive.decoAlgorithm),
          decoConservatism: Value(dive.decoConservatism),
          diveComputerModel: Value(dive.diveComputerModel),
          diveComputerSerial: Value(dive.diveComputerSerial),
          diveComputerFirmware: Value(dive.diveComputerFirmware),
          // Weight system fields
          weightAmount: Value(dive.weightAmount),
          weightType: Value(dive.weightType?.name),
          weightingFeedback: Value(dive.weightingFeedback?.name),
          weightingFeedbackKg: Value(dive.weightingFeedbackKg),
          // Favorite flag
          isFavorite: Value(dive.isFavorite),
          excludedFromStats: Value(dive.excludedFromStats),
          excludedFromGasStats: Value(dive.excludedFromGasStats),
          // CCR/SCR rebreather fields (v1.5)
          diveMode: Value(dive.diveMode.code),
          setpointLow: Value(dive.setpointLow),
          setpointHigh: Value(dive.setpointHigh),
          setpointDeco: Value(dive.setpointDeco),
          scrType: Value(dive.scrType?.code),
          scrInjectionRate: Value(dive.scrInjectionRate),
          scrAdditionRatio: Value(dive.scrAdditionRatio),
          scrOrificeSize: Value(dive.scrOrificeSize),
          assumedVo2: Value(dive.assumedVo2),
          diluentO2: Value(dive.diluentGas?.o2),
          diluentHe: Value(dive.diluentGas?.he),
          loopO2Min: Value(dive.loopO2Min),
          loopO2Max: Value(dive.loopO2Max),
          loopO2Avg: Value(dive.loopO2Avg),
          loopVolume: Value(dive.loopVolume),
          scrubberType: Value(dive.scrubber?.type),
          scrubberDurationMinutes: Value(dive.scrubber?.ratedMinutes),
          scrubberRemainingMinutes: Value(dive.scrubber?.remainingMinutes),
          // Dive planner (v1.5)
          isPlanned: Value(dive.isPlanned),
          // Training course (v1.5)
          courseId: Value(dive.courseId),
          // Import source tracking
          importSource: Value(dive.importSource),
          importId: Value(dive.importId),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: dive.id,
        localUpdatedAt: now,
      );
      await _replaceDiveTypeRows(dive.id, dive.diveTypeIds, now);

      // Update tanks:
      // Try to match existing tanks by ID to do updates instead of delete+insert when possible,
      // to preserve sync records and avoid unnecessary deletions/insertions in the sync engine.
      // Delete tanks that are no longer present.
      // This is more complex but should result in better sync behavior and performance when tanks
      // are edited but not completely changed (which is more likely).

      // Get existing tank IDs for this dive
      final existingTankRows = await (_db.select(
        _db.diveTanks,
      )..where((t) => t.diveId.equals(dive.id))).get();
      final existingTankIds = existingTankRows.map((t) => t.id).toSet();
      final updatedTankIds = <String>{};

      // Update or insert tanks
      for (final tank in dive.tanks) {
        // Tank ID is guaranteed to be non-empty by validation at start of method
        final tankId = tank.id;
        updatedTankIds.add(tankId);

        if (existingTankIds.contains(tankId)) {
          // Update existing tank
          await (_db.update(
            _db.diveTanks,
          )..where((t) => t.id.equals(tankId))).write(
            DiveTanksCompanion(
              volume: Value(tank.volume),
              workingPressure: Value(tank.workingPressure),
              startPressure: Value(tank.startPressure),
              endPressure: Value(tank.endPressure),
              o2Percent: Value(tank.gasMix.o2),
              hePercent: Value(tank.gasMix.he),
              tankOrder: Value(tank.order),
              tankRole: Value(tank.role.name),
              tankMaterial: Value(tank.material?.name),
              tankName: Value(tank.name),
              presetName: Value(tank.presetName),
            ),
          );
          // Log as pending update (assuming sync handles updates)
          await _syncRepository.markRecordPending(
            entityType: 'diveTanks',
            recordId: tankId,
            localUpdatedAt: now,
          );
        } else {
          // Insert new tank
          await _db
              .into(_db.diveTanks)
              .insert(
                DiveTanksCompanion(
                  id: Value(tankId),
                  diveId: Value(dive.id),
                  volume: Value(tank.volume),
                  workingPressure: Value(tank.workingPressure),
                  startPressure: Value(tank.startPressure),
                  endPressure: Value(tank.endPressure),
                  o2Percent: Value(tank.gasMix.o2),
                  hePercent: Value(tank.gasMix.he),
                  tankOrder: Value(tank.order),
                  tankRole: Value(tank.role.name),
                  tankMaterial: Value(tank.material?.name),
                  tankName: Value(tank.name),
                  presetName: Value(tank.presetName),
                  computerId: Value(tank.computerId),
                ),
              );
          await _syncRepository.markRecordPending(
            entityType: 'diveTanks',
            recordId: tankId,
            localUpdatedAt: now,
          );
        }
      }

      // Delete tanks that are no longer present
      // This will cascade to both tank_pressure_series and gas_switches for removed tanks
      final tanksToDelete = existingTankIds.difference(updatedTankIds);
      for (final tankId in tanksToDelete) {
        await (_db.delete(
          _db.diveTanks,
        )..where((t) => t.id.equals(tankId))).go();
        await _syncRepository.logDeletion(
          entityType: 'diveTanks',
          recordId: tankId,
        );
      }

      // Update weights: delete and re-insert
      final existingWeights = await (_db.select(
        _db.diveWeights,
      )..where((t) => t.diveId.equals(dive.id))).get();
      await (_db.delete(
        _db.diveWeights,
      )..where((t) => t.diveId.equals(dive.id))).go();
      for (final weight in existingWeights) {
        await _syncRepository.logDeletion(
          entityType: 'diveWeights',
          recordId: weight.id,
        );
      }
      for (final weight in dive.weights) {
        final weightId = weight.id.isNotEmpty ? weight.id : _uuid.v4();
        await _db
            .into(_db.diveWeights)
            .insert(
              DiveWeightsCompanion(
                id: Value(weightId),
                diveId: Value(dive.id),
                weightType: Value(weight.weightType.name),
                amountKg: Value(weight.amountKg),
                notes: Value(weight.notes),
                createdAt: Value(DateTime.now().millisecondsSinceEpoch),
              ),
            );
        await _syncRepository.markRecordPending(
          entityType: 'diveWeights',
          recordId: weightId,
          localUpdatedAt: now,
        );
      }

      // Update equipment: delete and re-insert
      final existingEquipment = await (_db.select(
        _db.diveEquipment,
      )..where((t) => t.diveId.equals(dive.id))).get();
      await (_db.delete(
        _db.diveEquipment,
      )..where((t) => t.diveId.equals(dive.id))).go();
      for (final item in existingEquipment) {
        await _syncRepository.logDeletion(
          entityType: 'diveEquipment',
          recordId: '${item.diveId}|${item.equipmentId}',
        );
      }
      for (final item in dive.equipment) {
        await _db
            .into(_db.diveEquipment)
            .insert(
              DiveEquipmentCompanion(
                diveId: Value(dive.id),
                equipmentId: Value(item.id),
              ),
            );
        await _syncRepository.markRecordPending(
          entityType: 'diveEquipment',
          recordId: '${dive.id}|${item.id}',
          localUpdatedAt: now,
        );
      }

      // Update custom fields: delete and re-insert
      final existingCustomFields = await (_db.select(
        _db.diveCustomFields,
      )..where((cf) => cf.diveId.equals(dive.id))).get();
      await (_db.delete(
        _db.diveCustomFields,
      )..where((cf) => cf.diveId.equals(dive.id))).go();
      for (final cf in existingCustomFields) {
        await _syncRepository.logDeletion(
          entityType: 'diveCustomFields',
          recordId: cf.id,
        );
      }
      for (final field in dive.customFields) {
        final fieldId = field.id.isNotEmpty ? field.id : _uuid.v4();
        await _db
            .into(_db.diveCustomFields)
            .insert(
              DiveCustomFieldsCompanion(
                id: Value(fieldId),
                diveId: Value(dive.id),
                fieldKey: Value(field.key),
                fieldValue: Value(field.value),
                sortOrder: Value(field.sortOrder),
                createdAt: Value(DateTime.now().millisecondsSinceEpoch),
              ),
            );
        await _syncRepository.markRecordPending(
          entityType: 'diveCustomFields',
          recordId: fieldId,
          localUpdatedAt: now,
        );
      }

      // Update tags
      await _tagRepository.setTagsForDive(dive.id, dive.tags);

      SyncEventBus.notifyLocalChange();
      _log.info('Updated dive: ${dive.id}');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update dive: ${dive.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Cascade a dying dive's media (orphan-prevention spec 4.2): dive-only
  /// non-library rows die with the dive (rows + tombstones + blob-delete
  /// intents via the coordinator's enqueue-before-delete path); site-linked
  /// and library-level rows survive with diveId nulled and HLC-stamped.
  ///
  /// Deliberately NOT wrapped in a transaction with the dive delete: the
  /// coordinator's queue writes live in another database, and every step is
  /// individually idempotent/tombstoned - a crash between cascade and dive
  /// delete leaves a re-deletable dive, never an orphan. Merge and
  /// consolidation services reassign media to the surviving dive BEFORE
  /// deleting sources, so this sees no doomed media for merged-away dives.
  Future<void> _cascadeMediaForDiveDeletion(List<String> ids) async {
    final split = await _mediaRepository.partitionMediaForDiveDeletion(ids);
    if (split.doomed.isNotEmpty) {
      // Items, not ids: the partition already read these rows, and the
      // blob-delete intent needs exactly the fields it carries.
      await _mediaDeletionCoordinator.deleteMediaItems(split.doomed);
    }
    if (split.unlinkIds.isNotEmpty) {
      await _mediaRepository.unlinkMediaFromDeletedDives(split.unlinkIds);
    }
  }

  /// Delete a dive.
  ///
  /// [cascadeMedia] is true for user-intent deletions (the dive's media
  /// goes with the dive). Restore/undo flows that re-point media
  /// afterwards (e.g. merge undo) pass false so the cascade cannot eat
  /// rows they are about to restore.
  Future<void> deleteDive(String id, {bool cascadeMedia = true}) async {
    try {
      _log.info('Deleting dive: $id');
      if (cascadeMedia) await _cascadeMediaForDiveDeletion([id]);
      await (_db.delete(_db.dives)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: 'dives', recordId: id);
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted dive: $id');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete dive: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Bulk delete multiple dives
  /// Returns the list of deleted dive IDs for potential undo
  Future<List<String>> bulkDeleteDives(
    List<String> ids, {
    bool cascadeMedia = true,
  }) async {
    if (ids.isEmpty) return [];

    try {
      _log.info('Bulk deleting ${ids.length} dives');
      if (cascadeMedia) await _cascadeMediaForDiveDeletion(ids);
      await (_db.delete(_db.dives)..where((t) => t.id.isIn(ids))).go();
      for (final id in ids) {
        await _syncRepository.logDeletion(entityType: 'dives', recordId: id);
      }
      SyncEventBus.notifyLocalChange();
      _log.info('Bulk deleted ${ids.length} dives');
      return ids;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to bulk delete dives',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get dives by their IDs (for undo functionality)
  Future<List<domain.Dive>> getDivesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    try {
      final query = _db.select(_db.dives)
        ..where((t) => t.id.isIn(ids))
        ..orderBy([
          (t) => OrderingTerm.desc(coalesce([t.entryTime, t.diveDateTime])),
          (t) => OrderingTerm.desc(t.diveNumber),
        ]);

      final rows = await query.get();
      return await Future.wait(rows.map(_mapRowToDive));
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dives by ids',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // Paginated Queries
  // ============================================================================

  /// Get paginated dive summaries with SQL-level filtering.
  ///
  /// Uses cursor-based pagination for stable page boundaries even when
  /// rows are inserted or deleted between page loads.
  /// Returns lightweight [DiveSummary] objects optimized for list display.
  /// Builds the `AND sf.rule_id NOT IN (...)` fragment and its bound args for
  /// the safety-finding count subquery, so the dive-list badge counts only
  /// findings whose rule is enabled (matching SafetyReviewSection). Returns an
  /// empty fragment and no args when the diver has disabled no rules.
  (String, List<Variable<Object>>) _disabledRulesCountFilter(
    Set<String> disabledRules,
  ) {
    if (disabledRules.isEmpty) return ('', const []);
    final placeholders = List.filled(disabledRules.length, '?').join(', ');
    return (
      ' AND sf.rule_id NOT IN ($placeholders)',
      disabledRules.map((r) => Variable<Object>(r)).toList(),
    );
  }

  // stats-scope-exempt: the logbook list itself. It SELECTS the exclusion
  // columns so the row can render its badge, but must never filter on them:
  // an excluded dive is still in the logbook and still shown.
  Future<List<DiveSummary>> getDiveSummaries({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    DiveSummaryCursor? cursor,
    int? offset,
    int limit = 50,
    SortState<DiveSortField>? sort,
    Set<String> disabledSafetyRules = const {},
  }) async {
    try {
      return await PerfTimer.measure('getDiveSummaries', () async {
        final whereClauses = <String>[];
        final args = <Variable<Object>>[];

        if (diverId != null) {
          whereClauses.add('d.diver_id = ?');
          args.add(Variable(diverId));
        }

        // Cursor-based pagination only works with default date sort.
        // For other sorts, use offset-based pagination instead.
        final isDateSort = sort == null || sort.field == DiveSortField.date;
        if (cursor != null && isDateSort) {
          final cmp = sort?.direction == SortDirection.ascending ? '>' : '<';
          final cmpNum = sort?.direction == SortDirection.ascending ? '>' : '<';
          whereClauses.add(
            '('
            'COALESCE(d.entry_time, d.dive_date_time) $cmp ? '
            'OR (COALESCE(d.entry_time, d.dive_date_time) = ? '
            'AND COALESCE(d.dive_number, 0) $cmpNum ?) '
            'OR (COALESCE(d.entry_time, d.dive_date_time) = ? '
            'AND COALESCE(d.dive_number, 0) = ? AND d.id $cmp ?)'
            ')',
          );
          args.add(Variable(cursor.sortTimestamp));
          args.add(Variable(cursor.sortTimestamp));
          args.add(Variable(cursor.diveNumber));
          args.add(Variable(cursor.sortTimestamp));
          args.add(Variable(cursor.diveNumber));
          args.add(Variable(cursor.id));
        }

        _buildFilterWhereClauses(filter, whereClauses, args);

        final whereClause = whereClauses.isNotEmpty
            ? 'WHERE ${whereClauses.join(' AND ')}'
            : '';

        final orderByClause = _buildSortOrderBy(sort);

        final offsetClause = (!isDateSort && offset != null && offset > 0)
            ? 'OFFSET $offset'
            : '';

        // Exclude findings for rules the diver has disabled so the badge count
        // matches what SafetyReviewSection actually renders. The subquery lives
        // in the SELECT list, so its placeholders bind BEFORE the WHERE/LIMIT
        // args and must be prepended to the variable list.
        final (safetyCountFilter, safetyCountArgs) = _disabledRulesCountFilter(
          disabledSafetyRules,
        );

        final sql =
            'SELECT '
            'd.id, d.dive_number, d.name AS dive_name, '
            'd.dive_date_time, d.entry_time, '
            'd.max_depth, d.bottom_time, d.runtime, d.water_temp, d.rating, '
            'd.is_favorite, d.excluded_from_stats, d.excluded_from_gas_stats, '
            'd.dive_type, d.dive_mode, '
            'COALESCE(d.entry_time, d.dive_date_time) AS sort_timestamp, '
            's.name AS site_name, s.country AS site_country, '
            's.region AS site_region, s.latitude AS site_latitude, '
            's.longitude AS site_longitude, '
            // Correlated count keyed by d.id so SQLite uses
            // idx_dive_safety_findings_dive_id and only counts findings for the
            // page's dives, instead of grouping the whole findings table.
            '(SELECT COUNT(*) FROM dive_safety_findings sf '
            'WHERE sf.dive_id = d.id AND sf.dismissed_at IS NULL'
            '$safetyCountFilter) '
            'AS safety_finding_count '
            'FROM dives d '
            'LEFT JOIN dive_sites s ON d.site_id = s.id '
            '$whereClause '
            'ORDER BY $orderByClause '
            'LIMIT ? $offsetClause';
        args.add(Variable(limit));

        final rows = await _db
            .customSelect(
              sql,
              variables: [...safetyCountArgs, ...args],
              readsFrom: {
                _db.dives,
                _db.diveSites,
                _db.diveSafetyFindings,
                _db.diveProfileSeries,
                _db.diveProfileEvents,
              },
            )
            .get();

        if (rows.isEmpty) return [];

        // Batch load tags for all returned dive IDs
        final diveIds = rows.map((r) => r.read<String>('id')).toList();
        final tagsByDive = await _tagRepository.getTagsForDives(diveIds);
        final diveTypesByDive = await _diveTypesForDives(diveIds);

        return _mapSummaryRows(rows, tagsByDive, diveTypesByDive);
      });
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive summaries',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Returns every dive id matching [filter] in [sort] order -- the same order
  /// as [getDiveSummaries] but without pagination and selecting only the id.
  ///
  /// Used to compute previous/next navigation from the detail page. Distinct
  /// from [getPreviousDive], which is the chronological surface-interval query.
  // stats-scope-exempt: drives detail-page next/prev over the displayed list
  Future<List<String>> getOrderedDiveIds({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    SortState<DiveSortField>? sort,
  }) async {
    try {
      return await PerfTimer.measure('getOrderedDiveIds', () async {
        final whereClauses = <String>[];
        final args = <Variable<Object>>[];

        if (diverId != null) {
          whereClauses.add('d.diver_id = ?');
          args.add(Variable(diverId));
        }

        _buildFilterWhereClauses(filter, whereClauses, args);

        final whereClause = whereClauses.isNotEmpty
            ? 'WHERE ${whereClauses.join(' AND ')}'
            : '';
        final orderByClause = _buildSortOrderBy(sort);

        // sort_timestamp / s.name aliases are referenced by _buildSortOrderBy,
        // so they must appear here even though only id is read back.
        final sql =
            'SELECT d.id, '
            'COALESCE(d.entry_time, d.dive_date_time) AS sort_timestamp '
            'FROM dives d '
            'LEFT JOIN dive_sites s ON d.site_id = s.id '
            '$whereClause '
            'ORDER BY $orderByClause';

        final rows = await _db
            .customSelect(
              sql,
              variables: args,
              readsFrom: {
                _db.dives,
                _db.diveSites,
                _db.diveProfileSeries,
                _db.diveProfileEvents,
              },
            )
            .get();

        return rows.map((r) => r.read<String>('id')).toList();
      });
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get ordered dive ids',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get total count of dives matching the given filters.
  ///
  /// Used to display "X dives" in the UI header without loading all data.
  ///
  /// Deliberately does NOT apply [DiveStatsScope]: an excluded dive is still
  /// in the logbook and the list still shows it, so the header still counts
  /// it. Only descriptive *statistics* honour the exclusion. Do not "fix"
  /// this; see the design doc and the census test's exemption list.
  // stats-scope-exempt: logbook list header, not a statistic
  Future<int> getDiveCount({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      return await PerfTimer.measure('getDiveCount', () async {
        final whereClauses = <String>[];
        final args = <Variable<Object>>[];

        if (diverId != null) {
          whereClauses.add('d.diver_id = ?');
          args.add(Variable(diverId));
        }

        _buildFilterWhereClauses(filter, whereClauses, args);

        final whereClause = whereClauses.isNotEmpty
            ? 'WHERE ${whereClauses.join(' AND ')}'
            : '';

        final result = await _db
            .customSelect(
              'SELECT COUNT(*) AS count FROM dives d $whereClause',
              variables: args,
              readsFrom: {
                _db.dives,
                _db.diveProfileSeries,
                _db.diveProfileEvents,
              },
            )
            .getSingle();
        return result.read<int>('count');
      });
    } catch (e, stackTrace) {
      _log.error('Failed to get dive count', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// The ids of every dive whose recorded profile signal classifies it as
  /// deco ([wantDeco] true) or no-deco ([wantDeco] false).
  ///
  /// The in-memory filter path ([DiveFilterState.apply]) cannot answer this:
  /// [getAllDives] deliberately skips profile hydration for list views, and
  /// deco-stop events never reach the entity at all. So the surfaces built on
  /// that path (the table view, the activity and heat maps) resolve the deco
  /// axis through this query instead, reusing [decoSignalCondition] so they
  /// classify dives exactly as the paginated SQL list does.
  ///
  /// Only called while the deco filter is active, which keeps the scan over
  /// `dive_profile_series` off the default dive-list load.
  // stats-scope-exempt: backs a view-filter axis; consumers apply the scope themselves
  Future<Set<String>> getDiveIdsWithDecoSignal({
    required bool wantDeco,
    String? diverId,
  }) async {
    try {
      return await PerfTimer.measure('getDiveIdsWithDecoSignal', () async {
        final whereClauses = <String>[
          decoSignalCondition(wantDeco: wantDeco, diveIdRef: 'd.id'),
        ];
        final args = <Variable<Object>>[];

        if (diverId != null) {
          whereClauses.add('d.diver_id = ?');
          args.add(Variable(diverId));
        }

        final rows = await _db
            .customSelect(
              'SELECT d.id AS id FROM dives d '
              'WHERE ${whereClauses.join(' AND ')}',
              variables: args,
              readsFrom: {
                _db.dives,
                _db.diveProfileSeries,
                _db.diveProfileEvents,
              },
            )
            .get();
        return rows.map((r) => r.read<String>('id')).toSet();
      });
    } catch (e, stackTrace) {
      _log.error(
        'Failed to resolve deco-signal dive ids',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Build SQL WHERE clauses from a [DiveFilterState].
  ///
  /// Builds the SQL ORDER BY clause from the sort state.
  ///
  /// Each sort field maps to a SQL expression with a tiebreaker on
  /// sort_timestamp DESC and id DESC to ensure stable ordering.
  String _buildSortOrderBy(SortState<DiveSortField>? sort) {
    final dir =
        (sort?.direction ?? SortDirection.descending) == SortDirection.ascending
        ? 'ASC'
        : 'DESC';
    final field = sort?.field ?? DiveSortField.date;
    // Tiebreaker ensures stable ordering across pages.
    const tiebreaker = 'sort_timestamp DESC, d.id DESC';

    switch (field) {
      case DiveSortField.date:
        return 'sort_timestamp $dir, '
            'COALESCE(d.dive_number, 0) $dir, d.id $dir';
      case DiveSortField.site:
        return 'COALESCE(s.name, \'\') $dir, $tiebreaker';
      case DiveSortField.depth:
        return 'COALESCE(d.max_depth, 0) $dir, $tiebreaker';
      case DiveSortField.bottomTime:
        return 'COALESCE(d.bottom_time, 0) $dir, $tiebreaker';
      case DiveSortField.rating:
        return 'COALESCE(d.rating, 0) $dir, $tiebreaker';
      case DiveSortField.diveNumber:
        return 'COALESCE(d.dive_number, 0) $dir, $tiebreaker';
    }
  }

  /// Translates each active filter field into parameterized SQL.
  /// Junction-table filters (tags, equipment, buddies) use EXISTS subqueries.
  // stats-scope-exempt: this IS the view filter; the scope is applied alongside it
  void _buildFilterWhereClauses(
    DiveFilterState filter,
    List<String> clauses,
    List<Variable<Object>> args,
  ) {
    // Bounds come pre-normalized to the wall-clock-as-UTC frame the column
    // stores, so a locally-built filter date lands on the right day boundary
    // whatever the device's UTC offset is (issue #1368). Half-open, matching
    // buildFilteredDiveIdSubquery and DiveFilterState.apply.
    final startBoundMs = filter.startDateBoundMs;
    if (startBoundMs != null) {
      clauses.add('d.dive_date_time >= ?');
      args.add(Variable(startBoundMs));
    }
    final endBoundMs = filter.endDateBoundMs;
    if (endBoundMs != null) {
      clauses.add('d.dive_date_time < ?');
      args.add(Variable(endBoundMs));
    }
    if (filter.diveTypeId != null) {
      clauses.add(
        'EXISTS (SELECT 1 FROM dive_dive_types ddt '
        'WHERE ddt.dive_id = d.id AND ddt.dive_type_id = ?)',
      );
      args.add(Variable(filter.diveTypeId!));
    }
    if (filter.siteId != null) {
      clauses.add('d.site_id = ?');
      args.add(Variable(filter.siteId!));
    }
    if (filter.tripId != null) {
      clauses.add('d.trip_id = ?');
      args.add(Variable(filter.tripId!));
    }
    if (filter.diveCenterId != null) {
      clauses.add('d.dive_center_id = ?');
      args.add(Variable(filter.diveCenterId!));
    }
    if (filter.minDepth != null) {
      clauses.add('d.max_depth >= ?');
      args.add(Variable(filter.minDepth!));
    }
    if (filter.maxDepth != null) {
      clauses.add('d.max_depth <= ?');
      args.add(Variable(filter.maxDepth!));
    }
    if (filter.favoritesOnly == true) {
      clauses.add('d.is_favorite = 1');
    }
    if (filter.excludedFromStatsOnly == true) {
      clauses.add('d.excluded_from_stats = 1');
    }
    if (filter.decoOnly != null) {
      clauses.add(
        decoSignalCondition(wantDeco: filter.decoOnly!, diveIdRef: 'd.id'),
      );
    }
    if (filter.noBuddyOnly == true) {
      clauses.add(
        "(d.buddy IS NULL OR d.buddy = '') AND "
        'NOT EXISTS (SELECT 1 FROM dive_buddies db WHERE db.dive_id = d.id)',
      );
    }
    if (filter.tagIds.isNotEmpty) {
      final placeholders = List.filled(filter.tagIds.length, '?').join(', ');
      clauses.add(
        'EXISTS (SELECT 1 FROM dive_tags dt '
        'WHERE dt.dive_id = d.id AND dt.tag_id IN ($placeholders))',
      );
      for (final tagId in filter.tagIds) {
        args.add(Variable(tagId));
      }
    }
    if (filter.weekdays.isNotEmpty) {
      // d.dive_date_time is wall-clock-as-UTC epoch ms, so strftime('%w', ...)
      // (0=Sunday..6=Saturday) already lines up with the wall-clock day.
      // Converting DateTime.weekday (1=Monday..7=Sunday) via `% 7` matches
      // that numbering, mirroring buildFilteredDiveIdSubquery.
      final placeholders = List.filled(filter.weekdays.length, '?').join(', ');
      clauses.add(
        "CAST(strftime('%w', d.dive_date_time / 1000, 'unixepoch') AS INTEGER) "
        'IN ($placeholders)',
      );
      for (final weekday in filter.weekdays) {
        args.add(Variable(weekday % 7));
      }
    }
    if (filter.equipmentIds.isNotEmpty) {
      final placeholders = List.filled(
        filter.equipmentIds.length,
        '?',
      ).join(', ');
      clauses.add(
        'EXISTS (SELECT 1 FROM dive_equipment de '
        'WHERE de.dive_id = d.id AND de.equipment_id IN ($placeholders))',
      );
      for (final eqId in filter.equipmentIds) {
        args.add(Variable(eqId));
      }
    }
    if (filter.buddyNameFilter != null && filter.buddyNameFilter!.isNotEmpty) {
      // The dive editor writes buddies only to the dive_buddies junction;
      // d.buddy is a legacy text column kept for old data (#757).
      final names = filter.buddyNameFilter!
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      for (final name in names) {
        clauses.add(
          '(LOWER(d.buddy) LIKE LOWER(?) OR '
          'EXISTS (SELECT 1 FROM dive_buddies db '
          'JOIN buddies b ON db.buddy_id = b.id '
          'WHERE db.dive_id = d.id AND LOWER(b.name) LIKE LOWER(?)))',
        );
        args.add(Variable('%$name%'));
        args.add(Variable('%$name%'));
      }
    }
    if (filter.buddyId != null) {
      clauses.add(
        'EXISTS (SELECT 1 FROM dive_buddies db '
        'WHERE db.dive_id = d.id AND db.buddy_id = ?)',
      );
      args.add(Variable(filter.buddyId!));
    }
    if (filter.diveIds.isNotEmpty) {
      final placeholders = List.filled(filter.diveIds.length, '?').join(', ');
      clauses.add('d.id IN ($placeholders)');
      for (final diveId in filter.diveIds) {
        args.add(Variable(diveId));
      }
    }
    if (filter.computerId != null) {
      clauses.add('d.computer_id = ?');
      args.add(Variable(filter.computerId!));
    }
    if (filter.minO2Percent != null || filter.maxO2Percent != null) {
      final tankClauses = <String>[];
      if (filter.minO2Percent != null) {
        tankClauses.add('t.o2_percent >= ?');
        args.add(Variable(filter.minO2Percent!));
      }
      if (filter.maxO2Percent != null) {
        tankClauses.add('t.o2_percent <= ?');
        args.add(Variable(filter.maxO2Percent!));
      }
      clauses.add(
        'EXISTS (SELECT 1 FROM dive_tanks t '
        'WHERE t.dive_id = d.id AND ${tankClauses.join(' AND ')})',
      );
    }
    if (filter.minRating != null) {
      clauses.add('d.rating >= ?');
      args.add(Variable(filter.minRating!));
    }
    if (filter.minBottomTimeMinutes != null) {
      clauses.add('d.bottom_time >= ?');
      args.add(Variable(filter.minBottomTimeMinutes! * 60));
    }
    if (filter.maxBottomTimeMinutes != null) {
      clauses.add('d.bottom_time <= ?');
      args.add(Variable(filter.maxBottomTimeMinutes! * 60));
    }
    if (filter.customFieldKey != null && filter.customFieldKey!.isNotEmpty) {
      if (filter.customFieldValue != null &&
          filter.customFieldValue!.isNotEmpty) {
        clauses.add(
          'EXISTS (SELECT 1 FROM dive_custom_fields cf '
          'WHERE cf.dive_id = d.id AND cf.field_key = ? '
          'AND cf.field_value LIKE ?)',
        );
        args.add(Variable(filter.customFieldKey!));
        args.add(Variable('%${filter.customFieldValue}%'));
      } else {
        clauses.add(
          'EXISTS (SELECT 1 FROM dive_custom_fields cf '
          'WHERE cf.dive_id = d.id AND cf.field_key = ?)',
        );
        args.add(Variable(filter.customFieldKey!));
      }
    }
  }

  // ============================================================================
  // Query Operations
  // ============================================================================

  /// Get dives for a specific site
  Future<List<domain.Dive>> getDivesForSite(String siteId) async {
    try {
      final query = _db.select(_db.dives)
        ..where((t) => t.siteId.equals(siteId))
        ..orderBy([
          (t) => OrderingTerm.desc(coalesce([t.entryTime, t.diveDateTime])),
          (t) => OrderingTerm.desc(t.diveNumber),
        ]);

      final rows = await query.get();
      return await Future.wait(rows.map(_mapRowToDive));
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dives for site: $siteId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get dives for a specific training course
  Future<List<domain.Dive>> getDivesForCourse(String courseId) async {
    try {
      final query = _db.select(_db.dives)
        ..where((t) => t.courseId.equals(courseId))
        ..orderBy([
          (t) => OrderingTerm.desc(coalesce([t.entryTime, t.diveDateTime])),
          (t) => OrderingTerm.desc(t.diveNumber),
        ]);

      final rows = await query.get();
      return await Future.wait(rows.map(_mapRowToDive));
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dives for course: $courseId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get dives within a date range.
  ///
  /// Optionally filter by [diverId] for per-diver queries.
  Future<List<domain.Dive>> getDivesInRange(
    DateTime start,
    DateTime end, {
    String? diverId,
  }) async {
    try {
      final query = _db.select(_db.dives)
        ..where(
          (t) =>
              t.diveDateTime.isBiggerOrEqualValue(start.millisecondsSinceEpoch),
        )
        ..where(
          (t) =>
              t.diveDateTime.isSmallerOrEqualValue(end.millisecondsSinceEpoch),
        )
        ..orderBy([
          (t) => OrderingTerm.desc(coalesce([t.entryTime, t.diveDateTime])),
          (t) => OrderingTerm.desc(t.diveNumber),
        ]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return await Future.wait(rows.map(_mapRowToDive));
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dives in range: $start - $end',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Newest dive start time for [diverId], or null when the log is empty.
  ///
  /// Scoped strictly to [diverId]: `t.diverId.equals(diverId)` only, no
  /// `isNull()` fallback for legacy null-diverId dives. This matches every
  /// other diverId-scoped query against the `dives` table in this
  /// repository (see [getAllDives], [getDivesInRange], [getNextDiveNumber]),
  /// none of which OR in an isNull() arm. (Some other repositories -- e.g.
  /// pre-dive templates, checklists, safety records -- do fall back to
  /// isNull() for their own diverId columns, but that convention was never
  /// applied to the dives table itself.)
  Future<DateTime?> getNewestDiveDateTime({required String diverId}) async {
    final row =
        await (_db.select(_db.dives)
              ..where((t) => t.diverId.equals(diverId))
              ..orderBy([(t) => OrderingTerm.desc(t.diveDateTime)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(row.diveDateTime, isUtc: true);
  }

  /// Get the next dive number based on MAX(dive_number) + 1
  /// Optionally filter by [diverId] for per-diver numbering
  /// Note: This returns the next number after the highest existing number,
  /// which may not be chronologically correct. Use [getDiveNumberForDate]
  /// for chronologically-based numbering.
  // stats-scope-exempt: numbering integrity, must see every dive or it reuses a number
  Future<int> getNextDiveNumber({String? diverId}) async {
    try {
      final String sql;
      final List<Object> args;

      if (diverId != null) {
        sql =
            'SELECT MAX(dive_number) as max_num FROM dives WHERE diver_id = ?';
        args = [diverId];
      } else {
        sql = 'SELECT MAX(dive_number) as max_num FROM dives';
        args = [];
      }

      final result = await _db
          .customSelect(sql, variables: args.map((a) => Variable(a)).toList())
          .getSingle();

      final maxNum = result.data['max_num'] as int?;
      return (maxNum ?? 0) + 1;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get next dive number',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get the next dive number for a given date.
  ///
  /// Delegates to [getNextDiveNumber] (MAX + 1) to avoid duplicate numbers
  /// when importing from multiple computers with overlapping dates.
  Future<int> getDiveNumberForDate(
    DateTime dateTime, {
    String? diverId,
    int startFrom = 1,
  }) async {
    return getNextDiveNumber(diverId: diverId);
  }

  /// Search dives by name, notes, buddy, dive master, site name/country/
  /// region, dive center name, linked buddy names, tag names, or custom
  /// fields, returning lightweight [DiveSummary] rows.
  ///
  /// Exactly four SQL statements regardless of match count (match ids,
  /// summary rows, batched tags, batched dive types), bounded to the [limit]
  /// most recent matches ([kDiveSearchResultLimit] by default). Callers that
  /// need to detect truncation pass `limit + 1` and treat a full-length
  /// result as "more matches exist". Replaces the unbounded full-Dive-
  /// hydrating search whose roughly-ten-queries-per-match N+1 dominated
  /// search cost on large databases (docs/superpowers/specs/2026-07-10-
  /// large-db-performance-findings.md).
  // stats-scope-exempt: search results are a displayed list, like the logbook
  Future<List<DiveSummary>> searchDiveSummaries(
    String query, {
    String? diverId,
    int limit = kDiveSearchResultLimit,
    Set<String> disabledSafetyRules = const {},
  }) async {
    try {
      return await PerfTimer.measure('searchDiveSummaries', () async {
        // Empty/whitespace queries match everything ('%%'); the provider
        // already treats them as "no search", so return nothing here too.
        // Guarding limit <= 0 also avoids SQLite's negative-LIMIT (unbounded)
        // case, which would defeat the bound this method exists to enforce.
        final trimmed = query.trim();
        if (trimmed.isEmpty || limit <= 0) return <DiveSummary>[];
        // Match on the trimmed term so incidental leading/trailing whitespace
        // (e.g. "manta ") does not silently exclude otherwise-matching dives.
        final likeTerm = '%$trimmed%';
        final diverClause = diverId != null ? 'AND d.diver_id = ?' : '';
        final diverArgs = diverId != null
            ? [Variable<String>(diverId)]
            : <Variable<String>>[];

        final matchingIds = await _db
            .customSelect(
              '''
              SELECT DISTINCT d.id,
                COALESCE(d.entry_time, d.dive_date_time) AS sort_ts,
                d.dive_number AS dive_number
              FROM dives d
              LEFT JOIN dive_sites ds ON d.site_id = ds.id
              LEFT JOIN dive_centers dc ON d.dive_center_id = dc.id
              LEFT JOIN dive_buddies db ON db.dive_id = d.id
              LEFT JOIN buddies b ON db.buddy_id = b.id
              LEFT JOIN dive_tags dt ON dt.dive_id = d.id
              LEFT JOIN tags t ON dt.tag_id = t.id
              LEFT JOIN dive_custom_fields cf ON cf.dive_id = d.id
              WHERE (
                d.notes LIKE ?
                OR d.name LIKE ?
                OR d.buddy LIKE ?
                OR d.dive_master LIKE ?
                OR ds.name LIKE ?
                OR ds.country LIKE ?
                OR ds.region LIKE ?
                OR dc.name LIKE ?
                OR b.name LIKE ?
                OR t.name LIKE ?
                OR cf.field_key LIKE ?
                OR cf.field_value LIKE ?
              )
              $diverClause
              ORDER BY sort_ts DESC,
                COALESCE(d.dive_number, 0) DESC, d.id DESC
              LIMIT ?
              ''',
              variables: [
                for (var i = 0; i < 12; i++) Variable<String>(likeTerm),
                ...diverArgs,
                Variable<int>(limit),
              ],
            )
            .get();

        if (matchingIds.isEmpty) return <DiveSummary>[];

        final ids = matchingIds.map((r) => r.read<String>('id')).toList();
        return _summariesForIds(ids, disabledSafetyRules: disabledSafetyRules);
      });
    } catch (e, stackTrace) {
      _log.error(
        'Failed to search dive summaries: $query',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Loads [DiveSummary] rows for [ids] (slim SELECT plus batched tags and
  /// dive types), ordered most recent first.
  // stats-scope-exempt: hydrates rows for an already-chosen id set. It
  // SELECTS the exclusion columns for the list badge and must not filter on
  // them; whoever produced the ids decided what belongs.
  Future<List<DiveSummary>> _summariesForIds(
    List<String> ids, {
    Set<String> disabledSafetyRules = const {},
  }) async {
    final placeholders = List.filled(ids.length, '?').join(', ');
    // Count subquery lives in the SELECT list, so its placeholders bind BEFORE
    // the WHERE id args and must be prepended to the variable list.
    final (safetyCountFilter, safetyCountArgs) = _disabledRulesCountFilter(
      disabledSafetyRules,
    );
    final rows = await _db
        .customSelect(
          'SELECT '
          'd.id, d.dive_number, d.name AS dive_name, '
          'd.dive_date_time, d.entry_time, '
          'd.max_depth, d.bottom_time, d.runtime, d.water_temp, d.rating, '
          'd.is_favorite, d.excluded_from_stats, d.excluded_from_gas_stats, '
          'd.dive_type, d.dive_mode, '
          'COALESCE(d.entry_time, d.dive_date_time) AS sort_timestamp, '
          's.name AS site_name, s.country AS site_country, '
          's.region AS site_region, s.latitude AS site_latitude, '
          's.longitude AS site_longitude, '
          // Correlated count keyed by d.id so SQLite uses
          // idx_dive_safety_findings_dive_id and only counts findings for the
          // requested dives, instead of grouping the whole findings table.
          '(SELECT COUNT(*) FROM dive_safety_findings sf '
          'WHERE sf.dive_id = d.id AND sf.dismissed_at IS NULL'
          '$safetyCountFilter) '
          'AS safety_finding_count '
          'FROM dives d '
          'LEFT JOIN dive_sites s ON d.site_id = s.id '
          'WHERE d.id IN ($placeholders) '
          'ORDER BY sort_timestamp DESC, '
          'COALESCE(d.dive_number, 0) DESC, d.id DESC',
          variables: [
            ...safetyCountArgs,
            for (final id in ids) Variable<String>(id),
          ],
          readsFrom: {_db.dives, _db.diveSites, _db.diveSafetyFindings},
        )
        .get();

    if (rows.isEmpty) return [];

    final diveIds = rows.map((r) => r.read<String>('id')).toList();
    final tagsByDive = await _tagRepository.getTagsForDives(diveIds);
    final diveTypesByDive = await _diveTypesForDives(diveIds);
    return _mapSummaryRows(rows, tagsByDive, diveTypesByDive);
  }

  /// Shared row mapper for the summary SELECT column list (used by
  /// [getDiveSummaries] and [_summariesForIds]).
  List<DiveSummary> _mapSummaryRows(
    List<QueryRow> rows,
    Map<String, List<domain.Tag>> tagsByDive,
    Map<String, List<String>> diveTypesByDive,
  ) {
    return rows.map((row) {
      final id = row.read<String>('id');
      final entryTime = row.readNullable<int>('entry_time');
      final bottomTime = row.readNullable<int>('bottom_time');
      final runtime = row.readNullable<int>('runtime');

      return DiveSummary(
        id: id,
        diveNumber: row.readNullable<int>('dive_number'),
        name: row.readNullable<String>('dive_name'),
        dateTime: DateTime.fromMillisecondsSinceEpoch(
          row.read<int>('dive_date_time'),
          isUtc: true,
        ),
        entryTime: entryTime != null
            ? DateTime.fromMillisecondsSinceEpoch(entryTime, isUtc: true)
            : null,
        maxDepth: row.readNullable<double>('max_depth'),
        bottomTime: bottomTime != null ? Duration(seconds: bottomTime) : null,
        runtime: runtime != null ? Duration(seconds: runtime) : null,
        waterTemp: row.readNullable<double>('water_temp'),
        rating: row.readNullable<int>('rating'),
        isFavorite: row.read<int>('is_favorite') == 1,
        excludedFromStats: row.read<int>('excluded_from_stats') == 1,
        excludedFromGasStats: row.read<int>('excluded_from_gas_stats') == 1,
        diveMode: DiveMode.fromCode(row.read<String>('dive_mode')),
        diveTypeIds: diveTypesByDive[id] ?? [row.read<String>('dive_type')],
        tags: tagsByDive[id] ?? [],
        siteName: row.readNullable<String>('site_name'),
        siteCountry: row.readNullable<String>('site_country'),
        siteRegion: row.readNullable<String>('site_region'),
        siteLatitude: row.readNullable<double>('site_latitude'),
        siteLongitude: row.readNullable<double>('site_longitude'),
        sortTimestamp: row.read<int>('sort_timestamp'),
        safetyFindingCount: row.readNullable<int>('safety_finding_count') ?? 0,
      );
    }).toList();
  }

  // ============================================================================
  // Statistics
  // ============================================================================

  /// Get statistics for dives
  /// Optionally filter by [diverId] for per-diver statistics
  Future<DiveStatistics> getStatistics({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final whereClause = diverId != null ? 'WHERE diver_id = ?' : '';
      // Explicitly typed List<Variable<Object>>: a bare `[Variable<String>(...)]`
      // literal would reify as List<Variable<String>>, and the later
      // `vars.addAll(filterVars)` (filterVars is List<Variable<Object>>) would
      // then throw a runtime type error whenever diverId is non-null.
      final List<Variable<Object>> vars = [
        if (diverId != null) Variable<String>(diverId),
      ];

      final df = buildFilteredDiveIdSubquery(filter);
      // params are always non-null so `p!` is safe.
      final filterVars = df.params.map((p) => Variable<Object>(p!)).toList();
      // Clause fragments per table alias used below. The statistics scope is
      // unconditional; the diver's view filter is appended only when active.
      final scopeBare = DiveStatsScope.and(alias: 'dives');
      final scopeAliasD = DiveStatsScope.and(alias: 'd');
      final fBare = df.subquery.isEmpty
          ? scopeBare
          : '$scopeBare AND id IN (${df.subquery})';
      final fAliasD = df.subquery.isEmpty
          ? scopeAliasD
          : '$scopeAliasD AND d.id IN (${df.subquery})';
      // WHERE-prefix helpers so an empty base WHERE still starts correctly.
      // Always emits a WHERE now, because the scope is never empty.
      final basicWhere = whereClause.isEmpty
          ? 'WHERE 1=1 $fBare'
          : '$whereClause $fBare';
      vars.addAll(filterVars);

      // Basic stats
      final stats = await _db.customSelect('''
      SELECT
        COUNT(*) as total_dives,
        SUM(COALESCE(runtime, bottom_time)) as total_time,
        MAX(max_depth) as max_depth,
        AVG(max_depth) as avg_max_depth,
        AVG(water_temp) as avg_temp,
        COUNT(DISTINCT site_id) as total_sites,
        MIN(dive_date_time) as first_dive_date
      FROM dives
      $basicWhere
    ''', variables: vars).getSingle();

      // Dives by month (last 12 months)
      final monthlyWhereClause = diverId != null
          ? 'WHERE dive_date_time >= strftime(\'%s\', \'now\', \'-12 months\') * 1000 AND diver_id = ?'
          : 'WHERE dive_date_time >= strftime(\'%s\', \'now\', \'-12 months\') * 1000';
      final monthlyStats = await _db.customSelect('''
      SELECT
        strftime('%Y', dive_date_time / 1000, 'unixepoch') as year,
        strftime('%m', dive_date_time / 1000, 'unixepoch') as month,
        COUNT(*) as count
      FROM dives
      $monthlyWhereClause $fBare
      GROUP BY year, month
      ORDER BY year, month
    ''', variables: vars).get();

      final divesByMonth = monthlyStats
          .map(
            (row) => MonthlyDiveCount(
              year: int.parse(row.data['year'] as String),
              month: int.parse(row.data['month'] as String),
              count: row.data['count'] as int,
            ),
          )
          .toList();

      // Depth distribution: 10 m buckets from the surface to 130 m, plus an
      // open-ended bucket for anything deeper (issue #641). A dive lands in
      // a bucket by its max depth, the same rule the old 0-40 m version used.
      //
      // Per-bucket duration resolves the full `Dive.effectiveRuntime` chain
      // in SQL (see `effectiveRuntimeSecondsSql`) rather than the
      // `COALESCE(runtime, bottom_time)` shortcut this query used before,
      // which skipped the profile-derived step and reported a dive that only
      // has a profile as zero minutes. Bucketing stays in SQL so the whole
      // distribution comes back as at most 14 rows, not one row per dive.
      const depthBucketSizeMeters = 10;
      const depthBucketCount = 13; // 0-10m, 10-20m, ..., 120-130m
      final depthWhereClause = diverId != null
          ? 'WHERE d.max_depth IS NOT NULL AND d.diver_id = ?'
          : 'WHERE d.max_depth IS NOT NULL';
      // The inner CAST forces real division whatever affinity the column
      // value carries; the outer one truncates toward zero. Truncation is
      // not floor for a negative, so the MAX/MIN pair clamps both ends: a
      // stray negative depth lands in the first bucket, and anything at or
      // past 130 m lands in the open-ended last one.
      const depthBucketExpression =
          'MIN(MAX(CAST(CAST(d.max_depth AS REAL) / $depthBucketSizeMeters '
          'AS INTEGER), 0), $depthBucketCount)';
      final depthRows = await _db
          .customSelect(
            'SELECT $depthBucketExpression AS bucket, '
            'COUNT(*) AS count, '
            'SUM(${effectiveRuntimeSecondsSql('d')}) AS total_time '
            'FROM dives d '
            '$depthWhereClause $fAliasD '
            'GROUP BY bucket',
            variables: vars,
            readsFrom: {_db.dives, _db.diveProfileSeries},
          )
          .get();

      final bucketCounts = List<int>.filled(depthBucketCount + 1, 0);
      final bucketDurationSeconds = List<int>.filled(depthBucketCount + 1, 0);
      for (final row in depthRows) {
        final bucket = row.read<int>('bucket');
        bucketCounts[bucket] = row.read<int>('count');
        // NULL when every dive in the bucket is missing all four duration
        // sources, which reads as zero minutes logged at that depth.
        bucketDurationSeconds[bucket] =
            row.readNullable<int>('total_time') ?? 0;
      }

      final depthDistribution = [
        for (var i = 0; i < depthBucketCount; i++)
          DepthRangeStat(
            label:
                '${i * depthBucketSizeMeters}-${(i + 1) * depthBucketSizeMeters}m',
            minDepth: i * depthBucketSizeMeters,
            maxDepth: (i + 1) * depthBucketSizeMeters,
            count: bucketCounts[i],
            totalDurationSeconds: bucketDurationSeconds[i],
          ),
        DepthRangeStat(
          label: '${depthBucketCount * depthBucketSizeMeters}m+',
          minDepth: depthBucketCount * depthBucketSizeMeters,
          maxDepth: depthBucketCount * depthBucketSizeMeters,
          count: bucketCounts[depthBucketCount],
          totalDurationSeconds: bucketDurationSeconds[depthBucketCount],
          openEnded: true,
        ),
      ];

      // Top sites
      final siteWhereClause = diverId != null
          ? 'WHERE d.diver_id = ? $fAliasD'
          : 'WHERE 1=1 $fAliasD';
      final siteStats = await _db.customSelect('''
      SELECT
        s.id as site_id,
        s.name as site_name,
        COUNT(*) as dive_count
      FROM dives d
      INNER JOIN dive_sites s ON d.site_id = s.id
      $siteWhereClause
      GROUP BY d.site_id
      ORDER BY dive_count DESC
      LIMIT 5
    ''', variables: vars).get();

      final topSites = siteStats
          .map(
            (row) => TopSiteStat(
              siteId: row.data['site_id'] as String,
              siteName: row.data['site_name'] as String,
              diveCount: row.data['dive_count'] as int,
            ),
          )
          .toList();

      final firstDiveEpochMs = stats.data['first_dive_date'] as int?;
      final firstDiveDate = firstDiveEpochMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(firstDiveEpochMs, isUtc: true);

      return DiveStatistics(
        totalDives: stats.data['total_dives'] as int? ?? 0,
        totalTimeSeconds: stats.data['total_time'] as int? ?? 0,
        maxDepth: stats.data['max_depth'] as double? ?? 0,
        avgMaxDepth: stats.data['avg_max_depth'] as double? ?? 0,
        avgTemperature: stats.data['avg_temp'] as double?,
        totalSites: stats.data['total_sites'] as int? ?? 0,
        firstDiveDate: firstDiveDate,
        divesByMonth: divesByMonth,
        depthDistribution: depthDistribution,
        topSites: topSites,
      );
    } catch (e, stackTrace) {
      _log.error('Failed to get statistics', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get dive records (superlatives)
  ///
  /// Optionally filter by [diverId] for per-diver records, and by [filter] for
  /// a narrowed scope. Issue #1028: the Statistics tab shows these superlatives
  /// beside totals that already honour its filter, so a deepest dive drawn from
  /// the whole logbook contradicted the panel right above it.
  Future<DiveRecords> getRecords({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      // Explicitly typed List<Variable<Object>>: a bare `[Variable<String>(...)]`
      // literal would reify as List<Variable<String>>, and the later addAll of
      // the filter binds would then throw (mirrors getStatistics).
      final List<Variable<Object>> vars = [
        if (diverId != null) Variable<String>(diverId),
      ];
      final df = buildFilteredDiveIdSubquery(filter);
      // params are always non-null so `p!` is safe.
      vars.addAll(df.params.map((p) => Variable<Object>(p!)));

      // Every statement below binds the same `vars` list, so the diver `?` must
      // always precede the filter `?`s -- hence the fixed clause order.
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      // The statistics scope is unconditional: an excluded dive must never
      // surface as a personal record. The view filter is appended only when
      // the diver has active axes.
      final filterClause = df.subquery.isEmpty
          ? DiveStatsScope.and(alias: 'd')
          : '${DiveStatsScope.and(alias: 'd')} '
                'AND d.id IN (${df.subquery})';
      // The first/last statements have no WHERE of their own, so their scope
      // clauses have to open one. The scope predicate binds no placeholders,
      // so listing it first cannot disturb the fixed `?` order.
      final scopeConditions = [
        DiveStatsScope.predicate(alias: 'd'),
        if (diverId != null) 'd.diver_id = ?',
        if (df.subquery.isNotEmpty) 'd.id IN (${df.subquery})',
      ];
      final diverFilterFirst = 'WHERE ${scopeConditions.join(' AND ')}';

      // Deepest dive
      final deepestResult = await _db.customSelect('''
      SELECT d.*, s.name as site_name
      FROM dives d
      LEFT JOIN dive_sites s ON d.site_id = s.id
      WHERE d.max_depth IS NOT NULL $diverFilter $filterClause
      ORDER BY d.max_depth DESC
      LIMIT 1
    ''', variables: vars).getSingleOrNull();

      // Longest dive (by runtime, falling back to bottom_time)
      final longestResult = await _db.customSelect('''
      SELECT d.*, s.name as site_name,
        COALESCE(d.runtime, d.bottom_time) as effective_runtime
      FROM dives d
      LEFT JOIN dive_sites s ON d.site_id = s.id
      WHERE COALESCE(d.runtime, d.bottom_time) IS NOT NULL $diverFilter $filterClause
      ORDER BY effective_runtime DESC
      LIMIT 1
    ''', variables: vars).getSingleOrNull();

      // Coldest dive
      final coldestResult = await _db.customSelect('''
      SELECT d.*, s.name as site_name
      FROM dives d
      LEFT JOIN dive_sites s ON d.site_id = s.id
      WHERE d.water_temp IS NOT NULL $diverFilter $filterClause
      ORDER BY d.water_temp ASC
      LIMIT 1
    ''', variables: vars).getSingleOrNull();

      // Warmest dive
      final warmestResult = await _db.customSelect('''
      SELECT d.*, s.name as site_name
      FROM dives d
      LEFT JOIN dive_sites s ON d.site_id = s.id
      WHERE d.water_temp IS NOT NULL $diverFilter $filterClause
      ORDER BY d.water_temp DESC
      LIMIT 1
    ''', variables: vars).getSingleOrNull();

      // First dive
      final firstResult = await _db.customSelect('''
      SELECT d.*, s.name as site_name
      FROM dives d
      LEFT JOIN dive_sites s ON d.site_id = s.id
      $diverFilterFirst
      ORDER BY d.dive_date_time ASC
      LIMIT 1
    ''', variables: vars).getSingleOrNull();

      // Most recent dive
      final lastResult = await _db.customSelect('''
      SELECT d.*, s.name as site_name
      FROM dives d
      LEFT JOIN dive_sites s ON d.site_id = s.id
      $diverFilterFirst
      ORDER BY d.dive_date_time DESC
      LIMIT 1
    ''', variables: vars).getSingleOrNull();

      // Shallowest dive (with max_depth recorded)
      final shallowestResult = await _db.customSelect('''
      SELECT d.*, s.name as site_name
      FROM dives d
      LEFT JOIN dive_sites s ON d.site_id = s.id
      WHERE d.max_depth IS NOT NULL AND d.max_depth > 0 $diverFilter $filterClause
      ORDER BY d.max_depth ASC
      LIMIT 1
    ''', variables: vars).getSingleOrNull();

      return DiveRecords(
        deepestDive: deepestResult != null
            ? _mapRecordRow(deepestResult)
            : null,
        longestDive: longestResult != null
            ? _mapRecordRow(longestResult)
            : null,
        coldestDive: coldestResult != null
            ? _mapRecordRow(coldestResult)
            : null,
        warmestDive: warmestResult != null
            ? _mapRecordRow(warmestResult)
            : null,
        firstDive: firstResult != null ? _mapRecordRow(firstResult) : null,
        lastDive: lastResult != null ? _mapRecordRow(lastResult) : null,
        shallowestDive: shallowestResult != null
            ? _mapRecordRow(shallowestResult)
            : null,
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive records',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  DiveRecord _mapRecordRow(QueryRow row) {
    return DiveRecord(
      diveId: row.data['id'] as String,
      diveNumber: row.data['dive_number'] as int?,
      siteName: row.data['site_name'] as String?,
      dateTime: DateTime.fromMillisecondsSinceEpoch(
        row.data['dive_date_time'] as int,
        isUtc: true,
      ),
      maxDepth: row.data['max_depth'] as double?,
      bottomTime: row.data['bottom_time'] != null
          ? Duration(seconds: row.data['bottom_time'] as int)
          : null,
      runtime: row.data['runtime'] != null
          ? Duration(seconds: row.data['runtime'] as int)
          : null,
      waterTemp: row.data['water_temp'] as double?,
    );
  }

  /// Number of dives strictly after [since] (dashboard month / year-to-date
  /// counters): one COUNT statement instead of hydrating every dive.
  Future<int> countDivesSince(DateTime since, {String? diverId}) async {
    final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM dives '
          'WHERE dive_date_time > ? $diverFilter'
          '${DiveStatsScope.and(alias: 'dives')}',
          variables: [
            Variable<int>(since.millisecondsSinceEpoch),
            if (diverId != null) Variable<String>(diverId),
          ],
          readsFrom: {_db.dives},
        )
        .getSingle();
    return row.read<int>('c');
  }

  /// Dive ids from prior years sharing the given month/day ("on this
  /// day" dashboard card). Newest first, capped at [limit].
  Future<List<String>> getOnThisDayDiveIds({
    required int month,
    required int day,
    required int excludeYear,
    String? diverId,
    int limit = 5,
  }) async {
    final monthDay =
        "${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
    final diverFilter = diverId != null ? 'AND diver_id = ? ' : '';
    final rows = await _db
        .customSelect(
          "SELECT id FROM dives "
          "WHERE strftime('%m-%d', dive_date_time / 1000, 'unixepoch') = ? "
          "AND CAST(strftime('%Y', dive_date_time / 1000, 'unixepoch') "
          "AS INTEGER) != ? "
          "$diverFilter"
          "${DiveStatsScope.and(alias: 'dives')} "
          "ORDER BY dive_date_time DESC LIMIT ?",
          variables: [
            Variable<String>(monthDay),
            Variable<int>(excludeYear),
            if (diverId != null) Variable<String>(diverId),
            Variable<int>(limit),
          ],
          readsFrom: {_db.dives},
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toList();
  }

  /// SQL expression mirroring [domain.Dive.effectiveRuntime]'s resolution
  /// order in seconds: runtime, exit - entry (when positive), profile span,
  /// bottom time.
  ///
  /// Delegates to the shared fragment rather than spelling the chain out a
  /// second time. This constant and the statistics aggregates have to agree
  /// on what a dive's duration is, and two hand-written copies of a four-step
  /// COALESCE are how they stop agreeing.
  static final _effectiveRuntimeSql = effectiveRuntimeSecondsSql('d');

  /// Deterministic tie-break for the personal-record winners, matching the
  /// most-recent-first order [getAllDives] used before WS4: the old in-memory
  /// loops scanned that order with a strict `>` (`<` for coldest), so ties
  /// implicitly resolved to the most recent dive. Appending this keeps a tied
  /// depth/runtime/temperature on the same visible winner.
  static const _recencyTieBreak =
      'COALESCE(d.entry_time, d.dive_date_time) DESC, d.dive_number DESC';

  /// Winner ids for the dashboard personal records (deepest / longest /
  /// coldest / warmest) plus the most visited site: six small indexed
  /// statements. Callers hydrate the handful of winner dives individually
  /// instead of loading the whole table (WS4, large-DB performance).
  Future<
    ({
      String? deepestId,
      String? longestId,
      String? coldestId,
      String? warmestId,
      String? mostVisitedSiteId,
      String? mostVisitedSiteName,
      int? mostVisitedSiteCount,
    })
  >
  getPersonalRecordIds({String? diverId}) async {
    final vars = diverId != null
        ? [Variable<String>(diverId)]
        : <Variable<Object>>[];
    // The statistics scope rides along with the diver filter, which every
    // statement below already interpolates: an excluded or planned dive must
    // never win a personal record.
    final diverFilter = diverId != null
        ? 'AND d.diver_id = ?${DiveStatsScope.and(alias: 'd')}'
        : DiveStatsScope.and(alias: 'd');

    Future<String?> winner(String where, String orderBy) async {
      final row = await _db
          .customSelect(
            'SELECT d.id FROM dives d WHERE $where $diverFilter '
            'ORDER BY $orderBy LIMIT 1',
            variables: vars,
            readsFrom: {_db.dives, _db.diveProfileSeries},
          )
          .getSingleOrNull();
      return row?.read<String>('id');
    }

    // The > 0 guards mirror the old in-memory loops' strict-greater seeding
    // (a lone dive with zero depth/runtime produced no record).
    final deepestId = await winner(
      'd.max_depth IS NOT NULL AND d.max_depth > 0',
      'd.max_depth DESC, $_recencyTieBreak',
    );
    // Longest evaluates the effective-runtime expression (a correlated
    // dive_profile_series subquery) once in a derived table and orders on
    // the alias, rather than paying for the subquery twice (WHERE + ORDER BY)
    // -- this is the dashboard hot path the PR is optimizing.
    final longestRow = await _db
        .customSelect(
          'SELECT id FROM ('
          'SELECT d.id AS id, $_effectiveRuntimeSql AS er, '
          'COALESCE(d.entry_time, d.dive_date_time) AS recency, '
          'd.dive_number AS dn FROM dives d WHERE 1 = 1 $diverFilter'
          ') WHERE er > 0 ORDER BY er DESC, recency DESC, dn DESC LIMIT 1',
          variables: vars,
          readsFrom: {_db.dives, _db.diveProfileSeries},
        )
        .getSingleOrNull();
    final longestId = longestRow?.read<String>('id');
    final coldestId = await winner(
      'd.water_temp IS NOT NULL',
      'd.water_temp ASC, $_recencyTieBreak',
    );
    final warmestId = await winner(
      'd.water_temp IS NOT NULL',
      'd.water_temp DESC, $_recencyTieBreak',
    );

    // On a count tie, keep the site whose most recent dive is latest -- the
    // old loop scanned most-recent-first and kept the first site to reach the
    // max count, i.e. the one owning the newest dive among the tied sites. The
    // trailing site_id is a final deterministic key so an exact recency tie
    // cannot flap across SQLite query plans.
    final siteRow = await _db
        .customSelect(
          'SELECT d.site_id AS site_id, s.name AS site_name, COUNT(*) AS c '
          'FROM dives d JOIN dive_sites s ON d.site_id = s.id '
          'WHERE d.site_id IS NOT NULL $diverFilter '
          'GROUP BY d.site_id ORDER BY c DESC, '
          'MAX(COALESCE(d.entry_time, d.dive_date_time)) DESC, d.site_id '
          'LIMIT 1',
          variables: vars,
          readsFrom: {_db.dives, _db.diveSites},
        )
        .getSingleOrNull();

    return (
      deepestId: deepestId,
      longestId: longestId,
      coldestId: coldestId,
      warmestId: warmestId,
      mostVisitedSiteId: siteRow?.readNullable<String>('site_id'),
      mostVisitedSiteName: siteRow?.readNullable<String>('site_name'),
      mostVisitedSiteCount: siteRow?.readNullable<int>('c'),
    );
  }

  // ============================================================================
  // Mapping Helpers
  // ============================================================================

  /// Map dive row to domain entity with pre-loaded related data (for batch loading)
  domain.Dive _mapRowToDiveWithPreloadedData(
    Dive row, {
    required List<DiveTank> tanks,
    required List<EquipmentItem> equipment,
    DiveSite? site,
    DiveCenter? center,
    Trip? trip,
    List<domain.Tag> tags = const [],
    List<String>? diveTypeIds,
    List<domain.DiveCustomField> customFields = const [],
    List<domain.BuddyWithRole> buddies = const [],
  }) {
    // Map site if exists
    final domainSite = site == null ? null : mapDiveSiteRow(site);

    // Map dive center if exists
    domain.DiveCenter? domainCenter;
    if (center != null) {
      domainCenter = domain.DiveCenter(
        id: center.id,
        name: center.name,
        street: center.street,
        city: center.city,
        stateProvince: center.stateProvince,
        postalCode: center.postalCode,
        latitude: center.latitude,
        longitude: center.longitude,
        country: center.country,
        phone: center.phone,
        email: center.email,
        website: center.website,
        affiliations:
            center.affiliations
                ?.split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
        rating: center.rating,
        notes: center.notes,
        createdAt: DateTime.fromMillisecondsSinceEpoch(center.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(center.updatedAt),
      );
    }

    // Map trip if exists
    domain.Trip? domainTrip;
    if (trip != null) {
      domainTrip = domain.Trip(
        id: trip.id,
        name: trip.name,
        startDate: DateTime.fromMillisecondsSinceEpoch(trip.startDate),
        endDate: DateTime.fromMillisecondsSinceEpoch(trip.endDate),
        location: trip.location,
        resortName: trip.resortName,
        liveaboardName: trip.liveaboardName,
        notes: trip.notes,
        createdAt: DateTime.fromMillisecondsSinceEpoch(trip.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(trip.updatedAt),
      );
    }

    return domain.Dive(
      id: row.id,
      diverId: row.diverId,
      diveNumber: row.diveNumber,
      dateTime: DateTime.fromMillisecondsSinceEpoch(
        row.diveDateTime,
        isUtc: true,
      ),
      entryTime: row.entryTime != null
          ? DateTime.fromMillisecondsSinceEpoch(row.entryTime!, isUtc: true)
          : null,
      exitTime: row.exitTime != null
          ? DateTime.fromMillisecondsSinceEpoch(row.exitTime!, isUtc: true)
          : null,
      bottomTime: row.bottomTime != null
          ? Duration(seconds: row.bottomTime!)
          : null,
      runtime: row.runtime != null ? Duration(seconds: row.runtime!) : null,
      maxDepth: row.maxDepth,
      avgDepth: row.avgDepth,
      entryLocation: row.entryLatitude != null && row.entryLongitude != null
          ? domain.GeoPoint(row.entryLatitude!, row.entryLongitude!)
          : null,
      exitLocation: row.exitLatitude != null && row.exitLongitude != null
          ? domain.GeoPoint(row.exitLatitude!, row.exitLongitude!)
          : null,
      waterTemp: row.waterTemp,
      airTemp: row.airTemp,
      visibility: row.visibility != null
          ? Visibility.values.firstWhere(
              (v) => v.name == row.visibility,
              orElse: () => Visibility.unknown,
            )
          : null,
      visibilityMeters: row.visibilityMeters,
      diveTypeIds: diveTypeIds ?? [row.diveType],
      buddy: row.buddy,
      diveMaster: row.diveMaster,
      buddies: buddies,
      diverRoleId: row.diverRole,
      notes: row.notes,
      name: row.name,
      site: domainSite,
      diveCenter: domainCenter,
      trip: domainTrip,
      tripId: row.tripId,
      rating: row.rating,
      currentDirection: row.currentDirection != null
          ? CurrentDirection.values.firstWhere(
              (c) => c.name == row.currentDirection,
              orElse: () => CurrentDirection.none,
            )
          : null,
      currentStrength: row.currentStrength != null
          ? CurrentStrength.values.firstWhere(
              (c) => c.name == row.currentStrength,
              orElse: () => CurrentStrength.none,
            )
          : null,
      swellHeight: row.swellHeight,
      entryMethod: row.entryMethod != null
          ? EntryMethod.values.firstWhere(
              (e) => e.name == row.entryMethod,
              orElse: () => EntryMethod.other,
            )
          : null,
      exitMethod: row.exitMethod != null
          ? EntryMethod.values.firstWhere(
              (e) => e.name == row.exitMethod,
              orElse: () => EntryMethod.other,
            )
          : null,
      waterType: row.waterType != null
          ? WaterType.values.firstWhere(
              (w) => w.name == row.waterType,
              orElse: () => WaterType.salt,
            )
          : null,
      altitude: row.altitude,
      surfacePressure: row.surfacePressure,
      surfaceInterval: row.surfaceIntervalSeconds != null
          ? Duration(seconds: row.surfaceIntervalSeconds!)
          : null,
      gradientFactorLow: row.gradientFactorLow,
      gradientFactorHigh: row.gradientFactorHigh,
      decoAlgorithm: row.decoAlgorithm,
      decoConservatism: row.decoConservatism,
      diveComputerModel: row.diveComputerModel,
      diveComputerSerial: row.diveComputerSerial,
      diveComputerFirmware: row.diveComputerFirmware,
      computerId: row.computerId,
      weightAmount: row.weightAmount,
      weightType: row.weightType != null
          ? WeightType.values.firstWhere(
              (w) => w.name == row.weightType,
              orElse: () => WeightType.belt,
            )
          : null,
      weightingFeedback: row.weightingFeedback != null
          ? WeightingFeedback.values.firstWhere(
              (f) => f.name == row.weightingFeedback,
              orElse: () => WeightingFeedback.correct,
            )
          : null,
      weightingFeedbackKg: row.weightingFeedbackKg,
      // Weather conditions
      windSpeed: row.windSpeed,
      windDirection: row.windDirection != null
          ? CurrentDirection.values.firstWhere(
              (c) => c.name == row.windDirection,
              orElse: () => CurrentDirection.none,
            )
          : null,
      cloudCover: row.cloudCover != null
          ? CloudCover.values.firstWhere(
              (c) => c.name == row.cloudCover,
              orElse: () => CloudCover.clear,
            )
          : null,
      precipitation: row.precipitation != null
          ? Precipitation.values.firstWhere(
              (p) => p.name == row.precipitation,
              orElse: () => Precipitation.none,
            )
          : null,
      humidity: row.humidity,
      weatherDescription: row.weatherDescription,
      weatherCode: row.weatherCode,
      weatherSource: row.weatherSource != null
          ? WeatherSource.values.firstWhere(
              (w) => w.name == row.weatherSource,
              orElse: () => WeatherSource.manual,
            )
          : null,
      weatherFetchedAt: row.weatherFetchedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.weatherFetchedAt! * 1000)
          : null,
      tanks: tanks
          .map(
            (t) => domain.DiveTank(
              id: t.id,
              name: t.tankName,
              volume: t.volume,
              workingPressure: t.workingPressure,
              startPressure: t.startPressure,
              endPressure: t.endPressure,
              gasMix: domain.GasMix(o2: t.o2Percent, he: t.hePercent),
              role: TankRole.values.firstWhere(
                (r) => r.name == t.tankRole,
                orElse: () => TankRole.backGas,
              ),
              material: t.tankMaterial != null
                  ? TankMaterial.values.firstWhere(
                      (m) => m.name == t.tankMaterial,
                      orElse: () => TankMaterial.aluminum,
                    )
                  : null,
              order: t.tankOrder,
              presetName: t.presetName,
              computerId: t.computerId,
            ),
          )
          .toList(),
      profile: const [], // Profile not loaded for list views
      equipment: equipment,
      weights: const [], // Weights not loaded for list views (use detail view)
      isFavorite: row.isFavorite,
      excludedFromStats: row.excludedFromStats,
      excludedFromGasStats: row.excludedFromGasStats,
      tags: tags,
      // CCR/SCR rebreather fields (v1.5)
      diveMode: DiveMode.fromCode(row.diveMode),
      setpointLow: row.setpointLow,
      setpointHigh: row.setpointHigh,
      setpointDeco: row.setpointDeco,
      scrType: ScrType.fromCode(row.scrType),
      scrInjectionRate: row.scrInjectionRate,
      scrAdditionRatio: row.scrAdditionRatio,
      scrOrificeSize: row.scrOrificeSize,
      assumedVo2: row.assumedVo2,
      diluentGas: row.diluentO2 != null
          ? domain.GasMix(o2: row.diluentO2!, he: row.diluentHe ?? 0)
          : null,
      loopO2Min: row.loopO2Min,
      loopO2Max: row.loopO2Max,
      loopO2Avg: row.loopO2Avg,
      loopVolume: row.loopVolume,
      scrubber: row.scrubberType != null
          ? domain.ScrubberInfo(
              type: row.scrubberType!,
              ratedMinutes: row.scrubberDurationMinutes,
              remainingMinutes: row.scrubberRemainingMinutes,
            )
          : null,
      // Dive planner (v1.5)
      isPlanned: row.isPlanned,
      // Training course (v1.5)
      courseId: row.courseId,
      // Import source tracking
      importSource: row.importSource,
      importId: row.importId,
      // User-defined custom fields
      customFields: customFields,
    );
  }

  /// The band a sample temperature has to fall in to be believed, Celsius.
  ///
  /// The same one every other temperature path applies (the v36 water_temp
  /// backfill in database.dart, and the four UDDF import checks): a computer
  /// with no thermistor, or a transmitter standing in for one, reports a
  /// sentinel such as -128, and taking the raw minimum would put that on the
  /// dive. `isFinite` covers the decoder's own NaN/infinity.
  static const double _minPlausibleWaterTempC = -2;
  static const double _maxPlausibleWaterTempC = 40;

  /// Minimum plausible sample temperature across [points], for a dive whose
  /// `water_temp` column is unset. Some imports populate per-sample
  /// temperature but miss the dive-level field. Returns null when [points]
  /// carries no usable temperature.
  static double? _minProfileTemp(List<domain.DiveProfilePoint> points) {
    double? min;
    for (final point in points) {
      final temp = point.temperature;
      if (temp == null ||
          !temp.isFinite ||
          temp < _minPlausibleWaterTempC ||
          temp > _maxPlausibleWaterTempC) {
        continue;
      }
      if (min == null || temp < min) min = temp;
    }
    return min;
  }

  /// Legacy method that loads all related data for a single dive (used for detail views)
  Future<domain.Dive> _mapRowToDive(Dive row) async {
    // Get tanks for this dive
    final tanksQuery = _db.select(_db.diveTanks)
      ..where((t) => t.diveId.equals(row.id))
      ..orderBy([(t) => OrderingTerm.asc(t.tankOrder)]);
    final tankRows = await tanksQuery.get();

    // Get per-tank pressure data to derive start/end pressure when the dive
    // computer provided time-series readings.
    final tankSeries = await _tankSeries.getSeriesForDive(row.id);
    final startPressureByTank = <String, double>{};
    final endPressureByTank = <String, double>{};
    final byTank = <String, List<dynamic>>{};
    for (final s in tankSeries) {
      byTank.putIfAbsent(s.tankId, () => []).add(s);
    }
    for (final entry in byTank.entries) {
      final merged = mergeTankSeriesPoints(entry.value.cast());
      if (merged.isEmpty) continue;
      startPressureByTank[entry.key] = merged.first.pressure;
      endPressureByTank[entry.key] = merged.last.pressure;
    }

    // Get profile for this dive from [_mergedSeriesPoints].
    // [getMergedProfile] mirrors this read and the two must stay in step.
    final seriesProfile = await _mergedSeriesPoints(row.id);

    // Get equipment for this dive
    final equipmentQuery = _db.select(_db.diveEquipment).join([
      innerJoin(
        _db.equipment,
        _db.equipment.id.equalsExp(_db.diveEquipment.equipmentId),
      ),
    ])..where(_db.diveEquipment.diveId.equals(row.id));
    final equipmentRows = await equipmentQuery.get();
    final equipmentItems = equipmentRows.map((joinRow) {
      final e = joinRow.readTable(_db.equipment);
      return EquipmentItem(
        id: e.id,
        name: e.name,
        type: EquipmentType.values.firstWhere(
          (t) => t.name == e.type,
          orElse: () => EquipmentType.other,
        ),
        brand: e.brand,
        model: e.model,
        serialNumber: e.serialNumber,
        status: EquipmentStatus.values.firstWhere(
          (s) => s.name == e.status,
          orElse: () => EquipmentStatus.active,
        ),
        purchaseDate: e.purchaseDate != null
            ? DateTime.fromMillisecondsSinceEpoch(e.purchaseDate!)
            : null,
        purchasePrice: e.purchasePrice,
        purchaseCurrency: e.purchaseCurrency,
        lastServiceDate: e.lastServiceDate != null
            ? DateTime.fromMillisecondsSinceEpoch(e.lastServiceDate!)
            : null,
        serviceIntervalDays: e.serviceIntervalDays,
        notes: e.notes,
        isActive: e.isActive,
      );
    }).toList();
    final singleDiveEquipmentAttrs = await _equipmentAttributesFor(
      equipmentItems.map((i) => i.id),
    );
    final hydratedEquipmentItems = equipmentItems
        .map(
          (i) => i.copyWith(
            attributes: singleDiveEquipmentAttrs[i.id] ?? const [],
          ),
        )
        .toList();

    // Get weights for this dive
    final weights = await _loadWeightsForDive(row.id);

    // Get custom fields for this dive
    final customFields = await _loadCustomFieldsForDive(row.id);

    // Get site if exists
    domain.DiveSite? site;
    if (row.siteId != null) {
      final siteQuery = _db.select(_db.diveSites)
        ..where((t) => t.id.equals(row.siteId!));
      final siteRow = await siteQuery.getSingleOrNull();
      if (siteRow != null) {
        site = mapDiveSiteRow(siteRow);
      }
    }

    // Get dive center if exists
    domain.DiveCenter? diveCenter;
    if (row.diveCenterId != null) {
      final centerQuery = _db.select(_db.diveCenters)
        ..where((t) => t.id.equals(row.diveCenterId!));
      final centerRow = await centerQuery.getSingleOrNull();
      if (centerRow != null) {
        diveCenter = domain.DiveCenter(
          id: centerRow.id,
          name: centerRow.name,
          street: centerRow.street,
          city: centerRow.city,
          stateProvince: centerRow.stateProvince,
          postalCode: centerRow.postalCode,
          latitude: centerRow.latitude,
          longitude: centerRow.longitude,
          country: centerRow.country,
          phone: centerRow.phone,
          email: centerRow.email,
          website: centerRow.website,
          affiliations:
              centerRow.affiliations
                  ?.split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList() ??
              [],
          rating: centerRow.rating,
          notes: centerRow.notes,
          createdAt: DateTime.fromMillisecondsSinceEpoch(centerRow.createdAt),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(centerRow.updatedAt),
        );
      }
    }

    // Get trip if exists
    domain.Trip? trip;
    if (row.tripId != null) {
      final tripQuery = _db.select(_db.trips)
        ..where((t) => t.id.equals(row.tripId!));
      final tripRow = await tripQuery.getSingleOrNull();
      if (tripRow != null) {
        trip = domain.Trip(
          id: tripRow.id,
          name: tripRow.name,
          startDate: DateTime.fromMillisecondsSinceEpoch(tripRow.startDate),
          endDate: DateTime.fromMillisecondsSinceEpoch(tripRow.endDate),
          location: tripRow.location,
          resortName: tripRow.resortName,
          liveaboardName: tripRow.liveaboardName,
          notes: tripRow.notes,
          createdAt: DateTime.fromMillisecondsSinceEpoch(tripRow.createdAt),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(tripRow.updatedAt),
        );
      }
    }

    // Get tags for this dive
    final tags = await _tagRepository.getTagsForDive(row.id);
    final diveTypesByDive = await _diveTypesForDives([row.id]);
    final diveTypeIds = diveTypesByDive[row.id] ?? [row.diveType];

    // Derive waterTemp from the profile if not set on the dive row. Some
    // imports populate per-sample temperature but miss the dive-level field.
    final effectiveWaterTemp = row.waterTemp ?? _minProfileTemp(seriesProfile);

    return domain.Dive(
      id: row.id,
      diverId: row.diverId,
      diveNumber: row.diveNumber,
      dateTime: DateTime.fromMillisecondsSinceEpoch(
        row.diveDateTime,
        isUtc: true,
      ),
      entryTime: row.entryTime != null
          ? DateTime.fromMillisecondsSinceEpoch(row.entryTime!, isUtc: true)
          : null,
      exitTime: row.exitTime != null
          ? DateTime.fromMillisecondsSinceEpoch(row.exitTime!, isUtc: true)
          : null,
      bottomTime: row.bottomTime != null
          ? Duration(seconds: row.bottomTime!)
          : null,
      runtime: row.runtime != null ? Duration(seconds: row.runtime!) : null,
      maxDepth: row.maxDepth,
      avgDepth: row.avgDepth,
      entryLocation: row.entryLatitude != null && row.entryLongitude != null
          ? domain.GeoPoint(row.entryLatitude!, row.entryLongitude!)
          : null,
      exitLocation: row.exitLatitude != null && row.exitLongitude != null
          ? domain.GeoPoint(row.exitLatitude!, row.exitLongitude!)
          : null,
      waterTemp: effectiveWaterTemp,
      airTemp: row.airTemp,
      visibility: row.visibility != null
          ? Visibility.values.firstWhere(
              (v) => v.name == row.visibility,
              orElse: () => Visibility.unknown,
            )
          : null,
      visibilityMeters: row.visibilityMeters,
      diveTypeIds: diveTypeIds,
      buddy: row.buddy,
      diveMaster: row.diveMaster,
      diverRoleId: row.diverRole,
      notes: row.notes,
      name: row.name,
      site: site,
      diveCenter: diveCenter,
      trip: trip,
      tripId: row.tripId,
      rating: row.rating,
      // Conditions fields
      currentDirection: row.currentDirection != null
          ? CurrentDirection.values.firstWhere(
              (c) => c.name == row.currentDirection,
              orElse: () => CurrentDirection.none,
            )
          : null,
      currentStrength: row.currentStrength != null
          ? CurrentStrength.values.firstWhere(
              (c) => c.name == row.currentStrength,
              orElse: () => CurrentStrength.none,
            )
          : null,
      swellHeight: row.swellHeight,
      entryMethod: row.entryMethod != null
          ? EntryMethod.values.firstWhere(
              (e) => e.name == row.entryMethod,
              orElse: () => EntryMethod.other,
            )
          : null,
      exitMethod: row.exitMethod != null
          ? EntryMethod.values.firstWhere(
              (e) => e.name == row.exitMethod,
              orElse: () => EntryMethod.other,
            )
          : null,
      waterType: row.waterType != null
          ? WaterType.values.firstWhere(
              (w) => w.name == row.waterType,
              orElse: () => WaterType.salt,
            )
          : null,
      altitude: row.altitude,
      surfacePressure: row.surfacePressure,
      surfaceInterval: row.surfaceIntervalSeconds != null
          ? Duration(seconds: row.surfaceIntervalSeconds!)
          : null,
      gradientFactorLow: row.gradientFactorLow,
      gradientFactorHigh: row.gradientFactorHigh,
      decoAlgorithm: row.decoAlgorithm,
      decoConservatism: row.decoConservatism,
      diveComputerModel: row.diveComputerModel,
      diveComputerSerial: row.diveComputerSerial,
      diveComputerFirmware: row.diveComputerFirmware,
      computerId: row.computerId,
      // Weight system fields
      weightAmount: row.weightAmount,
      weightType: row.weightType != null
          ? WeightType.values.firstWhere(
              (w) => w.name == row.weightType,
              orElse: () => WeightType.belt,
            )
          : null,
      weightingFeedback: row.weightingFeedback != null
          ? WeightingFeedback.values.firstWhere(
              (f) => f.name == row.weightingFeedback,
              orElse: () => WeightingFeedback.correct,
            )
          : null,
      weightingFeedbackKg: row.weightingFeedbackKg,
      // Weather conditions
      windSpeed: row.windSpeed,
      windDirection: row.windDirection != null
          ? CurrentDirection.values.firstWhere(
              (c) => c.name == row.windDirection,
              orElse: () => CurrentDirection.none,
            )
          : null,
      cloudCover: row.cloudCover != null
          ? CloudCover.values.firstWhere(
              (c) => c.name == row.cloudCover,
              orElse: () => CloudCover.clear,
            )
          : null,
      precipitation: row.precipitation != null
          ? Precipitation.values.firstWhere(
              (p) => p.name == row.precipitation,
              orElse: () => Precipitation.none,
            )
          : null,
      humidity: row.humidity,
      weatherDescription: row.weatherDescription,
      weatherCode: row.weatherCode,
      weatherSource: row.weatherSource != null
          ? WeatherSource.values.firstWhere(
              (w) => w.name == row.weatherSource,
              orElse: () => WeatherSource.manual,
            )
          : null,
      weatherFetchedAt: row.weatherFetchedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.weatherFetchedAt! * 1000)
          : null,
      tanks: tankRows.map((t) {
        return domain.DiveTank(
          id: t.id,
          name: t.tankName,
          volume: t.volume,
          workingPressure: t.workingPressure,
          startPressure: t.startPressure ?? startPressureByTank[t.id],
          endPressure: t.endPressure ?? endPressureByTank[t.id],
          gasMix: domain.GasMix(o2: t.o2Percent, he: t.hePercent),
          role: TankRole.values.firstWhere(
            (r) => r.name == t.tankRole,
            orElse: () => TankRole.backGas,
          ),
          material: t.tankMaterial != null
              ? TankMaterial.values.firstWhere(
                  (m) => m.name == t.tankMaterial,
                  orElse: () => TankMaterial.aluminum,
                )
              : null,
          order: t.tankOrder,
          presetName: t.presetName,
          computerId: t.computerId,
        );
      }).toList(),
      profile: seriesProfile,
      equipment: hydratedEquipmentItems,
      weights: weights,
      isFavorite: row.isFavorite,
      excludedFromStats: row.excludedFromStats,
      excludedFromGasStats: row.excludedFromGasStats,
      tags: tags,
      // CCR/SCR rebreather fields (v1.5)
      diveMode: DiveMode.fromCode(row.diveMode),
      setpointLow: row.setpointLow,
      setpointHigh: row.setpointHigh,
      setpointDeco: row.setpointDeco,
      scrType: ScrType.fromCode(row.scrType),
      scrInjectionRate: row.scrInjectionRate,
      scrAdditionRatio: row.scrAdditionRatio,
      scrOrificeSize: row.scrOrificeSize,
      assumedVo2: row.assumedVo2,
      diluentGas: row.diluentO2 != null
          ? domain.GasMix(o2: row.diluentO2!, he: row.diluentHe ?? 0)
          : null,
      loopO2Min: row.loopO2Min,
      loopO2Max: row.loopO2Max,
      loopO2Avg: row.loopO2Avg,
      loopVolume: row.loopVolume,
      scrubber: row.scrubberType != null
          ? domain.ScrubberInfo(
              type: row.scrubberType!,
              ratedMinutes: row.scrubberDurationMinutes,
              remainingMinutes: row.scrubberRemainingMinutes,
            )
          : null,
      // Dive planner (v1.5)
      isPlanned: row.isPlanned,
      // Training course (v1.5)
      courseId: row.courseId,
      // Import source tracking
      importSource: row.importSource,
      importId: row.importId,
      // User-defined custom fields
      customFields: customFields,
    );
  }

  // ============================================================================
  // Import ID Operations
  // ============================================================================

  /// Get all import IDs that have already been imported.
  ///
  /// Used for fast duplicate detection during imports.
  Future<Set<String>> getImportIds({String? diverId}) async {
    final query = _db.selectOnly(_db.dives)
      ..addColumns([_db.dives.importId])
      ..where(_db.dives.importId.isNotNull());
    if (diverId != null) {
      query.where(_db.dives.diverId.equals(diverId));
    }
    final rows = await query.get();
    return rows
        .map((row) => row.read(_db.dives.importId))
        .whereType<String>()
        .toSet();
  }

  // ============================================================================
  // Favorite Operations
  // ============================================================================

  /// Toggle favorite status for a dive
  Future<void> toggleFavorite(String diveId) async {
    try {
      _log.info('Toggling favorite for dive: $diveId');
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.customStatement(
        '''
        UPDATE dives SET is_favorite = NOT is_favorite, updated_at = ?
        WHERE id = ?
      ''',
        [now, diveId],
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Toggled favorite for dive: $diveId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to toggle favorite for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Set favorite status for a dive
  Future<void> setFavorite(String diveId, bool isFavorite) async {
    try {
      _log.info('Setting favorite=$isFavorite for dive: $diveId');
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        DivesCompanion(isFavorite: Value(isFavorite), updatedAt: Value(now)),
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Set favorite=$isFavorite for dive: $diveId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set favorite for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get all favorite dives
  Future<List<domain.Dive>> getFavoriteDives({String? diverId}) async {
    try {
      final query = _db.select(_db.dives)
        ..where((t) => t.isFavorite.equals(true))
        ..orderBy([
          (t) => OrderingTerm.desc(coalesce([t.entryTime, t.diveDateTime])),
          (t) => OrderingTerm.desc(t.diveNumber),
        ]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return await Future.wait(rows.map(_mapRowToDive));
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get favorite dives',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // Planned Dive Operations (v1.5)
  // ============================================================================

  /// Get all planned dives (not yet executed)
  Future<List<domain.Dive>> getPlannedDives({String? diverId}) async {
    try {
      final query = _db.select(_db.dives)
        ..where((t) => t.isPlanned.equals(true))
        ..orderBy([
          (t) => OrderingTerm.desc(coalesce([t.entryTime, t.diveDateTime])),
        ]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return await Future.wait(rows.map(_mapRowToDive));
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get planned dives',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Create a new planned dive
  Future<domain.Dive> createPlannedDive(domain.Dive plan) async {
    try {
      // Ensure isPlanned is true
      final plannedDive = plan.copyWith(isPlanned: true);
      return await createDive(plannedDive);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create planned dive',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Convert a planned dive to an actual dive
  /// Sets isPlanned to false and optionally updates the dateTime
  Future<String> convertPlanToActualDive(
    String planId, {
    DateTime? actualDateTime,
  }) async {
    try {
      _log.info('Converting planned dive to actual: $planId');

      // Get the planned dive first
      final plannedDive = await getDiveById(planId);
      if (plannedDive == null) {
        throw Exception('Planned dive not found: $planId');
      }

      if (!plannedDive.isPlanned) {
        throw Exception('Dive is not a planned dive: $planId');
      }

      // Get next dive number for the actual dive
      final diveNumber = await getNextDiveNumber(diverId: plannedDive.diverId);

      // Update the dive to mark it as actual
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.dives)..where((t) => t.id.equals(planId))).write(
        DivesCompanion(
          isPlanned: const Value(false),
          diveDateTime: actualDateTime != null
              ? Value(actualDateTime.millisecondsSinceEpoch)
              : const Value.absent(),
          entryTime: actualDateTime != null
              ? Value(actualDateTime.millisecondsSinceEpoch)
              : const Value.absent(),
          diveNumber: Value(diveNumber),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: planId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Converted planned dive to actual: $planId');
      return planId;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to convert planned dive: $planId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a planned dive
  Future<void> deletePlannedDive(String planId) async {
    try {
      _log.info('Deleting planned dive: $planId');

      // Verify it's a planned dive
      final dive = await getDiveById(planId);
      if (dive == null) {
        throw Exception('Planned dive not found: $planId');
      }

      if (!dive.isPlanned) {
        throw Exception('Dive is not a planned dive: $planId');
      }

      // Delete using existing delete method
      await deleteDive(planId);
      _log.info('Deleted planned dive: $planId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete planned dive: $planId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Load weights for a dive
  Future<List<domain.DiveWeight>> _loadWeightsForDive(String diveId) async {
    try {
      final query = _db.select(_db.diveWeights)
        ..where((w) => w.diveId.equals(diveId));
      final rows = await query.get();
      return rows
          .map(
            (row) => domain.DiveWeight(
              id: row.id,
              diveId: row.diveId,
              weightType: WeightType.values.firstWhere(
                (w) => w.name == row.weightType,
                orElse: () => WeightType.belt,
              ),
              amountKg: row.amountKg,
              notes: row.notes,
            ),
          )
          .toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to load weights for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Load custom fields for a dive
  Future<List<domain.DiveCustomField>> _loadCustomFieldsForDive(
    String diveId,
  ) async {
    try {
      return await _customFieldRepository.getFieldsForDive(diveId);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to load custom fields for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // ============================================================================
  // Gas Switch Operations
  // ============================================================================

  /// Get gas switches for a dive, ordered by timestamp
  /// Returns gas switches with full tank info for display purposes
  Future<List<GasSwitchWithTank>> getGasSwitchesForDive(String diveId) async {
    try {
      // Join gas_switches with dive_tanks to get full tank info
      final query =
          _db.select(_db.gasSwitches).join([
              innerJoin(
                _db.diveTanks,
                _db.diveTanks.id.equalsExp(_db.gasSwitches.tankId),
              ),
            ])
            ..where(_db.gasSwitches.diveId.equals(diveId))
            ..orderBy([OrderingTerm.asc(_db.gasSwitches.timestamp)]);

      final rows = await query.get();
      return rows.map((row) {
        final gs = row.readTable(_db.gasSwitches);
        final tank = row.readTable(_db.diveTanks);

        return GasSwitchWithTank(
          gasSwitch: GasSwitch(
            id: gs.id,
            diveId: gs.diveId,
            timestamp: gs.timestamp,
            tankId: gs.tankId,
            depth: gs.depth,
            createdAt: DateTime.fromMillisecondsSinceEpoch(gs.createdAt),
          ),
          tankName: tank.tankName ?? 'Tank ${tank.tankOrder + 1}',
          gasMix: _formatGasMixName(tank.o2Percent, tank.hePercent),
          o2Fraction: tank.o2Percent / 100.0,
          heFraction: tank.hePercent / 100.0,
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get gas switches for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Format gas mix as a readable name (e.g., "Air", "EAN32", "Tx 21/35")
  String _formatGasMixName(double o2, double he) {
    return domain.GasMix(o2: o2, he: he).name;
  }

  /// Create a gas switch record
  Future<GasSwitch> createGasSwitch(GasSwitch gasSwitch) async {
    try {
      final id = gasSwitch.id.isEmpty ? _uuid.v4() : gasSwitch.id;
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db
          .into(_db.gasSwitches)
          .insert(
            GasSwitchesCompanion(
              id: Value(id),
              diveId: Value(gasSwitch.diveId),
              timestamp: Value(gasSwitch.timestamp),
              tankId: Value(gasSwitch.tankId),
              depth: Value(gasSwitch.depth),
              createdAt: Value(now),
            ),
          );

      await _syncRepository.markRecordPending(
        entityType: 'gasSwitches',
        recordId: id,
        localUpdatedAt: now,
      );
      await (_db.update(_db.dives)..where((t) => t.id.equals(gasSwitch.diveId)))
          .write(DivesCompanion(updatedAt: Value(now)));
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: gasSwitch.diveId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Created gas switch for dive: ${gasSwitch.diveId}');
      return gasSwitch.copyWith(id: id);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create gas switch',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a gas switch
  Future<void> deleteGasSwitch(String id) async {
    try {
      final existing = await (_db.select(
        _db.gasSwitches,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      await (_db.delete(_db.gasSwitches)..where((t) => t.id.equals(id))).go();
      if (existing != null) {
        await _syncRepository.logDeletion(
          entityType: 'gasSwitches',
          recordId: existing.id,
        );
        final now = DateTime.now().millisecondsSinceEpoch;
        await (_db.update(_db.dives)
              ..where((t) => t.id.equals(existing.diveId)))
            .write(DivesCompanion(updatedAt: Value(now)));
        await _syncRepository.markRecordPending(
          entityType: 'dives',
          recordId: existing.diveId,
          localUpdatedAt: now,
        );
      }
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted gas switch: $id');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete gas switch: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete all gas switches for a dive
  Future<void> deleteGasSwitchesForDive(String diveId) async {
    try {
      final existing = await (_db.select(
        _db.gasSwitches,
      )..where((t) => t.diveId.equals(diveId))).get();
      await (_db.delete(
        _db.gasSwitches,
      )..where((t) => t.diveId.equals(diveId))).go();
      for (final row in existing) {
        await _syncRepository.logDeletion(
          entityType: 'gasSwitches',
          recordId: row.id,
        );
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        DivesCompanion(updatedAt: Value(now)),
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted gas switches for dive: $diveId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete gas switches for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Bulk insert gas switches (for dive computer imports)
  Future<void> insertGasSwitches(List<GasSwitch> switches) async {
    if (switches.isEmpty) return;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final diveIds = <String>{};
      for (final gs in switches) {
        final id = gs.id.isEmpty ? _uuid.v4() : gs.id;
        diveIds.add(gs.diveId);
        await _db
            .into(_db.gasSwitches)
            .insert(
              GasSwitchesCompanion(
                id: Value(id),
                diveId: Value(gs.diveId),
                timestamp: Value(gs.timestamp),
                tankId: Value(gs.tankId),
                depth: Value(gs.depth),
                createdAt: Value(now),
              ),
            );
        await _syncRepository.markRecordPending(
          entityType: 'gasSwitches',
          recordId: id,
          localUpdatedAt: now,
        );
      }
      for (final diveId in diveIds) {
        await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
          DivesCompanion(updatedAt: Value(now)),
        );
        await _syncRepository.markRecordPending(
          entityType: 'dives',
          recordId: diveId,
          localUpdatedAt: now,
        );
      }
      SyncEventBus.notifyLocalChange();
      _log.info('Inserted ${switches.length} gas switches');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to bulk insert gas switches',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // Profile Event Operations
  // ============================================================================

  /// Bulk insert profile events (for dive computer imports and analysis results)
  Future<void> insertProfileEvents(List<ProfileEvent> events) async {
    if (events.isEmpty) return;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final diveIds = <String>{};
      for (final event in events) {
        final id = event.id.isEmpty ? _uuid.v4() : event.id;
        diveIds.add(event.diveId);
        // Drift's default conflict mode is `insertOrFail` — duplicate IDs
        // throw. Callers are expected to pass unique IDs (either freshly
        // generated via _uuid.v4() or from domain entities that assigned them);
        // the `event.id.isEmpty ? _uuid.v4()` guard above covers the most
        // common case where the caller hasn't assigned an ID yet.
        await _db
            .into(_db.diveProfileEvents)
            .insert(
              DiveProfileEventsCompanion(
                id: Value(id),
                diveId: Value(event.diveId),
                timestamp: Value(event.timestamp),
                eventType: Value(event.eventType.name),
                severity: Value(event.severity.name),
                description: Value(event.description),
                depth: Value(event.depth),
                value: Value(event.value),
                tankId: Value(event.tankId),
                source: Value(event.source.name),
                // Preserve the domain entity's own createdAt (e.g., from dive computer
                // clock) rather than substituting wall-clock `now` — unlike GasSwitches,
                // profile events carry meaningful source timestamps used for sync dedup.
                createdAt: Value(event.createdAt.millisecondsSinceEpoch),
              ),
            );
        await _syncRepository.markRecordPending(
          entityType: 'diveProfileEvents',
          recordId: id,
          localUpdatedAt: now,
        );
      }
      for (final diveId in diveIds) {
        await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
          DivesCompanion(updatedAt: Value(now)),
        );
        await _syncRepository.markRecordPending(
          entityType: 'dives',
          recordId: diveId,
          localUpdatedAt: now,
        );
      }
      SyncEventBus.notifyLocalChange();
      _log.info('Inserted ${events.length} profile events');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to bulk insert profile events',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get all profile events for a dive, ordered by timestamp ascending
  Future<List<ProfileEvent>> getProfileEventsForDive(String diveId) async {
    try {
      final rows =
          await (_db.select(_db.diveProfileEvents)
                ..where((t) => t.diveId.equals(diveId))
                ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
              .get();
      return rows.map(mapDiveProfileEventToProfileEvent).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get profile events for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Delete all profile events for a dive
  Future<void> deleteProfileEventsForDive(String diveId) async {
    try {
      final existing = await (_db.select(
        _db.diveProfileEvents,
      )..where((t) => t.diveId.equals(diveId))).get();
      await (_db.delete(
        _db.diveProfileEvents,
      )..where((t) => t.diveId.equals(diveId))).go();
      for (final row in existing) {
        await _syncRepository.logDeletion(
          entityType: 'diveProfileEvents',
          recordId: row.id,
        );
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        DivesCompanion(updatedAt: Value(now)),
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted profile events for dive: $diveId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete profile events for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // Surface Interval Operations
  // ============================================================================

  /// Lightweight trailing-window query for the flying-after-diving
  /// classifier: end time (exit time, else entry/date + runtime) plus a
  /// had-deco flag derived from the recorded profile series (a recorded
  /// deco stop or a positive ceiling on any series of the dive).
  // stats-scope-exempt: flying-after-diving safety, an excluded dive still off-gassed
  Future<List<NoFlyDiveInput>> getNoFlyDiveInputs({
    required DateTime since,
    String? diverId,
  }) async {
    try {
      final diverClause = diverId != null ? 'AND d.diver_id = ?' : '';
      final rows = await _db
          .customSelect(
            'SELECT '
            'COALESCE(d.exit_time, '
            'COALESCE(d.entry_time, d.dive_date_time) '
            '+ COALESCE(d.runtime, 0) * 1000) AS end_ms, '
            'EXISTS(SELECT 1 FROM dive_profile_series s WHERE s.dive_id = d.id '
            'AND (s.has_deco_stop = 1 OR s.has_positive_ceiling = 1)) '
            'AS had_deco '
            'FROM dives d '
            'WHERE COALESCE(d.exit_time, '
            'COALESCE(d.entry_time, d.dive_date_time) '
            '+ COALESCE(d.runtime, 0) * 1000) >= ? '
            '$diverClause',
            variables: [
              Variable(since.millisecondsSinceEpoch),
              if (diverId != null) Variable(diverId),
            ],
            readsFrom: {_db.dives, _db.diveProfileSeries},
          )
          .get();
      return [
        for (final row in rows)
          NoFlyDiveInput(
            endTime: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('end_ms'),
              isUtc: true,
            ),
            hadDecoObligation: row.read<int>('had_deco') == 1,
          ),
      ];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to load no-fly dive inputs',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get the previous dive (by entry time) for surface interval calculation
  /// Returns null if this is the first dive
  Future<domain.Dive?> getPreviousDive(String diveId) async {
    try {
      // First get the current dive's entry time
      final currentDive = await getDiveById(diveId);
      if (currentDive == null) return null;

      final entryTime = currentDive.entryTime ?? currentDive.dateTime;

      // Find the most recent dive that ended before this one started
      final query = _db.select(_db.dives)
        ..where((t) => t.id.isNotValue(diveId))
        ..where(
          (t) =>
              t.entryTime.isSmallerThanValue(entryTime.millisecondsSinceEpoch) |
              (t.entryTime.isNull() &
                  t.diveDateTime.isSmallerThanValue(
                    entryTime.millisecondsSinceEpoch,
                  )),
        )
        ..orderBy([
          (t) => OrderingTerm.desc(t.entryTime),
          (t) => OrderingTerm.desc(t.diveDateTime),
        ])
        ..limit(1);

      final rows = await query.get();
      if (rows.isEmpty) return null;

      return await _mapRowToDive(rows.first);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get previous dive for: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Calculate surface interval between this dive and the previous dive
  /// Returns null if there is no previous dive
  ///
  /// Runs on the times-only projection ([getDiveTimes] /
  /// [getPreviousDiveTimes]) rather than full hydration: the formula needs
  /// only timestamps and effective runtime, and this method sits on the
  /// residual-decompression lookback hot path (WS2, large-DB performance).
  // stats-scope-exempt: physiological interval between real dives, not a statistic
  Future<Duration?> getSurfaceInterval(String diveId) async {
    try {
      final current = await getDiveTimes(diveId);
      if (current == null) return null;

      final previous = await getPreviousDiveTimes(diveId);
      if (previous == null) return null;

      // Calculate interval: from previous dive exit to current dive entry
      final previousExitTime =
          previous.exitTime ??
          (previous.entryTime ?? previous.dateTime).add(
            previous.effectiveRuntime ?? Duration.zero,
          );
      final currentEntryTime = current.entryTime ?? current.dateTime;

      final interval = currentEntryTime.difference(previousExitTime);
      return interval.isNegative ? Duration.zero : interval;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to calculate surface interval for: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Shared SELECT for the times-only dive projection. The scalar subquery
  /// carries the profile-derived runtime fallback so
  /// [DiveTimes.effectiveRuntime] can mirror [domain.Dive.effectiveRuntime]
  /// without loading profile rows.
  ///
  /// Every caller here reads a single dive or a short range, so the subquery
  /// runs a bounded number of times. Aggregates that scan the whole dive
  /// table use [effectiveRuntimeSecondsSql] instead, which resolves the same
  /// chain but short-circuits past the profile scan.
  static const _diveTimesSelect =
      'SELECT d.id, d.dive_date_time, d.entry_time, d.exit_time, '
      'd.runtime, d.bottom_time, '
      '(SELECT MAX(s.end_timestamp) - MIN(s.start_timestamp) '
      'FROM dive_profile_series s WHERE s.dive_id = d.id) AS profile_span '
      'FROM dives d';

  domain.DiveTimes _mapDiveTimesRow(QueryRow row) {
    final entry = row.readNullable<int>('entry_time');
    final exit = row.readNullable<int>('exit_time');
    final runtime = row.readNullable<int>('runtime');
    final bottom = row.readNullable<int>('bottom_time');
    final span = row.readNullable<int>('profile_span');
    return domain.DiveTimes(
      id: row.read<String>('id'),
      dateTime: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('dive_date_time'),
        isUtc: true,
      ),
      entryTime: entry != null
          ? DateTime.fromMillisecondsSinceEpoch(entry, isUtc: true)
          : null,
      exitTime: exit != null
          ? DateTime.fromMillisecondsSinceEpoch(exit, isUtc: true)
          : null,
      runtime: runtime != null ? Duration(seconds: runtime) : null,
      bottomTime: bottom != null ? Duration(seconds: bottom) : null,
      // Matches Dive.calculateRuntimeFromProfile: null unless positive.
      profileSpan: span != null && span > 0 ? Duration(seconds: span) : null,
    );
  }

  /// Times-only projection of one dive: a single SQL statement.
  Future<domain.DiveTimes?> getDiveTimes(String diveId) async {
    final rows = await _db
        .customSelect(
          '$_diveTimesSelect WHERE d.id = ?',
          variables: [Variable<String>(diveId)],
          readsFrom: {_db.dives, _db.diveProfileSeries},
        )
        .get();
    if (rows.isEmpty) return null;
    return _mapDiveTimesRow(rows.first);
  }

  /// Times-only equivalent of [getPreviousDive] (identical predicate and
  /// ordering), for lookback chains that need only id and timestamps.
  Future<domain.DiveTimes?> getPreviousDiveTimes(String diveId) async {
    final current = await getDiveTimes(diveId);
    if (current == null) return null;

    final cutoff =
        (current.entryTime ?? current.dateTime).millisecondsSinceEpoch;
    final rows = await _db
        .customSelect(
          '$_diveTimesSelect '
          'WHERE d.id != ? AND (d.entry_time < ? OR '
          '(d.entry_time IS NULL AND d.dive_date_time < ?)) '
          'ORDER BY d.entry_time DESC, d.dive_date_time DESC LIMIT 1',
          variables: [
            Variable<String>(diveId),
            Variable<int>(cutoff),
            Variable<int>(cutoff),
          ],
          readsFrom: {_db.dives, _db.diveProfileSeries},
        )
        .get();
    if (rows.isEmpty) return null;
    return _mapDiveTimesRow(rows.first);
  }

  /// Times-only equivalent of [getDivesInRange] (identical WHERE and
  /// ordering), for same-day and weekly exposure aggregation.
  Future<List<domain.DiveTimes>> getDiveTimesInRange(
    DateTime start,
    DateTime end, {
    String? diverId,
  }) async {
    final clauses = <String>['d.dive_date_time >= ?', 'd.dive_date_time <= ?'];
    final args = <Variable<Object>>[
      Variable<int>(start.millisecondsSinceEpoch),
      Variable<int>(end.millisecondsSinceEpoch),
    ];
    if (diverId != null) {
      clauses.add('d.diver_id = ?');
      args.add(Variable<String>(diverId));
    }
    final rows = await _db
        .customSelect(
          '$_diveTimesSelect WHERE ${clauses.join(' AND ')} '
          'ORDER BY COALESCE(d.entry_time, d.dive_date_time) DESC, '
          'd.dive_number DESC',
          variables: args,
          readsFrom: {_db.dives, _db.diveProfileSeries},
        )
        .get();
    return rows.map(_mapDiveTimesRow).toList();
  }

  /// All profile samples for [diveId] across every source, ordered by
  /// timestamp (one SQL statement, two for an edited dive). Matches the shape
  /// of `Dive.profile`.
  ///
  /// Every source is kept -- this is NOT the `isPrimary`-filtered view used by
  /// [getDiveProfile] -- except for the originals a profile edit superseded,
  /// which [dropSupersededSeries] removes. It mirrors the profile read in
  /// [getDiveById] exactly: [getDiveForAnalysis] must feed the analysis
  /// pipeline the same samples the `diveProvider` -> [getDiveById] path
  /// shows, which the parity test locks in. Any change to that merge
  /// semantics must be made in both places together rather than diverging
  /// here.
  Future<List<domain.DiveProfilePoint>> getMergedProfile(String diveId) async {
    return _mergedSeriesPoints(diveId);
  }

  /// Merged profiles for many dives, keyed by dive id.
  ///
  /// The batch form of [getMergedProfile], for the PDF exporter: [getAllDives]
  /// skips profile hydration for performance, so a logbook export has to load
  /// profiles itself, and doing that one dive at a time is an N+1 query.
  ///
  /// Deliberately not the `primaryOnly` read. That keeps only `is_primary`
  /// series, and per #623 a file-imported dive can end up with no primary
  /// series at all, which would render a blank chart for exactly the dives
  /// imported from another logbook. Sharing [_pointsForSeries] with
  /// [getMergedProfile] is what keeps the export and the on-screen chart on
  /// the same samples: every source, minus the originals a saved edit
  /// superseded.
  ///
  /// Dives with no samples are absent from the result rather than mapped to an
  /// empty list. [ProfileSeriesRepository.getSeriesForDives] chunks the id
  /// list so the `IN` clause stays bounded, but the returned map still holds
  /// every sample of every id passed in: a caller that cares about peak memory
  /// should call this in batches and reduce each batch before requesting the
  /// next (see `_buildLogbookPdfBytes`).
  Future<Map<String, List<domain.DiveProfilePoint>>> getMergedProfilesForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return {};

    final byDive = await _profileSeries.getSeriesForDives(diveIds);

    // The primary-source read is the only SQL the per-dive merge performs, and
    // only for mixed-source dives. Batching it here keeps the loop below free
    // of round trips, so a bulk export costs two statements rather than one
    // per dive.
    final primaries = await _primarySourceComputers([
      for (final entry in byDive.entries)
        if (_needsPrimarySource(entry.value)) entry.key,
    ]);

    final result = <String, List<domain.DiveProfilePoint>>{};
    for (final entry in byDive.entries) {
      // Absent for a dive that never needed the lookup, which resolves the
      // same way the single-dive path does when it skips the query.
      final primary = primaries[entry.key];
      final points = _mergePoints(
        entry.value,
        hasSources: primary?.hasSources ?? true,
        primaryComputerId: primary?.computerId,
      );
      if (points.isNotEmpty) result[entry.key] = points;
    }
    return result;
  }

  /// The merged profile from series rows; an empty list when [diveId] has
  /// none.
  ///
  /// Shared by [getMergedProfile] and [_mapRowToDive] so `getDiveById`,
  /// [getMergedProfile], and [getDiveForAnalysis] return the same list by
  /// construction (the parity test locks this in). Every source is kept,
  /// except the demoted originals a saved edit superseded
  /// ([dropSupersededSeries]).
  Future<List<domain.DiveProfilePoint>> _mergedSeriesPoints(
    String diveId,
  ) async {
    return _pointsForSeries(
      diveId,
      await _profileSeries.getSeriesForDive(diveId),
    );
  }

  /// [series] reduced to the points a reader should see: the superseded
  /// originals of a saved edit dropped, then every remaining source's samples
  /// interleaved by timestamp.
  ///
  /// Takes the series rather than reading them so [getMergedProfilesForDives]
  /// can batch the read and still land on the same points as the single-dive
  /// path. The extra [_primarySourceComputer] query is skipped unless a
  /// demoted series actually carries a computer id, which is the only case
  /// where the primary computer decides family membership; a single-source
  /// dive resolves with no further SQL.
  Future<List<domain.DiveProfilePoint>> _pointsForSeries(
    String diveId,
    List<ProfileSeries> series,
  ) async {
    var hasSources = true;
    String? primaryComputerId;
    if (_needsPrimarySource(series)) {
      final primary = await _primarySourceComputer(diveId);
      hasSources = primary.hasSources;
      primaryComputerId = primary.computerId;
    }
    return _mergePoints(
      series,
      hasSources: hasSources,
      primaryComputerId: primaryComputerId,
    );
  }

  /// Whether [series] needs the primary `dive_data_sources` row to resolve.
  ///
  /// Only a promoted series alongside a demoted one that still names a
  /// computer lets the primary computer decide family membership; a
  /// single-source dive resolves with no further SQL. Shared by the
  /// single-dive and batched paths so the condition cannot drift.
  bool _needsPrimarySource(List<ProfileSeries> series) =>
      series.any((s) => s.isPrimary) &&
      series.any((s) => !s.isPrimary && s.computerId != null);

  /// [series] reduced to displayable points. Pure: every read it depends on
  /// has already happened.
  List<domain.DiveProfilePoint> _mergePoints(
    List<ProfileSeries> series, {
    required bool hasSources,
    required String? primaryComputerId,
  }) => mergeSeriesPointsCollapsingDuplicates(
    dropSupersededSeries(
      series,
      hasSources: hasSources,
      primaryComputerId: primaryComputerId,
    ),
  );

  /// The computer owning [diveId]'s primary data source, and whether the dive
  /// has any `dive_data_sources` rows to read that from.
  Future<({bool hasSources, String? computerId})> _primarySourceComputer(
    String diveId,
  ) async {
    return _primaryFromRows(
      await (_db.select(
        _db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get(),
    );
  }

  /// [_primarySourceComputer] for many dives in one statement.
  ///
  /// The per-dive read is the only SQL [_pointsForSeries] performs, so
  /// hoisting it out of [getMergedProfilesForDives] turns that loop into pure
  /// computation instead of one round trip per dive.
  ///
  /// Every requested id gets an entry: a dive with no `dive_data_sources` rows
  /// answers `hasSources: false`, which is what decides family membership, so
  /// a missing key would silently read as "has sources".
  Future<Map<String, ({bool hasSources, String? computerId})>>
  _primarySourceComputers(List<String> diveIds) async {
    if (diveIds.isEmpty) return const {};

    final rows = <DiveDataSourcesData>[];
    for (final chunk in seriesIdChunks(diveIds)) {
      rows.addAll(
        await (_db.select(
          _db.diveDataSources,
        )..where((t) => t.diveId.isIn(chunk))).get(),
      );
    }

    final byDive = <String, List<DiveDataSourcesData>>{};
    for (final row in rows) {
      byDive.putIfAbsent(row.diveId, () => []).add(row);
    }

    return {
      for (final id in diveIds) id: _primaryFromRows(byDive[id] ?? const []),
    };
  }

  /// The primary-source answer for one dive's `dive_data_sources` [rows].
  ///
  /// Ordering happens here rather than in SQL so the batched read and the
  /// single-dive read collapse duplicate computers in the same order, which is
  /// what keeps the export and the on-screen chart on the same samples.
  ({bool hasSources, String? computerId}) _primaryFromRows(
    List<DiveDataSourcesData> rows,
  ) {
    final ordered = [...rows]
      ..sort((a, b) {
        if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
        return a.createdAt.compareTo(b.createdAt);
      });
    final sourceRows = _canonicalDataSourceRows(ordered);
    if (sourceRows.isEmpty) return (hasSources: false, computerId: null);
    return (hasSources: true, computerId: sourceRows.first.computerId);
  }

  /// Lean hydration for decompression/exposure analysis: the dive row's
  /// scalars plus tanks and the merged profile (three SQL statements).
  /// Joined display entities (site, center, trip, equipment, weights, tags,
  /// dive types, custom fields) are left at their defaults -- the analysis
  /// pipeline reads only row scalars, tanks, and profile (see the WS2
  /// findings doc). Never use the result for display.
  Future<domain.Dive?> getDiveForAnalysis(String diveId) async {
    try {
      final row = await (_db.select(
        _db.dives,
      )..where((t) => t.id.equals(diveId))).getSingleOrNull();
      if (row == null) return null;

      final tankRows =
          await (_db.select(_db.diveTanks)
                ..where((t) => t.diveId.equals(diveId))
                ..orderBy([(t) => OrderingTerm.asc(t.tankOrder)]))
              .get();
      final profile = await getMergedProfile(diveId);

      return _mapRowToDiveWithPreloadedData(
        row,
        tanks: tankRows,
        equipment: const [],
      ).copyWith(profile: profile);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive for analysis: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // Dive Numbering Operations
  // ============================================================================

  /// Get all dive numbers with gaps detected
  /// Returns a list of DiveNumberInfo including gaps
  Future<DiveNumberingInfo> getDiveNumberingInfo({String? diverId}) async {
    try {
      final query = _db.select(_db.dives)
        ..orderBy([
          (t) => OrderingTerm.asc(t.entryTime),
          (t) => OrderingTerm.asc(t.diveDateTime),
        ]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();

      final dives = <DiveNumberEntry>[];
      final gaps = <DiveNumberGap>[];

      int? lastNumber;
      for (final row in rows) {
        final entryTime = row.entryTime != null
            ? DateTime.fromMillisecondsSinceEpoch(row.entryTime!, isUtc: true)
            : DateTime.fromMillisecondsSinceEpoch(
                row.diveDateTime,
                isUtc: true,
              );

        dives.add(
          DiveNumberEntry(
            diveId: row.id,
            currentNumber: row.diveNumber,
            entryTime: entryTime,
          ),
        );

        // Check for gaps
        if (row.diveNumber != null && lastNumber != null) {
          final expected = lastNumber + 1;
          if (row.diveNumber! > expected) {
            gaps.add(
              DiveNumberGap(
                afterDiveId: dives.length > 1
                    ? dives[dives.length - 2].diveId
                    : null,
                missingStart: expected,
                missingEnd: row.diveNumber! - 1,
              ),
            );
          }
        }
        lastNumber = row.diveNumber;
      }

      return DiveNumberingInfo(
        dives: dives,
        gaps: gaps,
        hasGaps: gaps.isNotEmpty,
        hasUnnumbered: dives.any((d) => d.currentNumber == null),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive numbering info',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Renumber all dives sequentially based on entry time
  /// [startFrom] - The starting dive number (default 1)
  /// [diverId] - If non-null, only renumbers dives belonging to this diver.
  /// Dive numbers are a per-diver lifetime counter, so callers editing a
  /// single diver's numbering must pass their ID or the other diver's
  /// sequence will be overwritten.
  Future<void> renumberAllDives({int startFrom = 1, String? diverId}) async {
    try {
      _log.info(
        'Renumbering dives starting from $startFrom'
        '${diverId != null ? ' for diver $diverId' : ''}',
      );

      final query = _db.select(_db.dives)
        ..orderBy([
          (t) => OrderingTerm.asc(t.entryTime),
          (t) => OrderingTerm.asc(t.diveDateTime),
        ]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();

      int number = startFrom;
      for (final row in rows) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await (_db.update(_db.dives)..where((t) => t.id.equals(row.id))).write(
          DivesCompanion(diveNumber: Value(number), updatedAt: Value(now)),
        );
        await _syncRepository.markRecordPending(
          entityType: 'dives',
          recordId: row.id,
          localUpdatedAt: now,
        );
        number++;
      }

      SyncEventBus.notifyLocalChange();
      _log.info('Renumbered ${rows.length} dives');
    } catch (e, stackTrace) {
      _log.error('Failed to renumber dives', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Fill gaps in dive numbers by renumbering all dives chronologically
  /// This ensures dive numbers match chronological order
  /// [diverId] - If non-null, only operates on that diver's dives. The
  /// MIN(dive_number) used as the starting point is also scoped, so each
  /// diver preserves their own numbering baseline.
  // stats-scope-exempt: renumbering integrity, must see every dive
  Future<void> assignMissingDiveNumbers({String? diverId}) async {
    try {
      _log.info(
        'Assigning missing dive numbers by renumbering chronologically'
        '${diverId != null ? ' for diver $diverId' : ''}',
      );

      // Find the minimum existing dive number to preserve as the starting point.
      // Scope by diverId so one diver's baseline doesn't override another's.
      final minResult = diverId != null
          ? await _db
                .customSelect(
                  'SELECT MIN(dive_number) as min_num FROM dives '
                  'WHERE dive_number IS NOT NULL AND diver_id = ?',
                  variables: [Variable<String>(diverId)],
                )
                .getSingleOrNull()
          : await _db
                .customSelect(
                  'SELECT MIN(dive_number) as min_num FROM dives '
                  'WHERE dive_number IS NOT NULL',
                )
                .getSingleOrNull();

      final startFrom = (minResult?.data['min_num'] as int?) ?? 1;

      await renumberAllDives(startFrom: startFrom, diverId: diverId);

      _log.info(
        'Dive numbers assigned chronologically starting from $startFrom',
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to assign missing dive numbers',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // Bulk Operations
  // ============================================================================

  /// Bulk-set the columns present in [partial] on every dive in [diveIds].
  /// Absent columns are left untouched (Drift writes only present columns).
  /// Forces `updatedAt = now` and marks each dive pending. Does NOT open a
  /// transaction or notify sync — BulkDiveEditService owns those.
  Future<void> bulkUpdateFields(
    List<String> diveIds,
    DivesCompanion partial,
  ) async {
    // No-op when there's nothing to write; an all-absent companion must not
    // produce a sync-visible "touch" (updatedAt bump + pending mark).
    if (diveIds.isEmpty || partial.toColumns(false).isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.dives)..where((t) => t.id.isIn(diveIds))).write(
      partial.copyWith(updatedAt: Value(now)),
    );
    for (final diveId in diveIds) {
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
    }
  }

  /// Append [textToAppend] to the notes of every dive in [diveIds].
  /// Empty existing notes receive just the text. No transaction/notify.
  Future<void> bulkAppendNotes(
    List<String> diveIds,
    String textToAppend,
  ) async {
    if (diveIds.isEmpty || textToAppend.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final placeholders = List.filled(diveIds.length, '?').join(', ');
    await _db.customUpdate(
      "UPDATE dives SET notes = COALESCE(notes, '') || ?, updated_at = ? "
      'WHERE id IN ($placeholders)',
      variables: [
        Variable.withString(textToAppend),
        Variable.withInt(now),
        ...diveIds.map(Variable.withString),
      ],
      updates: {_db.dives},
    );
    for (final diveId in diveIds) {
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
    }
  }

  /// Shift dive times of every dive in [diveIds] by [offset].
  /// Shifts dive_date_time always, entry_time/exit_time only when non-null.
  /// Forces `updated_at = now` and marks each dive pending. Does NOT open a
  /// transaction or notify sync -- the repair executor owns those.
  Future<void> bulkShiftDiveTimes(List<String> diveIds, Duration offset) async {
    if (diveIds.isEmpty || offset == Duration.zero) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final ms = offset.inMilliseconds;
    final placeholders = List.filled(diveIds.length, '?').join(', ');
    await _db.customUpdate(
      'UPDATE dives SET '
      'dive_date_time = dive_date_time + ?, '
      'entry_time = CASE WHEN entry_time IS NULL THEN NULL '
      'ELSE entry_time + ? END, '
      'exit_time = CASE WHEN exit_time IS NULL THEN NULL '
      'ELSE exit_time + ? END, '
      'updated_at = ? '
      'WHERE id IN ($placeholders)',
      variables: [
        Variable.withInt(ms),
        Variable.withInt(ms),
        Variable.withInt(ms),
        Variable.withInt(now),
        ...diveIds.map(Variable.withString),
      ],
      updates: {_db.dives},
    );
    for (final diveId in diveIds) {
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
    }
  }

  /// Prior time columns for [diveIds]; feed to [restoreDiveTimes] for undo.
  Future<List<({String id, int diveDateTime, int? entryTime, int? exitTime})>>
  getDiveTimesSnapshot(List<String> diveIds) async {
    if (diveIds.isEmpty) return const [];
    final rows = await (_db.select(
      _db.dives,
    )..where((t) => t.id.isIn(diveIds))).get();
    return [
      for (final r in rows)
        (
          id: r.id,
          diveDateTime: r.diveDateTime,
          entryTime: r.entryTime,
          exitTime: r.exitTime,
        ),
    ];
  }

  /// Exact-restore of a [getDiveTimesSnapshot] result (repair undo).
  Future<void> restoreDiveTimes(
    List<({String id, int diveDateTime, int? entryTime, int? exitTime})>
    snapshot,
  ) async {
    if (snapshot.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final s in snapshot) {
      await (_db.update(_db.dives)..where((t) => t.id.equals(s.id))).write(
        DivesCompanion(
          diveDateTime: Value(s.diveDateTime),
          entryTime: Value(s.entryTime),
          exitTime: Value(s.exitTime),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: s.id,
        localUpdatedAt: now,
      );
    }
  }

  /// Narrow tank-record fix for pressure repairs: writes only the provided
  /// pressures on one tank. Marks the tank row and parent dive pending.
  /// No transaction/notify -- the repair executor owns those.
  Future<void> updateTankRecordPressures({
    required String diveId,
    required String tankId,
    double? startPressure,
    double? endPressure,
  }) async {
    if (startPressure == null && endPressure == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.diveTanks)..where((t) => t.id.equals(tankId))).write(
      DiveTanksCompanion(
        startPressure: startPressure != null
            ? Value(startPressure)
            : const Value.absent(),
        endPressure: endPressure != null
            ? Value(endPressure)
            : const Value.absent(),
      ),
    );
    await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
      DivesCompanion(updatedAt: Value(now)),
    );
    await _syncRepository.markRecordPending(
      entityType: 'diveTanks',
      recordId: tankId,
      localUpdatedAt: now,
    );
    await _syncRepository.markRecordPending(
      entityType: 'dives',
      recordId: diveId,
      localUpdatedAt: now,
    );
  }

  /// Load each dive's ordered dive-type slugs from the junction, keyed by dive
  /// id. Used by the mappers and the summary query to hydrate `diveTypeIds`.
  Future<Map<String, List<String>>> _diveTypesForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return {};
    final rows =
        await (_db.select(_db.diveDiveTypes)
              ..where((t) => t.diveId.isIn(diveIds))
              // `id` breaks the tie: rows written in the same millisecond
              // (a seed pass, a multi-type save) would otherwise read back in
              // an order SQLite is free to vary, and the FIRST row is the
              // dive's representative type.
              ..orderBy([
                (t) => OrderingTerm(expression: t.createdAt),
                (t) => OrderingTerm(expression: t.id),
              ]))
            .get();
    final map = <String, List<String>>{};
    for (final r in rows) {
      (map[r.diveId] ??= <String>[]).add(r.diveTypeId);
    }
    return map;
  }

  /// Load each dive's representative `dives.dive_type` slug, keyed by id. Used
  /// to seed the base set for bulk add/remove on legacy dives that have no
  /// junction rows yet (sync transition window).
  Future<Map<String, String>> _representativeDiveTypeColumn(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return {};
    final rows = await (_db.select(
      _db.dives,
    )..where((t) => t.id.isIn(diveIds))).get();
    return {for (final r in rows) r.id: r.diveType};
  }

  /// Replace [diveId]'s dive-type rows with exactly [typeIds] (>= 1 enforced),
  /// and write the representative `dives.dive_type` column. Fresh UUIDs per row
  /// so a reinsert never collides with a replaced row's tombstone (#347).
  ///
  /// [typeIds] is deduped first, keeping the first occurrence so the
  /// representative type (the first row written) is unchanged. The junction
  /// carries a unique index on (dive, type) since v178, so a repeated id here
  /// would throw rather than duplicate -- and a caller passing one is asking
  /// for a set it already believes it has (issue #1360).
  Future<void> _replaceDiveTypeRows(
    String diveId,
    List<String> typeIds,
    int now,
  ) async {
    // `Iterable.toSet()` builds a LinkedHashSet, which iterates in insertion
    // order, so this keeps the FIRST occurrence of each id. That ordering is
    // load-bearing, not incidental: the first row written becomes the dive's
    // representative type. Do not swap in an unordered Set implementation.
    final deduped = typeIds.toSet().toList();
    final types = deduped.isEmpty ? const ['recreational'] : deduped;
    final existing = await (_db.select(
      _db.diveDiveTypes,
    )..where((t) => t.diveId.equals(diveId))).get();
    await (_db.delete(
      _db.diveDiveTypes,
    )..where((t) => t.diveId.equals(diveId))).go();
    for (final row in existing) {
      await _syncRepository.logDeletion(
        entityType: 'diveDiveTypes',
        recordId: row.id,
      );
    }
    for (var i = 0; i < types.length; i++) {
      final id = _uuid.v4();
      await _db
          .into(_db.diveDiveTypes)
          .insert(
            DiveDiveTypesCompanion(
              id: Value(id),
              diveId: Value(diveId),
              diveTypeId: Value(types[i]),
              // +i keeps read-back order deterministic (representative = first)
              // even when several rows are written in the same millisecond.
              createdAt: Value(now + i),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'diveDiveTypes',
        recordId: id,
        localUpdatedAt: now,
      );
    }
    // Keep the denormalized representative column in lockstep with the set.
    await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
      DivesCompanion(diveType: Value(types.first)),
    );
  }

  /// Replace each dive's tag membership with exactly [tagIds]. No notify/txn.
  Future<void> bulkReplaceTags(
    List<String> diveIds,
    List<String> tagIds,
  ) async {
    if (diveIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (_db.select(
      _db.diveTags,
    )..where((t) => t.diveId.isIn(diveIds))).get();
    await (_db.delete(_db.diveTags)..where((t) => t.diveId.isIn(diveIds))).go();
    for (final row in existing) {
      await _syncRepository.logDeletion(
        entityType: 'diveTags',
        recordId: row.id,
      );
    }
    // Deduplicated: `dive_tags` is uniquely indexed on (dive_id, tag_id)
    // since v149, so a repeated id in the selection would throw (#1032).
    // Hoisted out of the loop -- the selection does not change per dive, and a
    // bulk edit multiplies this by the number of dives (PR #1033 review).
    final uniqueTagIds = tagIds.toSet();
    for (final diveId in diveIds) {
      for (final tagId in uniqueTagIds) {
        final id = _uuid.v4();
        await _db
            .into(_db.diveTags)
            .insert(
              DiveTagsCompanion(
                id: Value(id),
                diveId: Value(diveId),
                tagId: Value(tagId),
                createdAt: Value(now),
              ),
            );
        await _syncRepository.markRecordPending(
          entityType: 'diveTags',
          recordId: id,
          localUpdatedAt: now,
        );
      }
    }
    await (_db.update(_db.dives)..where((t) => t.id.isIn(diveIds))).write(
      DivesCompanion(updatedAt: Value(now)),
    );
    for (final diveId in diveIds) {
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
    }
  }

  /// Bump updatedAt + mark pending for a set of dives (shared by bulk ops).
  Future<void> _bumpDives(List<String> diveIds, int now) async {
    await (_db.update(_db.dives)..where((t) => t.id.isIn(diveIds))).write(
      DivesCompanion(updatedAt: Value(now)),
    );
    for (final diveId in diveIds) {
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
    }
  }

  /// Replace each dive's dive-type membership with exactly [typeIds] (coerced
  /// to a single recreational type if empty). No notify/txn.
  Future<void> bulkReplaceDiveTypes(
    List<String> diveIds,
    List<String> typeIds,
  ) async {
    if (diveIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final diveId in diveIds) {
      await _replaceDiveTypeRows(diveId, typeIds, now);
    }
    await _bumpDives(diveIds, now);
  }

  /// Add [typeIds] to each dive's set (union, deduped). No notify/txn.
  Future<void> bulkAddDiveTypes(
    List<String> diveIds,
    List<String> typeIds,
  ) async {
    if (diveIds.isEmpty || typeIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = await _diveTypesForDives(diveIds);
    final reps = await _representativeDiveTypeColumn(diveIds);
    for (final diveId in diveIds) {
      // Seed from the representative column for legacy dives with no junction
      // rows, so adding a type does not drop the existing representative.
      final merged = [
        ...(current[diveId] ?? [reps[diveId] ?? 'recreational']),
      ];
      for (final t in typeIds) {
        if (!merged.contains(t)) merged.add(t);
      }
      await _replaceDiveTypeRows(diveId, merged, now);
    }
    await _bumpDives(diveIds, now);
  }

  /// Remove [typeIds] from each dive's set. Never empties a dive: a removal
  /// that would clear the last type falls back to a single recreational type.
  Future<void> bulkRemoveDiveTypes(
    List<String> diveIds,
    List<String> typeIds,
  ) async {
    if (diveIds.isEmpty || typeIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = await _diveTypesForDives(diveIds);
    final reps = await _representativeDiveTypeColumn(diveIds);
    for (final diveId in diveIds) {
      // Seed from the representative column for legacy dives with no junction
      // rows, so a remove does not silently reset the type to recreational.
      final existing = current[diveId] ?? [reps[diveId] ?? 'recreational'];
      final remaining = existing.where((t) => !typeIds.contains(t)).toList();
      await _replaceDiveTypeRows(
        diveId,
        remaining.isEmpty ? const ['recreational'] : remaining,
        now,
      );
    }
    await _bumpDives(diveIds, now);
  }

  /// Add each equipment id to each dive (junction upsert). No notify/txn.
  Future<void> bulkAddEquipment(
    List<String> diveIds,
    List<String> equipmentIds,
  ) async {
    if (diveIds.isEmpty || equipmentIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final diveId in diveIds) {
      for (final equipmentId in equipmentIds) {
        await _db
            .into(_db.diveEquipment)
            .insertOnConflictUpdate(
              DiveEquipmentCompanion(
                diveId: Value(diveId),
                equipmentId: Value(equipmentId),
              ),
            );
        await _syncRepository.markRecordPending(
          entityType: 'diveEquipment',
          recordId: '$diveId|$equipmentId',
          localUpdatedAt: now,
        );
      }
    }
    await _bumpDives(diveIds, now);
  }

  /// Remove each equipment id from each dive. No notify/txn.
  Future<void> bulkRemoveEquipment(
    List<String> diveIds,
    List<String> equipmentIds,
  ) async {
    if (diveIds.isEmpty || equipmentIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing =
        await (_db.select(_db.diveEquipment)..where(
              (t) => t.diveId.isIn(diveIds) & t.equipmentId.isIn(equipmentIds),
            ))
            .get();
    await (_db.delete(_db.diveEquipment)..where(
          (t) => t.diveId.isIn(diveIds) & t.equipmentId.isIn(equipmentIds),
        ))
        .go();
    for (final row in existing) {
      await _syncRepository.logDeletion(
        entityType: 'diveEquipment',
        recordId: '${row.diveId}|${row.equipmentId}',
      );
    }
    await _bumpDives(diveIds, now);
  }

  /// Replace each dive's equipment with exactly [equipmentIds]. No notify/txn.
  Future<void> bulkReplaceEquipment(
    List<String> diveIds,
    List<String> equipmentIds,
  ) async {
    if (diveIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (_db.select(
      _db.diveEquipment,
    )..where((t) => t.diveId.isIn(diveIds))).get();
    await (_db.delete(
      _db.diveEquipment,
    )..where((t) => t.diveId.isIn(diveIds))).go();
    for (final row in existing) {
      await _syncRepository.logDeletion(
        entityType: 'diveEquipment',
        recordId: '${row.diveId}|${row.equipmentId}',
      );
    }
    for (final diveId in diveIds) {
      for (final equipmentId in equipmentIds) {
        await _db
            .into(_db.diveEquipment)
            .insertOnConflictUpdate(
              DiveEquipmentCompanion(
                diveId: Value(diveId),
                equipmentId: Value(equipmentId),
              ),
            );
        await _syncRepository.markRecordPending(
          entityType: 'diveEquipment',
          recordId: '$diveId|$equipmentId',
          localUpdatedAt: now,
        );
      }
    }
    await _bumpDives(diveIds, now);
  }

  /// {equipmentId: number of the given dives that reference it}. Junction PK
  /// is (diveId, equipmentId), so COUNT(diveId) equals the distinct-dive count.
  Future<Map<String, int>> equipmentCountsForDives(List<String> diveIds) async {
    if (diveIds.isEmpty) return {};
    final j = _db.diveEquipment;
    final countExpr = j.diveId.count();
    final rows =
        await (_db.selectOnly(j)
              ..addColumns([j.equipmentId, countExpr])
              ..where(j.diveId.isIn(diveIds))
              ..groupBy([j.equipmentId]))
            .get();
    return {for (final r in rows) r.read(j.equipmentId)!: r.read(countExpr)!};
  }

  /// {tagId: number of the given dives that carry it}.
  Future<Map<String, int>> tagCountsForDives(List<String> diveIds) async {
    if (diveIds.isEmpty) return {};
    final j = _db.diveTags;
    final countExpr = j.diveId.count();
    final rows =
        await (_db.selectOnly(j)
              ..addColumns([j.tagId, countExpr])
              ..where(j.diveId.isIn(diveIds))
              ..groupBy([j.tagId]))
            .get();
    return {for (final r in rows) r.read(j.tagId)!: r.read(countExpr)!};
  }

  /// {diveTypeId: number of the given dives that have it}.
  Future<Map<String, int>> diveTypeCountsForDives(List<String> diveIds) async {
    if (diveIds.isEmpty) return {};
    final j = _db.diveDiveTypes;
    final countExpr = j.diveId.count();
    final rows =
        await (_db.selectOnly(j)
              ..addColumns([j.diveTypeId, countExpr])
              ..where(j.diveId.isIn(diveIds))
              ..groupBy([j.diveTypeId]))
            .get();
    return {for (final r in rows) r.read(j.diveTypeId)!: r.read(countExpr)!};
  }

  DiveTanksCompanion _tankCompanion(
    String id,
    String diveId,
    domain.DiveTank t,
    int order,
  ) => DiveTanksCompanion(
    id: Value(id),
    diveId: Value(diveId),
    volume: Value(t.volume),
    workingPressure: Value(t.workingPressure),
    startPressure: Value(t.startPressure),
    endPressure: Value(t.endPressure),
    o2Percent: Value(t.gasMix.o2),
    hePercent: Value(t.gasMix.he),
    tankOrder: Value(order),
    tankRole: Value(t.role.name),
    tankMaterial: Value(t.material?.name),
    tankName: Value(t.name),
    presetName: Value(t.presetName),
    computerId: Value(t.computerId),
  );

  /// Append [tanks] to each dive (fresh ids, appended after existing tanks).
  /// When [onlyIfEmpty], a dive that already has any tank is skipped entirely.
  /// No notify/txn.
  Future<void> bulkAddTanks(
    List<String> diveIds,
    List<domain.DiveTank> tanks, {
    bool onlyIfEmpty = false,
  }) async {
    if (diveIds.isEmpty || tanks.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final changed = <String>[];
    for (final diveId in diveIds) {
      final existing = await (_db.select(
        _db.diveTanks,
      )..where((t) => t.diveId.equals(diveId))).get();
      // Evaluate emptiness once per dive (before any insert), so a multi-tank
      // add with onlyIfEmpty adds the whole list rather than just the first.
      if (onlyIfEmpty && existing.isNotEmpty) continue;
      var order = existing.length;
      for (final tank in tanks) {
        final tankId = _uuid.v4();
        await _db
            .into(_db.diveTanks)
            .insert(_tankCompanion(tankId, diveId, tank, order));
        order++;
        await _syncRepository.markRecordPending(
          entityType: 'diveTanks',
          recordId: tankId,
          localUpdatedAt: now,
        );
      }
      changed.add(diveId);
    }
    if (changed.isNotEmpty) await _bumpDives(changed, now);
  }

  /// Append a single tank to each dive. Convenience wrapper over [bulkAddTanks].
  Future<void> bulkAddTank(
    List<String> diveIds,
    domain.DiveTank tank, {
    bool onlyIfEmpty = false,
  }) => bulkAddTanks(diveIds, [tank], onlyIfEmpty: onlyIfEmpty);

  /// A companion carrying only the columns named in [fields]. Every other
  /// column stays absent, so the generated UPDATE never mentions it and the
  /// stored value survives untouched. This is what separates an in-place spec
  /// edit from [_tankCompanion], which always writes the whole row.
  DiveTanksCompanion _tankSpecsCompanion(
    domain.DiveTank specs,
    Set<domain.TankSpecField> fields,
  ) => DiveTanksCompanion(
    presetName: fields.contains(domain.TankSpecField.preset)
        ? Value(specs.presetName)
        : const Value.absent(),
    tankRole: fields.contains(domain.TankSpecField.role)
        ? Value(specs.role.name)
        : const Value.absent(),
    volume: fields.contains(domain.TankSpecField.volume)
        ? Value(specs.volume)
        : const Value.absent(),
    workingPressure: fields.contains(domain.TankSpecField.workingPressure)
        ? Value(specs.workingPressure)
        : const Value.absent(),
    tankMaterial: fields.contains(domain.TankSpecField.material)
        ? Value(specs.material?.name)
        : const Value.absent(),
    o2Percent: fields.contains(domain.TankSpecField.gasMix)
        ? Value(specs.gasMix.o2)
        : const Value.absent(),
    hePercent: fields.contains(domain.TankSpecField.gasMix)
        ? Value(specs.gasMix.he)
        : const Value.absent(),
    tankName: fields.contains(domain.TankSpecField.name)
        ? Value(specs.name)
        : const Value.absent(),
  );

  /// Overwrite the [fields] of every tank each dive already has with the values
  /// from [specs]. Dives with no tanks are skipped rather than given one.
  ///
  /// Start/end pressure, row id, tank order, and computer attribution are never
  /// written, so pressure profiles and gas switches keep pointing at live rows
  /// (#797). Returns the number of dives actually touched. No notify/txn.
  Future<int> bulkUpdateTankSpecs(
    List<String> diveIds,
    domain.DiveTank specs,
    Set<domain.TankSpecField> fields,
  ) async {
    if (diveIds.isEmpty || fields.isEmpty) return 0;
    final companion = _tankSpecsCompanion(specs, fields);
    final now = DateTime.now().millisecondsSinceEpoch;
    // One SELECT for every dive rather than one per dive: a 248-dive import
    // would otherwise cost 248 round-trips before the first write.
    final existing = await (_db.select(
      _db.diveTanks,
    )..where((t) => t.diveId.isIn(diveIds))).get();
    if (existing.isEmpty) return 0;
    final changed = <String>{};
    for (final row in existing) {
      await (_db.update(
        _db.diveTanks,
      )..where((t) => t.id.equals(row.id))).write(companion);
      await _syncRepository.markRecordPending(
        entityType: 'diveTanks',
        recordId: row.id,
        localUpdatedAt: now,
      );
      changed.add(row.diveId);
    }
    await _bumpDives(changed.toList(), now);
    return changed.length;
  }

  /// Write [rows] back over the tanks with the same ids, restoring prior NULLs.
  ///
  /// The undo counterpart of [bulkUpdateTankSpecs]. It updates in place instead
  /// of reusing [bulkReplaceTanks], which would re-insert under fresh ids and
  /// so destroy the very pressure profiles the update preserved. No notify/txn.
  Future<void> bulkRestoreTankRows(List<DiveTank> rows) async {
    if (rows.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final row in rows) {
      await (_db.update(
        _db.diveTanks,
      )..where((t) => t.id.equals(row.id))).write(row.toCompanion(false));
      await _syncRepository.markRecordPending(
        entityType: 'diveTanks',
        recordId: row.id,
        localUpdatedAt: now,
      );
    }
    await _bumpDives(rows.map((r) => r.diveId).toSet().toList(), now);
  }

  /// How many of [diveIds] have no tank rows at all. Used to warn before an
  /// in-place tank spec update, which skips them.
  Future<int> divesWithoutTanksCount(List<String> diveIds) async {
    if (diveIds.isEmpty) return 0;
    final rows =
        await (_db.selectOnly(_db.diveTanks)
              ..addColumns([_db.diveTanks.diveId])
              ..where(_db.diveTanks.diveId.isIn(diveIds))
              ..groupBy([_db.diveTanks.diveId]))
            .get();
    final withTanks = rows
        .map((r) => r.read(_db.diveTanks.diveId))
        .whereType<String>()
        .toSet();
    return diveIds.toSet().difference(withTanks).length;
  }

  /// Replace each dive's tank list with [tanks] (fresh ids, sequential order).
  /// No notify/txn. Cascades to delete tank_pressure_series/gas_switches.
  Future<void> bulkReplaceTanks(
    List<String> diveIds,
    List<domain.DiveTank> tanks,
  ) async {
    if (diveIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final diveId in diveIds) {
      final existing = await (_db.select(
        _db.diveTanks,
      )..where((t) => t.diveId.equals(diveId))).get();
      await (_db.delete(
        _db.diveTanks,
      )..where((t) => t.diveId.equals(diveId))).go();
      for (final row in existing) {
        await _syncRepository.logDeletion(
          entityType: 'diveTanks',
          recordId: row.id,
        );
      }
      for (var i = 0; i < tanks.length; i++) {
        final tankId = _uuid.v4();
        await _db
            .into(_db.diveTanks)
            .insert(_tankCompanion(tankId, diveId, tanks[i], i));
        await _syncRepository.markRecordPending(
          entityType: 'diveTanks',
          recordId: tankId,
          localUpdatedAt: now,
        );
      }
    }
    await _bumpDives(diveIds, now);
  }

  DiveWeightsCompanion _weightCompanion(
    String id,
    String diveId,
    domain.DiveWeight w,
    int now,
  ) => DiveWeightsCompanion(
    id: Value(id),
    diveId: Value(diveId),
    weightType: Value(w.weightType.name),
    amountKg: Value(w.amountKg),
    notes: Value(w.notes),
    createdAt: Value(now),
  );

  /// Append each weight to every dive (fresh id per dive). No notify/txn.
  Future<void> bulkAddWeights(
    List<String> diveIds,
    List<domain.DiveWeight> weights,
  ) async {
    if (diveIds.isEmpty || weights.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final diveId in diveIds) {
      for (final w in weights) {
        final id = _uuid.v4();
        await _db
            .into(_db.diveWeights)
            .insert(_weightCompanion(id, diveId, w, now));
        await _syncRepository.markRecordPending(
          entityType: 'diveWeights',
          recordId: id,
          localUpdatedAt: now,
        );
      }
    }
    await _bumpDives(diveIds, now);
  }

  /// Replace each dive's weight list with [weights]. No notify/txn.
  Future<void> bulkReplaceWeights(
    List<String> diveIds,
    List<domain.DiveWeight> weights,
  ) async {
    if (diveIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final diveId in diveIds) {
      final existing = await (_db.select(
        _db.diveWeights,
      )..where((t) => t.diveId.equals(diveId))).get();
      await (_db.delete(
        _db.diveWeights,
      )..where((t) => t.diveId.equals(diveId))).go();
      for (final row in existing) {
        await _syncRepository.logDeletion(
          entityType: 'diveWeights',
          recordId: row.id,
        );
      }
      for (final w in weights) {
        final id = _uuid.v4();
        await _db
            .into(_db.diveWeights)
            .insert(_weightCompanion(id, diveId, w, now));
        await _syncRepository.markRecordPending(
          entityType: 'diveWeights',
          recordId: id,
          localUpdatedAt: now,
        );
      }
    }
    await _bumpDives(diveIds, now);
  }

  /// Bulk update trip for multiple dives
  Future<void> bulkUpdateTrip(List<String> diveIds, String? tripId) async {
    if (diveIds.isEmpty) return;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.dives)..where((t) => t.id.isIn(diveIds))).write(
        DivesCompanion(tripId: Value(tripId), updatedAt: Value(now)),
      );
      for (final diveId in diveIds) {
        await _syncRepository.markRecordPending(
          entityType: 'dives',
          recordId: diveId,
          localUpdatedAt: now,
        );
      }
      SyncEventBus.notifyLocalChange();
      _log.info('Bulk updated trip for ${diveIds.length} dives');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to bulk update trip',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Bulk add tags to multiple dives
  Future<void> bulkAddTags(List<String> diveIds, List<String> tagIds) async {
    if (diveIds.isEmpty || tagIds.isEmpty) return;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      // Pairs these dives already carry. `dive_tags` is uniquely indexed on
      // (dive_id, tag_id) since v149, and the fresh uuid per row means an
      // upsert would never have matched the existing row anyway -- it just
      // added a second one (#1032).
      final existing =
          (await (_db.select(
                _db.diveTags,
              )..where((t) => t.diveId.isIn(diveIds))).get())
              .map((r) => '${r.diveId}|${r.tagId}')
              .toSet();
      // Hoisted: the selection is the same for every dive, and a bulk edit
      // multiplies this by the number of dives (PR #1033 review).
      final uniqueTagIds = tagIds.toSet();
      for (final diveId in diveIds) {
        for (final tagId in uniqueTagIds) {
          if (!existing.add('$diveId|$tagId')) continue;
          final diveTagId = _uuid.v4();
          await _db
              .into(_db.diveTags)
              .insert(
                DiveTagsCompanion(
                  id: Value(diveTagId),
                  diveId: Value(diveId),
                  tagId: Value(tagId),
                  createdAt: Value(now),
                ),
              );
          await _syncRepository.markRecordPending(
            entityType: 'diveTags',
            recordId: diveTagId,
            localUpdatedAt: now,
          );
        }
      }
      await (_db.update(_db.dives)..where((t) => t.id.isIn(diveIds))).write(
        DivesCompanion(updatedAt: Value(now)),
      );
      for (final diveId in diveIds) {
        await _syncRepository.markRecordPending(
          entityType: 'dives',
          recordId: diveId,
          localUpdatedAt: now,
        );
      }
      SyncEventBus.notifyLocalChange();
      _log.info('Bulk added ${tagIds.length} tags to ${diveIds.length} dives');
    } catch (e, stackTrace) {
      _log.error('Failed to bulk add tags', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Bulk remove tags from multiple dives
  Future<void> bulkRemoveTags(List<String> diveIds, List<String> tagIds) async {
    if (diveIds.isEmpty || tagIds.isEmpty) return;

    try {
      final existing = await (_db.select(
        _db.diveTags,
      )..where((t) => t.diveId.isIn(diveIds) & t.tagId.isIn(tagIds))).get();
      await (_db.delete(
        _db.diveTags,
      )..where((t) => t.diveId.isIn(diveIds) & t.tagId.isIn(tagIds))).go();
      for (final row in existing) {
        await _syncRepository.logDeletion(
          entityType: 'diveTags',
          recordId: row.id,
        );
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.dives)..where((t) => t.id.isIn(diveIds))).write(
        DivesCompanion(updatedAt: Value(now)),
      );
      for (final diveId in diveIds) {
        await _syncRepository.markRecordPending(
          entityType: 'dives',
          recordId: diveId,
          localUpdatedAt: now,
        );
      }
      SyncEventBus.notifyLocalChange();
      _log.info(
        'Bulk removed ${tagIds.length} tags from ${diveIds.length} dives',
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to bulk remove tags',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // Dive Data Sources (multi-source reading snapshots)
  // ============================================================================

  /// Get all data source snapshots for a dive.
  Future<List<DiveDataSource>> getDataSources(String diveId) async {
    try {
      final query = _db.select(_db.diveDataSources)
        ..where((t) => t.diveId.equals(diveId))
        ..orderBy([
          (t) => OrderingTerm.desc(t.isPrimary),
          (t) => OrderingTerm.asc(t.createdAt),
        ]);
      final rows = _canonicalDataSourceRows(await query.get());
      final computerNames = await _friendlyNamesFor(rows);
      return rows
          .map((row) => _mapRowToDataSource(row, computerNames))
          .toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get computer readings for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Every `dive_data_sources` row for [diveIds], for UDDF export.
  ///
  /// Deliberately NOT built on [getDataSources]: that one runs rows through
  /// `_canonicalDataSourceRows`, which collapses rows sharing a merge slot
  /// into one display source. Each collapsed row is the sole surviving copy
  /// of its half's `rawData`, so exporting through it would silently drop
  /// half of a combined dive's bytes.
  ///
  /// Rows with no `rawData` are included too. The provenance record has to
  /// cover them, or a dive with one plain source beside one carrying bytes
  /// would restore with fewer sources than it had.
  ///
  /// This MUST stay a Drift typed select. Issue #227 puts a `TypeConverter`
  /// on `raw_data`; typed selects run converters and `customSelect` does not,
  /// so a raw SQL version would return `SRD1` framed zlib and the export
  /// would write compressed bytes into `<dcdump>` with nothing to catch it.
  /// `sources_for_export_test.dart` pins this with a byte-identity check.
  ///
  /// The ordering is part of the contract: it defines the ordinals that pair
  /// a `<source>` entry with its `<divecomputerdump>`.
  Future<List<DiveSourceExport>> getSourcesForExport(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return const [];
    try {
      final query = _db.select(_db.diveDataSources)
        ..where((t) => t.diveId.isIn(diveIds))
        ..orderBy([
          (t) => OrderingTerm.asc(t.diveId),
          (t) => OrderingTerm.desc(t.isPrimary),
          (t) => OrderingTerm.asc(t.createdAt),
          (t) => OrderingTerm.asc(t.id),
        ]);
      final rows = await query.get();

      final ordinalByDive = <String, int>{};
      return rows
          .map((row) {
            final ordinal = ordinalByDive.update(
              row.diveId,
              (value) => value + 1,
              ifAbsent: () => 0,
            );
            return DiveSourceExport(
              id: row.id,
              diveId: row.diveId,
              ordinal: ordinal,
              isPrimary: row.isPrimary,
              importedAt: row.importedAt,
              createdAt: row.createdAt,
              rawData: row.rawData,
              rawFingerprint: row.rawFingerprint,
              computerId: row.computerId,
              computerModel: row.computerModel,
              computerSerial: row.computerSerial,
              sourceFormat: row.sourceFormat,
              sourceFileName: row.sourceFileName,
              sourceFileFormat: row.sourceFileFormat,
              sourceUuid: row.sourceUuid,
              descriptorVendor: row.descriptorVendor,
              descriptorProduct: row.descriptorProduct,
              descriptorModel: row.descriptorModel,
              libdivecomputerVersion: row.libdivecomputerVersion,
              mergeSourceSlot: row.mergeSourceSlot,
              timeOffsetSeconds: row.timeOffsetSeconds,
              maxDepth: row.maxDepth,
              avgDepth: row.avgDepth,
              duration: row.duration,
              waterTemp: row.waterTemp,
              entryLatitude: row.entryLatitude,
              entryLongitude: row.entryLongitude,
              exitLatitude: row.exitLatitude,
              exitLongitude: row.exitLongitude,
              entryTime: row.entryTime,
              exitTime: row.exitTime,
              maxAscentRate: row.maxAscentRate,
              maxDescentRate: row.maxDescentRate,
              surfaceInterval: row.surfaceInterval,
              cns: row.cns,
              otu: row.otu,
              decoAlgorithm: row.decoAlgorithm,
              gradientFactorLow: row.gradientFactorLow,
              gradientFactorHigh: row.gradientFactorHigh,
              lastParsedAt: row.lastParsedAt,
            );
          })
          .toList(growable: false);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to load data sources for export',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get every non-empty `source_uuid` and hex-encoded `raw_fingerprint`
  /// across ALL of a dive's `dive_data_sources` rows (not just the primary),
  /// as a `{ diveId -> { key, key, ... } }` map.
  ///
  /// Used by the import duplicate checker to detect exact re-downloads from
  /// ANY of a dive's consolidated sources — a re-download from a secondary
  /// (already-consolidated) computer must resolve as an exact duplicate of
  /// the target dive, not just re-downloads from the primary computer.
  ///
  /// Fingerprints are hex-encoded the same way SQLite's `hex()` function
  /// encodes them (uppercase, no separators) so callers can hex-encode a
  /// downloaded dive's raw fingerprint bytes the same way before comparing.
  /// Since fingerprint hex strings never contain a `-` and source UUIDs
  /// always do, the two kinds of key never collide within the set.
  ///
  /// When [diverId] is provided, the result is restricted to that diver's
  /// dives — callers that have already scoped `existingDives` to a single
  /// diver should pass it here so the key map shares the same scope.
  // stats-scope-exempt: import dedupe fingerprints, must see every dive or it re-imports
  Future<Map<String, Set<String>>> getSourceKeysByDiveId({
    String? diverId,
  }) async {
    try {
      final sql = StringBuffer(
        'SELECT s.dive_id, s.source_uuid, hex(s.raw_fingerprint) as fp ',
      )..write('FROM dive_data_sources s ');
      final variables = <Variable<Object>>[];
      if (diverId != null) {
        sql.write('INNER JOIN dives d ON d.id = s.dive_id ');
      }
      sql.write(
        'WHERE (s.source_uuid IS NOT NULL OR s.raw_fingerprint IS NOT NULL) ',
      );
      if (diverId != null) {
        sql.write('AND d.diver_id = ? ');
        variables.add(Variable<Object>(diverId));
      }
      // Deterministic row order: primary source first, then most recent.
      // getSourceKeysByDiveId itself unions ALL keys regardless of order,
      // but getSourceUuidByDiveId's reduction below relies on insertion
      // order into the per-dive LinkedHashSet to deterministically prefer
      // the primary source's UUID (falling back to the most recent
      // secondary) instead of an arbitrary one.
      sql.write('ORDER BY s.is_primary DESC, s.created_at DESC');

      final rows = await _db
          .customSelect(sql.toString(), variables: variables)
          .get();
      final result = <String, Set<String>>{};
      for (final row in rows) {
        final diveId = row.read<String>('dive_id');
        final uuid = row.read<String?>('source_uuid');
        final fingerprint = row.read<String?>('fp');
        final keys = result.putIfAbsent(diveId, () => <String>{});
        if (uuid != null && uuid.isNotEmpty) keys.add(uuid);
        if (fingerprint != null && fingerprint.isNotEmpty) {
          keys.add(fingerprint);
        }
      }
      return result;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to load source keys for dives',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// A source-uuid-shaped key always contains a hyphen; a hex-encoded
  /// fingerprint from SQLite's `hex()` never does. Used to filter
  /// [getSourceKeysByDiveId]'s combined set back down to UUIDs only.
  static bool _looksLikeSourceUuid(String key) => key.contains('-');

  /// Get `source_uuid` for every dive that has a non-null one, as a
  /// `{ diveId -> sourceUuid }` map.
  ///
  /// Used by the import duplicate checker to short-circuit content fuzzy
  /// matching for dives that already have a known source UUID. Thin wrapper
  /// over [getSourceKeysByDiveId] so the two queries cannot drift apart:
  /// when a dive has multiple data sources (multi-computer), the primary
  /// row's UUID wins; otherwise the most recently created row's UUID is
  /// used. This is deterministic (not "any" UUID) because
  /// [getSourceKeysByDiveId]'s underlying query orders rows by
  /// `is_primary DESC, created_at DESC` and per-dive keys are collected into
  /// a `LinkedHashSet`, which preserves that insertion order -- the first
  /// UUID-shaped key encountered below is always the primary's (or, absent
  /// a primary UUID, the most recent secondary's). Dives with no
  /// source_uuid on any row are absent from the map.
  ///
  /// When [diverId] is provided, the result is restricted to that diver's
  /// dives — callers that have already scoped `existingDives` to a single
  /// diver should pass it here so the UUID map shares the same scope.
  Future<Map<String, String>> getSourceUuidByDiveId({String? diverId}) async {
    final keysByDiveId = await getSourceKeysByDiveId(diverId: diverId);
    final result = <String, String>{};
    for (final entry in keysByDiveId.entries) {
      for (final key in entry.value) {
        if (_looksLikeSourceUuid(key)) {
          result[entry.key] = key;
          break;
        }
      }
    }
    return result;
  }

  /// One-column lookup of a dive's `computer_id`.
  ///
  /// Used by the import wizard's duplicate matcher to populate
  /// `DiveMatchResult.matchedComputerId`, since the domain [Dive] entity does
  /// not carry `computerId`.
  Future<String?> getComputerIdForDive(String diveId) async {
    try {
      final row =
          await (_db.selectOnly(_db.dives)
                ..addColumns([_db.dives.computerId])
                ..where(_db.dives.id.equals(diveId)))
              .getSingleOrNull();
      return row?.read(_db.dives.computerId);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to load computer id for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Return true if a dive has readings from 2 or more sources.
  ///
  /// Counts distinct canonical strands rather than raw rows, mirroring
  /// [dataSourceStrandKey] in SQL: computer_id when there is one, else
  /// merge_source_slot for a row a sequential Combine carried here, else the
  /// row's own id (unique, so such a row is always its own strand). The two
  /// rows a Combine leaves behind therefore count as one, whether or not the
  /// segments came from a computer download (issue #1451).
  ///
  /// Deliberately the collapse rule alone, without the disjoint-span test the
  /// profile surfaces add on top of it (`usesPerSourceRendering`). That test
  /// exists because drawing one source on a 2D chart HIDES the others, which
  /// is wrong for consecutive halves. This count's only caller is the 3D
  /// page's dive/computers switcher, whose computers scene overlays every
  /// strand at once, so nothing is hidden and two strands still have
  /// something to compare -- two computers that each recorded half a dive
  /// included.
  Future<bool> hasMultipleDataSources(String diveId) async {
    try {
      final result = await _db
          .customSelect(
            'SELECT COUNT(DISTINCT COALESCE('
            "'computer:' || computer_id, "
            "'mergeSlot:' || merge_source_slot, "
            "'row:' || id)) as cnt "
            'FROM dive_data_sources WHERE dive_id = ?',
            variables: [Variable(diveId)],
          )
          .getSingle();
      return (result.data['cnt'] as int) >= 2;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to count data source strands for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Apply a partial [DivesCompanion] update to a dive row.
  ///
  /// Used by the UDDF importer to persist fields that do not flow through
  /// the [domain.Dive] entity (e.g. MacDive boat/operator/weather metadata).
  /// Only columns set on [patch] are written; others are left untouched.
  /// Marks the row pending for sync.
  Future<void> applyImportedMetadata(
    String diveId,
    DivesCompanion patch,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        patch.copyWith(updatedAt: Value(now)),
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to apply imported metadata to dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Insert a new computer reading snapshot.
  Future<void> saveComputerReading(DiveDataSourcesCompanion reading) async {
    try {
      await _db.into(_db.diveDataSources).insert(reading);
      await _adoptUnattributedProfiles(reading);
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save computer reading',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Claim a dive's unattributed profile rows for a just-inserted source.
  ///
  /// The file-import pipeline writes samples before it writes the source row
  /// describing them (createDive runs first, saveComputerReading second), so
  /// those rows would carry no sourceId and depend on the pre-v154 computerId
  /// convention forever. Adopting them the moment their owner first exists
  /// closes that gap for newly imported dives (issue #1149).
  ///
  /// Only when this is the dive's sole source row. With a second source
  /// present the unattributed rows could belong to either, and a guess would
  /// be worse than leaving the documented fallback to handle them.
  Future<void> _adoptUnattributedProfiles(
    DiveDataSourcesCompanion reading,
  ) async {
    if (!reading.id.present || !reading.diveId.present) return;
    final diveId = reading.diveId.value;

    final sources =
        await (_db.select(_db.diveDataSources)
              ..where((t) => t.diveId.equals(diveId))
              ..limit(2))
            .get();
    if (sources.length != 1) return;

    await _profileSeries.adoptUnattributed(diveId, reading.id.value);
  }

  /// Delete a computer reading snapshot by its ID.
  Future<void> deleteComputerReading(String id) async {
    try {
      // Clear the series first: dive_profile_series.source_id is ON DELETE
      // SET NULL, so the delete below would strip their attribution through
      // the cascade without a fresh updated_at, an hlc restamp or a pending
      // mark, and this device would resolve their owner differently from
      // every peer forever (see ProfileSeriesRepository.clearSource). The
      // computer_id twin of this is DiveComputerRepository.deleteComputer.
      // One transaction, so a failure between them cannot publish series
      // that gave up an attribution the source row still claims.
      await _db.transaction(() async {
        await _profileSeries.clearSource(id);
        await (_db.delete(
          _db.diveDataSources,
        )..where((t) => t.id.equals(id))).go();
      });
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete computer reading: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Create a primary [DiveDataSource] by back-filling metadata from the
  /// existing [Dives] row.  No-ops if a primary reading already exists.
  Future<void> backfillPrimaryDataSource(String diveId) async {
    try {
      // Skip if a primary reading already exists.
      final existing =
          await (_db.select(_db.diveDataSources)
                ..where((t) => t.diveId.equals(diveId))
                ..where((t) => t.isPrimary.equals(true))
                ..limit(1))
              .getSingleOrNull();
      if (existing != null) return;

      // Load the raw DB row so we can access columns not exposed on the
      // domain Dive entity (e.g. computerId, surfaceIntervalSeconds, cnsEnd).
      final diveRow = await (_db.select(
        _db.dives,
      )..where((t) => t.id.equals(diveId))).getSingleOrNull();
      if (diveRow == null) return;

      final now = DateTime.now();
      final id = _uuid.v4();

      await saveComputerReading(
        DiveDataSourcesCompanion(
          id: Value(id),
          diveId: Value(diveId),
          computerId: Value(diveRow.computerId),
          isPrimary: const Value(true),
          computerModel: Value(diveRow.diveComputerModel),
          computerSerial: Value(diveRow.diveComputerSerial),
          maxDepth: Value(diveRow.maxDepth),
          avgDepth: Value(diveRow.avgDepth),
          duration: Value(diveRow.bottomTime),
          waterTemp: Value(diveRow.waterTemp),
          entryTime: Value(
            diveRow.entryTime != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    diveRow.entryTime!,
                    isUtc: true,
                  )
                : null,
          ),
          exitTime: Value(
            diveRow.exitTime != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    diveRow.exitTime!,
                    isUtc: true,
                  )
                : null,
          ),
          surfaceInterval: Value(diveRow.surfaceIntervalSeconds),
          cns: Value(diveRow.cnsEnd),
          decoAlgorithm: Value(diveRow.decoAlgorithm),
          gradientFactorLow: Value(diveRow.gradientFactorLow),
          gradientFactorHigh: Value(diveRow.gradientFactorHigh),
          importedAt: Value(now),
          createdAt: Value(now),
        ),
      );

      _log.info('Backfilled primary computer reading for dive: $diveId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to backfill primary computer reading for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // Consolidation and merge operations
  // ============================================================================

  /// Swaps which computer is primary for a dive.
  ///
  /// Updates both [DiveDataSources] `isPrimary` flags and the parent [Dives]
  /// record. Also swaps `isPrimary` on the associated profile series.
  Future<void> setPrimaryDataSource({
    required String diveId,
    required String computerReadingId,
  }) async {
    try {
      await _db.transaction(() async {
        // Load the reading that is being promoted.
        final newPrimary = await (_db.select(
          _db.diveDataSources,
        )..where((t) => t.id.equals(computerReadingId))).getSingleOrNull();

        if (newPrimary == null) return;

        // Demote all readings for this dive to non-primary.
        await (_db.update(_db.diveDataSources)
              ..where((t) => t.diveId.equals(diveId)))
            .write(const DiveDataSourcesCompanion(isPrimary: Value(false)));

        // Promote the selected reading.
        await (_db.update(_db.diveDataSources)
              ..where((t) => t.id.equals(computerReadingId)))
            .write(const DiveDataSourcesCompanion(isPrimary: Value(true)));

        // Update the dives record with the new primary's metadata.
        final now = DateTime.now().millisecondsSinceEpoch;
        await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
          DivesCompanion(
            diveComputerModel: Value(newPrimary.computerModel),
            diveComputerSerial: Value(newPrimary.computerSerial),
            maxDepth: Value(newPrimary.maxDepth),
            avgDepth: Value(newPrimary.avgDepth),
            bottomTime: Value(newPrimary.duration),
            waterTemp: Value(newPrimary.waterTemp),
            entryTime: Value(newPrimary.entryTime?.millisecondsSinceEpoch),
            exitTime: Value(newPrimary.exitTime?.millisecondsSinceEpoch),
            surfaceIntervalSeconds: Value(newPrimary.surfaceInterval),
            cnsEnd: Value(newPrimary.cns),
            decoAlgorithm: Value(newPrimary.decoAlgorithm),
            gradientFactorLow: Value(newPrimary.gradientFactorLow),
            gradientFactorHigh: Value(newPrimary.gradientFactorHigh),
            updatedAt: Value(now),
          ),
        );

        // Swap isPrimary on the profile series.
        //
        // Resolve what to promote BEFORE demoting anything (issue #1149).
        // The old order (demote every series for the dive, then promote)
        // stranded the dive with zero primary series whenever the promote
        // matched nothing, which happened for every file-imported source
        // (null computerId on both the source row and its series) and for
        // any metadata-only source that owns no samples. The dive kept
        // rendering, because getDiveById and getMergedProfile do not filter
        // on the flag, while getDiveProfile, getAscentDescentRates and the
        // data-quality prefilters silently skipped it.
        if (await _profileSeries.ownsAny(
          diveId,
          sourceId: newPrimary.id,
          computerId: newPrimary.computerId,
        )) {
          await _profileSeries.demoteAll(diveId, now: now);
          await _profileSeries.promoteWinnerOwnedBy(
            diveId,
            sourceId: newPrimary.id,
            computerId: newPrimary.computerId,
            now: now,
          );
        }
      });
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set primary computer $computerReadingId for dive $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Resolves a `{ computerId -> friendly name }` map for the given source
  /// rows by looking up each linked [DiveComputers] row's user-assigned
  /// `name`. Blank names are omitted so the display fallback (model, then
  /// serial/"Unknown") still applies. Rows with no `computerId` (manual
  /// entries, file imports, or a since-deleted computer) contribute nothing.
  Future<Map<String, String>> _friendlyNamesFor(
    List<DiveDataSourcesData> rows,
  ) async {
    final ids = {
      for (final row in rows)
        if (row.computerId != null) row.computerId!,
    };
    if (ids.isEmpty) return const {};
    final computers = await (_db.select(
      _db.diveComputers,
    )..where((c) => c.id.isIn(ids))).get();
    return {
      for (final computer in computers)
        if (computer.name.trim().isNotEmpty) computer.id: computer.name.trim(),
    };
  }

  /// Map a [DiveDataSourcesData] DB row to a [DiveDataSource] entity.
  ///
  /// [computerNames] carries the live `{ computerId -> friendly name }` lookup
  /// from [_friendlyNamesFor]; a source's `computerName` is filled from it when
  /// the row is linked to a registered computer.
  DiveDataSource _mapRowToDataSource(
    DiveDataSourcesData row, [
    Map<String, String> computerNames = const {},
  ]) {
    return DiveDataSource(
      id: row.id,
      diveId: row.diveId,
      computerId: row.computerId,
      isPrimary: row.isPrimary,
      computerModel: row.computerModel,
      computerName: row.computerId == null
          ? null
          : computerNames[row.computerId],
      computerSerial: row.computerSerial,
      sourceFormat: row.sourceFormat,
      sourceFileName: row.sourceFileName,
      sourceFileFormat: row.sourceFileFormat,
      maxDepth: row.maxDepth,
      avgDepth: row.avgDepth,
      duration: row.duration,
      waterTemp: row.waterTemp,
      entryLatitude: row.entryLatitude,
      entryLongitude: row.entryLongitude,
      exitLatitude: row.exitLatitude,
      exitLongitude: row.exitLongitude,
      entryTime: row.entryTime,
      exitTime: row.exitTime,
      maxAscentRate: row.maxAscentRate,
      maxDescentRate: row.maxDescentRate,
      surfaceInterval: row.surfaceInterval,
      cns: row.cns,
      otu: row.otu,
      decoAlgorithm: row.decoAlgorithm,
      gradientFactorLow: row.gradientFactorLow,
      gradientFactorHigh: row.gradientFactorHigh,
      importedAt: row.importedAt,
      createdAt: row.createdAt,
    );
  }

  /// Batch-loads equipment_attributes for the given equipment ids, grouped
  /// by equipment id (one query, list-safe).
  Future<Map<String, List<EquipmentAttribute>>> _equipmentAttributesFor(
    Iterable<String> equipmentIds,
  ) async {
    final ids = equipmentIds.toSet().toList();
    if (ids.isEmpty) return const {};
    // Order by sortOrder like the canonical equipment-repo loaders so custom
    // fields (and any ordered attributes) come back deterministically; without
    // it the UI/detail/export output can reshuffle between runs.
    final rows =
        await (_db.select(_db.equipmentAttributes)
              ..where((t) => t.equipmentId.isIn(ids))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    final byEquipment = <String, List<EquipmentAttribute>>{};
    for (final row in rows) {
      byEquipment
          .putIfAbsent(row.equipmentId, () => [])
          .add(
            EquipmentAttribute(
              id: row.id,
              equipmentId: row.equipmentId,
              key: row.attrKey,
              isCustom: row.isCustom,
              valueText: row.valueText,
              valueNum: row.valueNum,
              sortOrder: row.sortOrder,
            ),
          );
    }
    return byEquipment;
  }
}

/// Statistics summary for dives
class DiveStatistics {
  final int totalDives;
  final int totalTimeSeconds;
  final double maxDepth;
  final double avgMaxDepth;
  final double? avgTemperature;
  final int totalSites;
  final DateTime? firstDiveDate;
  final List<MonthlyDiveCount> divesByMonth;
  final List<DepthRangeStat> depthDistribution;
  final List<TopSiteStat> topSites;

  DiveStatistics({
    required this.totalDives,
    required this.totalTimeSeconds,
    required this.maxDepth,
    required this.avgMaxDepth,
    this.avgTemperature,
    required this.totalSites,
    this.firstDiveDate,
    this.divesByMonth = const [],
    this.depthDistribution = const [],
    this.topSites = const [],
  });

  Duration get totalTime => Duration(seconds: totalTimeSeconds);

  String get totalTimeFormatted {
    final hours = totalTime.inHours;
    final minutes = totalTime.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  // Gregorian average days per month (365.25 / 12).
  static const double _daysPerMonth = 30.44;

  /// Lifetime tenure in months since the diver's first dive.
  /// Returns null if no dives, firstDiveDate is in the future, or tenure < 1 month.
  double? get monthsSinceFirstDive {
    final first = firstDiveDate;
    if (first == null) return null;
    final now = DateTime.now();
    if (first.isAfter(now)) return null;
    final months = now.difference(first).inDays / _daysPerMonth;
    return months < 1 ? null : months;
  }

  /// Lifetime average dives per month. Returns null when tenure is unavailable.
  double? get divesPerMonth {
    final months = monthsSinceFirstDive;
    return months == null ? null : totalDives / months;
  }

  /// Lifetime average dives per year. Returns null when tenure is unavailable.
  double? get divesPerYear {
    final months = monthsSinceFirstDive;
    return months == null ? null : totalDives / (months / 12);
  }
}

/// Monthly dive count for bar chart
class MonthlyDiveCount {
  final int year;
  final int month;
  final int count;

  MonthlyDiveCount({
    required this.year,
    required this.month,
    required this.count,
  });

  String get label {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  String get fullLabel => '$label $year';
}

/// Depth range statistics for distribution chart
class DepthRangeStat {
  final String label;
  final int minDepth;
  final int maxDepth;
  final int count;

  /// Whether this is the deepest, open-ended bucket (e.g. "130m+"), which
  /// has no real upper bound unlike every other bucket.
  final bool openEnded;

  /// Summed dive duration (seconds) across dives whose max depth landed in
  /// this bucket (issue #641), mirroring
  /// [DistributionSegment.totalDurationSeconds].
  final int totalDurationSeconds;

  DepthRangeStat({
    required this.label,
    required this.minDepth,
    required this.maxDepth,
    required this.count,
    this.openEnded = false,
    this.totalDurationSeconds = 0,
  });
}

/// Top dive site statistics
class TopSiteStat {
  final String siteId;
  final String siteName;
  final int diveCount;

  TopSiteStat({
    required this.siteId,
    required this.siteName,
    required this.diveCount,
  });
}

/// Dive records (superlatives)
class DiveRecords {
  final DiveRecord? deepestDive;
  final DiveRecord? longestDive;
  final DiveRecord? coldestDive;
  final DiveRecord? warmestDive;
  final DiveRecord? firstDive;
  final DiveRecord? lastDive;
  final DiveRecord? shallowestDive;

  DiveRecords({
    this.deepestDive,
    this.longestDive,
    this.coldestDive,
    this.warmestDive,
    this.firstDive,
    this.lastDive,
    this.shallowestDive,
  });
}

/// A single dive record entry
class DiveRecord {
  final String diveId;
  final int? diveNumber;
  final String? siteName;
  final DateTime dateTime;
  final double? maxDepth;
  final Duration? bottomTime;
  final Duration? runtime;
  final double? waterTemp;

  DiveRecord({
    required this.diveId,
    this.diveNumber,
    this.siteName,
    required this.dateTime,
    this.maxDepth,
    this.bottomTime,
    this.runtime,
    this.waterTemp,
  });

  /// Best available runtime (runtime, then bottomTime).
  Duration? get effectiveRuntime => runtime ?? bottomTime;
}

/// Information about dive numbering, including gaps
class DiveNumberingInfo {
  final List<DiveNumberEntry> dives;
  final List<DiveNumberGap> gaps;
  final bool hasGaps;
  final bool hasUnnumbered;

  DiveNumberingInfo({
    required this.dives,
    required this.gaps,
    required this.hasGaps,
    required this.hasUnnumbered,
  });

  /// Total number of dives
  int get totalDives => dives.length;

  /// Number of numbered dives
  int get numberedDives => dives.where((d) => d.currentNumber != null).length;

  /// Number of unnumbered dives
  int get unnumberedDives => dives.where((d) => d.currentNumber == null).length;
}

/// Entry for dive number info
class DiveNumberEntry {
  final String diveId;
  final int? currentNumber;
  final DateTime entryTime;

  DiveNumberEntry({
    required this.diveId,
    this.currentNumber,
    required this.entryTime,
  });
}

/// A gap in dive numbers
class DiveNumberGap {
  final String? afterDiveId;
  final int missingStart;
  final int missingEnd;

  DiveNumberGap({
    this.afterDiveId,
    required this.missingStart,
    required this.missingEnd,
  });

  /// Number of missing dive numbers in this gap
  int get count => missingEnd - missingStart + 1;

  /// Human-readable description of the gap
  String get description {
    if (missingStart == missingEnd) {
      return 'Missing dive #$missingStart';
    }
    return 'Missing dives #$missingStart-$missingEnd';
  }
}
