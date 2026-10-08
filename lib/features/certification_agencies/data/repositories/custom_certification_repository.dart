import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/certification_agencies/domain/agency_colors.dart';
import 'package:submersion/features/certification_agencies/domain/entities/certification_usage.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_agency.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_level.dart';

/// A custom agency or level name that is already visible to the diver,
/// built-in names included.
class CertificationNameTakenException implements Exception {
  final String name;
  const CertificationNameTakenException(this.name);
  @override
  String toString() => 'CertificationNameTakenException($name)';
}

/// A write to a custom agency or level by a diver who does not own it.
class CertificationNotOwnerException implements Exception {
  final String id;
  const CertificationNotOwnerException(this.id);
  @override
  String toString() => 'CertificationNotOwnerException($id)';
}

CustomCertificationAgency mapCustomAgencyRow(CustomCertificationAgencyRow r) =>
    CustomCertificationAgency(
      id: r.id,
      diverId: r.diverId,
      name: r.name,
      colorArgb: r.colorArgb,
      isShared: r.isShared,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
    );

CustomCertificationLevel mapCustomLevelRow(CustomCertificationLevelRow r) =>
    CustomCertificationLevel(
      id: r.id,
      diverId: r.diverId,
      agencyId: r.agencyId,
      name: r.name,
      isProgression: r.isProgression,
      sortOrder: r.sortOrder,
      isShared: r.isShared,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
    );

/// Custom certification agencies and levels (issue #690). Owned per diver,
/// optionally shared; only the owner writes. Deletion is refused while any
/// certification or course references the entry, so nothing is rewritten.
class CustomCertificationRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(CustomCertificationRepository);

  static const agencyEntityType = 'customCertificationAgencies';
  static const levelEntityType = 'customCertificationLevels';

  /// Emits whenever either custom table changes, including sync applies.
  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([
      _db.customCertificationAgencies,
      _db.customCertificationLevels,
    ]),
  );

  Future<List<CustomCertificationAgency>> getAllAgencies() async {
    final rows = await (_db.select(
      _db.customCertificationAgencies,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
    return rows.map(mapCustomAgencyRow).toList();
  }

  Future<List<CustomCertificationLevel>> getAllLevels() async {
    final rows =
        await (_db.select(_db.customCertificationLevels)..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.name),
            ]))
            .get();
    return rows.map(mapCustomLevelRow).toList();
  }

  Future<CustomCertificationAgency> createAgency({
    required String diverId,
    required String name,
    int? colorArgb,
    required bool isShared,
  }) async {
    try {
      final trimmed = _requireName(name);
      await _ensureAgencyNameFree(
        trimmed,
        diverId: diverId,
        isShared: isShared,
      );
      final id = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db
          .into(_db.customCertificationAgencies)
          .insert(
            CustomCertificationAgenciesCompanion.insert(
              id: id,
              diverId: diverId,
              name: trimmed,
              colorArgb: colorArgb ?? defaultAgencyColorArgb(id),
              isShared: Value(isShared),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _markPending(agencyEntityType, id, now);
      _log.info('Created custom agency $id for diver $diverId');
      return (await _agency(id))!;
    } catch (e, st) {
      _log.error('Failed to create agency', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<CustomCertificationAgency> updateAgency(
    CustomCertificationAgency agency, {
    required String actingDiverId,
  }) async {
    try {
      final existing = await _agency(agency.id);
      if (existing == null || existing.diverId != actingDiverId) {
        throw CertificationNotOwnerException(agency.id);
      }
      final trimmed = _requireName(agency.name);
      // Only a rename or a newly shared agency can introduce a clash; a
      // same-name pair that arrived by sync must not block other edits.
      if (_nameOrSharingChanged(
        existing.name,
        trimmed,
        wasShared: existing.isShared,
        isShared: agency.isShared,
      )) {
        await _ensureAgencyNameFree(
          trimmed,
          diverId: actingDiverId,
          isShared: agency.isShared,
          exceptId: agency.id,
        );
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.customCertificationAgencies,
      )..where((t) => t.id.equals(agency.id))).write(
        CustomCertificationAgenciesCompanion(
          name: Value(trimmed),
          colorArgb: Value(agency.colorArgb),
          isShared: Value(agency.isShared),
          updatedAt: Value(now),
        ),
      );
      await _markPending(agencyEntityType, agency.id, now);
      return (await _agency(agency.id))!;
    } catch (e, st) {
      _log.error(
        'Failed to update agency ${agency.id}',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<CustomCertificationLevel> createLevel({
    required String diverId,
    required String agencyId,
    required String name,
    required bool isProgression,
    required bool isShared,
  }) async {
    try {
      // A custom agency's certifications belong to its owner; anyone may
      // add their own under a built-in agency.
      final parent = await _agency(agencyId);
      if (parent != null && parent.diverId != diverId) {
        throw CertificationNotOwnerException(agencyId);
      }
      final trimmed = _requireName(name);
      await _ensureLevelNameFree(
        trimmed,
        agencyId: agencyId,
        diverId: diverId,
        isShared: isShared,
      );
      final id = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final sortOrder = isProgression ? await _nextSortOrder(agencyId) : 0;
      await _db
          .into(_db.customCertificationLevels)
          .insert(
            CustomCertificationLevelsCompanion.insert(
              id: id,
              diverId: diverId,
              agencyId: agencyId,
              name: trimmed,
              isProgression: isProgression,
              sortOrder: Value(sortOrder),
              isShared: Value(isShared),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _markPending(levelEntityType, id, now);
      _log.info('Created custom level $id under $agencyId for $diverId');
      return (await _level(id))!;
    } catch (e, st) {
      _log.error('Failed to create level', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<CustomCertificationLevel> updateLevel(
    CustomCertificationLevel level, {
    required String actingDiverId,
  }) async {
    try {
      final existing = await _level(level.id);
      if (existing == null || existing.diverId != actingDiverId) {
        throw CertificationNotOwnerException(level.id);
      }
      final trimmed = _requireName(level.name);
      // As in updateAgency: only a rename or newly sharing can clash.
      if (_nameOrSharingChanged(
        existing.name,
        trimmed,
        wasShared: existing.isShared,
        isShared: level.isShared,
      )) {
        await _ensureLevelNameFree(
          trimmed,
          agencyId: existing.agencyId,
          diverId: actingDiverId,
          isShared: level.isShared,
          exceptId: level.id,
        );
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      // Moving a specialty onto the ladder appends it; the agency is fixed.
      final sortOrder = level.isProgression && !existing.isProgression
          ? await _nextSortOrder(existing.agencyId)
          : existing.sortOrder;
      await (_db.update(
        _db.customCertificationLevels,
      )..where((t) => t.id.equals(level.id))).write(
        CustomCertificationLevelsCompanion(
          name: Value(trimmed),
          isProgression: Value(level.isProgression),
          sortOrder: Value(sortOrder),
          isShared: Value(level.isShared),
          updatedAt: Value(now),
        ),
      );
      await _markPending(levelEntityType, level.id, now);
      return (await _level(level.id))!;
    } catch (e, st) {
      _log.error(
        'Failed to update level ${level.id}',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Rewrites sort_order for [orderedIds] (the agency's custom progression
  /// rungs owned by [actingDiverId]) in the given sequence. Each row is
  /// updated in place and stamped, never deleted and reinserted (#347).
  Future<void> reorderProgression(
    String agencyId,
    List<String> orderedIds, {
    required String actingDiverId,
  }) async {
    try {
      await _db.transaction(() async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final slots = <int>[];
        for (final id in orderedIds) {
          final existing = await _level(id);
          if (existing == null ||
              existing.diverId != actingDiverId ||
              existing.agencyId != agencyId) {
            throw CertificationNotOwnerException(id);
          }
          slots.add(existing.sortOrder);
        }
        // The diver's rungs trade the slots they already hold, so another
        // diver's shared rungs keep their place and no two rungs collide.
        slots.sort();
        for (var i = 0; i < orderedIds.length; i++) {
          await (_db.update(
            _db.customCertificationLevels,
          )..where((t) => t.id.equals(orderedIds[i]))).write(
            CustomCertificationLevelsCompanion(
              sortOrder: Value(slots[i]),
              updatedAt: Value(now),
            ),
          );
          await _syncRepository.markRecordPending(
            entityType: levelEntityType,
            recordId: orderedIds[i],
            localUpdatedAt: now,
          );
        }
      });
      SyncEventBus.notifyLocalChange();
    } catch (e, st) {
      _log.error(
        'Failed to reorder levels of $agencyId',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// References to [id] from certifications (own agency, own level, and the
  /// additional_credentials JSON) and courses.
  Future<CertificationUsage> usage(String id) async {
    final row = await _db
        .customSelect(
          'SELECT '
          // stats-scope-exempt: deletion guard. Counts references across
          // every diver, not statistics.
          '(SELECT COUNT(*) FROM certifications WHERE agency = ?1 '
          'OR level = ?1 OR additional_credentials LIKE ?2) AS certs, '
          '(SELECT COUNT(*) FROM courses WHERE agency = ?1) AS courses',
          variables: [Variable.withString(id), Variable.withString('%"$id"%')],
        )
        .getSingle();
    return CertificationUsage(
      certifications: row.read<int>('certs'),
      courses: row.read<int>('courses'),
    );
  }

  /// References to agency [id] and to every one of its custom levels: what
  /// stands in the way of deleting the agency.
  Future<CertificationUsage> agencyUsage(String id) async {
    final levels = await (_db.select(
      _db.customCertificationLevels,
    )..where((t) => t.agencyId.equals(id))).get();
    var total = await usage(id);
    for (final l in levels) {
      total = total + await usage(l.id);
    }
    return total;
  }

  /// Deletes an unused agency and its custom levels. Returns the usage and
  /// deletes nothing when the agency or any of its levels is referenced.
  Future<CertificationUsage?> deleteAgency(
    String id, {
    required String actingDiverId,
  }) async {
    try {
      final existing = await _agency(id);
      if (existing == null) return null;
      if (existing.diverId != actingDiverId) {
        throw CertificationNotOwnerException(id);
      }
      // The usage check and the deletes share one transaction, so a write
      // that lands between them (a sync pull, another screen) cannot leave a
      // reference to a deleted row.
      final refused = await _db.transaction<CertificationUsage?>(() async {
        final total = await agencyUsage(id);
        if (total.isUsed) return total;
        final levels = await (_db.select(
          _db.customCertificationLevels,
        )..where((t) => t.agencyId.equals(id))).get();
        for (final l in levels) {
          await (_db.delete(
            _db.customCertificationLevels,
          )..where((t) => t.id.equals(l.id))).go();
          await _syncRepository.logDeletion(
            entityType: levelEntityType,
            recordId: l.id,
          );
        }
        await (_db.delete(
          _db.customCertificationAgencies,
        )..where((t) => t.id.equals(id))).go();
        await _syncRepository.logDeletion(
          entityType: agencyEntityType,
          recordId: id,
        );
        return null;
      });
      if (refused != null) return refused;
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted custom agency $id and its levels');
      return null;
    } catch (e, st) {
      _log.error('Failed to delete agency $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Deletes an unused level. Returns the usage and deletes nothing when the
  /// level is referenced.
  Future<CertificationUsage?> deleteLevel(
    String id, {
    required String actingDiverId,
  }) async {
    try {
      final existing = await _level(id);
      if (existing == null) return null;
      if (existing.diverId != actingDiverId) {
        throw CertificationNotOwnerException(id);
      }
      // One transaction for the check and the delete, as in deleteAgency.
      final refused = await _db.transaction<CertificationUsage?>(() async {
        final used = await usage(id);
        if (used.isUsed) return used;
        await (_db.delete(
          _db.customCertificationLevels,
        )..where((t) => t.id.equals(id))).go();
        await _syncRepository.logDeletion(
          entityType: levelEntityType,
          recordId: id,
        );
        return null;
      });
      if (refused != null) return refused;
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted custom level $id');
      return null;
    } catch (e, st) {
      _log.error('Failed to delete level $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  bool _nameOrSharingChanged(
    String oldName,
    String newName, {
    required bool wasShared,
    required bool isShared,
  }) =>
      oldName.toLowerCase() != newName.toLowerCase() ||
      (isShared && !wasShared);

  String _requireName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'empty');
    return trimmed;
  }

  Future<CustomCertificationAgency?> _agency(String id) async {
    final row = await (_db.select(
      _db.customCertificationAgencies,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : mapCustomAgencyRow(row);
  }

  Future<CustomCertificationLevel?> _level(String id) async {
    final row = await (_db.select(
      _db.customCertificationLevels,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : mapCustomLevelRow(row);
  }

  /// Built-in names, the diver's own agencies and every shared one. A
  /// shared agency is seen by every diver, so it is checked against every
  /// diver's agencies, private ones included: two agencies of one name must
  /// never show side by side.
  Future<void> _ensureAgencyNameFree(
    String name, {
    required String diverId,
    required bool isShared,
    String? exceptId,
  }) async {
    final lower = name.toLowerCase();
    final builtIn = CertificationAgency.values.any(
      (a) =>
          a.displayName.toLowerCase() == lower || a.name.toLowerCase() == lower,
    );
    if (builtIn) throw CertificationNameTakenException(name);
    final clash = (await getAllAgencies()).any(
      (a) =>
          a.id != exceptId &&
          (isShared || a.diverId == diverId || a.isShared) &&
          a.name.toLowerCase() == lower,
    );
    if (clash) throw CertificationNameTakenException(name);
  }

  /// The agency's built-in levels and the custom levels of it the diver can
  /// see. Under a custom agency every level counts, since its levels follow
  /// the agency's visibility. A shared level is checked against every
  /// diver's levels of the agency, as a shared agency is.
  Future<void> _ensureLevelNameFree(
    String name, {
    required String agencyId,
    required String diverId,
    required bool isShared,
    String? exceptId,
  }) async {
    final lower = name.toLowerCase();
    final builtInAgency = CertificationAgency.fromId(agencyId);
    if (builtInAgency != null) {
      final builtIns = CertificationLevelCatalog.levelsFor(builtInAgency);
      if (builtIns.any((l) => l.displayName.toLowerCase() == lower)) {
        throw CertificationNameTakenException(name);
      }
    }
    final clash = (await getAllLevels()).any(
      (l) =>
          l.id != exceptId &&
          l.agencyId == agencyId &&
          (isShared ||
              l.diverId == diverId ||
              l.isShared ||
              builtInAgency == null) &&
          l.name.toLowerCase() == lower,
    );
    if (clash) throw CertificationNameTakenException(name);
  }

  Future<int> _nextSortOrder(String agencyId) async {
    final row = await _db
        .customSelect(
          'SELECT MAX(sort_order) AS m FROM custom_certification_levels '
          'WHERE agency_id = ? AND is_progression = 1',
          variables: [Variable.withString(agencyId)],
        )
        .getSingle();
    final max = row.data['m'] as int?;
    return max == null ? 0 : max + 1;
  }

  Future<void> _markPending(String type, String id, int now) async {
    await _syncRepository.markRecordPending(
      entityType: type,
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }
}
