import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;

/// Result returned by [DiverRepository.deleteDiverWithReassignment].
///
/// When shared trips/sites are reassigned to a surviving diver before
/// deletion, [hasReassignments] is true and the counts/target are populated.
class DeleteDiverResult {
  final int reassignedTripsCount;
  final int reassignedSitesCount;
  final String? reassignedToDiverId;
  final String? reassignedToDiverName;

  const DeleteDiverResult({
    required this.reassignedTripsCount,
    required this.reassignedSitesCount,
    this.reassignedToDiverId,
    this.reassignedToDiverName,
  });

  bool get hasReassignments =>
      reassignedTripsCount > 0 || reassignedSitesCount > 0;
}

class DiverRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final DiverSettingsRepository _settingsRepository = DiverSettingsRepository();
  final SyncRepository _syncRepository = SyncRepository();
  static const _uuid = Uuid();
  static final _log = LoggerService.forClass(DiverRepository);
  static const _activeDiverIdKey = 'active_diver_id';

  /// Get all divers ordered by name
  Future<List<domain.Diver>> getAllDivers() async {
    try {
      final query = _db.select(_db.divers)
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);
      final rows = await query.get();
      return rows.map(_mapRowToDiver).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get all divers', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get the default diver (or first if none marked default)
  Future<domain.Diver?> getDefaultDiver() async {
    try {
      // Try to get explicitly marked default
      var query = _db.select(_db.divers)
        ..where((t) => t.isDefault.equals(true))
        ..limit(1);
      var row = await query.getSingleOrNull();

      if (row != null) return _mapRowToDiver(row);

      // Fallback to first diver
      query = _db.select(_db.divers)
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
        ..limit(1);
      row = await query.getSingleOrNull();

      return row != null ? _mapRowToDiver(row) : null;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get default diver',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get diver by ID
  Future<domain.Diver?> getDiverById(String id) async {
    try {
      final query = _db.select(_db.divers)..where((t) => t.id.equals(id));
      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToDiver(row) : null;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get diver by id: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Create a new diver
  Future<domain.Diver> createDiver(domain.Diver diver) async {
    try {
      _log.info('Creating diver: ${diver.name}');
      final id = diver.id.isEmpty ? _uuid.v4() : diver.id;
      final now = DateTime.now();

      await _db
          .into(_db.divers)
          .insert(
            DiversCompanion(
              id: Value(id),
              name: Value(diver.name),
              email: Value(diver.email),
              phone: Value(diver.phone),
              photoPath: Value(diver.photoPath),
              emergencyContactName: Value(diver.emergencyContact.name),
              emergencyContactPhone: Value(diver.emergencyContact.phone),
              emergencyContactRelation: Value(diver.emergencyContact.relation),
              emergencyContact2Name: Value(diver.emergencyContact2.name),
              emergencyContact2Phone: Value(diver.emergencyContact2.phone),
              emergencyContact2Relation: Value(
                diver.emergencyContact2.relation,
              ),
              medicalNotes: Value(diver.medicalNotes),
              bloodType: Value(diver.bloodType),
              allergies: Value(diver.allergies),
              medications: Value(diver.medications),
              medicalClearanceExpiryDate: Value(
                diver.medicalClearanceExpiryDate?.millisecondsSinceEpoch,
              ),
              insuranceProvider: Value(diver.insurance.provider),
              insurancePolicyNumber: Value(diver.insurance.policyNumber),
              insuranceExpiryDate: Value(
                diver.insurance.expiryDate?.millisecondsSinceEpoch,
              ),
              notes: Value(diver.notes),
              isDefault: Value(diver.isDefault),
              createdAt: Value(now.millisecondsSinceEpoch),
              updatedAt: Value(now.millisecondsSinceEpoch),
            ),
          );

      // Create default settings for the new diver
      await _settingsRepository.createSettingsForDiver(id);

      await _syncRepository.markRecordPending(
        entityType: 'divers',
        recordId: id,
        localUpdatedAt: now.millisecondsSinceEpoch,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Created diver with id: $id');
      return diver.copyWith(id: id, createdAt: now, updatedAt: now);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create diver: ${diver.name}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update an existing diver
  Future<void> updateDiver(domain.Diver diver) async {
    try {
      _log.info('Updating diver: ${diver.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(_db.divers)..where((t) => t.id.equals(diver.id))).write(
        DiversCompanion(
          name: Value(diver.name),
          email: Value(diver.email),
          phone: Value(diver.phone),
          photoPath: Value(diver.photoPath),
          emergencyContactName: Value(diver.emergencyContact.name),
          emergencyContactPhone: Value(diver.emergencyContact.phone),
          emergencyContactRelation: Value(diver.emergencyContact.relation),
          emergencyContact2Name: Value(diver.emergencyContact2.name),
          emergencyContact2Phone: Value(diver.emergencyContact2.phone),
          emergencyContact2Relation: Value(diver.emergencyContact2.relation),
          medicalNotes: Value(diver.medicalNotes),
          bloodType: Value(diver.bloodType),
          allergies: Value(diver.allergies),
          medications: Value(diver.medications),
          medicalClearanceExpiryDate: Value(
            diver.medicalClearanceExpiryDate?.millisecondsSinceEpoch,
          ),
          insuranceProvider: Value(diver.insurance.provider),
          insurancePolicyNumber: Value(diver.insurance.policyNumber),
          insuranceExpiryDate: Value(
            diver.insurance.expiryDate?.millisecondsSinceEpoch,
          ),
          notes: Value(diver.notes),
          isDefault: Value(diver.isDefault),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'divers',
        recordId: diver.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Updated diver: ${diver.id}');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update diver: ${diver.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a diver.
  ///
  /// Delegates to [deleteDiverWithReassignment] so that shared trips and
  /// sites owned by the deleted diver are preserved by reassigning them
  /// to a surviving diver before the delete cascade runs. Use
  /// [deleteDiverWithReassignment] directly if you need the reassignment
  /// counts for user feedback.
  @Deprecated(
    'Use deleteDiverWithReassignment to get reassignment counts; '
    'this wrapper is kept for backwards compatibility.',
  )
  Future<void> deleteDiver(String id) async {
    await deleteDiverWithReassignment(id);
  }

  /// Delete a diver, reassigning shared trips/sites to a surviving diver first.
  ///
  /// - If surviving divers exist, shared trips and sites owned by [id] are
  ///   reassigned to the current default diver (if not the one being deleted)
  ///   or to the oldest surviving diver by [createdAt].
  /// - Private (non-shared) records are deleted as usual.
  /// - If no surviving diver exists, all records are deleted (same as
  ///   [deleteDiver]).
  ///
  /// Returns a [DeleteDiverResult] describing what was reassigned.
  Future<DeleteDiverResult> deleteDiverWithReassignment(String id) async {
    try {
      _log.info('Deleting diver with reassignment: $id');

      // Find surviving divers (all except the one being deleted), ordered so
      // that the default diver comes first, then oldest by createdAt.
      final allDiversRows =
          await (_db.select(_db.divers)
                ..where((t) => t.id.isNotValue(id))
                ..orderBy([
                  (t) => OrderingTerm.desc(t.isDefault),
                  (t) => OrderingTerm.asc(t.createdAt),
                ]))
              .get();

      String? targetId;
      String? targetName;
      int reassignedTrips = 0;
      int reassignedSites = 0;

      if (allDiversRows.isNotEmpty) {
        targetId = allDiversRows.first.id;
        targetName = allDiversRows.first.name;
      }

      await _db.transaction(() async {
        // Step 0: Reassign shared records to the surviving diver (if any).
        if (targetId != null) {
          final now = DateTime.now().millisecondsSinceEpoch;

          // Collect shared trip IDs before reassignment for sync marking.
          final sharedTripRows = await _db
              .customSelect(
                'SELECT id FROM trips WHERE diver_id = ? AND is_shared = 1',
                variables: [Variable.withString(id)],
              )
              .get();
          final sharedTripIds = sharedTripRows
              .map((r) => r.data['id'] as String)
              .toList();

          if (sharedTripIds.isNotEmpty) {
            await _db.customStatement(
              'UPDATE trips SET diver_id = ?, updated_at = ? '
              'WHERE diver_id = ? AND is_shared = 1',
              [targetId, now, id],
            );
            reassignedTrips = sharedTripIds.length;
          }

          // Collect shared site IDs before reassignment for sync marking.
          final sharedSiteRows = await _db
              .customSelect(
                'SELECT id FROM dive_sites WHERE diver_id = ? AND is_shared = 1',
                variables: [Variable.withString(id)],
              )
              .get();
          final sharedSiteIds = sharedSiteRows
              .map((r) => r.data['id'] as String)
              .toList();

          if (sharedSiteIds.isNotEmpty) {
            await _db.customStatement(
              'UPDATE dive_sites SET diver_id = ?, updated_at = ? '
              'WHERE diver_id = ? AND is_shared = 1',
              [targetId, now, id],
            );
            reassignedSites = sharedSiteIds.length;
          }

          // Mark reassigned records pending for sync.
          for (final tripId in sharedTripIds) {
            await _syncRepository.markRecordPending(
              entityType: 'trips',
              recordId: tripId,
              localUpdatedAt: now,
            );
          }
          for (final siteId in sharedSiteIds) {
            await _syncRepository.markRecordPending(
              entityType: 'diveSites',
              recordId: siteId,
              localUpdatedAt: now,
            );
          }
        }

        // Step 1: Null out cross-diver FK references to this diver's computers.
        await _db.customStatement(
          'UPDATE dives SET computer_id = NULL '
          'WHERE computer_id IN '
          '(SELECT id FROM dive_computers WHERE diver_id = ?) '
          'AND (diver_id IS NULL OR diver_id != ?)',
          [id, id],
        );
        await _db.customStatement(
          'UPDATE dive_profiles SET computer_id = NULL '
          'WHERE computer_id IN '
          '(SELECT id FROM dive_computers WHERE diver_id = ?) '
          'AND dive_id NOT IN (SELECT id FROM dives WHERE diver_id = ?)',
          [id, id],
        );
        await _db.customStatement(
          'UPDATE dive_data_sources SET computer_id = NULL '
          'WHERE computer_id IN '
          '(SELECT id FROM dive_computers WHERE diver_id = ?) '
          'AND dive_id NOT IN (SELECT id FROM dives WHERE diver_id = ?)',
          [id, id],
        );

        // Step 2: Delete dives (cascades: profiles, tanks, data_sources, etc.)
        await _db.customStatement('DELETE FROM dives WHERE diver_id = ?', [id]);

        // Step 3: Delete trip children for remaining (non-reassigned) trips.
        // Shared trips were reassigned out so their children survive with them.
        await _db.customStatement(
          'DELETE FROM liveaboard_detail_records WHERE trip_id IN '
          '(SELECT id FROM trips WHERE diver_id = ?)',
          [id],
        );
        await _db.customStatement(
          'DELETE FROM trip_itinerary_days WHERE trip_id IN '
          '(SELECT id FROM trips WHERE diver_id = ?)',
          [id],
        );

        // Step 4: Delete remaining per-diver entities (private records only,
        // since shared ones were reassigned in Step 0).
        await _db.customStatement('DELETE FROM trips WHERE diver_id = ?', [id]);
        await _db.customStatement('DELETE FROM dive_sites WHERE diver_id = ?', [
          id,
        ]);
        await _db.customStatement('DELETE FROM equipment WHERE diver_id = ?', [
          id,
        ]);
        await _db.customStatement(
          'DELETE FROM equipment_sets WHERE diver_id = ?',
          [id],
        );
        await _db.customStatement('DELETE FROM buddies WHERE diver_id = ?', [
          id,
        ]);
        await _db.customStatement(
          'DELETE FROM certifications WHERE diver_id = ?',
          [id],
        );
        await _db.customStatement(
          'DELETE FROM dive_centers WHERE diver_id = ?',
          [id],
        );
        await _db.customStatement('DELETE FROM tags WHERE diver_id = ?', [id]);
        await _db.customStatement(
          'DELETE FROM dive_types WHERE diver_id = ? AND is_built_in = 0',
          [id],
        );
        await _db.customStatement(
          'DELETE FROM tank_presets WHERE diver_id = ?',
          [id],
        );
        await _db.customStatement(
          'DELETE FROM dive_computers WHERE diver_id = ?',
          [id],
        );

        // Delete diver settings (not nullable, so delete instead of nullify).
        final settingsRows = await (_db.select(
          _db.diverSettings,
        )..where((t) => t.diverId.equals(id))).get();
        await (_db.delete(
          _db.diverSettings,
        )..where((t) => t.diverId.equals(id))).go();
        for (final row in settingsRows) {
          await _syncRepository.logDeletion(
            entityType: 'diverSettings',
            recordId: row.id,
          );
        }

        // Delete the diver record.
        await (_db.delete(_db.divers)..where((t) => t.id.equals(id))).go();
        await _syncRepository.logDeletion(entityType: 'divers', recordId: id);
      });

      SyncEventBus.notifyLocalChange();
      _log.info('Deleted diver: $id');

      return DeleteDiverResult(
        reassignedTripsCount: reassignedTrips,
        reassignedSitesCount: reassignedSites,
        reassignedToDiverId: reassignedTrips > 0 || reassignedSites > 0
            ? targetId
            : null,
        reassignedToDiverName: reassignedTrips > 0 || reassignedSites > 0
            ? targetName
            : null,
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete diver with reassignment: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Set a diver as the default (clears default from others)
  Future<void> setDefaultDiver(String id) async {
    try {
      _log.info('Setting default diver: $id');
      final now = DateTime.now().millisecondsSinceEpoch;
      // Clear all defaults
      await _db.customStatement(
        'UPDATE divers SET is_default = 0, updated_at = ?',
        [now],
      );
      // Set new default
      await (_db.update(_db.divers)..where((t) => t.id.equals(id))).write(
        DiversCompanion(isDefault: const Value(true), updatedAt: Value(now)),
      );
      final allDivers = await _db.select(_db.divers).get();
      for (final diver in allDivers) {
        await _syncRepository.markRecordPending(
          entityType: 'divers',
          recordId: diver.id,
          localUpdatedAt: now,
        );
      }
      SyncEventBus.notifyLocalChange();
      _log.info('Set default diver: $id');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set default diver: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get dive count for a diver
  Future<int> getDiveCountForDiver(String diverId) async {
    try {
      final result = await _db
          .customSelect(
            'SELECT COUNT(*) as count FROM dives WHERE diver_id = ?',
            variables: [Variable.withString(diverId)],
          )
          .getSingle();
      return result.data['count'] as int? ?? 0;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive count for diver: $diverId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get total bottom time for a diver in seconds
  Future<int> getTotalBottomTimeForDiver(String diverId) async {
    try {
      final result = await _db
          .customSelect(
            'SELECT COALESCE(SUM(bottom_time), 0) as total FROM dives WHERE diver_id = ?',
            variables: [Variable.withString(diverId)],
          )
          .getSingle();
      return result.data['total'] as int? ?? 0;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get total bottom time for diver: $diverId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Read the active diver ID from the Settings key-value table.
  /// Returns null if not set (e.g., older database without this key).
  Future<String?> getActiveDiverIdFromSettings() async {
    try {
      final query = _db.select(_db.settings)
        ..where((t) => t.key.equals(_activeDiverIdKey));
      final row = await query.getSingleOrNull();
      return row?.value;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to read active_diver_id from settings',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Write the active diver ID to the Settings key-value table.
  /// Pass null to clear it.
  Future<void> setActiveDiverIdInSettings(String? diverId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (diverId == null) {
        await (_db.delete(
          _db.settings,
        )..where((t) => t.key.equals(_activeDiverIdKey))).go();
      } else {
        await _db
            .into(_db.settings)
            .insertOnConflictUpdate(
              SettingsCompanion(
                key: const Value(_activeDiverIdKey),
                value: Value(diverId),
                updatedAt: Value(now),
              ),
            );
      }
    } catch (e, stackTrace) {
      _log.error(
        'Failed to write active_diver_id to settings',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  domain.Diver _mapRowToDiver(Diver row) {
    return domain.Diver(
      id: row.id,
      name: row.name,
      email: row.email,
      phone: row.phone,
      photoPath: row.photoPath,
      emergencyContact: domain.EmergencyContact(
        name: row.emergencyContactName,
        phone: row.emergencyContactPhone,
        relation: row.emergencyContactRelation,
      ),
      emergencyContact2: domain.EmergencyContact(
        name: row.emergencyContact2Name,
        phone: row.emergencyContact2Phone,
        relation: row.emergencyContact2Relation,
      ),
      medicalNotes: row.medicalNotes,
      bloodType: row.bloodType,
      allergies: row.allergies,
      medications: row.medications,
      medicalClearanceExpiryDate: row.medicalClearanceExpiryDate != null
          ? DateTime.fromMillisecondsSinceEpoch(row.medicalClearanceExpiryDate!)
          : null,
      insurance: domain.DiverInsurance(
        provider: row.insuranceProvider,
        policyNumber: row.insurancePolicyNumber,
        expiryDate: row.insuranceExpiryDate != null
            ? DateTime.fromMillisecondsSinceEpoch(row.insuranceExpiryDate!)
            : null,
      ),
      notes: row.notes,
      isDefault: row.isDefault,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
