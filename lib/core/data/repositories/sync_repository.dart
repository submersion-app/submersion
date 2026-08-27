import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';

/// Sync status for individual records
enum SyncStatus { synced, pending, conflict }

/// Cloud provider types
enum CloudProviderType { icloud, googledrive, s3, dropbox }

/// Repository for managing sync metadata and tracking
class SyncRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(SyncRepository);

  static const String _globalMetadataId = 'global';

  /// Conflict-capable syncable entities that carry an `hlc` column, mapped to
  /// their SQLite table name and primary-key column. markRecordPending stamps
  /// a fresh Hybrid Logical Clock onto these rows so cross-device merges can
  /// order edits correctly under wall-clock skew. Entities not listed here
  /// (append-only tables) fall back to updatedAt ordering.
  ///
  /// MUST cover every table declaring an `hlc` column: an omission is silent
  /// (`_stampHlc` no-ops on an unknown entity type), leaves the column NULL,
  /// and the incremental export's `hlc > watermark` filter then excludes the
  /// row from every changeset forever. `sync_hlc_target_registration_test`
  /// asserts this against the live schema.
  @visibleForTesting
  static const Map<String, ({String table, String pk})> hlcTargets = {
    'divers': (table: 'divers', pk: 'id'),
    'diverSettings': (table: 'diver_settings', pk: 'id'),
    'buddies': (table: 'buddies', pk: 'id'),
    'mediaStores': (table: 'media_stores', pk: 'id'),
    'connectedAccounts': (table: 'connected_accounts', pk: 'id'),
    'mediaSubscriptions': (table: 'media_subscriptions', pk: 'id'),
    'diveCenters': (table: 'dive_centers', pk: 'id'),
    'trips': (table: 'trips', pk: 'id'),
    'liveaboardDetails': (table: 'liveaboard_detail_records', pk: 'id'),
    'itineraryDays': (table: 'trip_itinerary_days', pk: 'id'),
    'checklistTemplates': (table: 'checklist_templates', pk: 'id'),
    'checklistTemplateItems': (table: 'checklist_template_items', pk: 'id'),
    'tripChecklistItems': (table: 'trip_checklist_items', pk: 'id'),
    'preDiveChecklistTemplates': (
      table: 'pre_dive_checklist_templates',
      pk: 'id',
    ),
    'preDiveChecklistTemplateItems': (
      table: 'pre_dive_checklist_template_items',
      pk: 'id',
    ),
    'preDiveSessions': (table: 'pre_dive_sessions', pk: 'id'),
    'preDiveSessionItems': (table: 'pre_dive_session_items', pk: 'id'),
    'gpsTracks': (table: 'gps_tracks', pk: 'id'),
    'siteFeatures': (table: 'site_features', pk: 'id'),
    'divePlans': (table: 'dive_plans', pk: 'id'),
    'divePlanTanks': (table: 'dive_plan_tanks', pk: 'id'),
    'divePlanSegments': (table: 'dive_plan_segments', pk: 'id'),
    'equipment': (table: 'equipment', pk: 'id'),
    'equipmentSets': (table: 'equipment_sets', pk: 'id'),
    // The equipmentSetItems junction is deliberately absent: it has no hlc
    // column and rides the parent set's clock (see _exportEquipmentSetItems).
    // Geofences are first-class rows with their own id and hlc, so they carry
    // their own clock.
    'equipmentSetGeofences': (table: 'equipment_set_geofences', pk: 'id'),
    'equipmentAttributes': (table: 'equipment_attributes', pk: 'id'),
    'cylinderConfigs': (table: 'cylinder_configs', pk: 'id'),
    'cylinderConfigItems': (table: 'cylinder_config_items', pk: 'id'),
    'diveTypes': (table: 'dive_types', pk: 'id'),
    'diveRoles': (table: 'dive_roles', pk: 'id'),
    'diverWeightEntries': (table: 'diver_weight_entries', pk: 'id'),
    'tankPresets': (table: 'tank_presets', pk: 'id'),
    'diveComputers': (table: 'dive_computers', pk: 'id'),
    'tags': (table: 'tags', pk: 'id'),
    'courses': (table: 'courses', pk: 'id'),
    // HLC merge-root only: the courseRequirementDives junction is clockless
    // and rides the parent requirement's hlc (equipment_set_items pattern).
    'courseRequirements': (table: 'course_requirements', pk: 'id'),
    'dives': (table: 'dives', pk: 'id'),
    'diveSites': (table: 'dive_sites', pk: 'id'),
    'certifications': (table: 'certifications', pk: 'id'),
    'serviceRecords': (table: 'service_records', pk: 'id'),
    'serviceKinds': (table: 'service_kinds', pk: 'id'),
    // Editing a schedule never touches the parent equipment row, so a
    // clockless child riding the parent's hlc would never replicate; the
    // schedule needs its own clock.
    'serviceSchedules': (table: 'service_schedules', pk: 'id'),
    'settings': (table: 'settings', pk: 'key'),
    'csvPresets': (table: 'csv_presets', pk: 'id'),
    'viewConfigs': (table: 'view_configs', pk: 'id'),
    'media': (table: 'media', pk: 'id'),
    'mediaEnrichment': (table: 'media_enrichment', pk: 'id'),
    'species': (table: 'species', pk: 'id'),
    'fieldPresets': (table: 'field_presets', pk: 'id'),
    'qualityFindings': (table: 'quality_findings', pk: 'id'),
    'emergencyChambers': (table: 'emergency_chambers', pk: 'id'),
    'incidents': (table: 'incidents', pk: 'id'),
    'mediaSmartAlbums': (table: 'media_smart_albums', pk: 'id'),
  };

  // ============================================================================
  // Sync Metadata Operations
  // ============================================================================

  /// Get the global sync metadata (creates if not exists)
  Future<SyncMetadataData> getOrCreateMetadata() async {
    try {
      final query = _db.select(_db.syncMetadata)
        ..where((t) => t.id.equals(_globalMetadataId));

      SyncMetadataData? existing;
      try {
        existing = await query.getSingleOrNull();
      } catch (e, stackTrace) {
        _log.warning(
          'Sync metadata read failed, attempting repair',
          error: e,
          stackTrace: stackTrace,
        );
        await _repairSyncMetadataRow();
        existing = await query.getSingleOrNull();
      }
      if (existing != null) return existing;

      // Create new metadata with a unique device ID. The seed uses
      // insertOrIgnore because getSingleOrNull above and this insert are not
      // atomic: on a fresh database two callers race to seed the 'global' row
      // (the launch reconcile via getDeviceId and the Cloud Sync page via
      // getLastSyncTime). Without insertOrIgnore the loser throws
      // SqliteException(1555) UNIQUE constraint failed, which the page surfaces
      // as "Failed to load sync state". First writer wins; the loser is a
      // no-op and re-reads the winning row below.
      final now = DateTime.now().millisecondsSinceEpoch;
      final deviceId = _uuid.v4();

      await _db
          .into(_db.syncMetadata)
          .insert(
            SyncMetadataCompanion(
              id: const Value(_globalMetadataId),
              deviceId: Value(deviceId),
              syncVersion: const Value(1),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
            mode: InsertMode.insertOrIgnore,
          );

      _log.info('Created sync metadata with deviceId: $deviceId');

      return (await query.getSingle());
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get or create sync metadata',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _repairSyncMetadataRow() async {
    final rows = await _db
        .customSelect(
          '''
      SELECT id, device_id, sync_version, created_at, updated_at
      FROM sync_metadata
      WHERE id = ?
      ''',
          variables: [Variable.withString(_globalMetadataId)],
        )
        .get();

    if (rows.isEmpty) return;

    final row = rows.first.data;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rawDeviceId = row['device_id'];
    final rawSyncVersion = row['sync_version'];
    final rawCreatedAt = row['created_at'];
    final rawUpdatedAt = row['updated_at'];

    final needsRepair =
        rawDeviceId == null ||
        rawDeviceId is! String ||
        rawDeviceId.isEmpty ||
        rawSyncVersion == null ||
        rawSyncVersion is! int ||
        rawCreatedAt == null ||
        rawCreatedAt is! int ||
        rawUpdatedAt == null ||
        rawUpdatedAt is! int;

    if (!needsRepair) return;

    final deviceId = rawDeviceId is String && rawDeviceId.isNotEmpty
        ? rawDeviceId
        : _uuid.v4();
    final syncVersion = rawSyncVersion is int ? rawSyncVersion : 1;
    final createdAt = rawCreatedAt is int ? rawCreatedAt : now;
    final updatedAt = rawUpdatedAt is int ? rawUpdatedAt : now;

    await _db.customStatement(
      '''
      UPDATE sync_metadata
      SET device_id = ?, sync_version = ?, created_at = ?, updated_at = ?
      WHERE id = ?
      ''',
      [deviceId, syncVersion, createdAt, updatedAt, _globalMetadataId],
    );
  }

  /// Get the device ID for this installation
  Future<String> getDeviceId() async {
    final metadata = await getOrCreateMetadata();
    return metadata.deviceId;
  }

  /// Get this database's instance token, or null if none has been set yet
  /// (rows predating the column, or a freshly created/restored database).
  Future<String?> getInstanceToken() async {
    final metadata = await getOrCreateMetadata();
    return metadata.instanceToken;
  }

  /// Generate and persist a fresh instance token, returning it.
  ///
  /// Rotating the token on each launch is what lets a later restore of an older
  /// backup be detected even when the device id is unchanged: the backup
  /// carries a superseded token that no longer matches the copy mirrored
  /// outside the database. See [SyncInitializer.reconcileDeviceIdentity].
  Future<String> rotateInstanceToken() async {
    await getOrCreateMetadata();
    final token = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.syncMetadata,
    )..where((t) => t.id.equals(_globalMetadataId))).write(
      SyncMetadataCompanion(instanceToken: Value(token), updatedAt: Value(now)),
    );
    return token;
  }

  /// Get the last sync timestamp.
  ///
  /// With [forProvider], the cursor is returned only if it was minted against
  /// that provider (or is a legacy unstamped cursor). A cursor belonging to a
  /// different backend reads as null -- "never synced here" -- so first
  /// contact with a switched backend stays detectable. Pass null only for
  /// display contexts that want the raw timestamp regardless of backend.
  Future<DateTime?> getLastSyncTime({String? forProvider}) async {
    final metadata = await getOrCreateMetadata();
    if (metadata.lastSyncTimestamp == null) return null;
    if (forProvider != null &&
        metadata.lastSyncProvider != null &&
        metadata.lastSyncProvider != forProvider) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(metadata.lastSyncTimestamp!);
  }

  /// Update the last sync timestamp, stamping the provider it was minted
  /// against. [providerId] should only be omitted by legacy-path tests; every
  /// production writer knows its provider.
  Future<void> updateLastSyncTime(
    DateTime syncTime, {
    String? providerId,
  }) async {
    try {
      await getOrCreateMetadata();
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(
        _db.syncMetadata,
      )..where((t) => t.id.equals(_globalMetadataId))).write(
        SyncMetadataCompanion(
          lastSyncTimestamp: Value(syncTime.millisecondsSinceEpoch),
          lastSyncProvider: Value(providerId),
          updatedAt: Value(now),
        ),
      );

      _log.info('Updated last sync time to: $syncTime');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update last sync time',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Claim a legacy (unstamped) cursor for [providerId]. Used at backend
  /// switch time: an unstamped cursor is valid for any provider, so without
  /// claiming it for the backend it was actually minted against, switching
  /// right after upgrading would carry it to the new backend.
  /// No-op when the cursor is absent or already stamped.
  Future<void> stampLegacyCursorProvider(String providerId) async {
    final metadata = await getOrCreateMetadata();
    if (metadata.lastSyncTimestamp == null) return;
    if (metadata.lastSyncProvider != null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.syncMetadata,
    )..where((t) => t.id.equals(_globalMetadataId))).write(
      SyncMetadataCompanion(
        lastSyncProvider: Value(providerId),
        updatedAt: Value(now),
      ),
    );
  }

  /// Set the cloud provider. Clearing it (null) also clears the sync
  /// account selection; setting a bare type leaves any account id in place
  /// (the account-aware writer is [setSyncAccount]).
  Future<void> setCloudProvider(CloudProviderType? provider) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(
        _db.syncMetadata,
      )..where((t) => t.id.equals(_globalMetadataId))).write(
        SyncMetadataCompanion(
          syncProvider: Value(provider?.name),
          syncAccountId: provider == null
              ? const Value(null)
              : const Value.absent(),
          updatedAt: Value(now),
        ),
      );

      _log.info('Set cloud provider to: ${provider?.name}');
      // Selection changed: let account-derived UI (pending-setup routes)
      // recompute while Settings stays mounted.
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set cloud provider',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Selects the connected account driving sync. Writes the provider name
  /// too so pre-account readers (and a rollback build) keep working.
  Future<void> setSyncAccount({
    required String accountId,
    required CloudProviderType providerType,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.syncMetadata,
    )..where((t) => t.id.equals(_globalMetadataId))).write(
      SyncMetadataCompanion(
        syncProvider: Value(providerType.name),
        syncAccountId: Value(accountId),
        updatedAt: Value(now),
      ),
    );
    SyncEventBus.notifyLocalChange();
  }

  /// The connected account driving sync, or null pre-account-migration or
  /// when no provider is selected.
  Future<String?> getSyncAccountId() async {
    final metadata = await getOrCreateMetadata();
    return metadata.syncAccountId;
  }

  /// Get the current cloud provider
  Future<CloudProviderType?> getCloudProvider() async {
    final metadata = await getOrCreateMetadata();
    if (metadata.syncProvider == null) return null;

    return CloudProviderType.values.firstWhere(
      (e) => e.name == metadata.syncProvider,
      orElse: () => CloudProviderType.googledrive,
    );
  }

  /// Set the remote file ID for the sync file
  Future<void> setRemoteFileId(String? fileId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(
        _db.syncMetadata,
      )..where((t) => t.id.equals(_globalMetadataId))).write(
        SyncMetadataCompanion(
          remoteFileId: Value(fileId),
          updatedAt: Value(now),
        ),
      );

      _log.info('Set remote file ID');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set remote file ID',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get the remote file ID
  Future<String?> getRemoteFileId() async {
    final metadata = await getOrCreateMetadata();
    return metadata.remoteFileId;
  }

  /// The library epoch this device last accepted, or null in the pre-epoch
  /// world. Dual-anchored with LibraryEpochStore's SharedPreferences mirror.
  Future<String?> getLastAcceptedEpochId() async {
    final metadata = await getOrCreateMetadata();
    return metadata.lastAcceptedEpochId;
  }

  Future<void> setLastAcceptedEpochId(String? epochId) async {
    try {
      await getOrCreateMetadata();
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.syncMetadata,
      )..where((t) => t.id.equals(_globalMetadataId))).write(
        SyncMetadataCompanion(
          lastAcceptedEpochId: Value(epochId),
          updatedAt: Value(now),
        ),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set last accepted epoch id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // Sync Records Operations
  // ============================================================================

  /// Mark a record as pending sync
  Future<void> markRecordPending({
    required String entityType,
    required String recordId,
    required int localUpdatedAt,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = '${entityType}_$recordId';

      // Mark-pending and the HLC stamp on the entity row are one logical write;
      // run them in a transaction so a crash can't leave the row pending with a
      // stale/absent HLC, and concurrent calls can't interleave the two steps.
      await _db.transaction(() async {
        await _db
            .into(_db.syncRecords)
            .insertOnConflictUpdate(
              SyncRecordsCompanion(
                id: Value(id),
                entityType: Value(entityType),
                recordId: Value(recordId),
                localUpdatedAt: Value(localUpdatedAt),
                syncStatus: const Value('pending'),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );

        await _stampHlc(entityType, recordId);
      });
    } catch (e, stackTrace) {
      _log.error(
        'Failed to mark record pending: $entityType/$recordId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Tables that can still hold rows written while their entity type did not
  /// stamp an HLC.
  ///
  /// Each entry names three things: the SQL table to scan, the `timestamp`
  /// column [backfillMissingHlc] reads as the row's local update time, and an
  /// optional `filter` restricting which rows are eligible.
  ///
  /// Two ways a table lands here: it gained the `hlc` column late
  /// (media_enrichment, schema v130), or it declared the column from the start
  /// but its entity type was missing from [hlcTargets], so `_stampHlc` silently
  /// no-opped on every write (issue #1144).
  static const List<
    ({String entityType, String table, String timestamp, String? filter})
  >
  _hlcBackfillTargets = [
    (
      entityType: 'mediaEnrichment',
      table: 'media_enrichment',
      timestamp: 'created_at',
      filter: null,
    ),
    (
      entityType: 'serviceKinds',
      table: 'service_kinds',
      timestamp: 'updated_at',
      // Built-ins are reference data seeded on every device and skipped by the
      // export, so stamping one only queues a sync record that publishes
      // nothing.
      filter: 'is_built_in = 0',
    ),
    (
      entityType: 'serviceSchedules',
      table: 'service_schedules',
      timestamp: 'updated_at',
      filter: null,
    ),
    (
      entityType: 'cylinderConfigs',
      table: 'cylinder_configs',
      timestamp: 'updated_at',
      filter: null,
    ),
    (
      entityType: 'cylinderConfigItems',
      table: 'cylinder_config_items',
      timestamp: 'updated_at',
      filter: null,
    ),
    (
      entityType: 'equipmentSetGeofences',
      table: 'equipment_set_geofences',
      timestamp: 'updated_at',
      filter: null,
    ),
  ];

  /// One-time self-heal for rows that carry `hlc IS NULL`. Such rows are
  /// invisible to the incremental export (which filters `hlc > watermark`;
  /// SQL `NULL > x` is false), so a local edit reaches peers only on a full
  /// base republish. markRecordPending stamps a fresh HLC (above every peer
  /// watermark) so they replicate on the next sync and heal peers that never
  /// received them.
  ///
  /// Self-limiting: every write path for these tables now stamps an HLC, so
  /// once the legacy rows are done this finds nothing.
  Future<void> backfillMissingHlc() async {
    for (final target in _hlcBackfillTargets) {
      final filter = target.filter == null ? '' : ' AND ${target.filter}';
      final rows = await _db
          .customSelect(
            'SELECT id, "${target.timestamp}" AS ts FROM "${target.table}" '
            'WHERE hlc IS NULL$filter',
          )
          .get();
      if (rows.isEmpty) continue;
      // One transaction per table: markRecordPending's own per-row transaction
      // nests as a savepoint, so a library with many affected rows commits once
      // instead of once per row (the per-row fsync was the sync-start cost
      // flagged in review).
      await _db.transaction(() async {
        for (final row in rows) {
          await markRecordPending(
            entityType: target.entityType,
            recordId: row.read<String>('id'),
            localUpdatedAt: row.read<int>('ts'),
          );
        }
      });
    }
  }

  /// Stamp a fresh Hybrid Logical Clock onto the just-written entity row, if
  /// the entity is conflict-capable and the clock is configured. Centralised
  /// here (the write choke point) rather than in every repository companion.
  /// The row is expected to already exist (repositories mark pending after the
  /// insert/update); if it does not, the UPDATE is a harmless no-op.
  Future<void> _stampHlc(String entityType, String recordId) async {
    final target = hlcTargets[entityType];
    if (target == null) return;
    await ensureSyncClockConfigured();
    final hlc = SyncClock.instance.issue();
    if (hlc == null) return;
    await _db.customStatement(
      'UPDATE "${target.table}" SET hlc = ? WHERE "${target.pk}" = ?',
      [hlc, recordId],
    );
  }

  /// Configure the process-wide [SyncClock] from this device's id and its
  /// persisted clock value, once per process. Lazy so the first local write
  /// stamps an HLC even before the first sync runs.
  Future<void> ensureSyncClockConfigured() async {
    if (SyncClock.instance.isConfigured) return;
    final metadata = await getOrCreateMetadata();
    // Seed from the greater of the persisted clock and the highest HLC already
    // stamped on any entity row, then force our own node id. The persisted
    // clock can lag the rows if the app was killed between syncs (it is only
    // persisted at sync time but advanced in memory per write); seeding from
    // the on-disk rows guarantees the next local write is never ordered behind
    // data this device already wrote -- which would otherwise let a remote win
    // a record the local device edited more recently.
    final seed = _seedHlc(
      metadata.deviceId,
      _parseHlc(metadata.hlc),
      _parseHlc(await _maxRowHlc()),
    );
    SyncClock.instance.configure(nodeId: metadata.deviceId, persisted: seed);
  }

  /// The highest `hlc` value across every conflict-capable table, or null if
  /// none has one yet. Lexically comparable because the packed format zero-pads
  /// physical time and counter.
  Future<String?> _maxRowHlc() async {
    final union = hlcTargets.values
        .map((t) => 'SELECT MAX(hlc) AS h FROM "${t.table}"')
        .join(' UNION ALL ');
    final row = await _db
        .customSelect('SELECT MAX(h) AS m FROM ($union)')
        .getSingleOrNull();
    return row?.read<String?>('m');
  }

  /// Public accessor for [_maxRowHlc] -- the highest hlc across conflict-capable
  /// tables.
  Future<String?> maxRowHlc() => _maxRowHlc();

  /// The highest hlc this device still ACCOUNTS FOR: live rows or tombstones.
  ///
  /// [maxRowHlc] alone answers "what do I still have", which is the wrong
  /// question for stale-restore detection. Deleting the newest record drops the
  /// live-row maximum below the published watermark even though nothing was
  /// rewound -- the tombstone stamped at deletion time (always ABOVE anything
  /// previously published, since it comes from `SyncClock.issue()`) is the
  /// device's record of that decision. Counting it distinguishes "the user
  /// removed data" from "a restore rewound this device", which loses the
  /// tombstones along with the rows.
  Future<String?> maxAccountedHlc() async {
    final rowHigh = await _maxRowHlc();
    final maxDeletionHlc = _db.deletionLog.hlc.max();
    final row = await (_db.selectOnly(
      _db.deletionLog,
    )..addColumns([maxDeletionHlc])).getSingleOrNull();
    final tombstoneHigh = row?.read(maxDeletionHlc);
    if (rowHigh == null) return tombstoneHigh;
    if (tombstoneHigh == null) return rowHigh;
    return rowHigh.compareTo(tombstoneHigh) >= 0 ? rowHigh : tombstoneHigh;
  }

  /// Pick the greater of [a]/[b] by (physicalTime, counter) and rebuild it with
  /// [nodeId] so the clock always issues under THIS device's identity.
  Hlc? _seedHlc(String nodeId, Hlc? a, Hlc? b) {
    Hlc? best;
    for (final h in [a, b]) {
      if (h == null) continue;
      if (best == null ||
          h.physicalTime > best.physicalTime ||
          (h.physicalTime == best.physicalTime && h.counter > best.counter)) {
        best = h;
      }
    }
    if (best == null) return null;
    return Hlc(best.physicalTime, best.counter, nodeId);
  }

  /// Persist the current [SyncClock] value so the logical counter survives an
  /// app restart. Called by the sync flow after a sync completes.
  Future<void> persistSyncClock() async {
    final current = SyncClock.instance.current;
    if (current == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.syncMetadata,
    )..where((t) => t.id.equals(_globalMetadataId))).write(
      SyncMetadataCompanion(
        hlc: Value(current.toString()),
        updatedAt: Value(now),
      ),
    );
  }

  Hlc? _parseHlc(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return Hlc.parse(value);
    } catch (_) {
      return null;
    }
  }

  /// Mark a record as synced
  Future<void> markRecordSynced({
    required String entityType,
    required String recordId,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = '${entityType}_$recordId';

      await _db
          .into(_db.syncRecords)
          .insertOnConflictUpdate(
            SyncRecordsCompanion(
              id: Value(id),
              entityType: Value(entityType),
              recordId: Value(recordId),
              localUpdatedAt: Value(now),
              syncStatus: const Value('synced'),
              syncedAt: Value(now),
              conflictData: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to mark record synced: $entityType/$recordId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Mark a record as having a conflict
  Future<void> markRecordConflict({
    required String entityType,
    required String recordId,
    required String conflictDataJson,
    required int localUpdatedAt,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = '${entityType}_$recordId';

      await _db
          .into(_db.syncRecords)
          .insertOnConflictUpdate(
            SyncRecordsCompanion(
              id: Value(id),
              entityType: Value(entityType),
              recordId: Value(recordId),
              localUpdatedAt: Value(localUpdatedAt),
              syncStatus: const Value('conflict'),
              conflictData: Value(conflictDataJson),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      _log.warning('Marked conflict for: $entityType/$recordId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to mark record conflict: $entityType/$recordId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get all pending sync records
  Future<List<SyncRecord>> getPendingRecords() async {
    try {
      final query = _db.select(_db.syncRecords)
        ..where((t) => t.syncStatus.equals('pending'));
      return await query.get();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get pending records',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get all conflict records
  Future<List<SyncRecord>> getConflictRecords() async {
    try {
      final query = _db.select(_db.syncRecords)
        ..where((t) => t.syncStatus.equals('conflict'));
      return await query.get();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get conflict records',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get count of pending changes.
  ///
  /// Counts in SQL rather than materializing every pending row: this runs on
  /// every local write now that the sync chip reflects it live.
  Future<int> getPendingCount() async {
    try {
      final count = _db.syncRecords.id.count();
      final row =
          await (_db.selectOnly(_db.syncRecords)
                ..addColumns([count])
                ..where(_db.syncRecords.syncStatus.equals('pending')))
              .getSingle();
      // Hoisted to a local on purpose: TypedResult.read is synchronous, but
      // Dart 3.13's unawaited_return_in_try_block false-positives on returning
      // it directly from a try. Do not inline this back.
      final pending = row.read(count) ?? 0;
      return pending;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get pending count',
        error: e,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  /// Deletions this device has made that have NOT yet been published.
  ///
  /// Deletions never touch `sync_records`, so [getPendingCount] alone reports
  /// a delete-only change set as zero -- the UI then claims "Synced" while
  /// tombstones sit unsent. The whole deletion log is the wrong number too:
  /// tombstones survive publication (only [clearAcknowledgedDeletions] removes
  /// them, once the fleet has acked), so counting all of them would pin the UI
  /// to "unsynced" forever.
  ///
  /// [upToHlc] is the active provider's `publishedHlcHigh`; this mirrors the
  /// filter the changeset writer applies, so the count matches what a sync
  /// would actually send. A null [upToHlc] means nothing has been published
  /// yet, so every tombstone counts. A null row hlc is always counted: it
  /// cannot be compared, so it rides every base and is unpublished until one
  /// goes out.
  Future<int> getUnpublishedDeletionCount({required String? upToHlc}) async {
    try {
      final count = _db.deletionLog.id.count();
      final query = _db.selectOnly(_db.deletionLog)..addColumns([count]);
      if (upToHlc != null) {
        query.where(
          _db.deletionLog.hlc.isNull() |
              _db.deletionLog.hlc.isBiggerThanValue(upToHlc),
        );
      }
      final row = await query.getSingle();
      // Hoisted to a local on purpose: TypedResult.read is synchronous, but
      // Dart 3.13's unawaited_return_in_try_block false-positives on returning
      // it directly from a try. Do not inline this back.
      final deletions = row.read(count) ?? 0;
      return deletions;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get unpublished deletion count',
        error: e,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  /// Every local change a sync would send: pending record edits plus the
  /// tombstones above [providerId]'s publish watermark. This is the number the
  /// UI means by "unsynced"; [getPendingCount] alone misses deletions.
  ///
  /// A null [providerId] means no cloud provider is configured, so nothing has
  /// ever been published and every tombstone counts.
  Future<int> getUnsyncedChangeCount({required String? providerId}) async {
    final pending = await getPendingCount();
    if (providerId == null) {
      return pending + await getUnpublishedDeletionCount(upToHlc: null);
    }
    final String? watermark;
    try {
      watermark = (await PublishStateStore(
        _db,
      ).get(providerId))?.publishedHlcHigh;
    } catch (e, stackTrace) {
      // This count is advisory and its callers treat it as non-failing (the
      // notifier would otherwise turn a status query into a page-wide error).
      // Without a watermark, report the pending records alone rather than
      // counting the entire deletion log as unsent.
      _log.error(
        'Failed to read publish watermark for $providerId',
        error: e,
        stackTrace: stackTrace,
      );
      return pending;
    }
    return pending + await getUnpublishedDeletionCount(upToHlc: watermark);
  }

  /// Clear all pending sync records
  Future<void> clearPendingRecords() async {
    try {
      await (_db.delete(
        _db.syncRecords,
      )..where((t) => t.syncStatus.equals('pending'))).go();
      _log.info('Cleared pending sync records');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to clear pending sync records',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get count of conflicts
  Future<int> getConflictCount() async {
    try {
      final records = await getConflictRecords();
      return records.length;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get conflict count',
        error: e,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  /// Clear a conflict record after resolution
  Future<void> clearConflict({
    required String entityType,
    required String recordId,
  }) async {
    try {
      final id = '${entityType}_$recordId';
      await (_db.delete(_db.syncRecords)..where((t) => t.id.equals(id))).go();
      _log.info('Cleared conflict for: $entityType/$recordId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to clear conflict: $entityType/$recordId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Clear all sync records (useful after full sync)
  Future<void> clearAllSyncRecords() async {
    try {
      await _db.delete(_db.syncRecords).go();
      _log.info('Cleared all sync records');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to clear all sync records',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // Deletion Log Operations
  // ============================================================================

  /// Log a record deletion for sync
  Future<void> logDeletion({
    required String entityType,
    required String recordId,
    int? deletedAt,
  }) async {
    try {
      final id = _uuid.v4();
      final now = deletedAt ?? DateTime.now().millisecondsSinceEpoch;

      // Stamp a monotonic HLC so the changeset writer can publish only NEW
      // tombstones (filtered by hlc > publishedHlcHigh) instead of re-sending
      // the whole deletion log every sync. Deliberately NOT gated on
      // hlcTargets: write-once child deletions (diveTanks, diveProfileEvents,
      // ...) have no row hlc but their tombstones still need one. Configure the
      // clock first -- deletes routinely fire outside a sync. A null hlc (clock
      // unconfigurable) still rides every full base, so no tombstone is lost.
      await ensureSyncClockConfigured();
      final hlc = SyncClock.instance.issue();

      await _db.transaction(() async {
        // One tombstone per record: replace any prior tombstone for this key
        // so its deletedAt/hlc advance (re-delete refreshes the stamp) and the
        // v114 unique index is never violated.
        await (_db.delete(_db.deletionLog)..where(
              (t) =>
                  t.entityType.equals(entityType) & t.recordId.equals(recordId),
            ))
            .go();
        await _db
            .into(_db.deletionLog)
            .insert(
              DeletionLogCompanion(
                id: Value(id),
                entityType: Value(entityType),
                recordId: Value(recordId),
                deletedAt: Value(now),
                hlc: Value(hlc),
              ),
            );
      });

      _log.info('Logged deletion: $entityType/$recordId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to log deletion: $entityType/$recordId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get deletions since a given timestamp
  Future<List<DeletionLogData>> getDeletionsSince(DateTime since) async {
    try {
      final query = _db.select(_db.deletionLog)
        ..where(
          (t) => t.deletedAt.isBiggerOrEqualValue(since.millisecondsSinceEpoch),
        );
      return await query.get();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get deletions since: $since',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get all deletions
  Future<List<DeletionLogData>> getAllDeletions() async {
    try {
      return await _db.select(_db.deletionLog).get();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get all deletions',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Log a deletion if one doesn't already exist for the same record
  Future<void> logDeletionIfMissing({
    required String entityType,
    required String recordId,
    required int deletedAt,
  }) async {
    // Use .get() instead of .getSingleOrNull() to handle cases where
    // duplicate deletion entries exist (the schema allows this since
    // the primary key is a UUID, not the entityType+recordId combo).
    final existing =
        await (_db.select(_db.deletionLog)
              ..where((t) => t.entityType.equals(entityType))
              ..where((t) => t.recordId.equals(recordId)))
            .get();
    if (existing.isNotEmpty) return;
    await logDeletion(
      entityType: entityType,
      recordId: recordId,
      deletedAt: deletedAt,
    );
  }

  /// Remove the tombstone(s) for one record of [entityType]. The deletion log
  /// is a single table shared across entity types and recordIds are only unique
  /// within an entity type, so the delete matches BOTH [entityType] and
  /// [recordId]. Called when a remote edit newer than the deletion revives the
  /// record, so the obsolete tombstone stops re-deleting it on later syncs.
  Future<void> removeDeletion({
    required String entityType,
    required String recordId,
  }) async {
    try {
      await (_db.delete(_db.deletionLog)..where(
            (t) =>
                t.entityType.equals(entityType) & t.recordId.equals(recordId),
          ))
          .go();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to remove deletion: $entityType/$recordId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Fleet-acked tombstone GC: delete tombstones that (a) are older than the
  /// safety floor, (b) carry an HLC (a null-hlc tombstone cannot be compared
  /// so it is kept and rides every base -- rare and harmless), and (c) sort at
  /// or below [upToHlc], the minimum HLC every live peer's manifest
  /// acknowledges having applied from us. A null [upToHlc] means no live peer
  /// constrains GC (single-device library): the floor alone applies.
  /// Replaces the old unconditional 90-day purge, which silently resurrected
  /// records on devices offline longer than the window.
  Future<void> clearAcknowledgedDeletions({
    required String? upToHlc,
    required int floorCutoffMillis,
  }) async {
    try {
      await (_db.delete(_db.deletionLog)..where((t) {
            final base =
                t.deletedAt.isSmallerThanValue(floorCutoffMillis) &
                t.hlc.isNotNull();
            if (upToHlc == null) return base;
            return base & t.hlc.isSmallerOrEqualValue(upToHlc);
          }))
          .go();
      _log.info('Cleared acknowledged deletions (upTo: $upToHlc)');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to clear acknowledged deletions',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Clear all deletions (after successful sync)
  Future<void> clearAllDeletions() async {
    try {
      await _db.delete(_db.deletionLog).go();
      _log.info('Cleared all deletions');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to clear all deletions',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // Utility Methods
  // ============================================================================

  /// Check if sync is enabled (has a provider set)
  Future<bool> isSyncEnabled() async {
    final provider = await getCloudProvider();
    return provider != null;
  }

  /// Check if there are any pending changes or conflicts
  Future<bool> hasUnsyncedChanges() async {
    final pendingCount = await getPendingCount();
    final conflictCount = await getConflictCount();
    final deletions = await getAllDeletions();
    return pendingCount > 0 || conflictCount > 0 || deletions.isNotEmpty;
  }

  /// Reset sync state (useful for testing or switching accounts).
  ///
  /// [clearDeletionLog] defaults to the historical full wipe (used by
  /// [rebaselineAfterRestore], where the restored log is the backup's stale
  /// snapshot). The user-facing Reset Sync State passes false: tombstones are
  /// data history, and wiping them lets any stale peer file re-insert every
  /// record deleted since that file was written.
  Future<void> resetSyncState({bool clearDeletionLog = true}) async {
    try {
      await clearAllSyncRecords();
      if (clearDeletionLog) {
        await clearAllDeletions();
      }

      // Changeset transport position is not data history: a reset must
      // cold-start the transport so the next sync re-pulls every peer from
      // scratch and republishes a fresh base. Leaving a provider-keyed publish
      // row behind would make the next publish append a changeset against a
      // base whose own manifest no longer exists.
      await _db.delete(_db.syncPeerCursors).go();
      await _db.delete(_db.localPublishStates).go();

      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.syncMetadata,
      )..where((t) => t.id.equals(_globalMetadataId))).write(
        SyncMetadataCompanion(
          lastSyncTimestamp: const Value(null),
          lastSyncProvider: const Value(null),
          remoteFileId: const Value(null),
          updatedAt: Value(now),
        ),
      );

      _log.info('Reset sync state');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to reset sync state',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Overwrite the stored device id. Used to preserve this installation's sync
  /// identity across a database restore, which would otherwise replace it with
  /// the (possibly stale, possibly foreign) device id captured in the backup.
  Future<void> setDeviceId(String deviceId) async {
    if (deviceId.trim().isEmpty) {
      // A blank device id would corrupt sync identity (per-device file name and
      // HLC node id), so reject it rather than persist it.
      throw ArgumentError.value(
        deviceId,
        'deviceId',
        'device id must not be empty',
      );
    }
    try {
      await getOrCreateMetadata();
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.syncMetadata,
      )..where((t) => t.id.equals(_globalMetadataId))).write(
        SyncMetadataCompanion(deviceId: Value(deviceId), updatedAt: Value(now)),
      );
    } catch (e, stackTrace) {
      _log.error('Failed to set device id', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Re-baseline sync after a database restore.
  ///
  /// A restore replaces the entire database, so `sync_metadata` (device id,
  /// HLC clock, last-sync timestamp, cursors) and the deletion log all revert
  /// to the backup's stale snapshot. The merge gates on the persisted
  /// `lastSync` (`localUpdatedAt > lastSyncMs` reads almost every restored row
  /// as a conflict), so a rewound baseline stalls sync and lets a peer's
  /// still-live copy keep resurrecting deletes.
  ///
  /// Preserve the live device identity (captured by the caller *before* the
  /// restore) and clear the sync baseline so the next sync performs a clean
  /// full reconcile of the restored data instead of replaying a stale position.
  Future<void> rebaselineAfterRestore({
    String? preserveDeviceId,
    String? preserveEpochId,
  }) async {
    if (preserveDeviceId != null && preserveDeviceId.isNotEmpty) {
      await setDeviceId(preserveDeviceId);
    }
    await resetSyncState();
    // The restored database carries the backup's stale epoch; overwrite it
    // with the live value captured by the caller before the swap (or null
    // when this install has never accepted an epoch).
    await setLastAcceptedEpochId(preserveEpochId);
    // Drop the in-memory clock so it re-seeds from the restored rows under this
    // device's id on the next write. (issue() advances physical time to now()
    // regardless, so local writes are never ordered behind the restored data.)
    SyncClock.instance.reset();
  }
}
