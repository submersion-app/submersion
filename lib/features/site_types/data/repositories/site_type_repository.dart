import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/site_types/data/mappers/site_type_row_mapper.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';

/// The site type vocabulary (issue #1765). The twin of DiveTypeRepository:
/// built-ins are read-only, custom types belong to one diver.
class SiteTypeRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(SiteTypeRepository);

  Stream<void> watchSiteTypesChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.siteTypes));

  /// Built-ins, then [diverId]'s custom types, each in sort order. Without a
  /// diver only the built-ins are returned.
  Future<List<SiteTypeEntity>> getAllSiteTypes({String? diverId}) async {
    try {
      final query = _db.select(_db.siteTypes)
        ..orderBy([
          (t) => OrderingTerm.desc(t.isBuiltIn),
          (t) => OrderingTerm.asc(t.sortOrder),
          (t) => OrderingTerm.asc(t.name),
        ]);
      if (diverId != null) {
        query.where(
          (t) =>
              t.isBuiltIn.equals(true) |
              (t.isBuiltIn.equals(false) & t.diverId.equals(diverId)),
        );
      } else {
        query.where((t) => t.isBuiltIn.equals(true));
      }
      final rows = await query.get();
      return rows.map(mapSiteTypeRow).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get site types', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<SiteTypeEntity?> getSiteTypeById(String id) async {
    final row = await (_db.select(
      _db.siteTypes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : mapSiteTypeRow(row);
  }

  /// [diverId]'s custom type whose trimmed name matches [name] ignoring case.
  /// Importers use it so a re-import reuses the type instead of minting a
  /// near-duplicate.
  Future<SiteTypeEntity?> getCustomSiteTypeByName(
    String name, {
    required String diverId,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM site_types WHERE is_built_in = 0 AND diver_id = ? '
          'AND lower(trim(name)) = lower(trim(?)) ORDER BY id LIMIT 1',
          variables: [Variable.withString(diverId), Variable.withString(name)],
          readsFrom: {_db.siteTypes},
        )
        .get();
    if (rows.isEmpty) return null;
    return mapSiteTypeRow(_db.siteTypes.map(rows.single.data));
  }

  /// Creates a custom type for `type.diverId`. A slug already taken (by a
  /// built-in or another custom type) gets a random suffix, as dive types do.
  Future<SiteTypeEntity> createSiteType(SiteTypeEntity type) async {
    try {
      if (type.diverId == null) {
        throw Exception('Cannot create a custom site type without a diver ID.');
      }
      final name = type.name.trim();
      final slug = type.id.isEmpty
          ? SiteTypeEntity.generateSlug(name)
          : type.id;
      final uniqueId = await getSiteTypeById(slug) != null
          ? '${slug}_${_uuid.v4().substring(0, 8)}'
          : slug;
      final now = DateTime.now().millisecondsSinceEpoch;
      final sortOrder = type.sortOrder > 0
          ? type.sortOrder
          : await _getMaxSortOrder() + 1;

      await _db
          .into(_db.siteTypes)
          .insert(
            SiteTypesCompanion(
              id: Value(uniqueId),
              diverId: Value(type.diverId),
              name: Value(name),
              isBuiltIn: const Value(false),
              sortOrder: Value(sortOrder),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'siteTypes',
        recordId: uniqueId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      return type.copyWith(
        id: uniqueId,
        name: name,
        isBuiltIn: false,
        sortOrder: sortOrder,
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create site type',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> updateSiteType(SiteTypeEntity type) async {
    final existing = await getSiteTypeById(type.id);
    if (existing != null && existing.isBuiltIn) {
      throw Exception('Cannot update built-in site types');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.siteTypes)..where((t) => t.id.equals(type.id))).write(
      SiteTypesCompanion(
        name: Value(type.name.trim()),
        sortOrder: Value(type.sortOrder),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'siteTypes',
      recordId: type.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Deletes a custom type and every site link to it. The junction has no
  /// foreign key to cascade through, so the links are deleted and tombstoned
  /// here, in the same transaction.
  Future<void> deleteSiteType(String id) async {
    final existing = await getSiteTypeById(id);
    if (existing != null && existing.isBuiltIn) {
      throw Exception('Cannot delete built-in site types');
    }
    await _db.transaction(() async {
      final links = await (_db.select(
        _db.siteSiteTypes,
      )..where((t) => t.siteTypeId.equals(id))).get();
      for (final link in links) {
        await (_db.delete(
          _db.siteSiteTypes,
        )..where((t) => t.id.equals(link.id))).go();
        await _syncRepository.logDeletion(
          entityType: 'siteSiteTypes',
          recordId: link.id,
        );
      }
      await (_db.delete(_db.siteTypes)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: 'siteTypes', recordId: id);
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Every type [diverId] can see, with the number of sites using it.
  Future<List<SiteTypeStatistic>> getSiteTypeStatistics({
    String? diverId,
  }) async {
    final where = diverId != null
        ? 'WHERE st.is_built_in = 1 OR (st.is_built_in = 0 AND st.diver_id = ?)'
        : 'WHERE st.is_built_in = 1';
    final rows = await _db
        .customSelect(
          '''
      SELECT st.*, COUNT(sst.id) AS site_count
      FROM site_types st
      LEFT JOIN site_site_types sst ON sst.site_type_id = st.id
      $where
      GROUP BY st.id
      ORDER BY st.is_built_in DESC, st.sort_order, st.name
    ''',
          variables: [if (diverId != null) Variable.withString(diverId)],
          readsFrom: {_db.siteTypes, _db.siteSiteTypes},
        )
        .get();
    return [
      for (final row in rows)
        SiteTypeStatistic(
          siteType: mapSiteTypeRow(_db.siteTypes.map(row.data)),
          siteCount: row.read<int>('site_count'),
        ),
    ];
  }

  Future<int> _getMaxSortOrder() async {
    final result = await _db
        .customSelect('SELECT MAX(sort_order) AS max_order FROM site_types')
        .getSingleOrNull();
    return (result?.data['max_order'] as int?) ?? 0;
  }
}

/// A site type with the number of sites that carry it.
class SiteTypeStatistic {
  final SiteTypeEntity siteType;
  final int siteCount;

  const SiteTypeStatistic({required this.siteType, required this.siteCount});
}
