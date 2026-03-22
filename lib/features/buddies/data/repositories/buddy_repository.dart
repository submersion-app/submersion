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

class BuddyRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(BuddyRepository);

  /// Get all buddies ordered by name
  Future<List<domain.Buddy>> getAllBuddies({String? diverId}) async {
    try {
      final query = _db.select(_db.buddies)
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return rows.map(_mapRowToBuddy).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get all buddies', e, stackTrace);
      rethrow;
    }
  }

  /// Get buddy by ID
  Future<domain.Buddy?> getBuddyById(String id) async {
    try {
      final query = _db.select(_db.buddies)..where((t) => t.id.equals(id));

      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToBuddy(row) : null;
    } catch (e, stackTrace) {
      _log.error('Failed to get buddy by id: $id', e, stackTrace);
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

    return results.map((row) {
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
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.data['created_at'] as int,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row.data['updated_at'] as int,
        ),
      );
    }).toList();
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
              certificationLevel: Value(buddy.certificationLevel?.name),
              certificationAgency: Value(buddy.certificationAgency?.name),
              photoPath: Value(buddy.photoPath),
              notes: Value(buddy.notes),
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
      _log.error('Failed to create buddy: ${buddy.name}', e, stackTrace);
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
        return domain.Buddy(
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
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row.data['created_at'] as int,
          ),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            row.data['updated_at'] as int,
          ),
        );
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

      return createBuddy(newBuddy);
    } catch (e, stackTrace) {
      _log.error('Failed to find or create buddy: $name', e, stackTrace);
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
          certificationLevel: Value(buddy.certificationLevel?.name),
          certificationAgency: Value(buddy.certificationAgency?.name),
          photoPath: Value(buddy.photoPath),
          notes: Value(buddy.notes),
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
      _log.error('Failed to update buddy: ${buddy.id}', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a buddy
  Future<void> deleteBuddy(String id) async {
    try {
      _log.info('Deleting buddy: $id');
      // Dive buddies will be automatically deleted due to CASCADE
      await (_db.delete(_db.buddies)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: 'buddies', recordId: id);
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted buddy: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to delete buddy: $id', e, stackTrace);
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

    return results.map((row) {
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
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.data['created_at'] as int,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row.data['updated_at'] as int,
        ),
      );
      final role = BuddyRole.values.firstWhere(
        (r) => r.name == row.data['role'],
        orElse: () => BuddyRole.buddy,
      );
      return domain.BuddyWithRole(buddy: buddy, role: role);
    }).toList();
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
              role: Value(buddyWithRole.role.name),
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

  /// Add a buddy to a dive
  Future<void> addBuddyToDive(
    String diveId,
    String buddyId,
    BuddyRole role,
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
          .write(DiveBuddiesCompanion(role: Value(role.name)));
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
              role: Value(role.name),
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

  /// Get all buddies with their dive counts in a single efficient query
  Future<List<BuddyWithDiveCount>> getAllBuddiesWithDiveCount({
    String? diverId,
  }) async {
    try {
      final diverFilter = diverId != null ? 'WHERE b.diver_id = ?' : '';
      final variables = [if (diverId != null) Variable.withString(diverId)];

      final results = await _db.customSelect('''
        SELECT b.*, COALESCE(dc.dive_count, 0) as dive_count
        FROM buddies b
        LEFT JOIN (
          SELECT buddy_id, COUNT(*) as dive_count
          FROM dive_buddies
          GROUP BY buddy_id
        ) dc ON b.id = dc.buddy_id
        $diverFilter
        ORDER BY b.name ASC
      ''', variables: variables).get();

      return results.map((row) {
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
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row.data['created_at'] as int,
          ),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            row.data['updated_at'] as int,
          ),
        );
        return BuddyWithDiveCount(
          buddy: buddy,
          diveCount: row.data['dive_count'] as int,
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get buddies with dive counts', e, stackTrace);
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

  /// Get dives shared with a buddy
  Future<List<String>> getDiveIdsForBuddy(String buddyId) async {
    final results = await _db
        .customSelect(
          '''
      SELECT dive_id
      FROM dive_buddies
      WHERE buddy_id = ?
      ORDER BY created_at DESC
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

  static const _roleRank = {
    'solo': 0,
    'student': 1,
    'buddy': 2,
    'diveGuide': 3,
    'diveMaster': 4,
    'instructor': 5,
  };

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
      final originalSurvivor = await getBuddyById(survivorId);
      if (originalSurvivor == null) {
        throw StateError('Survivor buddy $survivorId does not exist');
      }

      final deletedBuddies = <domain.Buddy>[];
      for (final id in duplicateIds) {
        final buddy = await getBuddyById(id);
        if (buddy == null) {
          throw StateError('Buddy not found: $id');
        }
        deletedBuddies.add(buddy);
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
            ),
          )
          .toList(growable: false);

      final deletedDiveBuddyEntries = <DiveBuddySnapshot>[];
      final modifiedDiveBuddyEntries = <DiveBuddySnapshot>[];

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
                // Duplicate's role outranks survivor's - upgrade survivor entry
                final originalSnapshot = DiveBuddySnapshot(
                  id: existingSurvivorRow.id,
                  diveId: existingSurvivorRow.diveId,
                  buddyId: existingSurvivorRow.buddyId,
                  role: existingSurvivorRow.role,
                );
                modifiedDiveBuddyEntries.add(originalSnapshot);

                await (_db.update(_db.diveBuddies)
                      ..where((t) => t.id.equals(existingSurvivorRow.id)))
                    .write(DiveBuddiesCompanion(role: Value(dupRow.role)));
                await _syncRepository.markRecordPending(
                  entityType: 'diveBuddies',
                  recordId: existingSurvivorRow.id,
                  localUpdatedAt: now,
                );
              }

              // Delete the duplicate's junction entry
              deletedDiveBuddyEntries.add(
                DiveBuddySnapshot(
                  id: dupRow.id,
                  diveId: dupRow.diveId,
                  buddyId: dupRow.buddyId,
                  role: dupRow.role,
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
        ),
      );
    } catch (e, stackTrace) {
      _log.error('Failed to merge buddies: $buddyIds', e, stackTrace);
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

/// Buddy with dive count for efficient list sorting
class BuddyWithDiveCount {
  final domain.Buddy buddy;
  final int diveCount;

  const BuddyWithDiveCount({required this.buddy, required this.diveCount});
}

/// Snapshot of a DiveBuddies junction row for undo.
class DiveBuddySnapshot {
  final String id;
  final String diveId;
  final String buddyId;
  final String role;

  const DiveBuddySnapshot({
    required this.id,
    required this.diveId,
    required this.buddyId,
    required this.role,
  });
}

/// Snapshot captured before a buddy merge for undo.
class BuddyMergeSnapshot {
  final domain.Buddy originalSurvivor;
  final List<domain.Buddy> deletedBuddies;
  final List<DiveBuddySnapshot> deletedDiveBuddyEntries;
  final List<DiveBuddySnapshot> modifiedDiveBuddyEntries;

  const BuddyMergeSnapshot({
    required this.originalSurvivor,
    required this.deletedBuddies,
    required this.deletedDiveBuddyEntries,
    required this.modifiedDiveBuddyEntries,
  });
}

/// Result from a buddy merge operation.
class BuddyMergeResult {
  final String survivorId;
  final BuddyMergeSnapshot? snapshot;

  const BuddyMergeResult({required this.survivorId, this.snapshot});
}
