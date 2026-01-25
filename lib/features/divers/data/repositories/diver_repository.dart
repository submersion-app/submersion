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

class DiverRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final DiverSettingsRepository _settingsRepository = DiverSettingsRepository();
  final SyncRepository _syncRepository = SyncRepository();
  static const _uuid = Uuid();
  static final _log = LoggerService.forClass(DiverRepository);

  /// Get all divers ordered by name
  Future<List<domain.Diver>> getAllDivers() async {
    try {
      final query = _db.select(_db.divers)
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);
      final rows = await query.get();
      return rows.map(_mapRowToDiver).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get all divers', e, stackTrace);
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
      _log.error('Failed to get default diver', e, stackTrace);
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
      _log.error('Failed to get diver by id: $id', e, stackTrace);
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
      _log.error('Failed to create diver: ${diver.name}', e, stackTrace);
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
      _log.error('Failed to update diver: ${diver.id}', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a diver
  Future<void> deleteDiver(String id) async {
    try {
      _log.info('Deleting diver: $id');

      // First, set diverId to null in all related tables to avoid FK constraint
      await _db.customStatement(
        'UPDATE dives SET diver_id = NULL WHERE diver_id = ?',
        [id],
      );
      await _db.customStatement(
        'UPDATE trips SET diver_id = NULL WHERE diver_id = ?',
        [id],
      );
      await _db.customStatement(
        'UPDATE dive_sites SET diver_id = NULL WHERE diver_id = ?',
        [id],
      );
      await _db.customStatement(
        'UPDATE equipment SET diver_id = NULL WHERE diver_id = ?',
        [id],
      );
      await _db.customStatement(
        'UPDATE equipment_sets SET diver_id = NULL WHERE diver_id = ?',
        [id],
      );
      await _db.customStatement(
        'UPDATE buddies SET diver_id = NULL WHERE diver_id = ?',
        [id],
      );
      await _db.customStatement(
        'UPDATE certifications SET diver_id = NULL WHERE diver_id = ?',
        [id],
      );
      await _db.customStatement(
        'UPDATE dive_centers SET diver_id = NULL WHERE diver_id = ?',
        [id],
      );
      await _db.customStatement(
        'UPDATE tags SET diver_id = NULL WHERE diver_id = ?',
        [id],
      );
      await _db.customStatement(
        'UPDATE dive_types SET diver_id = NULL WHERE diver_id = ?',
        [id],
      );
      await _db.customStatement(
        'UPDATE dive_computers SET diver_id = NULL WHERE diver_id = ?',
        [id],
      );

      // Delete diver settings (not nullable, so delete instead of nullify)
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

      // Now delete the diver
      await (_db.delete(_db.divers)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: 'divers', recordId: id);
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted diver: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to delete diver: $id', e, stackTrace);
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
      _log.error('Failed to set default diver: $id', e, stackTrace);
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
      _log.error('Failed to get dive count for diver: $diverId', e, stackTrace);
      rethrow;
    }
  }

  /// Get total bottom time for a diver in seconds
  Future<int> getTotalBottomTimeForDiver(String diverId) async {
    try {
      final result = await _db
          .customSelect(
            'SELECT COALESCE(SUM(duration), 0) as total FROM dives WHERE diver_id = ?',
            variables: [Variable.withString(diverId)],
          )
          .getSingle();
      return result.data['total'] as int? ?? 0;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get total bottom time for diver: $diverId',
        e,
        stackTrace,
      );
      rethrow;
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
