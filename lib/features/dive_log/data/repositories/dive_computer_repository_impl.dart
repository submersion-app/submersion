import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/database/database.dart'
    show
        AppDatabase,
        DiveComputersCompanion,
        DiveDataSourcesCompanion,
        DiveDiveTypesCompanion,
        DiveProfileEventsCompanion,
        DivesCompanion,
        DiveTanksCompanion,
        GasSwitchesCompanion,
        DiveProfileEvent;
import 'package:submersion/core/database/imported_computer_identity.dart';
import 'package:submersion/core/matching/match_scorer.dart';
import 'package:submersion/core/utils/deco_dive_detector.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    show GeoPoint;
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart'
    as codec;
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart'
    show TankPressureSample;
import 'package:submersion/features/dive_log/domain/services/bottom_time_calculator.dart';
import 'package:submersion/features/dive_log/domain/services/dive_altitude_enricher.dart';
import 'package:submersion/features/dive_log/domain/services/tank_pressure_series.dart';
import 'package:submersion/features/equipment/data/services/dive_computer_gear_linker.dart';
import 'package:submersion/features/equipment/data/services/dive_computer_gear_resolver.dart';
import 'package:submersion/features/equipment/data/services/dive_equipment_defaulter.dart';
import 'package:submersion/features/pre_dive/data/services/checklist_dive_linker.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart'
    as domain;

/// Repository for managing dive computers and multi-profile support.
class DiveComputerRepository {
  DiveComputerRepository({DiveAltitudeEnricher? altitudeEnricher})
    : _altitudeEnricher = altitudeEnricher ?? DiveAltitudeEnricher();

  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final ProfileSeriesRepository _profileSeries = ProfileSeriesRepository();
  final TankPressureSeriesRepository _tankSeries =
      TankPressureSeriesRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(DiveComputerRepository);

  /// Emits whenever the `dive_computers` registry changes so the computer
  /// pickers and the favourite/primary selectors refresh after a download
  /// registers a new computer, or a sync applies a remote rename or removal.
  ///
  /// Debounced, unlike most ticks in the app: registering a computer happens
  /// inside a download that also writes dives, profiles, tanks, and data
  /// sources, so an un-debounced tick would rebuild the pickers repeatedly
  /// mid-download instead of once on the settled state.
  Stream<void> watchComputersChanges() => _db
      .tableUpdates(TableUpdateQuery.onTable(_db.diveComputers))
      .debounce(DiveRepository.changeTickDebounce);

  /// Held for the repository's lifetime so a multi-dive download shares one
  /// elevation-lookup cache: a trip's worth of dives at the same site costs a
  /// single request (and a single failure) instead of one per dive.
  final DiveAltitudeEnricher _altitudeEnricher;

  // ============================================================================
  // CRUD Operations for Dive Computers
  // ============================================================================

  /// Get all dive computers
  Future<List<domain.DiveComputer>> getAllComputers({String? diverId}) async {
    try {
      final query = _db.select(_db.diveComputers)
        ..orderBy([
          (t) => OrderingTerm.desc(t.isFavorite),
          (t) => OrderingTerm.asc(t.name),
        ]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return rows.map((row) => _mapRowToComputer(row)).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get all dive computers',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get a dive computer by ID
  Future<domain.DiveComputer?> getComputerById(String id) async {
    try {
      final query = _db.select(_db.diveComputers)
        ..where((t) => t.id.equals(id));

      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToComputer(row) : null;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive computer by id: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get the favorite (primary) dive computer
  Future<domain.DiveComputer?> getFavoriteComputer({String? diverId}) async {
    try {
      final query = _db.select(_db.diveComputers)
        ..where((t) => t.isFavorite.equals(true))
        ..limit(1);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToComputer(row) : null;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get favorite dive computer',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Find a dive computer by its Bluetooth address.
  ///
  /// When [diverId] is provided (non-empty), only returns a computer that
  /// belongs to that diver. The query orders by most recently updated and
  /// applies `LIMIT 1` before calling `.getSingleOrNull()`, so it does not
  /// throw when multiple records exist for the same bluetooth address.
  /// Empty/blank [diverId] is treated as null (no diver filter).
  ///
  /// Returns `null` if no matching computer exists.
  Future<domain.DiveComputer?> findByBluetoothAddress(
    String address, {
    String? diverId,
  }) async {
    try {
      final normalizedDiverId = diverId?.trim().isEmpty == true
          ? null
          : diverId;
      final query = _db.select(_db.diveComputers)
        ..where((t) => t.bluetoothAddress.equals(address))
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
        ..limit(1);

      if (normalizedDiverId != null) {
        query.where((t) => t.diverId.equals(normalizedDiverId));
      }

      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToComputer(row) : null;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to find dive computer by bluetooth address: $address',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Find a computer by its stable hardware identity.
  ///
  /// BLE identifiers are host-specific and are therefore only useful for a
  /// local connection. The serial number, together with manufacturer/model,
  /// identifies the physical computer across devices.
  Future<domain.DiveComputer?> findByHardwareIdentity({
    required String manufacturer,
    required String model,
    required String serialNumber,
    String? diverId,
  }) async {
    try {
      final query = _db.select(_db.diveComputers)
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
      final normalizedDiverId = diverId?.trim();
      if (normalizedDiverId != null && normalizedDiverId.isNotEmpty) {
        query.where((t) => t.diverId.equals(normalizedDiverId));
      }

      // Matched in Dart (rather than pushed into the SQL filter) because a
      // stored serialNumber/manufacturer/model may itself carry whitespace
      // from an older import; trimming only the input would miss that row.
      final rows = await query.get();
      final normalizedSerial = serialNumber.trim();
      final normalizedManufacturer = manufacturer.trim().toLowerCase();
      final normalizedModel = model.trim().toLowerCase();
      for (final row in rows) {
        if (row.serialNumber?.trim() == normalizedSerial &&
            row.manufacturer?.trim().toLowerCase() == normalizedManufacturer &&
            row.model?.trim().toLowerCase() == normalizedModel) {
          return _mapRowToComputer(row);
        }
      }
      return null;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to find dive computer by hardware identity',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Create a new dive computer
  Future<domain.DiveComputer> createComputer(
    domain.DiveComputer computer,
  ) async {
    try {
      _log.info('Creating dive computer: ${computer.name}');
      final id = computer.id.isEmpty ? _uuid.v4() : computer.id;
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db
          .into(_db.diveComputers)
          .insert(
            DiveComputersCompanion(
              id: Value(id),
              diverId: Value(computer.diverId),
              name: Value(computer.name),
              manufacturer: Value(computer.manufacturer),
              model: Value(computer.model),
              serialNumber: Value(computer.serialNumber),
              firmwareVersion: Value(computer.firmwareVersion),
              connectionType: Value(computer.connectionType),
              bluetoothAddress: Value(computer.bluetoothAddress),
              lastDownloadTimestamp: Value(
                computer.lastDownload?.millisecondsSinceEpoch,
              ),
              diveCount: Value(computer.diveCount),
              isFavorite: Value(computer.isFavorite),
              notes: Value(computer.notes),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      // Seed the gear twin once, here, because this is the only repository
      // path that genuinely inserts a registry row (v175). Minting nowhere
      // else is what makes a user-deleted twin permanent. Pass the resolved
      // id: the caller's may have been empty and minted just above.
      final twinId = await DiveComputerGearResolver().resolveGearTwin(
        computer.copyWith(id: id),
      );
      if (twinId != null) {
        await _db.customStatement(
          'UPDATE dive_computers SET equipment_id = ? WHERE id = ?',
          [twinId, id],
        );
      }

      // Marked pending ONCE, after the optional equipment_id write, so the row
      // carries a single HLC representing its final state. Marking on either
      // side of that update would spend two clock ticks on one logical
      // creation. Unconditional: a computer whose twin failed to resolve is
      // still a registered computer and still has to sync.
      await _syncRepository.markRecordPending(
        entityType: 'diveComputers',
        recordId: id,
        localUpdatedAt: now,
      );

      // If a computer with this hardware identity was deleted earlier, its
      // dives kept provenance snapshots; give them their link back.
      await _relinkOrphanedRows(id, computer);
      SyncEventBus.notifyLocalChange();

      _log.info('Created dive computer with id: $id');
      return computer.copyWith(
        id: id,
        equipmentId: twinId,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create dive computer',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update an existing dive computer
  Future<void> updateComputer(domain.DiveComputer computer) async {
    try {
      _log.info('Updating dive computer: ${computer.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(
        _db.diveComputers,
      )..where((t) => t.id.equals(computer.id))).write(
        DiveComputersCompanion(
          name: Value(computer.name),
          manufacturer: Value(computer.manufacturer),
          model: Value(computer.model),
          serialNumber: Value(computer.serialNumber),
          firmwareVersion: Value(computer.firmwareVersion),
          connectionType: Value(computer.connectionType),
          bluetoothAddress: Value(computer.bluetoothAddress),
          lastDownloadTimestamp: Value(
            computer.lastDownload?.millisecondsSinceEpoch,
          ),
          diveCount: Value(computer.diveCount),
          isFavorite: Value(computer.isFavorite),
          notes: Value(computer.notes),
          updatedAt: Value(now),
        ),
      );

      await _syncRepository.markRecordPending(
        entityType: 'diveComputers',
        recordId: computer.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Updated dive computer: ${computer.id}');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update dive computer: ${computer.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a dive computer
  ///
  /// Every dive referencing the computer keeps a `dive_data_sources` text
  /// snapshot (model + serial) of the device that produced it, backfilled
  /// here when missing, so the provenance record survives the delete and
  /// [_relinkOrphanedRows] can restore the links if the same hardware is
  /// added again. FK references in `dives`, `dive_profile_series`, and
  /// `dive_data_sources` are then nulled out so the delete is not blocked by
  /// foreign key constraints; the dive/profile/data-source rows themselves
  /// are preserved.
  Future<void> deleteComputer(String id) async {
    try {
      _log.info('Deleting dive computer: $id');

      final row = await (_db.select(
        _db.diveComputers,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row != null) {
        await _backfillProvenanceSnapshots(_mapRowToComputer(row));
      }

      // Clear the series first: their FK is ON DELETE SET NULL, so the
      // dive_computers delete that follows would null series.computer_id via
      // the cascade without restamping hlc, and peers would never learn of
      // the change.
      await _profileSeries.clearComputer(id);
      await _tankSeries.clearComputer(id);

      // Clear FK references that would block the delete. dives.computer_id
      // has no ON DELETE action, so leaving it set fails the delete with
      // SqliteException(787) on any computer that a dive references (#823).
      await _db.customStatement(
        'UPDATE dives SET computer_id = NULL WHERE computer_id = ?',
        [id],
      );
      await _db.customStatement(
        'UPDATE dive_data_sources SET computer_id = NULL WHERE computer_id = ?',
        [id],
      );
      // The v183 rung drops dive_profiles only once its rows have actually
      // moved into the series table, so a device whose pack threw still
      // carries it, and its computer_id FK has no ON DELETE action either.
      // Same #823 failure as dives.computer_id, so clear it the same way.
      // tank_pressure_profiles needs no equivalent: its FK is SET NULL.
      if (await _legacyProfilesTableExists()) {
        await _db.customStatement(
          'UPDATE dive_profiles SET computer_id = NULL WHERE computer_id = ?',
          [id],
        );
      }

      await (_db.delete(_db.diveComputers)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(
        entityType: 'diveComputers',
        recordId: id,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted dive computer: $id');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete dive computer: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Whether the pre-v183 row-per-sample `dive_profiles` table is still in
  /// this database. Every current build reads samples from the series
  /// tables, so a hit here means the v183 pack could not finish and the
  /// table was deliberately kept for a later retry.
  Future<bool> _legacyProfilesTableExists() async {
    final rows = await _db
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' "
          "AND name = 'dive_profiles'",
        )
        .get();
    return rows.isNotEmpty;
  }

  /// Insert a `dive_data_sources` snapshot for every dive that references
  /// [computer] but has no data source row for it (dives imported before
  /// provenance rows existed). The snapshot's text columns are what the UI
  /// shows and what relinking matches on once the computer row is gone.
  Future<void> _backfillProvenanceSnapshots(
    domain.DiveComputer computer,
  ) async {
    final orphanDives = await _db
        .customSelect(
          'SELECT d.id AS dive_id, '
          'NOT EXISTS(SELECT 1 FROM dive_data_sources p '
          'WHERE p.dive_id = d.id AND p.is_primary = 1) AS needs_primary '
          'FROM dives d WHERE d.computer_id = ? AND NOT EXISTS('
          'SELECT 1 FROM dive_data_sources s WHERE s.dive_id = d.id '
          'AND s.computer_id = ?)',
          variables: [Variable(computer.id), Variable(computer.id)],
          readsFrom: {_db.dives, _db.diveDataSources},
        )
        .get();
    if (orphanDives.isEmpty) return;

    final now = DateTime.now();
    for (final row in orphanDives) {
      await _db
          .into(_db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion.insert(
              id: _uuid.v4(),
              diveId: row.read<String>('dive_id'),
              isPrimary: Value(row.read<int>('needs_primary') == 1),
              computerModel: Value(computer.fullName),
              computerSerial: Value(computer.serialNumber),
              sourceFormat: const Value('dive_computer'),
              importedAt: now,
              createdAt: now,
            ),
          );
    }
    _log.info(
      'Backfilled ${orphanDives.length} provenance snapshot(s) '
      'for computer ${computer.id}',
    );
  }

  /// Restore the links a deleted computer with this hardware identity left
  /// behind. Orphaned `dive_data_sources` rows are matched on the model +
  /// serial snapshot; their dives (when the matched source is the dive's
  /// primary and no live computer claims the dive) and, for dives whose
  /// computer attribution is unambiguous, their profiles get [computerId]
  /// back. Relinked dives are marked pending so the restored link syncs.
  /// Best-effort: a relink failure must never fail the computer creation.
  Future<void> _relinkOrphanedRows(
    String computerId,
    domain.DiveComputer computer,
  ) async {
    final serial = computer.serialNumber;
    if (serial == null || serial.isEmpty) return;
    try {
      final matched = await _db
          .customSelect(
            'SELECT id, dive_id, is_primary FROM dive_data_sources '
            'WHERE computer_id IS NULL AND source_format = ? '
            'AND computer_model = ? AND computer_serial = ?',
            variables: [
              const Variable('dive_computer'),
              Variable(computer.fullName),
              Variable(serial),
            ],
            readsFrom: {_db.diveDataSources},
          )
          .get();
      if (matched.isEmpty) return;

      final sourceIds = matched.map((r) => r.read<String>('id')).toList();
      final sourcePh = List.filled(sourceIds.length, '?').join(', ');
      await _db.customStatement(
        'UPDATE dive_data_sources SET computer_id = ? WHERE id IN ($sourcePh)',
        [computerId, ...sourceIds],
      );

      // Restore the dive's primary-computer link where the matched source is
      // the dive's primary and no live computer claims the dive.
      final primaryDiveIds = matched
          .where((r) => r.read<int>('is_primary') != 0)
          .map((r) => r.read<String>('dive_id'))
          .toSet()
          .toList();
      if (primaryDiveIds.isNotEmpty) {
        final divePh = List.filled(primaryDiveIds.length, '?').join(', ');
        final claimable = await _db
            .customSelect(
              'SELECT id FROM dives '
              'WHERE computer_id IS NULL AND id IN ($divePh)',
              variables: [for (final d in primaryDiveIds) Variable(d)],
              readsFrom: {_db.dives},
            )
            .get();
        final diveIds = claimable.map((r) => r.read<String>('id')).toList();
        if (diveIds.isNotEmpty) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final ph = List.filled(diveIds.length, '?').join(', ');
          await _db.customStatement(
            'UPDATE dives SET computer_id = ?, updated_at = ? '
            'WHERE id IN ($ph)',
            [computerId, now, ...diveIds],
          );
          for (final diveId in diveIds) {
            await _syncRepository.markRecordPending(
              entityType: 'dives',
              recordId: diveId,
              localUpdatedAt: now,
            );
          }
        }
      }

      // Profiles carry no serial snapshot of their own, so restore them only
      // when the dive's computer attribution is unambiguous: exactly one
      // dive_computer source row.
      final matchedDiveIds = matched
          .map((r) => r.read<String>('dive_id'))
          .toSet()
          .toList();
      await _profileSeries.relinkComputer(computerId, matchedDiveIds);

      _log.info(
        'Relinked ${sourceIds.length} data source(s) from previous '
        '${computer.fullName} (${computer.serialNumber}) '
        'to computer $computerId',
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to relink orphaned rows to computer $computerId',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Set a computer as the favorite (clears other favorites first for the same diver)
  Future<void> setFavoriteComputer(String id, {String? diverId}) async {
    try {
      _log.info('Setting favorite computer: $id');
      final now = DateTime.now().millisecondsSinceEpoch;

      // Clear all favorites for this diver (or all if no diverId)
      if (diverId != null) {
        await (_db.update(
          _db.diveComputers,
        )..where((t) => t.diverId.equals(diverId))).write(
          DiveComputersCompanion(
            isFavorite: const Value(false),
            updatedAt: Value(now),
          ),
        );
      } else {
        await (_db.update(_db.diveComputers)).write(
          DiveComputersCompanion(
            isFavorite: const Value(false),
            updatedAt: Value(now),
          ),
        );
      }

      // Set the new favorite
      await (_db.update(
        _db.diveComputers,
      )..where((t) => t.id.equals(id))).write(
        DiveComputersCompanion(
          isFavorite: const Value(true),
          updatedAt: Value(now),
        ),
      );

      final updated = await _db.select(_db.diveComputers).get();
      for (final row in updated) {
        await _syncRepository.markRecordPending(
          entityType: 'diveComputers',
          recordId: row.id,
          localUpdatedAt: now,
        );
      }
      SyncEventBus.notifyLocalChange();

      _log.info('Set favorite computer: $id');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set favorite computer: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Increment dive count for a computer
  Future<void> incrementDiveCount(String id, {int by = 1}) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.customStatement(
        '''
        UPDATE dive_computers
        SET dive_count = dive_count + ?,
            updated_at = ?
        WHERE id = ?
      ''',
        [by, now, id],
      );
      await _syncRepository.markRecordPending(
        entityType: 'diveComputers',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to increment dive count for: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update last download timestamp
  Future<void> updateLastDownload(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.diveComputers,
      )..where((t) => t.id.equals(id))).write(
        DiveComputersCompanion(
          lastDownloadTimestamp: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'diveComputers',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update last download for: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update the last dive fingerprint after a successful import.
  ///
  /// This fingerprint is passed to libdivecomputer on the next download
  /// to enable incremental downloads (only new dives).
  Future<void> updateLastFingerprint(String id, String fingerprint) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.diveComputers,
      )..where((t) => t.id.equals(id))).write(
        DiveComputersCompanion(
          lastDiveFingerprint: Value(fingerprint),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'diveComputers',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update last fingerprint for: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // Multi-Profile Operations
  // ============================================================================

  /// Get all computer IDs that have profiles for a given dive
  Future<List<String>> getComputerIdsForDive(String diveId) async {
    try {
      // Identity columns only: they live unencoded on the row, so there is
      // nothing to inflate here. Decoding the blobs also dropped a computer
      // whose samples would not decode, which this question is not about.
      final identities = await _profileSeries.getIdentitiesForDive(diveId);
      return {
        for (final s in identities)
          if (s.computerId != null) s.computerId!,
      }.toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get computer ids for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get computers with profiles for a given dive
  Future<List<domain.DiveComputer>> getComputersForDive(String diveId) async {
    try {
      final computerIds = await getComputerIdsForDive(diveId);
      if (computerIds.isEmpty) return [];

      final query = _db.select(_db.diveComputers)
        ..where((t) => t.id.isIn(computerIds));

      final rows = await query.get();
      return rows.map((row) => _mapRowToComputer(row)).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get computers for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// The dive_data_sources row on [diveId] that describes [computerId], or
  /// null when the dive has no source row for that computer yet.
  ///
  /// Used to stamp the series row's `sourceId` at insert time (issue #1149).
  /// Primary first so a dive that somehow carries two rows for one computer
  /// resolves to the one the rest of the app treats as canonical.
  Future<String?> _dataSourceIdFor(String diveId, String computerId) async {
    final row =
        await (_db.select(_db.diveDataSources)
              ..where(
                (t) =>
                    t.diveId.equals(diveId) & t.computerId.equals(computerId),
              )
              ..orderBy([
                (t) => OrderingTerm.desc(t.isPrimary),
                (t) => OrderingTerm.asc(t.createdAt),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row?.id;
  }

  /// Get the primary profile's computer for a dive
  Future<String?> getPrimaryComputerId(String diveId) async {
    try {
      // Identity columns only; see getComputerIdsForDive.
      final identities = await _profileSeries.getIdentitiesForDive(diveId);
      for (final s in identities) {
        if (s.isPrimary && s.computerId != null) return s.computerId;
      }
      return null;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get primary computer for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Set the primary profile for a dive (by computer ID)
  Future<void> setPrimaryProfile(String diveId, String computerId) async {
    try {
      _log.info(
        'Setting primary profile for dive $diveId to computer $computerId',
      );
      final now = DateTime.now().millisecondsSinceEpoch;

      // Resolve what to promote BEFORE demoting anything, and do both in
      // one transaction. Demoting every series and then promoting nothing
      // leaves the dive with no primary at all: it keeps rendering
      // (getDiveById and getMergedProfile ignore the flag) while
      // getDiveProfile, the rate aggregates and the quality prefilters all
      // silently skip it. That is reachable whenever the chosen computer
      // owns no series (a null-computer series after a clearComputer, a
      // consolidation that moved samples, a metadata-only source), and a
      // crash between two separate commits produced it even when the
      // promote would have matched. DiveRepository.setPrimaryDataSource
      // guards the same pair the same way (issue #1149).
      await _db.transaction(() async {
        if (await _profileSeries.ownsComputer(diveId, computerId)) {
          await _profileSeries.demoteAll(diveId, now: now);
          await _profileSeries.promoteByComputer(diveId, computerId, now: now);
        }

        await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
          DivesCompanion(updatedAt: Value(now)),
        );
        await _syncRepository.markRecordPending(
          entityType: 'dives',
          recordId: diveId,
          localUpdatedAt: now,
        );
      });
      SyncEventBus.notifyLocalChange();

      _log.info('Set primary profile for dive $diveId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set primary profile for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // Profile Import and Matching
  // ============================================================================

  /// Find a dive that matches a profile's timestamp within a tolerance window.
  /// Used during import to associate profiles with existing dives.
  ///
  /// [profileStartTime] - The start time of the profile being imported
  /// [toleranceMinutes] - Time window for matching (default 5 minutes)
  /// [durationSeconds] - Expected duration to help with matching
  /// [maxDepth] - Maximum depth to help with matching
  Future<String?> findMatchingDive({
    required DateTime profileStartTime,
    int toleranceMinutes = 5,
    int? durationSeconds,
    double? maxDepth,
  }) async {
    try {
      final match = await findMatchingDiveWithScore(
        profileStartTime: profileStartTime,
        toleranceMinutes: toleranceMinutes,
        durationSeconds: durationSeconds,
        maxDepth: maxDepth,
      );
      return match?.diveId;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to find matching dive for profile',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Find a dive that matches with detailed scoring information.
  /// Returns a [DiveMatchResult] with the match details, or null if no match.
  Future<DiveMatchResult?> findMatchingDiveWithScore({
    required DateTime profileStartTime,
    int toleranceMinutes = 5,
    int? durationSeconds,
    double? maxDepth,
    String? diverId,
  }) async {
    try {
      final startMs = profileStartTime.millisecondsSinceEpoch;
      final toleranceMs = toleranceMinutes * 60 * 1000;

      // Normalize blank diverId to null so an empty string doesn't scope
      // the SQL filter to `diver_id = ''` and prevent real matches.
      final normalizedDiverId = diverId?.trim().isEmpty == true
          ? null
          : diverId;

      // Build diver filter conditionally
      final diverClause = normalizedDiverId != null ? 'AND diver_id = ?' : '';
      final diverVars = normalizedDiverId != null
          ? [Variable(normalizedDiverId)]
          : <Variable>[];

      // Search for dives within the tolerance window
      final result = await _db
          .customSelect(
            '''
        SELECT id, dive_date_time, entry_time, bottom_time, max_depth,
          COALESCE(entry_time, dive_date_time) as effective_time,
          ABS(COALESCE(entry_time, dive_date_time) - ?) as time_diff
        FROM dives
        WHERE ABS(COALESCE(entry_time, dive_date_time) - ?) <= ?
          $diverClause
        ORDER BY time_diff ASC
        LIMIT 10
      ''',
            variables: [
              Variable(startMs),
              Variable(startMs),
              Variable(toleranceMs),
              ...diverVars,
            ],
          )
          .get();

      if (result.isEmpty) return null;

      // Weighted scorer for downloads: time 40%, depth 35%, duration 25%.
      // Time is scored in milliseconds over the SQL tolerance window, depth in
      // absolute meters (0-5 m), duration in seconds (0-10 min). Missing depth
      // or duration scores 1.0 (a `full: 0` band on a 0 value). No time gate:
      // the SQL pre-filter already bounds candidates to the tolerance window.
      final scorer = MatchScorer(
        timeWeight: 0.40,
        depthWeight: 0.35,
        durationWeight: 0.25,
        timeFull: 0,
        timeZero: toleranceMs.toDouble(),
        depthFull: 0,
        depthZero: 5.0,
        durationFull: 0,
        durationZero: 600,
      );

      // Score each candidate and find the best match
      DiveMatchResult? bestMatch;
      double bestScore = 0.0;

      for (final row in result) {
        final diveId = row.data['id'] as String;
        final timeDiff = row.data['time_diff'] as int;
        final diveDuration = row.data['bottom_time'] as int?;
        final diveMaxDepth = row.data['max_depth'] as double?;

        final durationDiff = (durationSeconds != null && diveDuration != null)
            ? (diveDuration - durationSeconds).abs()
            : null;
        final depthDiff = (maxDepth != null && diveMaxDepth != null)
            ? (diveMaxDepth - maxDepth).abs()
            : null;

        final score = scorer.score(
          timeValue: timeDiff.toDouble(),
          depthValue: depthDiff ?? 0.0,
          durationValue: durationDiff?.toDouble() ?? 0.0,
        );

        if (score > bestScore) {
          bestScore = score;
          bestMatch = DiveMatchResult(
            diveId: diveId,
            score: score,
            timeDifferenceMs: timeDiff,
            durationDifferenceSeconds: durationDiff,
            depthDifferenceMeters: depthDiff,
          );
        }
      }

      // Only return a match if score meets minimum threshold
      if (bestMatch != null && bestMatch.score >= 0.5) {
        return bestMatch;
      }

      return null;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to find matching dive with score',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Get dive IDs that were imported from a specific computer.
  Future<List<String>> getDiveIdsForComputer(
    String computerId, {
    int? limit,
  }) async {
    try {
      final query =
          '''
        SELECT DISTINCT d.id, d.dive_date_time
        FROM dives d
        INNER JOIN dive_profile_series dp ON d.id = dp.dive_id
        WHERE dp.computer_id = ?
        ORDER BY d.dive_date_time DESC
        ${limit != null ? 'LIMIT $limit' : ''}
      ''';

      final result = await _db
          .customSelect(query, variables: [Variable(computerId)])
          .get();

      return result.map((row) => row.data['id'] as String).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive ids for computer: $computerId',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Remove existing profiles, derived rows, and data source for a
  /// dive+computer pair.
  ///
  /// Used by the replaceSource path so that a subsequent [importProfile] call
  /// inserts fresh data instead of short-circuiting. Also clears per-dive
  /// derived rows (events, gas switches, tank pressure series) that lack a
  /// computer_id column and would otherwise accumulate stale rows.
  Future<void> clearSourceAndProfiles({
    required String diveId,
    required String computerId,
  }) async {
    // Delete per-dive derived rows that importProfile will re-create.
    // These tables lack a computer_id column, so we clear by dive_id.
    await _db.customStatement(
      'DELETE FROM dive_profile_events WHERE dive_id = ?',
      [diveId],
    );
    await _tankSeries.deleteForDive(diveId);
    await _db.customStatement('DELETE FROM gas_switches WHERE dive_id = ?', [
      diveId,
    ]);
    // Delete profile points for this computer+dive
    await _profileSeries.deleteByComputer(diveId, computerId);
    // Whatever series survive that (deleteByComputer never matches the
    // null-computer series a manual edit writes) must give up their
    // source_id explicitly before the row they point at goes: the FK is ON
    // DELETE SET NULL, so the cascade would strip their attribution with no
    // updated_at bump, no hlc restamp and nothing pending, leaving this
    // device to resolve their owner differently from every peer forever (see
    // ProfileSeriesRepository.clearSource). One transaction with the delete,
    // so a failure between them cannot publish series that gave up an
    // attribution the source row still claims.
    await _db.transaction(() async {
      final doomed =
          await (_db.select(_db.diveDataSources)..where(
                (t) =>
                    t.diveId.equals(diveId) & t.computerId.equals(computerId),
              ))
              .get();
      for (final source in doomed) {
        await _profileSeries.clearSource(source.id);
      }
      // Delete the data source row for this computer+dive
      await _db.customStatement(
        'DELETE FROM dive_data_sources WHERE dive_id = ? AND computer_id = ?',
        [diveId, computerId],
      );
    });
  }

  /// Import a profile and associate it with a dive (creating one if needed).
  ///
  /// Returns the dive ID the profile was associated with.
  Future<String> importProfile({
    required String computerId,
    required DateTime profileStartTime,
    required List<ProfilePointData> points,
    required int durationSeconds,
    double? maxDepth,
    double? avgDepth,
    bool isPrimary = false,
    String? diverId,
    List<TankData>? tanks,
    String? decoAlgorithm,
    DiveMode diveMode = DiveMode.oc,
    int? gfLow,
    int? gfHigh,
    int? decoConservatism,
    List<EventData>? events,
    List<GasSwitchData>? gasSwitches,
    int? diveNumber,
    bool forceNew = false,
    Uint8List? rawData,
    Uint8List? rawFingerprint,
    String? descriptorVendor,
    String? descriptorProduct,
    int? descriptorModel,
    String? libdivecomputerVersion,
    double? entryLatitude,
    double? entryLongitude,
    double? exitLatitude,
    double? exitLongitude,
  }) async {
    try {
      _log.info('Importing profile from computer $computerId');
      final now = DateTime.now().millisecondsSinceEpoch;

      // Try to find an existing dive (skip matching when forceNew is true)
      final matchedDiveId = forceNew
          ? null
          : await findMatchingDive(
              profileStartTime: profileStartTime,
              durationSeconds: durationSeconds,
            );

      final diveId = matchedDiveId ?? _uuid.v4();
      final isNewDive = matchedDiveId == null;

      if (isNewDive) {
        // Create a new dive for this profile
        _log.info('No matching dive found, creating new dive');

        // Max CNS across the profile samples. Both the dive row and the
        // provenance row below are filled from it, so ReparseService (which
        // derives the same value from stored raw_data) stays in agreement.
        // Scoped to this branch because both consumers live here; a profile
        // that matches an existing dive must not pay the traversal.
        final sampleCns = points.map((p) => p.cns).whereType<double>().toList();
        final maxCns = sampleCns.isNotEmpty
            ? sampleCns.reduce((a, b) => a > b ? a : b)
            : null;

        // Calculate exit time from entry time + duration
        final entryTimeMs = profileStartTime.millisecondsSinceEpoch;
        final exitTimeMs = entryTimeMs + (durationSeconds * 1000);

        // Look up computer details to store on the dive record
        final computer = await getComputerById(computerId);

        // Use provided avgDepth, or calculate from profile points
        final effectiveAvgDepth =
            avgDepth ??
            (points.isNotEmpty
                ? points.map((p) => p.depth).reduce((a, b) => a + b) /
                      points.length
                : null);

        // durationSeconds from the dive computer is total runtime,
        // not bottom time. Calculate bottom time from the profile.
        final bottomTimeSeconds = _calculateBottomTimeFromPoints(points);

        // Downloaded profiles carry no dive type, so every dive used to land
        // on 'recreational', including dives whose samples show mandatory
        // deco (ceiling, deco stops, exhausted NDL). Default those to the
        // built-in 'technical' type instead.
        //
        // _mapEventTypeString is a display mapping and is lossy: it collapses
        // libdivecomputer's 'deepstop' onto 'decoStopStart' and
        // 'ceiling_safetystop' onto 'decoViolation'. Both of those raw events
        // are precautionary rather than proof of a mandatory deco obligation
        // (a deep stop, and breaching a *safety* stop ceiling), so they are
        // filtered out before detection, mirroring the decoType: 3 exclusion
        // already applied to samples. The mapping itself stays untouched so
        // the persisted profile events and their icons are unchanged.
        final decoEventMaps = events
            ?.where((e) => !_nonDecoEventTypes.contains(e.type))
            .map((e) => _mapEventTypeString(e.type))
            .whereType<String>()
            .map((type) => {'eventType': type})
            .toList();
        final diveTypeId =
            DecoDiveDetector.isDecoDive(
              samples: points.map(
                (p) => DecoDiveSample(
                  depth: p.depth,
                  ndl: p.ndl,
                  ceiling: p.ceiling,
                  decoType: p.decoType,
                  tts: p.tts,
                ),
              ),
              eventMaps: decoEventMaps,
            )
            ? 'technical'
            : 'recreational';

        await _db
            .into(_db.dives)
            .insert(
              DivesCompanion(
                id: Value(diveId),
                diverId: Value(diverId),
                diveNumber: Value(diveNumber),
                diveDateTime: Value(entryTimeMs),
                entryTime: Value(entryTimeMs),
                exitTime: Value(exitTimeMs),
                bottomTime: Value(bottomTimeSeconds),
                runtime: Value(durationSeconds),
                maxDepth: Value(maxDepth),
                avgDepth: Value(effectiveAvgDepth),
                cnsEnd: Value(maxCns),
                // Populated so DiveConsolidationService (Task 5) can attribute
                // consolidated children and enforce its same-computer guard;
                // without this the dives row's own computerId stayed null
                // even though every child row (profiles, tanks, data source)
                // already carried it.
                computerId: Value(computerId),
                diveComputerModel: Value(computer?.fullName),
                diveComputerSerial: Value(computer?.serialNumber),
                diveComputerFirmware: Value(computer?.firmwareVersion),
                gradientFactorLow: Value(gfLow),
                gradientFactorHigh: Value(gfHigh),
                decoAlgorithm: Value(decoAlgorithm),
                decoConservatism: Value(decoConservatism),
                diveMode: Value(diveMode.code),
                diveType: Value(diveTypeId),
                createdAt: Value(now),
                updatedAt: Value(now),
                entryLatitude: Value(entryLatitude),
                entryLongitude: Value(entryLongitude),
                exitLatitude: Value(exitLatitude),
                exitLongitude: Value(exitLongitude),
              ),
            );

        final diveTypeRowId = _uuid.v4();
        await _db
            .into(_db.diveDiveTypes)
            .insert(
              DiveDiveTypesCompanion(
                id: Value(diveTypeRowId),
                diveId: Value(diveId),
                diveTypeId: Value(diveTypeId),
                createdAt: Value(now),
              ),
            );
        await _syncRepository.markRecordPending(
          entityType: 'diveDiveTypes',
          recordId: diveTypeRowId,
          localUpdatedAt: now,
        );

        await _syncRepository.markRecordPending(
          entityType: 'dives',
          recordId: diveId,
          localUpdatedAt: now,
        );

        // Auto-apply the diver's default / geofenced equipment set to this
        // freshly downloaded dive (only when it has no equipment yet). Entry
        // and exit GPS fixes drive geofence matching.
        final defaultPoints = <GeoPoint>[
          if (entryLatitude != null && entryLongitude != null)
            GeoPoint(entryLatitude, entryLongitude),
          if (exitLatitude != null && exitLongitude != null)
            GeoPoint(exitLatitude, exitLongitude),
        ];
        await DiveEquipmentDefaulter().applyDefaultEquipmentIfEmpty(
          diveId: diveId,
          diverId: diverId,
          divePoints: defaultPoints,
        );

        // After the defaulter, never before: the defaulter bails on a dive
        // that already has equipment, so linking first would suppress the
        // diver's default and geofenced sets.
        await DiveComputerGearLinker().linkComputerGearForDive(diveId: diveId);

        // Auto-link a pre-dive checklist session started shortly before
        // this dive's entry time.
        await ChecklistDiveLinker().autoLinkForDive(
          diveId: diveId,
          diverId: diverId,
          diveStart: DateTime.fromMillisecondsSinceEpoch(entryTimeMs),
        );

        // Fill altitude from the entry/exit GPS fixes (best-effort). Awaited
        // rather than fire-and-forget so the write cannot outlive the download
        // and race a database close; the shared cache keeps the cost bounded.
        await _altitudeEnricher.applyForDownloadedDive(
          diveId: diveId,
          points: defaultPoints,
        );

        // Create a data source record for provenance tracking.
        // Derive water temp from profile samples when not provided as a
        // top-level value (e.g. Shearwater); maxCns is derived at the top of
        // this branch.
        final sampleTemps = points
            .map((p) => p.temperature)
            .whereType<double>()
            .toList();
        final minWaterTemp = sampleTemps.isNotEmpty
            ? sampleTemps.reduce((a, b) => a < b ? a : b)
            : null;

        final nowDt = DateTime.fromMillisecondsSinceEpoch(now);
        await _db
            .into(_db.diveDataSources)
            .insert(
              DiveDataSourcesCompanion.insert(
                id: _uuid.v4(),
                diveId: diveId,
                computerId: Value(computerId),
                isPrimary: const Value(true),
                computerModel: Value(computer?.fullName),
                computerSerial: Value(computer?.serialNumber),
                sourceFormat: const Value('dive_computer'),
                maxDepth: Value(maxDepth),
                avgDepth: Value(effectiveAvgDepth),
                duration: Value(durationSeconds),
                waterTemp: Value(minWaterTemp),
                entryLatitude: Value(entryLatitude),
                entryLongitude: Value(entryLongitude),
                exitLatitude: Value(exitLatitude),
                exitLongitude: Value(exitLongitude),
                entryTime: Value(profileStartTime),
                exitTime: Value(
                  profileStartTime.add(Duration(seconds: durationSeconds)),
                ),
                cns: Value(maxCns),
                decoAlgorithm: Value(decoAlgorithm),
                gradientFactorLow: Value(gfLow),
                gradientFactorHigh: Value(gfHigh),
                rawData: Value(rawData),
                rawFingerprint: Value(rawFingerprint),
                descriptorVendor: Value(descriptorVendor),
                descriptorProduct: Value(descriptorProduct),
                descriptorModel: Value(descriptorModel),
                libdivecomputerVersion: Value(libdivecomputerVersion),
                lastParsedAt: Value(rawData != null ? DateTime.now() : null),
                importedAt: nowDt,
                createdAt: nowDt,
              ),
            );

        isPrimary = true; // First profile is always primary
      }

      // The re-download guard: this computer already contributed a series.
      if (await _profileSeries.hasSeriesForComputer(diveId, computerId)) {
        _log.info('Profile from this computer already exists for dive $diveId');
        return diveId;
      }

      // If this dive has no series yet, make this one primary
      final hadSeries = await _profileSeries.hasAnySeries(diveId);
      if (!hadSeries) {
        isPrimary = true;
      }

      // Attribute the samples to the dive_data_sources row that describes
      // this computer's reading (issue #1149), so a later primary swap
      // promotes them by identity instead of re-deriving ownership from
      // computerId. Null when no source row exists yet; consumers fall back
      // to the pre-v154 computerId convention.
      final ownerSourceId = await _dataSourceIdFor(diveId, computerId);

      if (points.isNotEmpty) {
        await _profileSeries.insertSeries(
          diveId: diveId,
          computerId: computerId,
          sourceId: ownerSourceId,
          isPrimary: isPrimary,
          samples: [for (final point in points) _sampleFromPointData(point)],
        );
      }

      // Profile data changed (new source added or re-imported): drop any
      // stored safety review so it recomputes against the new profile.
      // No-op for a brand-new dive.
      await SafetyFindingsRepository.clearReviewForDive(
        _db,
        _syncRepository,
        diveId,
      );

      // Map to track tank index → tank ID for pressure data
      final tankIdsByIndex = <int, String>{};
      // Map gas mix (o2%, he%) → tank ID, so gas switches can be linked to the
      // cylinder that actually holds the gas even when the stored tank order
      // does not match the parsed cylinder index (e.g. a replace-source
      // re-download that keeps pre-existing, possibly user-edited, tanks).
      final tankIdByGas = <(double, double), String>{};

      // Insert tanks for new dives (batch insert for performance)
      if (isNewDive && tanks != null && tanks.isNotEmpty) {
        _log.info('Importing ${tanks.length} tanks for dive $diveId');
        await _db.batch((batch) {
          for (final tank in tanks) {
            final tankId = _uuid.v4();
            tankIdsByIndex[tank.index] = tankId;
            tankIdByGas[(tank.o2Percent, tank.hePercent)] = tankId;

            batch.insert(
              _db.diveTanks,
              DiveTanksCompanion(
                id: Value(tankId),
                diveId: Value(diveId),
                computerId: Value(computerId),
                volume: Value(tank.volumeLiters),
                workingPressure: Value.absentIfNull(tank.workingPressure),
                tankMaterial: Value.absentIfNull(tank.material),
                presetName: Value.absentIfNull(tank.presetName),
                startPressure: Value(tank.startPressure),
                endPressure: Value(tank.endPressure),
                o2Percent: Value(tank.o2Percent),
                hePercent: Value(tank.hePercent),
                tankOrder: Value(tank.index),
                tankRole: Value(tank.role ?? 'backGas'),
              ),
            );
            _log.info(
              'Created tank ${tank.index}: '
              'O2=${tank.o2Percent}%, start=${tank.startPressure} bar, '
              'end=${tank.endPressure} bar',
            );
          }
        });
      } else if (!isNewDive) {
        // For existing dives, fetch tank IDs
        final existingTanks =
            await (_db.select(_db.diveTanks)
                  ..where((t) => t.diveId.equals(diveId))
                  ..orderBy([(t) => OrderingTerm.asc(t.tankOrder)]))
                .get();
        for (final tank in existingTanks) {
          tankIdsByIndex[tank.tankOrder] = tank.id;
          tankIdByGas[(tank.o2Percent, tank.hePercent)] = tank.id;
        }
      }

      // Insert per-tank pressure time-series data: one series insert per
      // tank, each marked pending and stamped with an hlc by the repository.
      if (tankIdsByIndex.isNotEmpty) {
        // Group pressure readings by tank index. A sample can carry a reading
        // per air-integrated transmitter (issue #1223), so this walks
        // tankPressures rather than the single pressure/tankIndex pair.
        final pressuresByTank = groupPressuresByTank([
          for (final point in points)
            (
              timeSeconds: point.timestamp,
              pressureBar: point.pressure,
              tankIndex: point.tankIndex,
              tankPressuresBar: point.tankPressures,
            ),
        ]);

        // Insert one series per tank; each series is marked pending and
        // stamped with an hlc by the repository.
        final insertEntries = pressuresByTank.entries
            .where((entry) => tankIdsByIndex.containsKey(entry.key))
            .toList();
        // One transaction for the pressure set: a multi-transmitter download
        // whose second tank cannot be written must not leave the first
        // committed and pending, publishing half a dive's pressures to peers
        // as if they were all of them.
        await _db.transaction(() async {
          for (final entry in insertEntries) {
            if (entry.value.isEmpty) continue;
            await _tankSeries.insertSeries(
              diveId: diveId,
              tankId: tankIdsByIndex[entry.key]!,
              computerId: computerId,
              samples: [
                for (final point in entry.value)
                  TankPressureSample(
                    timestamp: point.timestamp,
                    pressure: point.pressure,
                  ),
              ],
            );
          }
        });
        for (final entry in insertEntries) {
          _log.info(
            'Imported ${entry.value.length} pressure points for tank ${entry.key}',
          );
        }

        // Backfill start/end pressure from profile data when the dive computer
        // didn't provide explicit tank pressure values but did provide
        // time-series readings (e.g. via AI transmitters).
        if (isNewDive && tanks != null) {
          for (final entry in insertEntries) {
            final tankIndex = entry.key;
            final pressurePoints = entry.value;
            if (pressurePoints.isEmpty) continue;

            final tank = tanks.firstWhere((t) => t.index == tankIndex);
            if (tank.startPressure == null || tank.endPressure == null) {
              final tankId = tankIdsByIndex[tankIndex]!;
              final sorted = [...pressurePoints]
                ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
              await (_db.update(
                _db.diveTanks,
              )..where((t) => t.id.equals(tankId))).write(
                DiveTanksCompanion(
                  startPressure: tank.startPressure == null
                      ? Value(sorted.first.pressure)
                      : const Value.absent(),
                  endPressure: tank.endPressure == null
                      ? Value(sorted.last.pressure)
                      : const Value.absent(),
                ),
              );
              _log.info(
                'Derived tank $tankIndex pressures from profile: '
                'start=${sorted.first.pressure.toStringAsFixed(1)} bar, '
                'end=${sorted.last.pressure.toStringAsFixed(1)} bar',
              );
            }
          }
        }
      }

      // Batch insert gas switches. The gas-usage timeline is driven solely by
      // the gas_switches table. A switch is linked to the cylinder holding the
      // gas it switched to: prefer matching by gas mix (robust when stored tank
      // order differs from the parsed cylinder index, e.g. replace-source
      // re-downloads), and only fall back to the cylinder index for new dives
      // whose tanks were just created from this same parse. Switches that match
      // no cylinder are dropped rather than risk a wrong-tank link.
      if (gasSwitches != null && gasSwitches.isNotEmpty) {
        final gasByIndex = {
          if (tanks != null)
            for (final t in tanks) t.index: (t.o2Percent, t.hePercent),
        };
        var inserted = 0;
        await _db.batch((batch) {
          for (final sw in gasSwitches) {
            final gas = gasByIndex[sw.toTankIndex];
            final tankId =
                (gas != null ? tankIdByGas[gas] : null) ??
                (isNewDive ? tankIdsByIndex[sw.toTankIndex] : null);
            if (tankId == null) continue;
            inserted++;
            batch.insert(
              _db.gasSwitches,
              GasSwitchesCompanion(
                id: Value(_uuid.v4()),
                diveId: Value(diveId),
                timestamp: Value(sw.timestamp),
                tankId: Value(tankId),
                depth: Value(sw.depth),
                createdAt: Value(now),
              ),
            );
          }
        });
        _log.info('Imported $inserted gas switches for dive $diveId');
      }

      // Batch insert dive events
      if (events != null && events.isNotEmpty) {
        await _db.batch((batch) {
          for (final event in events) {
            final eventType = _mapEventTypeString(event.type);
            if (eventType == null) continue;

            // Find depth at event time from profile points
            final depthAtEvent = _findDepthAtTime(points, event.timestamp);

            batch.insert(
              _db.diveProfileEvents,
              DiveProfileEventsCompanion(
                id: Value(_uuid.v4()),
                diveId: Value(diveId),
                computerId: Value(computerId),
                timestamp: Value(event.timestamp),
                eventType: Value(eventType),
                severity: Value(_eventSeverity(eventType)),
                source: const Value('imported'), // native DC events are imports
                depth: Value(depthAtEvent),
                value: Value(event.value?.toDouble()),
                createdAt: Value(now),
              ),
            );
          }
        });
        _log.info('Imported events for dive $diveId');
      }

      if (!isNewDive) {
        await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
          DivesCompanion(
            updatedAt: Value(now),
            gradientFactorLow: Value(gfLow),
            gradientFactorHigh: Value(gfHigh),
            decoAlgorithm: Value(decoAlgorithm),
            decoConservatism: Value(decoConservatism),
          ),
        );
        await _syncRepository.markRecordPending(
          entityType: 'dives',
          recordId: diveId,
          localUpdatedAt: now,
        );

        // The replaceSource path clears this dive's data source on the way in
        // and importProfile re-creates it above, so the linker can see this
        // computer again by here. The creation-seam trio does not run for an
        // existing dive, but the computer did log it. Idempotent through
        // insertOnConflictUpdate.
        await DiveComputerGearLinker().linkComputerGearForDive(diveId: diveId);
      }

      // Note: Computer stats (incrementDiveCount, updateLastDownload) are
      // updated by the higher-level import workflow in DiveImportService/
      // DownloadNotifier, which correctly counts only actually imported dives

      SyncEventBus.notifyLocalChange();
      _log.info('Imported ${points.length} profile points for dive $diveId');
      return diveId;
    } catch (e, stackTrace) {
      _log.error('Failed to import profile', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Attribute a dive to a computer, with explicit intent.
  ///
  /// `Dive.computerId` is a read-only projection: the insert/update
  /// companions deliberately omit the column so saving a dive never rewrites
  /// attribution. Setting it therefore needs a deliberate write, which is
  /// what the download, consolidation, split, and reparse paths do; file
  /// import (#1288) joins them through here.
  ///
  /// Marks the dive pending so the restored link syncs, matching
  /// [_relinkOrphanedRows].
  Future<void> attributeDiveToComputer({
    required String diveId,
    required String computerId,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.customStatement(
        'UPDATE dives SET computer_id = ?, updated_at = ? WHERE id = ?',
        [computerId, now, diveId],
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to attribute dive $diveId to computer $computerId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Register the dive computer a file import names, reusing an existing row
  /// when one already stands for the same physical device (#1288).
  ///
  /// File imports only ever wrote the `dive_computer_model`/`_serial`
  /// display snapshots onto each dive, so a logbook built entirely from
  /// files showed a computer on every dive and still reported "No dive
  /// computers registered" in the filter, which reads `dive_computers`.
  ///
  /// The match key is weaker than the download path's, because a file offers
  /// less to go on:
  ///
  /// - With a serial, match on the serial alone (scoped to the diver), the
  ///   same strong key [findOrCreateComputer] uses. A file's model spelling
  ///   must not defeat it.
  /// - Without one, match a row that also has no serial and whose model, or
  ///   whose manufacturer + model, normalizes to the same string. Matching
  ///   the full name too is what lets a file's `'Shearwater Perdix'` find a
  ///   downloaded row stored as manufacturer `'Shearwater'`, model
  ///   `'Perdix'`.
  ///
  /// A serial-bearing row is deliberately never adopted by a serial-less
  /// import: two units of one model are common, and collapsing them would
  /// misattribute dives with no way to undo it.
  ///
  /// Returns null when the file names no model, which is the signal to leave
  /// the dive unattributed rather than register a placeholder device.
  Future<domain.DiveComputer?> findOrRegisterImportedComputer({
    required String model,
    String? manufacturer,
    String? serialNumber,
    String? firmwareVersion,
    String? diverId,
  }) async {
    try {
      final normalizedModel = normalizeComputerIdentityPart(model);
      if (normalizedModel.isEmpty) return null;

      // Most recently updated first, ties broken on id: matchImportedComputer
      // takes the first candidate that matches, so an unstable order would let
      // two devices attribute the same dives to different rows. Mirrors the
      // backfill's `ORDER BY updated_at DESC, id`.
      final query = _db.select(_db.diveComputers)
        ..orderBy([
          (t) => OrderingTerm.desc(t.updatedAt),
          (t) => OrderingTerm.asc(t.id),
        ]);
      final normalizedDiverId = diverId?.trim();
      if (normalizedDiverId != null && normalizedDiverId.isNotEmpty) {
        query.where((t) => t.diverId.equals(normalizedDiverId));
      }

      // Matched in Dart, like findByHardwareIdentity: a stored serial or
      // model may itself carry whitespace from an older import, so trimming
      // only the input would miss that row. The rule itself lives in
      // [matchImportedComputer] because the beforeOpen self-heal has to apply
      // exactly the same one.
      final rows = await query.get();
      final match = matchImportedComputer(
        model: model,
        serialNumber: serialNumber,
        diverId: diverId,
        candidates: rows.map(
          (row) => ImportedComputerCandidate(
            id: row.id,
            diverId: row.diverId,
            manufacturer: row.manufacturer,
            model: row.model,
            serialNumber: row.serialNumber,
          ),
        ),
      );
      if (match != null) {
        return _mapRowToComputer(rows.firstWhere((r) => r.id == match.id));
      }

      // Deterministic, so the import and the beforeOpen self-heal agree and a
      // synced fleet converges on one row per device.
      final id = importedDiveComputerId(
        model: model,
        serialNumber: serialNumber,
        diverId: diverId,
      );

      // The identity match above reads the row's CURRENT text while the id is
      // derived from the FILE's text, so renaming a registered computer makes
      // them disagree: the match misses and the id still collides. Adopt the
      // row holding it rather than letting the insert throw and abort the
      // import.
      final byDerivedId = await (_db.select(
        _db.diveComputers,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (byDerivedId != null) return _mapRowToComputer(byDerivedId);

      final trimmedModel = model.trim();
      final trimmedManufacturer = manufacturer?.trim();
      final now = DateTime.now();
      return await createComputer(
        domain.DiveComputer(
          id: id,
          diverId: diverId,
          name: trimmedManufacturer != null && trimmedManufacturer.isNotEmpty
              ? '$trimmedManufacturer $trimmedModel'
              : trimmedModel,
          manufacturer: trimmedManufacturer?.isNotEmpty ?? false
              ? trimmedManufacturer
              : null,
          model: trimmedModel,
          serialNumber: serialNumber?.trim().isNotEmpty ?? false
              ? serialNumber!.trim()
              : null,
          firmwareVersion: firmwareVersion?.trim().isNotEmpty ?? false
              ? firmwareVersion!.trim()
              : null,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to register imported dive computer',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Find or create a dive computer by serial number and model
  Future<domain.DiveComputer> findOrCreateComputer({
    required String serialNumber,
    String? diverId,
    String? manufacturer,
    String? model,
    String? connectionType,
  }) async {
    try {
      // Try to find existing computer for this diver
      final query = _db.select(_db.diveComputers)
        ..where((t) => t.serialNumber.equals(serialNumber));

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final existing = await query.getSingleOrNull();
      if (existing != null) {
        return _mapRowToComputer(existing);
      }

      // Create new computer
      final now = DateTime.now();
      final name = model != null
          ? (manufacturer != null ? '$manufacturer $model' : model)
          : 'Dive Computer';

      final computer = domain.DiveComputer(
        id: _uuid.v4(),
        diverId: diverId,
        name: name,
        manufacturer: manufacturer,
        model: model,
        serialNumber: serialNumber,
        connectionType: connectionType,
        createdAt: now,
        updatedAt: now,
      );

      return await createComputer(computer);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to find or create computer',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // Profile Event Operations
  // ============================================================================

  /// Get all events for a dive
  Future<List<DiveProfileEvent>> getEventsForDive(String diveId) async {
    try {
      final query = _db.select(_db.diveProfileEvents)
        ..where((t) => t.diveId.equals(diveId))
        ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);

      return await query.get();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get events for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Add an event to a dive profile
  Future<void> addProfileEvent({
    required String diveId,
    required int timestamp,
    required String eventType,
    String severity = 'info',
    String? description,
    double? depth,
    double? value,
    String? tankId,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final eventId = _uuid.v4();
      await _db
          .into(_db.diveProfileEvents)
          .insert(
            DiveProfileEventsCompanion(
              id: Value(eventId),
              diveId: Value(diveId),
              timestamp: Value(timestamp),
              eventType: Value(eventType),
              severity: Value(severity),
              source: const Value('user'), // manual UI-added event
              description: Value(description),
              depth: Value(depth),
              value: Value(value),
              tankId: Value(tankId),
              createdAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'diveProfileEvents',
        recordId: eventId,
        localUpdatedAt: now,
      );
      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        DivesCompanion(updatedAt: Value(now)),
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to add profile event',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete all events for a dive
  Future<void> clearEventsForDive(String diveId) async {
    try {
      final existing = await (_db.select(
        _db.diveProfileEvents,
      )..where((t) => t.diveId.equals(diveId))).get();
      await (_db.delete(
        _db.diveProfileEvents,
      )..where((t) => t.diveId.equals(diveId))).go();
      for (final event in existing) {
        await _syncRepository.logDeletion(
          entityType: 'diveProfileEvents',
          recordId: event.id,
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
    } catch (e, stackTrace) {
      _log.error(
        'Failed to clear events for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // Mapping Helpers
  // ============================================================================

  domain.DiveComputer _mapRowToComputer(db.DiveComputer row) {
    return domain.DiveComputer(
      id: row.id,
      diverId: row.diverId,
      name: row.name,
      manufacturer: row.manufacturer,
      model: row.model,
      serialNumber: row.serialNumber,
      firmwareVersion: row.firmwareVersion,
      connectionType: row.connectionType,
      bluetoothAddress: row.bluetoothAddress,
      lastDiveFingerprint: row.lastDiveFingerprint,
      lastDownload: row.lastDownloadTimestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(row.lastDownloadTimestamp!)
          : null,
      diveCount: row.diveCount,
      isFavorite: row.isFavorite,
      notes: row.notes,
      equipmentId: row.equipmentId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  /// Maps a parsed profile point to the codec's sample type. Per-sample
  /// pressure is not carried here; it lives in the tank series.
  static codec.ProfileSample _sampleFromPointData(ProfilePointData p) =>
      codec.ProfileSample(
        timestamp: p.timestamp,
        depth: p.depth,
        temperature: p.temperature,
        heartRate: p.heartRate,
        heading: p.heading,
        setpoint: p.setpoint,
        ppO2: p.ppO2,
        cns: p.cns,
        ndl: p.ndl,
        ceiling: p.ceiling,
        ascentRate: p.ascentRate,
        rbt: p.rbt,
        decoType: p.decoType,
        tts: p.tts,
        o2Sensor1: p.o2Sensor1,
        o2Sensor2: p.o2Sensor2,
        o2Sensor3: p.o2Sensor3,
        o2Sensor4: p.o2Sensor4,
        o2Sensor5: p.o2Sensor5,
        o2Sensor6: p.o2Sensor6,
        o2SensorMv1: p.o2SensorMv1,
        o2SensorMv2: p.o2SensorMv2,
        o2SensorMv3: p.o2SensorMv3,
        o2SensorMv4: p.o2SensorMv4,
        o2SensorMv5: p.o2SensorMv5,
        o2SensorMv6: p.o2SensorMv6,
      );

  /// Calculate bottom time (seconds) from profile points.
  ///
  /// Delegates to [BottomTimeCalculator]: bottom time runs from surface
  /// departure to the start of the final ascent, so multilevel dives
  /// count their shallower segments.
  ///
  /// Returns null if profile data is insufficient for calculation.
  int? _calculateBottomTimeFromPoints(List<ProfilePointData> points) {
    return BottomTimeCalculator.secondsFromSamples([
      for (final point in points)
        (timestamp: point.timestamp, depth: point.depth),
    ]);
  }

  /// Raw libdivecomputer event types that [_mapEventTypeString] folds into a
  /// deco-flavoured label for display, but which do not by themselves prove a
  /// decompression obligation. See the deco-default block in [importProfile].
  static const Set<String> _nonDecoEventTypes = {
    'deepstop',
    'ceiling_safetystop',
  };

  /// Map libdivecomputer event type strings to ProfileEventType enum names.
  ///
  /// Only maps to values that exist in [ProfileEventType]. Returns null for
  /// unknown event types that should be skipped.
  String? _mapEventTypeString(String type) {
    switch (type) {
      case 'safetystop':
      case 'safetystop_voluntary':
      case 'safetystop_mandatory':
        return 'safetyStopStart';
      case 'deco':
      case 'deepstop':
        return 'decoStopStart';
      case 'violation':
        return 'decoViolation';
      case 'gaschange':
      case 'gaschange2':
        return 'gasSwitch';
      case 'bookmark':
        return 'bookmark';
      case 'ascent':
        return 'ascentRateWarning';
      case 'ceiling':
      case 'ceiling_safetystop':
        // Ceiling violation = ascending above deco ceiling
        return 'decoViolation';
      case 'PO2':
        return 'ppO2High';
      default:
        return null;
    }
  }

  /// Determine severity for a mapped event type.
  ///
  /// Uses the default severity from [ProfileEventType] where possible.
  String _eventSeverity(String eventType) {
    switch (eventType) {
      case 'decoViolation':
      case 'ppO2High':
        return 'alert';
      case 'ascentRateWarning':
        return 'warning';
      case 'safetyStopStart':
      case 'decoStopStart':
      case 'gasSwitch':
      case 'bookmark':
      default:
        return 'info';
    }
  }

  /// Find the depth at a given timestamp by interpolating between profile
  /// points.
  ///
  /// Returns the depth of the closest point, or null if no points exist.
  double? _findDepthAtTime(List<ProfilePointData> points, int timestamp) {
    if (points.isEmpty) return null;

    // Find the two bracketing points
    ProfilePointData? before;
    ProfilePointData? after;

    for (final point in points) {
      if (point.timestamp <= timestamp) {
        before = point;
      }
      if (point.timestamp >= timestamp && after == null) {
        after = point;
      }
    }

    // Exact match or only one side available
    if (before != null && before.timestamp == timestamp) {
      return before.depth;
    }
    if (after != null && after.timestamp == timestamp) {
      return after.depth;
    }

    // Interpolate between the two points
    if (before != null && after != null) {
      final timeDelta = after.timestamp - before.timestamp;
      if (timeDelta == 0) return before.depth;
      final fraction = (timestamp - before.timestamp) / timeDelta;
      return before.depth + (after.depth - before.depth) * fraction;
    }

    // Only one side available
    return (before ?? after)?.depth;
  }
}

/// Data class for importing profile points
class ProfilePointData {
  final int timestamp;
  final double depth;
  final double? pressure;
  final double? temperature;
  final int? heartRate;

  /// Compass heading in degrees (0-359); null when not reported.
  final double? heading;

  /// Tank index for pressure (0-based), used for multi-tank pressure tracking
  final int? tankIndex;

  /// Every tank's pressure in bar at this sample, indexed by tank index, with
  /// null where that tank reported nothing. A dive computer reports one
  /// pressure per air-integrated transmitter, so a single sample can carry
  /// several; [pressure]/[tankIndex] hold only the last of them (issue #1223).
  /// Null for sources that report at most one pressure per sample.
  final List<double?>? tankPressures;

  /// CCR setpoint in bar
  final double? setpoint;

  /// Partial pressure O2 in bar
  final double? ppO2;

  /// CNS percentage 0-100
  final double? cns;

  /// No-deco limit in seconds
  final int? ndl;

  /// Deco ceiling in meters
  final double? ceiling;

  /// Ascent rate in m/min
  final double? ascentRate;

  /// Remaining bottom time in seconds
  final int? rbt;

  /// Deco type: 0=NDL, 1=safety, 2=deco, 3=deep
  final int? decoType;

  /// NDL seconds or deco stop time remaining
  final int? decoTime;

  /// Deco stop depth in meters
  final double? decoDepth;

  /// Time to surface in seconds
  final int? tts;

  /// Individual CCR O2 cell ppO2 readings in bar (sensor 1..6)
  final double? o2Sensor1;
  final double? o2Sensor2;
  final double? o2Sensor3;
  final double? o2Sensor4;
  final double? o2Sensor5;
  final double? o2Sensor6;

  /// Raw O2 cell output in millivolts (sensor 1..6), reported even when the
  /// matching ppO2 is absent for want of a trusted calibration (issue #810)
  final int? o2SensorMv1;
  final int? o2SensorMv2;
  final int? o2SensorMv3;
  final int? o2SensorMv4;
  final int? o2SensorMv5;
  final int? o2SensorMv6;

  const ProfilePointData({
    required this.timestamp,
    required this.depth,
    this.pressure,
    this.temperature,
    this.heartRate,
    this.heading,
    this.tankIndex,
    this.tankPressures,
    this.setpoint,
    this.ppO2,
    this.cns,
    this.ndl,
    this.ceiling,
    this.ascentRate,
    this.rbt,
    this.decoType,
    this.decoTime,
    this.decoDepth,
    this.tts,
    this.o2Sensor1,
    this.o2Sensor2,
    this.o2Sensor3,
    this.o2Sensor4,
    this.o2Sensor5,
    this.o2Sensor6,
    this.o2SensorMv1,
    this.o2SensorMv2,
    this.o2SensorMv3,
    this.o2SensorMv4,
    this.o2SensorMv5,
    this.o2SensorMv6,
  });
}

/// Data class for importing dive events from dive computers
class EventData {
  /// Time offset from dive start in seconds
  final int timestamp;

  /// Event type string from libdivecomputer
  final String type;

  /// Event flags (if available)
  final int? flags;

  /// Event value (if available)
  final int? value;

  const EventData({
    required this.timestamp,
    required this.type,
    this.flags,
    this.value,
  });
}

/// Data class for importing tank information
class TankData {
  final int index;
  final double o2Percent;
  final double hePercent;
  final double? startPressure;
  final double? endPressure;
  final double? volumeLiters;

  /// Rated working pressure in bar, when known (from the default tank preset;
  /// computers do not report it).
  final double? workingPressure;

  /// Cylinder material (a `TankMaterial` name), when known.
  final String? material;

  /// The tank preset the physical attributes came from, when they did.
  final String? presetName;

  /// Inferred cylinder role (a [TankRole] name), or null for the default.
  final String? role;

  const TankData({
    required this.index,
    required this.o2Percent,
    this.hePercent = 0.0,
    this.startPressure,
    this.endPressure,
    this.volumeLiters,
    this.workingPressure,
    this.material,
    this.presetName,
    this.role,
  });
}

/// Data class for importing a gas switch (a change to the cylinder at [toTankIndex]).
class GasSwitchData {
  /// Time offset from dive start in seconds
  final int timestamp;

  /// Depth at the switch in meters
  final double depth;

  /// Index of the cylinder switched to (matches [TankData.index])
  final int toTankIndex;

  const GasSwitchData({
    required this.timestamp,
    required this.depth,
    required this.toTankIndex,
  });
}

/// Result of duplicate dive matching with scoring.
class DiveMatchResult {
  /// ID of the matching dive
  final String diveId;

  /// Match score from 0.0 to 1.0
  final double score;

  /// Time difference in milliseconds
  final int timeDifferenceMs;

  /// Duration difference in seconds (if compared)
  final int? durationDifferenceSeconds;

  /// Depth difference in meters (if compared)
  final double? depthDifferenceMeters;

  const DiveMatchResult({
    required this.diveId,
    required this.score,
    required this.timeDifferenceMs,
    this.durationDifferenceSeconds,
    this.depthDifferenceMeters,
  });

  /// Time difference as Duration
  Duration get timeDifference => Duration(milliseconds: timeDifferenceMs);

  /// Whether this is a high-confidence match (score >= 0.8)
  bool get isHighConfidence => score >= 0.8;

  /// Whether this is a likely match (score >= 0.6)
  bool get isLikelyMatch => score >= 0.6;

  /// Human-readable confidence level
  String get confidenceLevel {
    if (score >= 0.9) return 'Exact';
    if (score >= 0.8) return 'Very Likely';
    if (score >= 0.6) return 'Likely';
    if (score >= 0.5) return 'Possible';
    return 'Unlikely';
  }
}
