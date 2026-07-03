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
  ///
  /// Rows whose `role` string doesn't match a known [kProfessionalBuddyRoles]
  /// value are skipped rather than coerced (issue #395 follow-up): a future
  /// app version may add a role value this build doesn't understand yet, and
  /// coercing it would let [setRolesForBuddy] delete it on the next save.
  Future<List<BuddyRoleCredential>> getRolesForBuddy(String buddyId) async {
    final rows =
        await (_db.select(_db.buddyRoles)
              ..where((t) => t.buddyId.equals(buddyId))
              ..orderBy([(t) => OrderingTerm.asc(t.role)]))
            .get();
    return rows
        .where((row) => _isProfessionalRole(row.role))
        .map(_mapRowToRoleCredential)
        .toList();
  }

  /// All credentials keyed by buddy id, for pickers annotating many buddies.
  ///
  /// See [getRolesForBuddy] for why unrecognized role rows are skipped.
  Future<Map<String, List<BuddyRoleCredential>>> getAllRoles() async {
    final rows = await _db.select(_db.buddyRoles).get();
    final map = <String, List<BuddyRoleCredential>>{};
    for (final row in rows) {
      if (!_isProfessionalRole(row.role)) continue;
      map.putIfAbsent(row.buddyId, () => []).add(_mapRowToRoleCredential(row));
    }
    return map;
  }

  /// Replace the credential set for [buddyId]. Dedupes by role (last entry
  /// wins) and preserves the existing row id for roles that stay, so sync
  /// peers see an update rather than delete+insert.
  ///
  /// Only manages rows whose role is a known professional role
  /// ([kProfessionalBuddyRoles]); rows with any other role value (e.g. a
  /// future app version's role this build doesn't recognize yet) are left
  /// completely untouched -- no delete, no update, no tombstone.
  ///
  /// No-op updates (identical credentialNumber/agency/notes) are skipped
  /// entirely so an unrelated buddy save doesn't stamp a fresh HLC and win
  /// last-write-wins over a real concurrent credential edit on another
  /// device. The whole sequence runs in one transaction.
  Future<void> setRolesForBuddy(
    String buddyId,
    List<BuddyRoleCredential> roles,
  ) async {
    // Reject non-professional input loudly: writing e.g. BuddyRole.buddy
    // would create a row this repository's reads hide and its delete loop
    // never manages -- invisible and undeletable through this API.
    final unsupported = roles
        .where((r) => !kProfessionalBuddyRoles.contains(r.role))
        .toList();
    if (unsupported.isNotEmpty) {
      throw ArgumentError(
        'setRolesForBuddy only manages professional roles '
        '(${kProfessionalBuddyRoles.map((r) => r.name).join(', ')}); got: '
        '${unsupported.map((r) => r.role.name).join(', ')}',
      );
    }
    final byRole = <BuddyRole, BuddyRoleCredential>{};
    for (final role in roles) {
      byRole[role.role] = role;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    var wroteAny = false;

    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.buddyRoles,
      )..where((t) => t.buddyId.equals(buddyId))).get();

      // Converge duplicate (buddyId, role) rows to one winner before doing
      // anything else. The surrogate-id PK lets sync land two rows for the
      // same professional role (each device inserts its own UUID); keep the
      // authoritative one (highest hlc, else highest updatedAt) and tombstone
      // the extras so the table returns to its one-row-per-role invariant and
      // the deletions propagate to peers. Non-professional rows are left as-is.
      final byRoleName = <String, List<BuddyRoleRow>>{};
      for (final row in existing) {
        if (!_isProfessionalRole(row.role)) continue;
        byRoleName.putIfAbsent(row.role, () => []).add(row);
      }
      final survivors = <BuddyRoleRow>[];
      for (final rows in byRoleName.values) {
        if (rows.length == 1) {
          survivors.add(rows.first);
          continue;
        }
        rows.sort(_roleRowPrecedence); // best last
        final winner = rows.last;
        survivors.add(winner);
        for (final loser in rows) {
          if (loser.id == winner.id) continue;
          await (_db.delete(
            _db.buddyRoles,
          )..where((t) => t.id.equals(loser.id))).go();
          await _syncRepository.logDeletion(
            entityType: 'buddyRoles',
            recordId: loser.id,
          );
          wroteAny = true;
        }
      }
      final existingByRole = {for (final row in survivors) row.role: row};

      // Delete professional roles no longer present. Non-professional rows
      // (unrecognized role strings) are never touched here.
      for (final row in survivors) {
        if (!byRole.keys.any((r) => r.name == row.role)) {
          await (_db.delete(
            _db.buddyRoles,
          )..where((t) => t.id.equals(row.id))).go();
          await _syncRepository.logDeletion(
            entityType: 'buddyRoles',
            recordId: row.id,
          );
          wroteAny = true;
        }
      }

      // Upsert kept/new roles.
      for (final credential in byRole.values) {
        final existingRow = existingByRole[credential.role.name];
        if (existingRow != null) {
          final unchanged =
              existingRow.credentialNumber == credential.credentialNumber &&
              existingRow.agency == credential.agency?.name &&
              existingRow.notes == credential.notes;
          if (unchanged) continue;

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
          wroteAny = true;
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
          wroteAny = true;
        }
      }
    });

    if (wroteAny) {
      SyncEventBus.notifyLocalChange();
    }
  }

  bool _isProfessionalRole(String roleName) =>
      kProfessionalBuddyRoles.any((r) => r.name == roleName);

  /// Orders two duplicate role rows worst-to-best (best sorts last). HLC is
  /// authoritative when present (canonical zero-padded form compares
  /// lexicographically); a row with an HLC outranks one without; ties fall
  /// back to updatedAt, then id for a stable, deterministic winner.
  static int _roleRowPrecedence(BuddyRoleRow a, BuddyRoleRow b) {
    final aHlc = a.hlc, bHlc = b.hlc;
    if (aHlc != null && bHlc != null && aHlc != bHlc) {
      return aHlc.compareTo(bHlc);
    }
    if ((aHlc == null) != (bHlc == null)) {
      return aHlc == null ? -1 : 1; // the row with an HLC wins
    }
    if (a.updatedAt != b.updatedAt) return a.updatedAt.compareTo(b.updatedAt);
    return a.id.compareTo(b.id);
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
