import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    as domain;
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_merge_repository.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/certification_primary.dart';

// Re-export merge types so callers can import from buddy_repository.dart
export 'package:submersion/features/buddies/data/repositories/buddy_merge_repository.dart'
    show
        BuddyMergeResult,
        BuddyMergeSnapshot,
        DiveBuddySnapshot,
        CertificationInstructorSnapshot;
// Re-exported so existing importers of BuddyWithDiveCount keep compiling
// after the class moved to the domain layer.
export 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';

class BuddyRepository {
  AppDatabase get _db => DatabaseService.instance.database;

  /// {buddyId: number of the given dives that include the buddy}. Junction PK
  /// is (diveId, buddyId), so COUNT(diveId) equals the distinct-dive count.
  Future<Map<String, int>> buddyCountsForDives(List<String> diveIds) async {
    if (diveIds.isEmpty) return {};
    final j = _db.diveBuddies;
    final countExpr = j.diveId.count();
    final rows =
        await (_db.selectOnly(j)
              ..addColumns([j.buddyId, countExpr])
              ..where(j.diveId.isIn(diveIds))
              ..groupBy([j.buddyId]))
            .get();
    return {for (final r in rows) r.read(j.buddyId)!: r.read(countExpr)!};
  }

  /// {buddyId: the role id every one of [diveIds] agrees on for that buddy}.
  /// Buddies whose links disagree are omitted, so a caller filling in missing
  /// links can reuse a unanimous role without flattening a deliberate mix.
  /// HAVING MIN(role) = MAX(role) keeps the mixed rows in SQLite rather than
  /// shipping every junction row to Dart on the bulk-edit load path.
  Future<Map<String, String>> unanimousBuddyRolesForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return {};
    final j = _db.diveBuddies;
    final minRole = j.role.min();
    final maxRole = j.role.max();
    final rows =
        await (_db.selectOnly(j)
              ..addColumns([j.buddyId, minRole])
              ..where(j.diveId.isIn(diveIds))
              ..groupBy([j.buddyId], having: minRole.equalsExp(maxRole)))
            .get();
    return {for (final r in rows) r.read(j.buddyId)!: r.read(minRole)!};
  }

  final SyncRepository _syncRepository = SyncRepository();
  final CertificationRepository _certRepo = CertificationRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(BuddyRepository);

  /// Emits whenever the `buddies` table changes so list providers can
  /// refresh after a sync or any other write.
  Stream<void> watchBuddiesChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.buddies));

  /// Get all buddies ordered by name
  Future<List<domain.Buddy>> getAllBuddies({String? diverId}) async {
    try {
      final query = _db.select(_db.buddies)
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return await _withPrimaryCerts(rows.map(_mapRowToBuddy).toList());
    } catch (e, stackTrace) {
      _log.error('Failed to get all buddies', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get buddy by ID
  Future<domain.Buddy?> getBuddyById(String id) async {
    try {
      final query = _db.select(_db.buddies)..where((t) => t.id.equals(id));

      final row = await query.getSingleOrNull();
      if (row == null) return null;
      return (await _withPrimaryCerts([_mapRowToBuddy(row)])).first;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get buddy by id: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Search buddies by name, email, or phone
  Future<List<domain.Buddy>> searchBuddies(
    String query, {
    String? diverId,
  }) async {
    final searchTerm = '%${query.toLowerCase()}%';
    final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
    final variables = [
      Variable.withString(searchTerm),
      Variable.withString(searchTerm),
      Variable.withString(searchTerm),
      if (diverId != null) Variable.withString(diverId),
    ];

    final results = await _db.customSelect('''
      SELECT * FROM buddies
      WHERE (LOWER(name) LIKE ?
         OR LOWER(email) LIKE ?
         OR phone LIKE ?)
      $diverFilter
      ORDER BY name ASC
    ''', variables: variables).get();

    final buddies = results.map((row) {
      return domain.Buddy(
        id: row.data['id'] as String,
        diverId: row.data['diver_id'] as String?,
        name: row.data['name'] as String,
        email: row.data['email'] as String?,
        phone: row.data['phone'] as String?,
        certificationLevel: _parseCertificationLevel(
          row.data['certification_level'] as String?,
        ),
        certificationAgency: _parseCertificationAgency(
          row.data['certification_agency'] as String?,
        ),
        photoPath: row.data['photo_path'] as String?,
        notes: (row.data['notes'] as String?) ?? '',
        isFavorite: (row.data['is_favorite'] as int? ?? 0) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.data['created_at'] as int,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row.data['updated_at'] as int,
        ),
      );
    }).toList();
    return _withPrimaryCerts(buddies);
  }

  /// Create a new buddy
  Future<domain.Buddy> createBuddy(domain.Buddy buddy) async {
    try {
      _log.info('Creating buddy: ${buddy.name}');
      final id = buddy.id.isEmpty ? _uuid.v4() : buddy.id;
      final now = DateTime.now();

      await _db
          .into(_db.buddies)
          .insert(
            BuddiesCompanion(
              id: Value(id),
              diverId: Value(buddy.diverId),
              name: Value(buddy.name),
              email: Value(buddy.email),
              phone: Value(buddy.phone),
              photoPath: Value(buddy.photoPath),
              notes: Value(buddy.notes),
              isFavorite: Value(buddy.isFavorite),
              createdAt: Value(now.millisecondsSinceEpoch),
              updatedAt: Value(now.millisecondsSinceEpoch),
            ),
          );

      await _syncRepository.markRecordPending(
        entityType: 'buddies',
        recordId: id,
        localUpdatedAt: now.millisecondsSinceEpoch,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Created buddy with id: $id');
      return buddy.copyWith(id: id, createdAt: now, updatedAt: now);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create buddy: ${buddy.name}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Find an existing buddy by exact name (case-insensitive) or create a new one
  /// Used during import to convert legacy plaintext buddy names to proper entities
  Future<domain.Buddy> findOrCreateByName(String name, {String? notes}) async {
    try {
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) {
        throw ArgumentError('Buddy name cannot be empty');
      }

      // Search for exact match (case-insensitive)
      final results = await _db
          .customSelect(
            '''
        SELECT * FROM buddies
        WHERE LOWER(name) = LOWER(?)
        LIMIT 1
      ''',
            variables: [Variable.withString(trimmedName)],
          )
          .get();

      if (results.isNotEmpty) {
        final row = results.first;
        _log.info('Found existing buddy: $trimmedName');
        final found = domain.Buddy(
          id: row.data['id'] as String,
          name: row.data['name'] as String,
          email: row.data['email'] as String?,
          phone: row.data['phone'] as String?,
          certificationLevel: _parseCertificationLevel(
            row.data['certification_level'] as String?,
          ),
          certificationAgency: _parseCertificationAgency(
            row.data['certification_agency'] as String?,
          ),
          photoPath: row.data['photo_path'] as String?,
          notes: (row.data['notes'] as String?) ?? '',
          isFavorite: (row.data['is_favorite'] as int? ?? 0) == 1,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row.data['created_at'] as int,
          ),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            row.data['updated_at'] as int,
          ),
        );
        return (await _withPrimaryCerts([found])).first;
      }

      // Create new buddy
      _log.info('Creating new buddy from import: $trimmedName');
      final newBuddy = domain.Buddy(
        id: _uuid.v4(),
        name: trimmedName,
        notes: notes ?? 'Imported from dive log',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      return await createBuddy(newBuddy);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to find or create buddy: $name',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update an existing buddy
  Future<void> updateBuddy(domain.Buddy buddy) async {
    try {
      _log.info('Updating buddy: ${buddy.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(
        _db.buddies,
      )..where((t) => t.id.equals(buddy.id))).write(
        BuddiesCompanion(
          diverId: Value(buddy.diverId),
          name: Value(buddy.name),
          email: Value(buddy.email),
          phone: Value(buddy.phone),
          photoPath: Value(buddy.photoPath),
          notes: Value(buddy.notes),
          isFavorite: Value(buddy.isFavorite),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'buddies',
        recordId: buddy.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Updated buddy: ${buddy.id}');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update buddy: ${buddy.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a buddy
  Future<void> deleteBuddy(String id) async {
    try {
      _log.info('Deleting buddy: $id');
      // Atomic (issue #553 review): tombstone the buddy's certs, delete the
      // buddy, and tombstone the buddy in one transaction. FK cascade deletes
      // the cert rows but writes no deletion_log entry, so they must be
      // tombstoned explicitly or they resurrect on the next sync.
      await _db.transaction(() async {
        // Delete + tombstone cert rows inline (no per-cert notifyLocalChange):
        // deleteCertification() emits an event per cert, which would fire
        // observers mid-transaction. We tombstone here (the FK cascade writes
        // no deletion_log) and emit a single notify after commit instead.
        for (final cert in await _certRepo.getCertificationsByBuddy(id)) {
          await (_db.delete(
            _db.certifications,
          )..where((t) => t.id.equals(cert.id))).go();
          await _syncRepository.logDeletion(
            entityType: 'certifications',
            recordId: cert.id,
          );
        }
        // Dive buddies will be automatically deleted due to CASCADE
        await (_db.delete(_db.buddies)..where((t) => t.id.equals(id))).go();
        await _syncRepository.logDeletion(entityType: 'buddies', recordId: id);
      });
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted buddy: $id');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete buddy: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get buddies for a specific dive
  Future<List<domain.BuddyWithRole>> getBuddiesForDive(String diveId) async {
    final results = await _db
        .customSelect(
          '''
      SELECT b.*, db.role
      FROM buddies b
      INNER JOIN dive_buddies db ON b.id = db.buddy_id
      WHERE db.dive_id = ?
      ORDER BY b.name ASC
    ''',
          variables: [Variable.withString(diveId)],
        )
        .get();

    // Resolve role ids against dive_roles; unknown slugs stay visible as
    // synthetic roles instead of silently coercing to Buddy.
    final roleRows = await _db.select(_db.diveRoles).get();
    final rolesById = {for (final r in roleRows) r.id: mapDiveRoleRow(r)};

    final list = results.map((row) {
      final buddy = domain.Buddy(
        id: row.data['id'] as String,
        name: row.data['name'] as String,
        email: row.data['email'] as String?,
        phone: row.data['phone'] as String?,
        certificationLevel: _parseCertificationLevel(
          row.data['certification_level'] as String?,
        ),
        certificationAgency: _parseCertificationAgency(
          row.data['certification_agency'] as String?,
        ),
        photoPath: row.data['photo_path'] as String?,
        notes: (row.data['notes'] as String?) ?? '',
        isFavorite: (row.data['is_favorite'] as int? ?? 0) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.data['created_at'] as int,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row.data['updated_at'] as int,
        ),
      );
      final roleId = (row.data['role'] as String?) ?? DiveRole.buddyId;
      final role = rolesById[roleId] ?? DiveRole.synthetic(roleId);
      return domain.BuddyWithRole(buddy: buddy, role: role);
    }).toList();
    final filled = await _withPrimaryCerts(list.map((w) => w.buddy).toList());
    final byId = {for (final b in filled) b.id: b};
    return [
      for (final w in list)
        domain.BuddyWithRole(buddy: byId[w.buddy.id]!, role: w.role),
    ];
  }

  /// Lean batch load of buddies for many dives at once, for list/table views.
  ///
  /// Returns a map keyed by dive id (dives with no buddies are simply absent).
  /// Unlike [getBuddiesForDive] this skips the primary-certification hydration
  /// ([_withPrimaryCerts]) because list/table views only render names and
  /// roles -- keeping it to two queries total (the junction join plus
  /// dive_roles) regardless of how many dives are passed. Uses the same
  /// `isIn(diveIds)` batching as the other related-data loads in
  /// [DiveRepository.getAllDives].
  Future<Map<String, List<domain.BuddyWithRole>>> getBuddiesForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return {};

    final joinRows =
        await (_db.select(_db.buddies).join([
                innerJoin(
                  _db.diveBuddies,
                  _db.diveBuddies.buddyId.equalsExp(_db.buddies.id),
                ),
              ])
              ..where(_db.diveBuddies.diveId.isIn(diveIds))
              ..orderBy([OrderingTerm.asc(_db.buddies.name)]))
            .get();

    // Resolve role ids against dive_roles once; unknown slugs stay visible as
    // synthetic roles instead of silently coercing to Buddy.
    final roleRows = await _db.select(_db.diveRoles).get();
    final rolesById = {for (final r in roleRows) r.id: mapDiveRoleRow(r)};

    final byDive = <String, List<domain.BuddyWithRole>>{};
    for (final jr in joinRows) {
      final b = jr.readTable(_db.buddies);
      final link = jr.readTable(_db.diveBuddies);
      final buddy = domain.Buddy(
        id: b.id,
        diverId: b.diverId,
        name: b.name,
        email: b.email,
        phone: b.phone,
        photoPath: b.photoPath,
        notes: b.notes,
        isFavorite: b.isFavorite,
        createdAt: DateTime.fromMillisecondsSinceEpoch(b.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(b.updatedAt),
      );
      final role = rolesById[link.role] ?? DiveRole.synthetic(link.role);
      byDive
          .putIfAbsent(link.diveId, () => [])
          .add(domain.BuddyWithRole(buddy: buddy, role: role));
    }
    return byDive;
  }

  /// Set buddies for a dive (replaces existing)
  Future<void> setBuddiesForDive(
    String diveId,
    List<domain.BuddyWithRole> buddies,
  ) async {
    // Delete existing dive buddies
    final existing = await (_db.select(
      _db.diveBuddies,
    )..where((t) => t.diveId.equals(diveId))).get();
    await (_db.delete(
      _db.diveBuddies,
    )..where((t) => t.diveId.equals(diveId))).go();
    for (final row in existing) {
      await _syncRepository.logDeletion(
        entityType: 'diveBuddies',
        recordId: row.id,
      );
    }

    // Insert new dive buddies
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final buddyWithRole in buddies) {
      final id = _uuid.v4();
      await _db
          .into(_db.diveBuddies)
          .insert(
            DiveBuddiesCompanion(
              id: Value(id),
              diveId: Value(diveId),
              buddyId: Value(buddyWithRole.buddy.id),
              role: Value(buddyWithRole.role.id),
              createdAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'diveBuddies',
        recordId: id,
        localUpdatedAt: now,
      );
    }
    await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
      DivesCompanion(updatedAt: Value(now)),
    );
    await _syncRepository.markRecordPending(
      entityType: 'dives',
      recordId: diveId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Add a buddy to a dive. [roleId] is a dive_roles id (see [DiveRole]).
  Future<void> addBuddyToDive(
    String diveId,
    String buddyId,
    String roleId,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check if already exists
    final existing =
        await (_db.select(_db.diveBuddies)..where(
              (t) => t.diveId.equals(diveId) & t.buddyId.equals(buddyId),
            ))
            .getSingleOrNull();

    if (existing != null) {
      // Update role
      await (_db.update(_db.diveBuddies)
            ..where((t) => t.diveId.equals(diveId) & t.buddyId.equals(buddyId)))
          .write(DiveBuddiesCompanion(role: Value(roleId)));
      await _syncRepository.markRecordPending(
        entityType: 'diveBuddies',
        recordId: existing.id,
        localUpdatedAt: now,
      );
    } else {
      // Insert new
      final id = _uuid.v4();
      await _db
          .into(_db.diveBuddies)
          .insert(
            DiveBuddiesCompanion(
              id: Value(id),
              diveId: Value(diveId),
              buddyId: Value(buddyId),
              role: Value(roleId),
              createdAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'diveBuddies',
        recordId: id,
        localUpdatedAt: now,
      );
    }
    await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
      DivesCompanion(updatedAt: Value(now)),
    );
    await _syncRepository.markRecordPending(
      entityType: 'dives',
      recordId: diveId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Remove a buddy from a dive
  Future<void> removeBuddyFromDive(String diveId, String buddyId) async {
    final existing = await (_db.select(
      _db.diveBuddies,
    )..where((t) => t.diveId.equals(diveId) & t.buddyId.equals(buddyId))).get();
    await (_db.delete(
      _db.diveBuddies,
    )..where((t) => t.diveId.equals(diveId) & t.buddyId.equals(buddyId))).go();
    for (final row in existing) {
      await _syncRepository.logDeletion(
        entityType: 'diveBuddies',
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
  }

  Future<void> _bumpDive(String diveId, int now) async {
    await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
      DivesCompanion(updatedAt: Value(now)),
    );
    await _syncRepository.markRecordPending(
      entityType: 'dives',
      recordId: diveId,
      localUpdatedAt: now,
    );
  }

  /// Add each buddy (with role) to every dive. Upserts role if already linked,
  /// unless [overwriteRole] is false — a membership-only add must leave the
  /// role each existing link already carries untouched (#893).
  /// No notify/transaction — BulkDiveEditService owns those.
  Future<void> bulkAddBuddies(
    List<String> diveIds,
    List<domain.BuddyWithRole> buddies, {
    bool overwriteRole = true,
  }) async {
    if (diveIds.isEmpty || buddies.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final diveId in diveIds) {
      for (final bwr in buddies) {
        final existing =
            await (_db.select(_db.diveBuddies)..where(
                  (t) =>
                      t.diveId.equals(diveId) & t.buddyId.equals(bwr.buddy.id),
                ))
                .getSingleOrNull();
        if (existing != null) {
          if (!overwriteRole) continue;
          await (_db.update(_db.diveBuddies)..where(
                (t) => t.diveId.equals(diveId) & t.buddyId.equals(bwr.buddy.id),
              ))
              .write(DiveBuddiesCompanion(role: Value(bwr.role.id)));
          await _syncRepository.markRecordPending(
            entityType: 'diveBuddies',
            recordId: existing.id,
            localUpdatedAt: now,
          );
        } else {
          final id = _uuid.v4();
          await _db
              .into(_db.diveBuddies)
              .insert(
                DiveBuddiesCompanion(
                  id: Value(id),
                  diveId: Value(diveId),
                  buddyId: Value(bwr.buddy.id),
                  role: Value(bwr.role.id),
                  createdAt: Value(now),
                ),
              );
          await _syncRepository.markRecordPending(
            entityType: 'diveBuddies',
            recordId: id,
            localUpdatedAt: now,
          );
        }
      }
      await _bumpDive(diveId, now);
    }
  }

  /// Rewrite the role on the links each dive ALREADY has for [buddies],
  /// inserting nothing. The role-only counterpart to [bulkAddBuddies]: a dive
  /// the buddy is missing from stays missing, so changing someone's role
  /// across a mixed selection cannot quietly add them to the rest (#1220).
  ///
  /// No notify/transaction; the caller wraps this like every other bulk op.
  Future<void> bulkUpdateBuddyRoles(
    List<String> diveIds,
    List<domain.BuddyWithRole> buddies,
  ) async {
    if (diveIds.isEmpty || buddies.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final touched = <String>{};
    for (final bwr in buddies) {
      final existing =
          await (_db.select(_db.diveBuddies)..where(
                (t) => t.diveId.isIn(diveIds) & t.buddyId.equals(bwr.buddy.id),
              ))
              .get();
      if (existing.isEmpty) continue;
      await (_db.update(_db.diveBuddies)..where(
            (t) => t.diveId.isIn(diveIds) & t.buddyId.equals(bwr.buddy.id),
          ))
          .write(DiveBuddiesCompanion(role: Value(bwr.role.id)));
      for (final row in existing) {
        await _syncRepository.markRecordPending(
          entityType: 'diveBuddies',
          recordId: row.id,
          localUpdatedAt: now,
        );
        touched.add(row.diveId);
      }
    }
    for (final diveId in touched) {
      await _bumpDive(diveId, now);
    }
  }

  /// Remove each buddy id from every dive. No notify/transaction.
  Future<void> bulkRemoveBuddies(
    List<String> diveIds,
    List<String> buddyIds,
  ) async {
    if (diveIds.isEmpty || buddyIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (_db.select(
      _db.diveBuddies,
    )..where((t) => t.diveId.isIn(diveIds) & t.buddyId.isIn(buddyIds))).get();
    await (_db.delete(
      _db.diveBuddies,
    )..where((t) => t.diveId.isIn(diveIds) & t.buddyId.isIn(buddyIds))).go();
    for (final row in existing) {
      await _syncRepository.logDeletion(
        entityType: 'diveBuddies',
        recordId: row.id,
      );
    }
    for (final diveId in diveIds) {
      await _bumpDive(diveId, now);
    }
  }

  /// Replace each dive's buddy set with exactly [buddies]. No notify/transaction.
  Future<void> bulkReplaceBuddies(
    List<String> diveIds,
    List<domain.BuddyWithRole> buddies,
  ) async {
    if (diveIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final diveId in diveIds) {
      final existing = await (_db.select(
        _db.diveBuddies,
      )..where((t) => t.diveId.equals(diveId))).get();
      await (_db.delete(
        _db.diveBuddies,
      )..where((t) => t.diveId.equals(diveId))).go();
      for (final row in existing) {
        await _syncRepository.logDeletion(
          entityType: 'diveBuddies',
          recordId: row.id,
        );
      }
      for (final bwr in buddies) {
        final id = _uuid.v4();
        await _db
            .into(_db.diveBuddies)
            .insert(
              DiveBuddiesCompanion(
                id: Value(id),
                diveId: Value(diveId),
                buddyId: Value(bwr.buddy.id),
                role: Value(bwr.role.id),
                createdAt: Value(now),
              ),
            );
        await _syncRepository.markRecordPending(
          entityType: 'diveBuddies',
          recordId: id,
          localUpdatedAt: now,
        );
      }
      await _bumpDive(diveId, now);
    }
  }

  /// Get all buddies with their dive counts in a single efficient query.
  ///
  /// [query] optionally filters by name/email/phone (case-insensitive), for
  /// the "Add buddy" picker's search box, which needs dive counts too so it
  /// can sort search results the same way as the unfiltered list.
  Future<List<BuddyWithDiveCount>> getAllBuddiesWithDiveCount({
    String? diverId,
    String? query,
  }) async {
    try {
      final conditions = <String>[
        if (diverId != null) 'b.diver_id = ?',
        if (query != null && query.isNotEmpty)
          '(LOWER(b.name) LIKE ? OR LOWER(b.email) LIKE ? OR b.phone LIKE ?)',
      ];
      final where = conditions.isEmpty
          ? ''
          : 'WHERE ${conditions.join(' AND ')}';
      final searchTerm = query != null && query.isNotEmpty
          ? '%${query.toLowerCase()}%'
          : null;
      final variables = [
        if (diverId != null) Variable.withString(diverId),
        if (searchTerm != null) ...[
          Variable.withString(searchTerm),
          Variable.withString(searchTerm),
          Variable.withString(searchTerm),
        ],
      ];

      final results = await _db.customSelect('''
        SELECT b.*, COALESCE(dc.dive_count, 0) AS dive_count, dc.last_dive
        FROM buddies b
        LEFT JOIN (
          SELECT db.buddy_id,
                 COUNT(*) AS dive_count,
                 MAX(d.dive_date_time) AS last_dive
          FROM dive_buddies db
          LEFT JOIN dives d ON d.id = db.dive_id
          GROUP BY db.buddy_id
        ) dc ON b.id = dc.buddy_id
        $where
        ORDER BY b.name ASC
      ''', variables: variables).get();

      // Second whole-table query: how often each buddy held each role. The
      // per-buddy winner is picked in Dart by usualRoleFor.
      final roleRows = await _db.customSelect('''
        SELECT buddy_id, role, COUNT(*) AS role_count
        FROM dive_buddies
        GROUP BY buddy_id, role
      ''').get();
      final roleCountsByBuddy = <String, Map<String, int>>{};
      for (final r in roleRows) {
        roleCountsByBuddy.putIfAbsent(
          r.data['buddy_id'] as String,
          () => {},
        )[r.data['role'] as String] = r.data['role_count'] as int;
      }

      final list = results.map((row) {
        final buddy = domain.Buddy(
          id: row.data['id'] as String,
          diverId: row.data['diver_id'] as String?,
          name: row.data['name'] as String,
          email: row.data['email'] as String?,
          phone: row.data['phone'] as String?,
          certificationLevel: _parseCertificationLevel(
            row.data['certification_level'] as String?,
          ),
          certificationAgency: _parseCertificationAgency(
            row.data['certification_agency'] as String?,
          ),
          photoPath: row.data['photo_path'] as String?,
          notes: (row.data['notes'] as String?) ?? '',
          isFavorite: (row.data['is_favorite'] as int? ?? 0) == 1,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row.data['created_at'] as int,
          ),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            row.data['updated_at'] as int,
          ),
        );
        final lastDive = row.data['last_dive'] as int?;
        return BuddyWithDiveCount(
          buddy: buddy,
          diveCount: row.data['dive_count'] as int,
          lastDiveAt: lastDive == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(lastDive),
          usualRoleId: usualRoleFor(roleCountsByBuddy[buddy.id] ?? const {}),
        );
      }).toList();
      final filled = await _withPrimaryCerts(list.map((w) => w.buddy).toList());
      final byId = {for (final b in filled) b.id: b};
      return [
        for (final w in list)
          BuddyWithDiveCount(
            buddy: byId[w.buddy.id]!,
            diveCount: w.diveCount,
            lastDiveAt: w.lastDiveAt,
            usualRoleId: w.usualRoleId,
          ),
      ];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get buddies with dive counts',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Toggle favorite status for a buddy
  Future<void> toggleFavorite(String buddyId) async {
    try {
      _log.info('Toggling favorite for buddy: $buddyId');
      final now = DateTime.now().millisecondsSinceEpoch;
      final buddy = await (_db.select(
        _db.buddies,
      )..where((t) => t.id.equals(buddyId))).getSingleOrNull();
      if (buddy == null) return;
      await (_db.update(_db.buddies)..where((t) => t.id.equals(buddyId))).write(
        BuddiesCompanion(
          isFavorite: Value(!buddy.isFavorite),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'buddies',
        recordId: buddyId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Toggled favorite for buddy: $buddyId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to toggle favorite for buddy: $buddyId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Set favorite status for a buddy
  Future<void> setFavorite(String buddyId, bool isFavorite) async {
    try {
      _log.info('Setting favorite=$isFavorite for buddy: $buddyId');
      final now = DateTime.now().millisecondsSinceEpoch;
      final updated =
          await (_db.update(
            _db.buddies,
          )..where((t) => t.id.equals(buddyId))).write(
            BuddiesCompanion(
              isFavorite: Value(isFavorite),
              updatedAt: Value(now),
            ),
          );
      // A stale or deleted buddyId updates nothing; marking it pending would
      // leave a sync record pointing at a row that does not exist.
      if (updated == 0) {
        _log.info('No buddy matched id, skipping favorite update: $buddyId');
        return;
      }
      await _syncRepository.markRecordPending(
        entityType: 'buddies',
        recordId: buddyId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Set favorite=$isFavorite for buddy: $buddyId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set favorite for buddy: $buddyId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get dive count for a buddy
  Future<int> getDiveCountForBuddy(String buddyId) async {
    final result = await _db
        .customSelect(
          '''
      SELECT COUNT(*) as count
      FROM dive_buddies
      WHERE buddy_id = ?
    ''',
          variables: [Variable.withString(buddyId)],
        )
        .getSingle();

    return result.data['count'] as int? ?? 0;
  }

  /// Get dives shared with a buddy, newest dive first.
  ///
  /// Ordered by the dive's own timestamp rather than by when the
  /// `dive_buddies` link row was written, so callers that truncate the result
  /// (the detail page previews the first five) get the newest dives and not an
  /// arbitrary slice of the import order. The sort key mirrors
  /// `DiveRepository.getAllDives` so the preview agrees with the dive list,
  /// with a final tiebreak on id so dives that tie on both keys keep a stable
  /// order instead of an arbitrary one: the caller truncates this list, so an
  /// unstable tail would change *which* dives the preview shows, not merely
  /// their order.
  /// The join also drops links whose dive row no longer exists.
  Future<List<String>> getDiveIdsForBuddy(String buddyId) async {
    final results = await _db
        .customSelect(
          '''
      SELECT db.dive_id
      FROM dive_buddies db
      INNER JOIN dives d ON d.id = db.dive_id
      WHERE db.buddy_id = ?
      ORDER BY COALESCE(d.entry_time, d.dive_date_time) DESC,
               d.dive_number DESC,
               d.id
    ''',
          variables: [Variable.withString(buddyId)],
        )
        .get();

    return results.map((row) => row.data['dive_id'] as String).toList();
  }

  /// Get buddy statistics
  Future<BuddyStats> getBuddyStats(String buddyId) async {
    // Get dive count
    final diveCount = await getDiveCountForBuddy(buddyId);

    // Get first and last dive dates
    final datesResult = await _db
        .customSelect(
          '''
      SELECT
        MIN(d.dive_date_time) as first_dive,
        MAX(d.dive_date_time) as last_dive
      FROM dives d
      INNER JOIN dive_buddies db ON d.id = db.dive_id
      WHERE db.buddy_id = ?
    ''',
          variables: [Variable.withString(buddyId)],
        )
        .getSingleOrNull();

    DateTime? firstDive;
    DateTime? lastDive;

    if (datesResult != null) {
      final firstDiveTs = datesResult.data['first_dive'] as int?;
      final lastDiveTs = datesResult.data['last_dive'] as int?;
      if (firstDiveTs != null) {
        firstDive = DateTime.fromMillisecondsSinceEpoch(firstDiveTs);
      }
      if (lastDiveTs != null) {
        lastDive = DateTime.fromMillisecondsSinceEpoch(lastDiveTs);
      }
    }

    // Get favorite site (most dived together)
    final favoriteSiteResult = await _db
        .customSelect(
          '''
      SELECT ds.name, COUNT(*) as count
      FROM dives d
      INNER JOIN dive_buddies db ON d.id = db.dive_id
      INNER JOIN dive_sites ds ON d.site_id = ds.id
      WHERE db.buddy_id = ?
      GROUP BY d.site_id
      ORDER BY count DESC
      LIMIT 1
    ''',
          variables: [Variable.withString(buddyId)],
        )
        .getSingleOrNull();

    String? favoriteSite;
    if (favoriteSiteResult != null) {
      favoriteSite = favoriteSiteResult.data['name'] as String?;
    }

    return BuddyStats(
      totalDives: diveCount,
      firstDive: firstDive,
      lastDive: lastDive,
      favoriteSite: favoriteSite,
    );
  }

  /// Merge multiple buddies into the first buddy in [buddyIds].
  ///
  /// Delegates to [BuddyMergeRepository]. The first ID is treated as the
  /// survivor. DiveBuddies entries are re-linked with role conflict resolution.
  Future<BuddyMergeResult?> mergeBuddies({
    required domain.Buddy mergedBuddy,
    required List<String> buddyIds,
  }) => BuddyMergeRepository().mergeBuddies(
    mergedBuddy: mergedBuddy,
    buddyIds: buddyIds,
  );

  /// Reverse a merge operation. Delegates to [BuddyMergeRepository].
  Future<void> undoMerge(BuddyMergeSnapshot snapshot) =>
      BuddyMergeRepository().undoMerge(snapshot);

  /// Bulk delete multiple buddies. Delegates to [BuddyMergeRepository].
  Future<void> bulkDeleteBuddies(List<String> ids) =>
      BuddyMergeRepository().bulkDeleteBuddies(ids);

  /// Fill each buddy's derived primary certification (highest by ladder) from
  /// the certifications table. Single batched query (no N+1); buddies with no
  /// certs get null level/agency. Issue #553.
  Future<List<domain.Buddy>> _withPrimaryCerts(
    List<domain.Buddy> buddies,
  ) async {
    if (buddies.isEmpty) return buddies;
    final certsByBuddy = await _certRepo.getCertificationsForBuddies(
      buddies.map((b) => b.id).toList(),
    );
    return buddies.map((b) {
      // copyWith (not a field-by-field rebuild): the incoming buddy already has
      // null cert fields (the inline columns were dropped in v110), so copyWith
      // just sets the derived primary -- and stays correct if Buddy gains new
      // fields later, which a full constructor call would silently drop.
      final primary = primaryCertification(certsByBuddy[b.id] ?? const []);
      return b.copyWith(
        certificationLevel: primary?.level,
        certificationAgency: primary?.agency,
      );
    }).toList();
  }

  domain.Buddy _mapRowToBuddy(Buddy row) {
    return domain.Buddy(
      id: row.id,
      diverId: row.diverId,
      name: row.name,
      email: row.email,
      phone: row.phone,
      // Derived at hydration from the certifications table (issue #553);
      // _withPrimaryCerts overwrites these on the read paths.
      certificationLevel: null,
      certificationAgency: null,
      photoPath: row.photoPath,
      notes: row.notes,
      isFavorite: row.isFavorite,
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
}

/// Statistics about a buddy's dive history
class BuddyStats {
  final int totalDives;
  final DateTime? firstDive;
  final DateTime? lastDive;
  final String? favoriteSite;

  const BuddyStats({
    required this.totalDives,
    this.firstDive,
    this.lastDive,
    this.favoriteSite,
  });
}
