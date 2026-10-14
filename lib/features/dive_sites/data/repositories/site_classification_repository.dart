import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/site_types/data/mappers/site_type_row_mapper.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/data/mappers/tag_row_mapper.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';

/// Reads and writes a site's types and tags (issue #1765): the
/// `site_site_types` and `site_tags` junctions.
///
/// Both are clockless children of the site. A change marks only the changed
/// junction rows pending and tombstones removed rows. It never marks the
/// parent site pending: a stale whole-row site snapshot from a peer must not
/// be able to overwrite a newer site edit (#1769).
///
/// Writers take `notify: false` when they run inside a caller's transaction;
/// the caller notifies once afterwards.
class SiteClassificationRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final LibraryEditStamper _libraryStamper = LibraryEditStamper();
  final _uuid = const Uuid();

  /// Emits when either junction, or the type or tag vocabulary, changes.
  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([
      _db.siteSiteTypes,
      _db.siteTags,
      _db.siteTypes,
      _db.tags,
    ]),
  );

  Future<List<SiteTypeEntity>> getTypesForSite(String siteId) async {
    final rows = await _db
        .customSelect(
          'SELECT st.* FROM site_site_types sst '
          'JOIN site_types st ON st.id = sst.site_type_id '
          'WHERE sst.site_id = ? ORDER BY sst.created_at, sst.id',
          variables: [Variable.withString(siteId)],
          readsFrom: {_db.siteSiteTypes, _db.siteTypes},
        )
        .get();
    return [for (final r in rows) mapSiteTypeRow(_db.siteTypes.map(r.data))];
  }

  Future<List<domain.Tag>> getTagsForSite(String siteId) async {
    final rows = await _db
        .customSelect(
          'SELECT t.* FROM site_tags stg JOIN tags t ON t.id = stg.tag_id '
          'WHERE stg.site_id = ? ORDER BY t.name COLLATE NOCASE',
          variables: [Variable.withString(siteId)],
          readsFrom: {_db.siteTags, _db.tags},
        )
        .get();
    return [
      for (final r in sortedByText(rows, (r) => r.data['name'] as String))
        mapTagRow(_db.tags.map(r.data)),
    ];
  }

  /// Every site's types, in each site's own order. A row pointing at a
  /// custom type that has not arrived by sync yet is skipped by the join.
  Future<Map<String, List<SiteTypeEntity>>> getTypesBySite() async {
    final rows = await _db
        .customSelect(
          'SELECT sst.site_id AS link_site_id, st.* FROM site_site_types sst '
          'JOIN site_types st ON st.id = sst.site_type_id '
          'ORDER BY sst.site_id, sst.created_at, sst.id',
          readsFrom: {_db.siteSiteTypes, _db.siteTypes},
        )
        .get();
    final bySite = <String, List<SiteTypeEntity>>{};
    for (final r in rows) {
      bySite
          .putIfAbsent(r.read<String>('link_site_id'), () => [])
          .add(mapSiteTypeRow(_db.siteTypes.map(r.data)));
    }
    return bySite;
  }

  /// Every site's tags, by name.
  Future<Map<String, List<domain.Tag>>> getTagsBySite() async {
    final rows = await _db
        .customSelect(
          'SELECT stg.site_id AS link_site_id, t.* FROM site_tags stg '
          'JOIN tags t ON t.id = stg.tag_id ORDER BY stg.site_id, t.name COLLATE NOCASE',
          readsFrom: {_db.siteTags, _db.tags},
        )
        .get();
    final bySite = <String, List<domain.Tag>>{};
    for (final r in sortedByText(
      rows,
      (r) => r.data['name'] as String,
      groupOf: (r) => r.read<String>('link_site_id'),
    )) {
      bySite
          .putIfAbsent(r.read<String>('link_site_id'), () => [])
          .add(mapTagRow(_db.tags.map(r.data)));
    }
    return bySite;
  }

  /// The distinct sites of [diveIds], for the dives-only UDDF export.
  Future<List<String>> getSiteIdsForDives(List<String> diveIds) async {
    if (diveIds.isEmpty) return const [];
    final rows =
        await (_db.selectOnly(_db.dives, distinct: true)
              ..addColumns([_db.dives.siteId])
              ..where(
                _db.dives.id.isIn(diveIds) & _db.dives.siteId.isNotNull(),
              ))
            .get();
    return [for (final r in rows) r.read(_db.dives.siteId)!];
  }

  /// Raw type ids per site for [siteIds] (no join), for merge snapshots and
  /// exports.
  Future<Map<String, List<String>>> getTypeIdsBySite(
    List<String> siteIds,
  ) async {
    if (siteIds.isEmpty) return const {};
    final rows =
        await (_db.select(_db.siteSiteTypes)
              ..where((t) => t.siteId.isIn(siteIds))
              ..orderBy([
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final bySite = <String, List<String>>{};
    for (final r in rows) {
      bySite.putIfAbsent(r.siteId, () => []).add(r.siteTypeId);
    }
    return bySite;
  }

  /// Raw tag ids per site for [siteIds].
  Future<Map<String, List<String>>> getTagIdsBySite(
    List<String> siteIds,
  ) async {
    if (siteIds.isEmpty) return const {};
    final rows =
        await (_db.select(_db.siteTags)
              ..where((t) => t.siteId.isIn(siteIds))
              ..orderBy([
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final bySite = <String, List<String>>{};
    for (final r in rows) {
      bySite.putIfAbsent(r.siteId, () => []).add(r.tagId);
    }
    return bySite;
  }

  /// Makes [siteId]'s types exactly [typeIds]. Rows for types that stay are
  /// left alone, so their ids, clocks and order survive the save.
  Future<void> replaceTypes(
    String siteId,
    List<String> typeIds, {
    bool notify = true,
    String? actingDiverId,
  }) async {
    // A library site [actingDiverId] may not edit (a reader's): never
    // changed here, or the list would differ from the library's for good
    // (issue #2567). The bridge applying a pulled list does not notify.
    if (notify &&
        !await _libraryStamper.mayEdit(siteId, actingDiverId: actingDiverId)) {
      return;
    }
    final changed = await _db.transaction(() async {
      final wanted = typeIds.toSet();
      final existing = await (_db.select(
        _db.siteSiteTypes,
      )..where((t) => t.siteId.equals(siteId))).get();
      var removed = false;
      for (final row in existing) {
        if (wanted.contains(row.siteTypeId)) continue;
        await (_db.delete(
          _db.siteSiteTypes,
        )..where((t) => t.id.equals(row.id))).go();
        await _syncRepository.logDeletion(
          entityType: 'siteSiteTypes',
          recordId: row.id,
        );
        removed = true;
      }
      final have = {for (final r in existing) r.siteTypeId};
      final added = [
        for (final id in wanted)
          if (!have.contains(id)) id,
      ];
      await _insertTypes(siteId, added);
      return removed || added.isNotEmpty;
    });
    if (notify) {
      // A shared site library clock only for a real change (issue #2567): a fresh
      // clock on an unchanged list would beat another member's edit.
      if (changed) {
        await _libraryStamper.stamp(siteId, {
          'siteTypes',
        }, actingDiverId: actingDiverId);
      }
      SyncEventBus.notifyLocalChange();
    }
  }

  /// Adds [typeIds] to [siteId]'s types; never removes one.
  Future<void> addTypes(
    String siteId,
    List<String> typeIds, {
    bool notify = true,
    String? actingDiverId,
  }) async {
    // A library site [actingDiverId] may not edit (a reader's): never
    // changed here, or the list would differ from the library's for good
    // (issue #2567). The bridge applying a pulled list does not notify.
    if (notify &&
        !await _libraryStamper.mayEdit(siteId, actingDiverId: actingDiverId)) {
      return;
    }
    if (typeIds.isEmpty) return;
    final changed = await _db.transaction(() async {
      final existing = await (_db.select(
        _db.siteSiteTypes,
      )..where((t) => t.siteId.equals(siteId))).get();
      final have = {for (final r in existing) r.siteTypeId};
      final added = [
        for (final id in typeIds.toSet())
          if (!have.contains(id)) id,
      ];
      await _insertTypes(siteId, added);
      return added.isNotEmpty;
    });
    if (notify) {
      if (changed) {
        await _libraryStamper.stamp(siteId, {
          'siteTypes',
        }, actingDiverId: actingDiverId);
      }
      SyncEventBus.notifyLocalChange();
    }
  }

  /// Makes [siteId]'s tags exactly [tagIds].
  Future<void> replaceTags(
    String siteId,
    List<String> tagIds, {
    bool notify = true,
    String? actingDiverId,
  }) async {
    // A library site [actingDiverId] may not edit (a reader's): never
    // changed here, or the list would differ from the library's for good
    // (issue #2567). The bridge applying a pulled list does not notify.
    if (notify &&
        !await _libraryStamper.mayEdit(siteId, actingDiverId: actingDiverId)) {
      return;
    }
    final changed = await _db.transaction(() async {
      final wanted = tagIds.toSet();
      final existing = await (_db.select(
        _db.siteTags,
      )..where((t) => t.siteId.equals(siteId))).get();
      var removed = false;
      for (final row in existing) {
        if (wanted.contains(row.tagId)) continue;
        await (_db.delete(
          _db.siteTags,
        )..where((t) => t.id.equals(row.id))).go();
        await _syncRepository.logDeletion(
          entityType: 'siteTags',
          recordId: row.id,
        );
        removed = true;
      }
      final have = {for (final r in existing) r.tagId};
      final added = [
        for (final id in wanted)
          if (!have.contains(id)) id,
      ];
      await _insertTags(siteId, added);
      return removed || added.isNotEmpty;
    });
    if (notify) {
      if (changed) {
        await _libraryStamper.stamp(siteId, {
          'tags',
        }, actingDiverId: actingDiverId);
      }
      SyncEventBus.notifyLocalChange();
    }
  }

  /// Adds [tagIds] to [siteId]'s tags; never removes one.
  Future<void> addTags(
    String siteId,
    List<String> tagIds, {
    bool notify = true,
    String? actingDiverId,
  }) async {
    // A library site [actingDiverId] may not edit (a reader's): never
    // changed here, or the list would differ from the library's for good
    // (issue #2567). The bridge applying a pulled list does not notify.
    if (notify &&
        !await _libraryStamper.mayEdit(siteId, actingDiverId: actingDiverId)) {
      return;
    }
    if (tagIds.isEmpty) return;
    final changed = await _db.transaction(() async {
      final existing = await (_db.select(
        _db.siteTags,
      )..where((t) => t.siteId.equals(siteId))).get();
      final have = {for (final r in existing) r.tagId};
      final added = [
        for (final id in tagIds.toSet())
          if (!have.contains(id)) id,
      ];
      await _insertTags(siteId, added);
      return added.isNotEmpty;
    });
    if (notify) {
      if (changed) {
        await _libraryStamper.stamp(siteId, {
          'tags',
        }, actingDiverId: actingDiverId);
      }
      SyncEventBus.notifyLocalChange();
    }
  }

  /// Moves the duplicates' links onto [survivorId] during a site merge.
  /// Runs inside the merge transaction, so it does not notify. A pair the
  /// survivor already holds is deleted and tombstoned instead of moved.
  Future<void> relinkForMerge(
    List<String> duplicateIds,
    String survivorId,
  ) async {
    if (duplicateIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    final haveTypes = {
      for (final r in await (_db.select(
        _db.siteSiteTypes,
      )..where((t) => t.siteId.equals(survivorId))).get())
        r.siteTypeId,
    };
    final dupTypes = await (_db.select(
      _db.siteSiteTypes,
    )..where((t) => t.siteId.isIn(duplicateIds))).get();
    for (final row in dupTypes) {
      if (haveTypes.add(row.siteTypeId)) {
        await (_db.update(_db.siteSiteTypes)..where((t) => t.id.equals(row.id)))
            .write(SiteSiteTypesCompanion(siteId: Value(survivorId)));
        await _syncRepository.markRecordPending(
          entityType: 'siteSiteTypes',
          recordId: row.id,
          localUpdatedAt: now,
        );
      } else {
        await (_db.delete(
          _db.siteSiteTypes,
        )..where((t) => t.id.equals(row.id))).go();
        await _syncRepository.logDeletion(
          entityType: 'siteSiteTypes',
          recordId: row.id,
        );
      }
    }

    final haveTags = {
      for (final r in await (_db.select(
        _db.siteTags,
      )..where((t) => t.siteId.equals(survivorId))).get())
        r.tagId,
    };
    final dupTags = await (_db.select(
      _db.siteTags,
    )..where((t) => t.siteId.isIn(duplicateIds))).get();
    for (final row in dupTags) {
      if (haveTags.add(row.tagId)) {
        await (_db.update(_db.siteTags)..where((t) => t.id.equals(row.id)))
            .write(SiteTagsCompanion(siteId: Value(survivorId)));
        await _syncRepository.markRecordPending(
          entityType: 'siteTags',
          recordId: row.id,
          localUpdatedAt: now,
        );
      } else {
        await (_db.delete(
          _db.siteTags,
        )..where((t) => t.id.equals(row.id))).go();
        await _syncRepository.logDeletion(
          entityType: 'siteTags',
          recordId: row.id,
        );
      }
    }
  }

  /// Inserts in the given order: `created_at` is `now + index`, because the
  /// read order is `created_at, id` and a shared timestamp would leave the
  /// order to random uuids.
  Future<void> _insertTypes(String siteId, List<String> typeIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < typeIds.length; i++) {
      final id = _uuid.v4();
      final inserted = await _db
          .into(_db.siteSiteTypes)
          .insertReturningOrNull(
            SiteSiteTypesCompanion.insert(
              id: id,
              siteId: siteId,
              siteTypeId: typeIds[i],
              createdAt: now + i,
            ),
            onConflict: DoNothing<$SiteSiteTypesTable, SiteSiteType>(
              target: const [],
            ),
          );
      if (inserted == null) continue;
      await _syncRepository.markRecordPending(
        entityType: 'siteSiteTypes',
        recordId: id,
        localUpdatedAt: now,
      );
    }
  }

  Future<void> _insertTags(String siteId, List<String> tagIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < tagIds.length; i++) {
      final id = _uuid.v4();
      final inserted = await _db
          .into(_db.siteTags)
          .insertReturningOrNull(
            SiteTagsCompanion.insert(
              id: id,
              siteId: siteId,
              tagId: tagIds[i],
              createdAt: now + i,
            ),
            onConflict: DoNothing<$SiteTagsTable, SiteTag>(target: const []),
          );
      if (inserted == null) continue;
      await _syncRepository.markRecordPending(
        entityType: 'siteTags',
        recordId: id,
        localUpdatedAt: now,
      );
    }
  }
}
