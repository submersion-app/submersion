import 'package:collection/collection.dart';
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

  /// Links per statement in the writes over many sites. Each binds at most
  /// four variables, well under SQLite's limit.
  static const _linkChunk = 500;

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
      await addTypesToSites({siteId: added});
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
      await addTypesToSites({siteId: added});
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
      await addTagsToSites({siteId: added});
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
      await addTagsToSites({siteId: added});
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

  /// Removes [tagIds] from [siteId]'s tags; never adds one. [replaceTags]
  /// with the rest, so the library rule, the tombstones and the stamp are
  /// that one write's. A tag the site does not carry is ignored.
  Future<void> removeTags(
    String siteId,
    List<String> tagIds, {
    bool notify = true,
    String? actingDiverId,
  }) async {
    if (tagIds.isEmpty) return;
    final unwanted = tagIds.toSet();
    await replaceTags(
      siteId,
      [
        for (final id in (await getTagIdsBySite([siteId]))[siteId] ?? const [])
          if (!unwanted.contains(id)) id,
      ],
      notify: notify,
      actingDiverId: actingDiverId,
    );
  }

  /// Removes [typeIds] from [siteId]'s types; never adds one. [replaceTypes]
  /// with the rest, as [removeTags] does.
  Future<void> removeTypes(
    String siteId,
    List<String> typeIds, {
    bool notify = true,
    String? actingDiverId,
  }) async {
    if (typeIds.isEmpty) return;
    final unwanted = typeIds.toSet();
    await replaceTypes(
      siteId,
      [
        for (final id in (await getTypeIdsBySite([siteId]))[siteId] ?? const [])
          if (!unwanted.contains(id)) id,
      ],
      notify: notify,
      actingDiverId: actingDiverId,
    );
  }

  /// [addTypes] over many sites in one pass (#4012): [missing] names the
  /// types each site lacks, in the order to add them, from a read the caller
  /// has just made. For a caller's transaction, as `notify: false` is: it
  /// neither notifies nor checks who may edit a library site.
  Future<void> addTypesToSites(Map<String, List<String>> missing) =>
      _insertLinks(
        _db.siteSiteTypes,
        linkColumn: 'site_type_id',
        entityType: 'siteSiteTypes',
        missing: missing,
      );

  /// [addTypesToSites] for tags.
  Future<void> addTagsToSites(Map<String, List<String>> missing) =>
      _insertLinks(
        _db.siteTags,
        linkColumn: 'tag_id',
        entityType: 'siteTags',
        missing: missing,
      );

  /// [removeTypes] over many sites in one pass (#4012), on the terms of
  /// [addTypesToSites]. A type a site does not carry is ignored.
  Future<void> removeTypesFromSites(
    List<String> siteIds,
    List<String> typeIds,
  ) => _removeLinks(
    _db.siteSiteTypes,
    linkColumn: 'site_type_id',
    entityType: 'siteSiteTypes',
    siteIds: siteIds,
    linkedIds: typeIds,
  );

  /// [removeTypesFromSites] for tags.
  Future<void> removeTagsFromSites(List<String> siteIds, List<String> tagIds) =>
      _removeLinks(
        _db.siteTags,
        linkColumn: 'tag_id',
        entityType: 'siteTags',
        siteIds: siteIds,
        linkedIds: tagIds,
      );

  /// Inserts [missing], one statement per chunk. `created_at` counts up
  /// within each site, because the read order is `created_at, id` and a
  /// shared timestamp would leave the order to random uuids. RETURNING names
  /// the rows that landed, so a pair already held is not marked pending.
  Future<void> _insertLinks(
    TableInfo<Table, dynamic> table, {
    required String linkColumn,
    required String entityType,
    required Map<String, List<String>> missing,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = [
      for (final MapEntry(key: siteId, value: linkedIds) in missing.entries)
        for (final (i, linkedId) in linkedIds.indexed)
          (siteId: siteId, linkedId: linkedId, createdAt: now + i),
    ];
    if (rows.isEmpty) return;
    await _db.transaction(() async {
      final inserted = <String>[];
      for (final chunk in rows.slices(_linkChunk)) {
        final landed = await _db.customWriteReturning(
          'INSERT INTO ${table.actualTableName} '
          '(id, site_id, $linkColumn, created_at) '
          "VALUES ${List.filled(chunk.length, '(?, ?, ?, ?)').join(', ')} "
          'ON CONFLICT DO NOTHING RETURNING id',
          variables: [
            for (final row in chunk) ...[
              Variable.withString(_uuid.v4()),
              Variable.withString(row.siteId),
              Variable.withString(row.linkedId),
              Variable.withInt(row.createdAt),
            ],
          ],
          updates: {table},
          updateKind: UpdateKind.insert,
        );
        inserted.addAll(landed.map((r) => r.read<String>('id')));
      }
      await _syncRepository.markRecordsPending(
        entityType: entityType,
        recordIds: inserted,
        localUpdatedAt: now,
      );
    });
  }

  /// Deletes [linkedIds] from [siteIds], one statement per chunk, and
  /// tombstones each row that went.
  Future<void> _removeLinks(
    TableInfo<Table, dynamic> table, {
    required String linkColumn,
    required String entityType,
    required List<String> siteIds,
    required List<String> linkedIds,
  }) async {
    if (siteIds.isEmpty || linkedIds.isEmpty) return;
    final unwanted = linkedIds.toSet().toList();
    await _db.transaction(() async {
      final removed = <String>[];
      for (final chunk in siteIds.slices(_linkChunk)) {
        final gone = await _db.customWriteReturning(
          'DELETE FROM ${table.actualTableName} '
          "WHERE site_id IN (${List.filled(chunk.length, '?').join(', ')}) "
          "AND $linkColumn IN (${List.filled(unwanted.length, '?').join(', ')}) "
          'RETURNING id',
          variables: [
            for (final id in chunk) Variable.withString(id),
            for (final id in unwanted) Variable.withString(id),
          ],
          updates: {table},
          updateKind: UpdateKind.delete,
        );
        removed.addAll(gone.map((r) => r.read<String>('id')));
      }
      await _syncRepository.logDeletions(
        entityType: entityType,
        recordIds: removed,
      );
    });
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
}
