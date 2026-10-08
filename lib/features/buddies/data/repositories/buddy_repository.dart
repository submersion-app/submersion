import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    as domain;
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_conversion_repository.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_merge_repository.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_link_repository.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/domain/services/dive_role_set.dart';
import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/certification_primary.dart';
import 'package:submersion/features/certifications/domain/certification_title.dart';

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

  /// {buddyId: number of the given dives that include the buddy}. There is
  /// one dive_buddies row per (dive, buddy), so COUNT(diveId) equals the
  /// distinct-dive count.
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

  /// {buddyId: the role set every one of [diveIds] that links the buddy
  /// agrees on}. Buddies whose sets disagree are omitted, so a caller
  /// filling in missing links can reuse a unanimous set without flattening a
  /// deliberate mix (issue #1221).
  Future<Map<String, List<String>>> unanimousBuddyRolesForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return {};
    final sets = await _roleLinks.buddyRoleIdsForDives(diveIds);
    final seen = <String, List<String>>{};
    final mixed = <String>{};
    for (final perDive in sets.values) {
      for (final entry in perDive.entries) {
        final held = seen[entry.key];
        if (held == null) {
          seen[entry.key] = entry.value;
        } else if (!const ListEquality<String>().equals(held, entry.value)) {
          mixed.add(entry.key);
        }
      }
    }
    return {
      for (final e in seen.entries)
        if (!mixed.contains(e.key)) e.key: e.value,
    };
  }

  final SyncRepository _syncRepository = SyncRepository();
  final DiveRoleLinkRepository _roleLinks = DiveRoleLinkRepository();
  final CertificationRepository _certRepo = CertificationRepository();
  final CustomCertificationRepository _customCertRepo =
      CustomCertificationRepository();
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
        ..orderBy([(t) => OrderingTerm.asc(t.name.collate(Collate.noCase))]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return await _withPrimaryCerts(
        sortedByText(rows, (r) => r.name).map(_mapRowToBuddy).toList(),
      );
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
      ORDER BY name COLLATE NOCASE ASC
    ''', variables: variables).get();

    final buddies = sortedByText(results, (r) => r.data['name'] as String).map((
      row,
    ) {
      return domain.Buddy(
        id: row.data['id'] as String,
        diverId: row.data['diver_id'] as String?,
        linkedDiverId: row.data['linked_diver_id'] as String?,
        name: row.data['name'] as String,
        email: row.data['email'] as String?,
        phone: row.data['phone'] as String?,
        photoPath: row.data['photo_path'] as String?,
        photo: row.data['photo'] as Uint8List?,
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
              linkedDiverId: Value(buddy.linkedDiverId),
              name: Value(buddy.name),
              email: Value(buddy.email),
              phone: Value(buddy.phone),
              photoPath: Value(buddy.photoPath),
              photo: Value(buddy.photo),
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
  ///
  /// With [diverId], only that diver's people and unowned ones match, the
  /// diver's own first, and a new person is created for that diver. People
  /// are diver-scoped, so an import into one profile must not link another
  /// profile's namesake (#1806).
  Future<domain.Buddy> findOrCreateByName(
    String name, {
    String? notes,
    String? diverId,
  }) async {
    try {
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) {
        throw ArgumentError('Buddy name cannot be empty');
      }

      // Search for exact match (case-insensitive)
      final scope = diverId == null
          ? ''
          : 'AND (diver_id = ? OR diver_id IS NULL) ORDER BY diver_id IS NULL';
      final results = await _db
          .customSelect(
            '''
        SELECT * FROM buddies
        WHERE LOWER(name) = LOWER(?) $scope
        LIMIT 1
      ''',
            variables: [
              Variable.withString(trimmedName),
              if (diverId != null) Variable.withString(diverId),
            ],
          )
          .get();

      if (results.isNotEmpty) {
        final row = results.first;
        _log.info('Found existing buddy: $trimmedName');
        final found = domain.Buddy(
          id: row.data['id'] as String,
          linkedDiverId: row.data['linked_diver_id'] as String?,
          diverId: row.data['diver_id'] as String?,
          name: row.data['name'] as String,
          email: row.data['email'] as String?,
          phone: row.data['phone'] as String?,
          photoPath: row.data['photo_path'] as String?,
          photo: row.data['photo'] as Uint8List?,
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
        diverId: diverId,
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
          linkedDiverId: Value(buddy.linkedDiverId),
          name: Value(buddy.name),
          email: Value(buddy.email),
          phone: Value(buddy.phone),
          photoPath: Value(buddy.photoPath),
          photo: Value(buddy.photo),
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
  // stats-scope-exempt: reads the dive's diver only to scope role lookup
  Future<List<domain.BuddyWithRole>> getBuddiesForDive(String diveId) async {
    final results = await _db
        .customSelect(
          '''
      SELECT b.*, db.role, d.diver_id AS dive_diver_id
      FROM buddies b
      INNER JOIN dive_buddies db ON b.id = db.buddy_id
      LEFT JOIN dives d ON d.id = db.dive_id
      WHERE db.dive_id = ?
      ORDER BY b.name COLLATE NOCASE ASC
    ''',
          variables: [Variable.withString(diveId)],
        )
        .get();

    // Resolve role ids against dive_roles, scoped to the dive's diver (see
    // resolveDiveRole).
    final roleRows = await _db.select(_db.diveRoles).get();
    final rolesById = {for (final r in roleRows) r.id: mapDiveRoleRow(r)};
    final roleSets =
        (await _roleLinks.buddyRoleIdsForDives([diveId]))[diveId] ?? const {};

    final list = sortedByText(results, (r) => r.data['name'] as String).map((
      row,
    ) {
      final buddy = domain.Buddy(
        id: row.data['id'] as String,
        diverId: row.data['diver_id'] as String?,
        linkedDiverId: row.data['linked_diver_id'] as String?,
        name: row.data['name'] as String,
        email: row.data['email'] as String?,
        phone: row.data['phone'] as String?,
        photoPath: row.data['photo_path'] as String?,
        photo: row.data['photo'] as Uint8List?,
        notes: (row.data['notes'] as String?) ?? '',
        isFavorite: (row.data['is_favorite'] as int? ?? 0) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.data['created_at'] as int,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row.data['updated_at'] as int,
        ),
      );
      final roleIds =
          roleSets[buddy.id] ??
          DiveRoleSet.resolveBuddy(
            scalar: row.data['role'] as String?,
            junction: const [],
          );
      return domain.BuddyWithRole(
        buddy: buddy,
        roles: [
          for (final id in roleIds)
            resolveDiveRole(
              rolesById,
              id,
              diveDiverId: row.data['dive_diver_id'] as String?,
            ),
        ],
      );
    }).toList();
    final filled = await _withPrimaryCerts(list.map((w) => w.buddy).toList());
    final byId = {for (final b in filled) b.id: b};
    return [
      for (final w in list)
        domain.BuddyWithRole(buddy: byId[w.buddy.id]!, roles: w.roles),
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
                leftOuterJoin(
                  _db.dives,
                  _db.dives.id.equalsExp(_db.diveBuddies.diveId),
                  useColumns: false,
                ),
              ])
              ..addColumns([_db.dives.diverId])
              ..where(_db.diveBuddies.diveId.isIn(diveIds))
              ..orderBy([
                OrderingTerm.asc(_db.buddies.name.collate(Collate.noCase)),
              ]))
            .get();

    // Resolve role ids against dive_roles once, scoped to each dive's diver
    // (see resolveDiveRole).
    final roleRows = await _db.select(_db.diveRoles).get();
    final rolesById = {for (final r in roleRows) r.id: mapDiveRoleRow(r)};
    final roleSets = await _roleLinks.buddyRoleIdsForDives(diveIds);

    final byDive = <String, List<domain.BuddyWithRole>>{};
    for (final jr in sortedByText(
      joinRows,
      (jr) => jr.readTable(_db.buddies).name,
    )) {
      final b = jr.readTable(_db.buddies);
      final link = jr.readTable(_db.diveBuddies);
      final buddy = domain.Buddy(
        id: b.id,
        diverId: b.diverId,
        linkedDiverId: b.linkedDiverId,
        name: b.name,
        email: b.email,
        phone: b.phone,
        photoPath: b.photoPath,
        photo: b.photo,
        notes: b.notes,
        isFavorite: b.isFavorite,
        createdAt: DateTime.fromMillisecondsSinceEpoch(b.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(b.updatedAt),
      );
      final roleIds =
          roleSets[link.diveId]?[link.buddyId] ??
          DiveRoleSet.resolveBuddy(scalar: link.role, junction: const []);
      final roles = [
        for (final id in roleIds)
          resolveDiveRole(
            rolesById,
            id,
            diveDiverId: jr.read(_db.dives.diverId),
          ),
      ];
      byDive
          .putIfAbsent(link.diveId, () => [])
          .add(domain.BuddyWithRole(buddy: buddy, roles: roles));
    }
    return byDive;
  }

  /// [getBuddiesForDives] plus each person's derived primary certification,
  /// for readers that show or export it (the dives only UDDF export writes
  /// it into every `<buddy>` declaration).
  ///
  /// One extra query over the lean load, however many dives and people:
  /// each distinct person is hydrated once through [_withPrimaryCerts], and
  /// a person on several dives gets the same hydrated record on each.
  Future<Map<String, List<domain.BuddyWithRole>>>
  getBuddiesForDivesWithCertifications(List<String> diveIds) async {
    final byDive = await getBuddiesForDives(diveIds);
    final people = <String, domain.Buddy>{
      for (final rows in byDive.values)
        for (final row in rows) row.buddy.id: row.buddy,
    };
    final hydrated = {
      for (final b in await _withPrimaryCerts(people.values.toList())) b.id: b,
    };
    return {
      for (final entry in byDive.entries)
        entry.key: [
          for (final row in entry.value)
            domain.BuddyWithRole(
              buddy: hydrated[row.buddy.id]!,
              roles: row.roles,
            ),
        ],
    };
  }

  /// Set buddies for a dive (replaces existing). Each person's roles are
  /// written to `dive_buddy_roles` (issue #1221); a buddy who left the dive
  /// loses their role rows.
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
    await _insertLinks(diveId, buddies, now);
    await _writeRoleSets(diveId, existing, buddies, now);
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

  /// One fresh `dive_buddies` row per entry of [buddies], carrying the
  /// entry's primary role.
  Future<void> _insertLinks(
    String diveId,
    List<domain.BuddyWithRole> buddies,
    int now,
  ) async {
    for (final bwr in buddies) {
      final id = _uuid.v4();
      await _db
          .into(_db.diveBuddies)
          .insert(
            DiveBuddiesCompanion(
              id: Value(id),
              diveId: Value(diveId),
              buddyId: Value(bwr.buddy.id),
              role: Value(DiveRoleSet.normalizeBuddy(bwr.roleIds).first),
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

  /// After a dive's links were replaced: drops the role rows of everyone in
  /// [previous] who is not in [buddies], and writes each entry's set.
  Future<void> _writeRoleSets(
    String diveId,
    List<DiveBuddy> previous,
    List<domain.BuddyWithRole> buddies,
    int now,
  ) async {
    final kept = {for (final b in buddies) b.buddy.id};
    await _roleLinks.deleteBuddyRoles(diveId, {
      for (final row in previous)
        if (!kept.contains(row.buddyId)) row.buddyId,
    });
    for (final bwr in buddies) {
      await _roleLinks.writeBuddyRoles(
        diveId,
        bwr.buddy.id,
        bwr.roleIds,
        now: now,
      );
    }
  }

  /// Add a buddy to a dive in one role. [roleId] is a dive_roles id (see
  /// [DiveRole]); [addBuddyToDiveWithRoles] takes several.
  Future<void> addBuddyToDive(String diveId, String buddyId, String roleId) =>
      addBuddyToDiveWithRoles(diveId, buddyId, [roleId]);

  /// Add a buddy to a dive holding [roleIds] (issue #1221), or replace the
  /// roles of a buddy already on it. An empty list means Buddy.
  Future<void> addBuddyToDiveWithRoles(
    String diveId,
    String buddyId,
    List<String> roleIds,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final existing =
        await (_db.select(_db.diveBuddies)..where(
              (t) => t.diveId.equals(diveId) & t.buddyId.equals(buddyId),
            ))
            .getSingleOrNull();

    if (existing == null) {
      final id = _uuid.v4();
      await _db
          .into(_db.diveBuddies)
          .insert(
            DiveBuddiesCompanion(
              id: Value(id),
              diveId: Value(diveId),
              buddyId: Value(buddyId),
              role: Value(DiveRoleSet.normalizeBuddy(roleIds).first),
              createdAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'diveBuddies',
        recordId: id,
        localUpdatedAt: now,
      );
    }
    // Sets the link's primary role too, marking it pending when it changes.
    await _roleLinks.writeBuddyRoles(diveId, buddyId, roleIds, now: now);
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

  /// Remove a buddy from a dive, with their role rows.
  Future<void> removeBuddyFromDive(String diveId, String buddyId) async {
    await _roleLinks.deleteBuddyRoles(diveId, [buddyId]);
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

  /// Add each buddy (with roles) to every dive. Upserts the roles if already
  /// linked, unless [overwriteRole] is false: a membership-only add must
  /// leave the roles each existing link already carries untouched (#893).
  /// No notify/transaction: BulkDiveEditService owns those.
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
        if (existing != null && !overwriteRole) continue;
        if (existing == null) await _insertLinks(diveId, [bwr], now);
        await _roleLinks.writeBuddyRoles(
          diveId,
          bwr.buddy.id,
          bwr.roleIds,
          now: now,
        );
      }
      await _bumpDive(diveId, now);
    }
  }

  /// Rewrite the roles on the links each dive ALREADY has for [buddies],
  /// inserting nothing. The role-only counterpart to [bulkAddBuddies]: a dive
  /// the buddy is missing from stays missing, so changing someone's roles
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
      for (final row in existing) {
        // Marks the link pending, on its own clock, when its primary role
        // changes (#2644).
        await _roleLinks.writeBuddyRoles(
          row.diveId,
          bwr.buddy.id,
          bwr.roleIds,
          now: now,
        );
        touched.add(row.diveId);
      }
    }
    for (final diveId in touched) {
      await _bumpDive(diveId, now);
    }
  }

  /// Remove each buddy id from every dive, with their role rows. No
  /// notify/transaction.
  Future<void> bulkRemoveBuddies(
    List<String> diveIds,
    List<String> buddyIds,
  ) async {
    if (diveIds.isEmpty || buddyIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _roleLinks.deleteBuddyRolesOnDives(diveIds, buddyIds);
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

  /// Replace each dive's buddy set with exactly [buddies], roles included.
  /// No notify/transaction.
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
      await _insertLinks(diveId, buddies, now);
      await _writeRoleSets(diveId, existing, buddies, now);
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
          INNER JOIN dives d ON d.id = db.dive_id
                            ${DiveStatsScope.and(alias: 'd')}
          GROUP BY db.buddy_id
        ) dc ON b.id = dc.buddy_id
        $where
        ORDER BY b.name COLLATE NOCASE ASC
      ''', variables: variables).get();

      // How often each buddy held each role, every role of every dive
      // counted (several per dive since #1221). The per-buddy winner is
      // picked in Dart by usualRoleFor.
      final roleCountsByBuddy = <String, Map<String, int>>{};
      for (final perDive in (await _roleLinks.allBuddyRoleIds()).values) {
        for (final entry in perDive.entries) {
          final counts = roleCountsByBuddy.putIfAbsent(entry.key, () => {});
          for (final roleId in entry.value) {
            counts.update(roleId, (n) => n + 1, ifAbsent: () => 1);
          }
        }
      }

      final list = sortedByText(results, (r) => r.data['name'] as String).map((
        row,
      ) {
        final buddy = domain.Buddy(
          id: row.data['id'] as String,
          diverId: row.data['diver_id'] as String?,
          linkedDiverId: row.data['linked_diver_id'] as String?,
          name: row.data['name'] as String,
          email: row.data['email'] as String?,
          phone: row.data['phone'] as String?,
          photoPath: row.data['photo_path'] as String?,
          photo: row.data['photo'] as Uint8List?,
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
              : wallClockUtcFromMillis(lastDive),
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

  /// Get dive count for a buddy, as shown on the buddy card and detail
  /// header. Honours [DiveStatsScope], so a dive the diver excluded from
  /// statistics does not inflate "N dives with this buddy".
  Future<int> getDiveCountForBuddy(String buddyId) async {
    final result = await _db
        .customSelect(
          '''
      SELECT COUNT(*) as count
      FROM dive_buddies db
      INNER JOIN dives d ON d.id = db.dive_id
      WHERE db.buddy_id = ?${DiveStatsScope.and(alias: 'd')}
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
  // stats-scope-exempt: drives the buddy's displayed dive list, like the logbook
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
      WHERE db.buddy_id = ?${DiveStatsScope.and(alias: 'd')}
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
        firstDive = wallClockUtcFromMillis(firstDiveTs);
      }
      if (lastDiveTs != null) {
        lastDive = wallClockUtcFromMillis(lastDiveTs);
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
      WHERE db.buddy_id = ?${DiveStatsScope.and(alias: 'd')}
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

  /// Legacy buddy text conversion (#1831). Delegates to
  /// [BuddyConversionRepository].
  Future<List<MatchCandidate>> legacyConversionCandidates(String diverId) =>
      BuddyConversionRepository().candidateBuddies(diverId);

  Future<List<UnlinkedTextDive>> unlinkedLegacyTextDives(String diverId) =>
      BuddyConversionRepository().unlinkedTextDives(diverId);

  Future<ConversionReceipt> applyLegacyConversion(
    List<ConversionPlan> plans, {
    required String diverId,
    required String newBuddyNote,
  }) => BuddyConversionRepository().apply(
    plans,
    diverId: diverId,
    newBuddyNote: newBuddyNote,
  );

  Future<void> undoLegacyConversion(ConversionReceipt receipt) =>
      BuddyConversionRepository().undo(receipt);

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
    // Every custom row, not just the viewer's: rank and title must not
    // depend on which profile is looking (issue #690).
    final catalog = CertificationCatalog(
      agencies: await _customCertRepo.getAllAgencies(),
      levels: await _customCertRepo.getAllLevels(),
    );
    return buddies.map((b) {
      // copyWith (not a field-by-field rebuild): the incoming buddy already has
      // null cert fields (the inline columns were dropped in v110), so copyWith
      // just sets the derived primary -- and stays correct if Buddy gains new
      // fields later, which a full constructor call would silently drop.
      final primary = primaryCertification(
        certsByBuddy[b.id] ?? const [],
        catalog: catalog,
      );
      return b.copyWith(
        certificationLevel: primary?.level,
        certificationAgency: primary?.agency,
        certificationTitle: primary == null
            ? null
            : certificationTitle(primary, catalog: catalog),
      );
    }).toList();
  }

  domain.Buddy _mapRowToBuddy(Buddy row) {
    return domain.Buddy(
      id: row.id,
      diverId: row.diverId,
      linkedDiverId: row.linkedDiverId,
      name: row.name,
      email: row.email,
      phone: row.phone,
      // Derived at hydration from the certifications table (issue #553);
      // _withPrimaryCerts overwrites these on the read paths.
      certificationLevel: null,
      certificationAgency: null,
      certificationTitle: null,
      photoPath: row.photoPath,
      photo: row.photo,
      notes: row.notes,
      isFavorite: row.isFavorite,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
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
