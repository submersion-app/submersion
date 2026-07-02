import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_role_credential.dart';

/// Repository handling professional buddy role credentials (issue #395).
///
/// Extracted from [BuddyRepository] to keep file sizes manageable.
/// Uses the same DB/sync access pattern as [BuddyRepository].
class BuddyRoleRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  /// Emits whenever the `buddy_roles` table changes.
  Stream<void> watchBuddyRolesChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.buddyRoles));

  /// Professional credentials for one buddy.
  Future<List<BuddyRoleCredential>> getRolesForBuddy(String buddyId) async {
    final rows =
        await (_db.select(_db.buddyRoles)
              ..where((t) => t.buddyId.equals(buddyId))
              ..orderBy([(t) => OrderingTerm.asc(t.role)]))
            .get();
    return rows.map(_mapRowToRoleCredential).toList();
  }

  /// All credentials keyed by buddy id, for pickers annotating many buddies.
  Future<Map<String, List<BuddyRoleCredential>>> getAllRoles() async {
    final rows = await _db.select(_db.buddyRoles).get();
    final map = <String, List<BuddyRoleCredential>>{};
    for (final row in rows) {
      map.putIfAbsent(row.buddyId, () => []).add(_mapRowToRoleCredential(row));
    }
    return map;
  }

  /// Replace the credential set for [buddyId]. Dedupes by role (last entry
  /// wins) and preserves the existing row id for roles that stay, so sync
  /// peers see an update rather than delete+insert.
  Future<void> setRolesForBuddy(
    String buddyId,
    List<BuddyRoleCredential> roles,
  ) async {
    final byRole = <BuddyRole, BuddyRoleCredential>{};
    for (final role in roles) {
      byRole[role.role] = role;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (_db.select(
      _db.buddyRoles,
    )..where((t) => t.buddyId.equals(buddyId))).get();
    final existingByRole = {for (final row in existing) row.role: row};

    // Delete roles no longer present.
    for (final row in existing) {
      if (!byRole.keys.any((r) => r.name == row.role)) {
        await (_db.delete(
          _db.buddyRoles,
        )..where((t) => t.id.equals(row.id))).go();
        await _syncRepository.logDeletion(
          entityType: 'buddyRoles',
          recordId: row.id,
        );
      }
    }

    // Upsert kept/new roles.
    for (final credential in byRole.values) {
      final existingRow = existingByRole[credential.role.name];
      if (existingRow != null) {
        await (_db.update(
          _db.buddyRoles,
        )..where((t) => t.id.equals(existingRow.id))).write(
          BuddyRolesCompanion(
            credentialNumber: Value(credential.credentialNumber),
            agency: Value(credential.agency?.name),
            notes: Value(credential.notes),
            updatedAt: Value(now),
          ),
        );
        await _syncRepository.markRecordPending(
          entityType: 'buddyRoles',
          recordId: existingRow.id,
          localUpdatedAt: now,
        );
      } else {
        final id = credential.id.isEmpty ? _uuid.v4() : credential.id;
        await _db
            .into(_db.buddyRoles)
            .insert(
              BuddyRolesCompanion(
                id: Value(id),
                buddyId: Value(buddyId),
                role: Value(credential.role.name),
                credentialNumber: Value(credential.credentialNumber),
                agency: Value(credential.agency?.name),
                notes: Value(credential.notes),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        await _syncRepository.markRecordPending(
          entityType: 'buddyRoles',
          recordId: id,
          localUpdatedAt: now,
        );
      }
    }
    SyncEventBus.notifyLocalChange();
  }

  BuddyRoleCredential _mapRowToRoleCredential(BuddyRoleRow row) {
    return BuddyRoleCredential(
      id: row.id,
      buddyId: row.buddyId,
      role: BuddyRole.values.firstWhere(
        (r) => r.name == row.role,
        orElse: () => BuddyRole.buddy,
      ),
      credentialNumber: row.credentialNumber,
      agency: _parseCertificationAgency(row.agency),
      notes: row.notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }

  CertificationAgency? _parseCertificationAgency(String? value) {
    if (value == null) return null;
    return CertificationAgency.values.firstWhere(
      (a) => a.name == value,
      orElse: () => CertificationAgency.other,
    );
  }
}
