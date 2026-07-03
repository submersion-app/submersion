import 'package:drift/drift.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    as domain;

/// Snapshot of a DiveBuddies junction row for undo.
class DiveBuddySnapshot {
  final String id;
  final String diveId;
  final String buddyId;
  final String role;
  final int createdAt;

  const DiveBuddySnapshot({
    required this.id,
    required this.diveId,
    required this.buddyId,
    required this.role,
    required this.createdAt,
  });
}

/// Snapshot of a buddy_roles row for undo.
class BuddyRoleSnapshot {
  final String id;
  final String buddyId;
  final String role;
  final String? credentialNumber;
  final String? agency;
  final String notes;
  final int createdAt;
  final int updatedAt;

  const BuddyRoleSnapshot({
    required this.id,
    required this.buddyId,
    required this.role,
    this.credentialNumber,
    this.agency,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// Snapshot of a certification's instructor link for undo.
class CertificationInstructorSnapshot {
  final String certificationId;
  final String instructorId;

  const CertificationInstructorSnapshot({
    required this.certificationId,
    required this.instructorId,
  });
}

/// Snapshot captured before a buddy merge for undo.
class BuddyMergeSnapshot {
  final domain.Buddy originalSurvivor;
  final List<domain.Buddy> deletedBuddies;
  final List<DiveBuddySnapshot> deletedDiveBuddyEntries;
  final List<DiveBuddySnapshot> modifiedDiveBuddyEntries;
  final List<BuddyRoleSnapshot> deletedBuddyRoles;
  final List<CertificationInstructorSnapshot> repointedCertifications;

  const BuddyMergeSnapshot({
    required this.originalSurvivor,
    required this.deletedBuddies,
    required this.deletedDiveBuddyEntries,
    required this.modifiedDiveBuddyEntries,
    this.deletedBuddyRoles = const [],
    this.repointedCertifications = const [],
  });
}

/// Result from a buddy merge operation.
class BuddyMergeResult {
  final String survivorId;
  final BuddyMergeSnapshot? snapshot;

  const BuddyMergeResult({required this.survivorId, this.snapshot});
}

/// Repository handling buddy merge and bulk-delete operations.
///
/// Extracted from [BuddyRepository] to keep file sizes manageable.
/// Uses the same DB/sync access pattern as [BuddyRepository].
class BuddyMergeRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _log = LoggerService.forClass(BuddyMergeRepository);

  static const _roleRank = {
    'solo': 0,
    'student': 1,
    'buddy': 2,
    'diveGuide': 3,
    'diveMaster': 4,
    'instructor': 5,
  };

  /// Look up a buddy by [id]. Returns null if not found.
  Future<domain.Buddy?> _getBuddyById(String id) async {
    final query = _db.select(_db.buddies)..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return _mapRowToBuddy(row);
  }

  domain.Buddy _mapRowToBuddy(Buddy row) {
    return domain.Buddy(
      id: row.id,
      diverId: row.diverId,
      name: row.name,
      email: row.email,
      phone: row.phone,
      certificationLevel: _parseCertificationLevel(row.certificationLevel),
      certificationAgency: _parseCertificationAgency(row.certificationAgency),
      photoPath: row.photoPath,
      notes: row.notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  CertificationLevel? _parseCertificationLevel(String? value) {
    if (value == null) return null;
    return CertificationLevel.values.firstWhere(
      (l) => l.name == value,
      orElse: () => CertificationLevel.other,
    );
  }

  CertificationAgency? _parseCertificationAgency(String? value) {
    if (value == null) return null;
    return CertificationAgency.values.firstWhere(
      (a) => a.name == value,
      orElse: () => CertificationAgency.other,
    );
  }

  /// Merge multiple buddies into the first buddy in [buddyIds].
  ///
  /// The first ID is treated as the survivor. The survivor is updated with
  /// [mergedBuddy], DiveBuddies entries are re-linked with role conflict
  /// resolution, and the remaining buddies are deleted.
  ///
  /// Returns a [BuddyMergeResult] that can be used to undo the operation,
  /// or `null` if the merge was a no-op.
  Future<BuddyMergeResult?> mergeBuddies({
    required domain.Buddy mergedBuddy,
    required List<String> buddyIds,
  }) async {
    final orderedIds = buddyIds.toSet().toList(growable: false);
    if (orderedIds.length < 2) return null;

    final survivorId = orderedIds.first;
    final duplicateIds = orderedIds.skip(1).toList(growable: false);
    final now = DateTime.now().millisecondsSinceEpoch;
    final survivorBuddy = mergedBuddy.copyWith(id: survivorId);

    try {
      _log.info(
        'Merging ${orderedIds.length} buddies into survivor: $survivorId',
      );

      // Validate all buddies exist before mutating
      final originalSurvivor = await _getBuddyById(survivorId);
      if (originalSurvivor == null) {
        throw StateError('Survivor buddy $survivorId does not exist');
      }

      final deletedBuddies = <domain.Buddy>[];
      for (final id in duplicateIds) {
        final buddy = await _getBuddyById(id);
        if (buddy == null) {
          throw StateError('Buddy not found: $id');
        }
        deletedBuddies.add(buddy);
      }

      // Validate all buddies belong to the same diver
      // Null diverIds (global buddies) are allowed to merge with scoped buddies
      final allBuddies = [originalSurvivor, ...deletedBuddies];
      final nonNullDiverIds = allBuddies
          .map((b) => b.diverId)
          .whereType<String>()
          .toSet();
      if (nonNullDiverIds.length > 1) {
        throw StateError('Cannot merge buddies from different divers');
      }

      // Capture snapshot of all DiveBuddies for ALL buddies (survivor + duplicates)
      final allDiveBuddyRows = await (_db.select(
        _db.diveBuddies,
      )..where((t) => t.buddyId.isIn(orderedIds))).get();
      final allDiveBuddySnapshots = allDiveBuddyRows
          .map(
            (row) => DiveBuddySnapshot(
              id: row.id,
              diveId: row.diveId,
              buddyId: row.buddyId,
              role: row.role,
              createdAt: row.createdAt,
            ),
          )
          .toList(growable: false);

      final deletedDiveBuddyEntries = <DiveBuddySnapshot>[];
      final modifiedDiveBuddyEntries = <DiveBuddySnapshot>[];
      // Track which survivor rows have already been snapshotted so that
      // 3+ buddy merges don't record intermediate roles.
      final modifiedRowIds = <String>{};
      final deletedBuddyRoles = <BuddyRoleSnapshot>[];
      final repointedCertifications = <CertificationInstructorSnapshot>[];

      await _db.transaction(() async {
        // Update survivor with merged fields
        await _updateBuddyRow(survivorBuddy, now);
        await _syncRepository.markRecordPending(
          entityType: 'buddies',
          recordId: survivorId,
          localUpdatedAt: now,
        );

        // Build survivor's current diveId -> row map for collision detection
        final survivorRows = await (_db.select(
          _db.diveBuddies,
        )..where((t) => t.buddyId.equals(survivorId))).get();
        final survivorDiveMap = {
          for (final row in survivorRows) row.diveId: row,
        };

        // Process each duplicate's DiveBuddies entries
        for (final duplicateId in duplicateIds) {
          final duplicateRows = await (_db.select(
            _db.diveBuddies,
          )..where((t) => t.buddyId.equals(duplicateId))).get();

          for (final dupRow in duplicateRows) {
            final existingSurvivorRow = survivorDiveMap[dupRow.diveId];

            if (existingSurvivorRow == null) {
              // No collision: relink to survivor
              await (_db.update(_db.diveBuddies)
                    ..where((t) => t.id.equals(dupRow.id)))
                  .write(DiveBuddiesCompanion(buddyId: Value(survivorId)));
              await _syncRepository.markRecordPending(
                entityType: 'diveBuddies',
                recordId: dupRow.id,
                localUpdatedAt: now,
              );
              // Update our local map so subsequent duplicates see updated state
              survivorDiveMap[dupRow.diveId] = DiveBuddy(
                id: dupRow.id,
                diveId: dupRow.diveId,
                buddyId: survivorId,
                role: dupRow.role,
                createdAt: dupRow.createdAt,
              );
            } else {
              // Collision: compare roles via hierarchy
              final dupRank = _roleRank[dupRow.role] ?? 0;
              final survivorRank = _roleRank[existingSurvivorRow.role] ?? 0;

              if (dupRank > survivorRank) {
                // Duplicate's role outranks survivor's - upgrade survivor entry.
                // Only snapshot the original role the first time this row is
                // modified, so 3+ merges don't record intermediate roles.
                if (!modifiedRowIds.contains(existingSurvivorRow.id)) {
                  modifiedRowIds.add(existingSurvivorRow.id);
                  modifiedDiveBuddyEntries.add(
                    DiveBuddySnapshot(
                      id: existingSurvivorRow.id,
                      diveId: existingSurvivorRow.diveId,
                      buddyId: existingSurvivorRow.buddyId,
                      role: existingSurvivorRow.role,
                      createdAt: existingSurvivorRow.createdAt,
                    ),
                  );
                }

                await (_db.update(_db.diveBuddies)
                      ..where((t) => t.id.equals(existingSurvivorRow.id)))
                    .write(DiveBuddiesCompanion(role: Value(dupRow.role)));
                await _syncRepository.markRecordPending(
                  entityType: 'diveBuddies',
                  recordId: existingSurvivorRow.id,
                  localUpdatedAt: now,
                );

                // Update in-memory map so subsequent duplicates see the new role
                survivorDiveMap[dupRow.diveId] = DiveBuddy(
                  id: existingSurvivorRow.id,
                  diveId: existingSurvivorRow.diveId,
                  buddyId: existingSurvivorRow.buddyId,
                  role: dupRow.role,
                  createdAt: existingSurvivorRow.createdAt,
                );
              }

              // Delete the duplicate's junction entry
              deletedDiveBuddyEntries.add(
                DiveBuddySnapshot(
                  id: dupRow.id,
                  diveId: dupRow.diveId,
                  buddyId: dupRow.buddyId,
                  role: dupRow.role,
                  createdAt: dupRow.createdAt,
                ),
              );
              await (_db.delete(
                _db.diveBuddies,
              )..where((t) => t.id.equals(dupRow.id))).go();
              await _syncRepository.logDeletion(
                entityType: 'diveBuddies',
                recordId: dupRow.id,
              );
            }
          }
        }

        // Move professional credentials (issue #395). Relink when the
        // survivor lacks the role; drop the duplicate's row when the
        // survivor already holds it. Snapshot everything for undo.
        final survivorRoleRows = await (_db.select(
          _db.buddyRoles,
        )..where((t) => t.buddyId.equals(survivorId))).get();
        final survivorRoles = survivorRoleRows.map((r) => r.role).toSet();
        for (final duplicateId in duplicateIds) {
          final dupRoleRows = await (_db.select(
            _db.buddyRoles,
          )..where((t) => t.buddyId.equals(duplicateId))).get();
          for (final row in dupRoleRows) {
            deletedBuddyRoles.add(
              BuddyRoleSnapshot(
                id: row.id,
                buddyId: row.buddyId,
                role: row.role,
                credentialNumber: row.credentialNumber,
                agency: row.agency,
                notes: row.notes,
                createdAt: row.createdAt,
                updatedAt: row.updatedAt,
              ),
            );
            if (survivorRoles.contains(row.role)) {
              await (_db.delete(
                _db.buddyRoles,
              )..where((t) => t.id.equals(row.id))).go();
              await _syncRepository.logDeletion(
                entityType: 'buddyRoles',
                recordId: row.id,
              );
            } else {
              await (_db.update(
                _db.buddyRoles,
              )..where((t) => t.id.equals(row.id))).write(
                BuddyRolesCompanion(
                  buddyId: Value(survivorId),
                  updatedAt: Value(now),
                ),
              );
              await _syncRepository.markRecordPending(
                entityType: 'buddyRoles',
                recordId: row.id,
                localUpdatedAt: now,
              );
              survivorRoles.add(row.role);
            }
          }
        }

        // Re-point certification instructor links (issue #395).
        final linkedCerts = await (_db.select(
          _db.certifications,
        )..where((t) => t.instructorId.isIn(duplicateIds))).get();
        for (final cert in linkedCerts) {
          repointedCertifications.add(
            CertificationInstructorSnapshot(
              certificationId: cert.id,
              instructorId: cert.instructorId!,
            ),
          );
          await (_db.update(
            _db.certifications,
          )..where((t) => t.id.equals(cert.id))).write(
            CertificationsCompanion(
              instructorId: Value(survivorId),
              updatedAt: Value(now),
            ),
          );
          await _syncRepository.markRecordPending(
            entityType: 'certifications',
            recordId: cert.id,
            localUpdatedAt: now,
          );
        }

        // Delete duplicate buddy rows (CASCADE cleans remaining junction rows)
        for (final duplicateId in duplicateIds) {
          await (_db.delete(
            _db.buddies,
          )..where((t) => t.id.equals(duplicateId))).go();
          await _syncRepository.logDeletion(
            entityType: 'buddies',
            recordId: duplicateId,
          );
        }
      });

      SyncEventBus.notifyLocalChange();
      _log.info(
        'Merged ${orderedIds.length} buddies into survivor: $survivorId',
      );

      // Categorize snapshot entries: entries from allDiveBuddySnapshots that
      // were not explicitly captured as deleted or modified were relinked (no
      // snapshot needed beyond the explicit lists above).
      // Include all pre-merge entries for duplicate buddies as deleted
      // (either explicitly deleted collisions or relinked entries that no
      // longer exist under their original id/buddyId).
      final explicitlyDeletedIds = deletedDiveBuddyEntries
          .map((s) => s.id)
          .toSet();
      final remainingDuplicateSnapshots = allDiveBuddySnapshots
          .where(
            (s) =>
                duplicateIds.contains(s.buddyId) &&
                !explicitlyDeletedIds.contains(s.id),
          )
          .toList(growable: false);
      final allDeleted = [
        ...deletedDiveBuddyEntries,
        ...remainingDuplicateSnapshots,
      ];

      return BuddyMergeResult(
        survivorId: survivorId,
        snapshot: BuddyMergeSnapshot(
          originalSurvivor: originalSurvivor,
          deletedBuddies: deletedBuddies,
          deletedDiveBuddyEntries: allDeleted,
          modifiedDiveBuddyEntries: modifiedDiveBuddyEntries,
          deletedBuddyRoles: deletedBuddyRoles,
          repointedCertifications: repointedCertifications,
        ),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to merge buddies: $buddyIds',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Reverse a merge operation using a previously captured [BuddyMergeSnapshot].
  Future<void> undoMerge(BuddyMergeSnapshot snapshot) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      _log.info(
        'Undoing buddy merge: restoring ${snapshot.deletedBuddies.length} buddies',
      );

      await _db.transaction(() async {
        // 1. Restore survivor to original state
        await _updateBuddyRow(snapshot.originalSurvivor, now);
        await _syncRepository.markRecordPending(
          entityType: 'buddies',
          recordId: snapshot.originalSurvivor.id,
          localUpdatedAt: now,
        );

        // 2. Re-create deleted buddies
        for (final buddy in snapshot.deletedBuddies) {
          await _db
              .into(_db.buddies)
              .insert(
                BuddiesCompanion(
                  id: Value(buddy.id),
                  diverId: Value(buddy.diverId),
                  name: Value(buddy.name),
                  email: Value(buddy.email),
                  phone: Value(buddy.phone),
                  certificationLevel: Value(buddy.certificationLevel?.name),
                  certificationAgency: Value(buddy.certificationAgency?.name),
                  photoPath: Value(buddy.photoPath),
                  notes: Value(buddy.notes),
                  createdAt: Value(buddy.createdAt.millisecondsSinceEpoch),
                  updatedAt: Value(buddy.updatedAt.millisecondsSinceEpoch),
                ),
              );
          await _syncRepository.markRecordPending(
            entityType: 'buddies',
            recordId: buddy.id,
            localUpdatedAt: now,
          );
        }

        // 3. Restore deleted/relinked DiveBuddies entries.
        // Relinked entries still exist in the DB (buddyId updated to survivor),
        // so use insertOrReplace to handle both truly-deleted and relinked rows.
        for (final entry in snapshot.deletedDiveBuddyEntries) {
          await _db
              .into(_db.diveBuddies)
              .insert(
                DiveBuddiesCompanion(
                  id: Value(entry.id),
                  diveId: Value(entry.diveId),
                  buddyId: Value(entry.buddyId),
                  role: Value(entry.role),
                  createdAt: Value(entry.createdAt),
                ),
                mode: InsertMode.insertOrReplace,
              );
          await _syncRepository.markRecordPending(
            entityType: 'diveBuddies',
            recordId: entry.id,
            localUpdatedAt: now,
          );
        }

        // 4. Restore modified DiveBuddies entries (revert role changes)
        for (final entry in snapshot.modifiedDiveBuddyEntries) {
          await (_db.update(_db.diveBuddies)
                ..where((t) => t.id.equals(entry.id)))
              .write(DiveBuddiesCompanion(role: Value(entry.role)));
          await _syncRepository.markRecordPending(
            entityType: 'diveBuddies',
            recordId: entry.id,
            localUpdatedAt: now,
          );
        }

        // 5. Restore duplicate credentials. Relinked rows still exist
        // (buddyId updated), truly-deleted rows do not - insertOrReplace
        // handles both.
        for (final entry in snapshot.deletedBuddyRoles) {
          await _db
              .into(_db.buddyRoles)
              .insert(
                BuddyRolesCompanion(
                  id: Value(entry.id),
                  buddyId: Value(entry.buddyId),
                  role: Value(entry.role),
                  credentialNumber: Value(entry.credentialNumber),
                  agency: Value(entry.agency),
                  notes: Value(entry.notes),
                  createdAt: Value(entry.createdAt),
                  updatedAt: Value(entry.updatedAt),
                ),
                mode: InsertMode.insertOrReplace,
              );
          await _syncRepository.markRecordPending(
            entityType: 'buddyRoles',
            recordId: entry.id,
            localUpdatedAt: now,
          );
        }

        // 6. Restore certification instructor links.
        for (final entry in snapshot.repointedCertifications) {
          await (_db.update(
            _db.certifications,
          )..where((t) => t.id.equals(entry.certificationId))).write(
            CertificationsCompanion(
              instructorId: Value(entry.instructorId),
              updatedAt: Value(now),
            ),
          );
          await _syncRepository.markRecordPending(
            entityType: 'certifications',
            recordId: entry.certificationId,
            localUpdatedAt: now,
          );
        }
      });

      SyncEventBus.notifyLocalChange();
      _log.info('Undo buddy merge complete');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to undo buddy merge',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Bulk delete multiple buddies.
  Future<void> bulkDeleteBuddies(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      _log.info('Bulk deleting ${ids.length} buddies');
      await (_db.delete(_db.buddies)..where((t) => t.id.isIn(ids))).go();
      for (final id in ids) {
        await _syncRepository.logDeletion(entityType: 'buddies', recordId: id);
      }
      SyncEventBus.notifyLocalChange();
      _log.info('Bulk deleted ${ids.length} buddies');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to bulk delete buddies',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _updateBuddyRow(domain.Buddy buddy, int now) async {
    await (_db.update(_db.buddies)..where((t) => t.id.equals(buddy.id))).write(
      BuddiesCompanion(
        diverId: Value(buddy.diverId),
        name: Value(buddy.name),
        email: Value(buddy.email),
        phone: Value(buddy.phone),
        certificationLevel: Value(buddy.certificationLevel?.name),
        certificationAgency: Value(buddy.certificationAgency?.name),
        photoPath: Value(buddy.photoPath),
        notes: Value(buddy.notes),
        updatedAt: Value(now),
      ),
    );
  }
}
