import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/tags/data/mappers/tag_row_mapper.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;

class TagRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(TagRepository);

  // ============================================================================
  // CRUD Operations
  // ============================================================================

  /// Emits whenever the `tags` table changes so list providers can
  /// refresh after a sync or any other write.
  Stream<void> watchTagsChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.tags));

  /// Get all tags, ordered by name. [scope] limits the list to tags offered
  /// on dives or on sites (issue #1765); null returns every tag.
  Future<List<domain.Tag>> getAllTags({
    String? diverId,
    domain.TagScope? scope,
  }) async {
    try {
      final query = _db.select(_db.tags)
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }
      switch (scope) {
        case domain.TagScope.dives:
          query.where((t) => t.appliesToDives.equals(true));
        case domain.TagScope.sites:
          query.where((t) => t.appliesToSites.equals(true));
        case null:
          break;
      }

      final rows = await query.get();
      return rows.map(_mapRowToTag).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get all tags', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get a single tag by ID
  Future<domain.Tag?> getTagById(String id) async {
    try {
      final query = _db.select(_db.tags)..where((t) => t.id.equals(id));
      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToTag(row) : null;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get tag by id: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get a tag by name (case-insensitive, whitespace-insensitive)
  ///
  /// Normalizes both sides exactly as `idx_tags_diver_name_unique` does
  /// (`lower(trim(name))`), so a lookup can never miss a row the index
  /// considers the same tag.
  ///
  /// Deliberately takes the lowest id rather than asserting a single match:
  /// an unscoped lookup legitimately spans two divers who both use "Wreck",
  /// and `getSingleOrNull()` threw "too many elements" there -- which is what
  /// the import wizard reported as "tagging failed" (#1032). Ordering by id
  /// makes the winner the same row the uniqueness collapse keeps.
  Future<domain.Tag?> getTagByName(String name, {String? diverId}) async {
    try {
      final query = _db.select(_db.tags)
        ..where((t) => t.name.trim().lower().equals(name.trim().toLowerCase()));

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }
      query
        ..orderBy([(t) => OrderingTerm.asc(t.id)])
        ..limit(1);

      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToTag(row) : null;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get tag by name: $name',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// The tag occupying [name]'s uniqueness slot in [diverId]'s scope, if any.
  ///
  /// Mirrors `idx_tags_diver_name_unique` exactly -- (COALESCE(diver_id, ''),
  /// lower(trim(name))) -- so a caller that checks here can never be surprised by
  /// the index. A NULL `diverId` is the shared "unassigned" scope, not a scope
  /// of its own per row.
  Future<domain.Tag?> _tagOccupying(String name, String? diverId) async {
    final rows =
        await (_db.select(_db.tags)
              ..where(
                (t) =>
                    t.name.trim().lower().equals(name.trim().toLowerCase()) &
                    coalesce([
                      t.diverId,
                      const Constant(''),
                    ]).equals(diverId ?? ''),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.id)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : _mapRowToTag(rows.first);
  }

  /// Create a new tag, or return the one already holding the name.
  ///
  /// `tags` is uniquely indexed on (diver scope, case-folded name) since v149,
  /// so inserting a second row for a name the scope already has would throw.
  /// Returning the incumbent keeps every caller's contract ("a tag with this
  /// name now exists and here it is") while never creating the duplicate that
  /// made a dive show one tag twice (#1032).
  ///
  /// When the incumbent lacks a scope the new tag asks for (a site tag named
  /// like an existing dive tag), the incumbent is widened rather than a second
  /// tag minted: the name index allows only one, and the diver meant the same
  /// tag in both places (issue #1765).
  Future<domain.Tag> createTag(domain.Tag tag) async {
    try {
      _requireScope(tag);
      final incumbent = await _tagOccupying(tag.name, tag.diverId);
      if (incumbent != null) {
        _log.info('Tag "${tag.name}" already exists as ${incumbent.id}');
        return await _widenTo(incumbent, tag);
      }

      // Store the SAME normalization the index and every lookup key on.
      // Persisting the raw value while matching on a trimmed one is what let
      // " Wreck" and "Wreck" coexist as two rows (PR #1033 review).
      final name = tag.name.trim();
      _log.info('Creating tag: $name');
      final id = tag.id.isEmpty ? _uuid.v4() : tag.id;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Conflict-aware rather than a bare insert. The incumbent check above is
      // an `await`, so two callers can both pass it and the loser would then
      // throw on idx_tags_diver_name_unique -- failing an operation whose whole
      // contract is "a tag with this name now exists" (PR #1033 review). A null
      // return means someone won the race; fall back to reading their row,
      // which is the same answer the incumbent check would have given.
      final created = await _db
          .into(_db.tags)
          .insertReturningOrNull(
            TagsCompanion(
              id: Value(id),
              diverId: Value(tag.diverId),
              name: Value(name),
              color: Value(tag.colorHex),
              createdAt: Value(now),
              updatedAt: Value(now),
              appliesToDives: Value(tag.appliesToDives),
              appliesToSites: Value(tag.appliesToSites),
            ),
            onConflict: DoNothing<$TagsTable, Tag>(target: const []),
          );
      if (created == null) {
        final winner = await _tagOccupying(name, tag.diverId);
        _log.info('Tag "$name" was created concurrently as ${winner?.id}');
        if (winner != null) return await _widenTo(winner, tag);
        // Vanishingly unlikely: the conflicting row was deleted between the
        // insert and this read. Surfacing it beats returning a tag id that
        // does not exist.
        throw StateError('Tag "$name" conflicted but could not be read back');
      }

      await _syncRepository.markRecordPending(
        entityType: 'tags',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Created tag with id: $id');
      return tag.copyWith(id: id, name: name);
    } catch (e, stackTrace) {
      _log.error('Failed to create tag', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Create a tag or get existing if name already exists. The tag comes back
  /// offered in [scope]: an existing tag lacking it is widened (issue #1765).
  Future<domain.Tag> getOrCreateTag(
    String name, {
    String? colorHex,
    String? diverId,
    domain.TagScope scope = domain.TagScope.dives,
  }) async {
    try {
      // Check if tag with this name exists for this diver
      final existing = await getTagByName(name, diverId: diverId);
      if (existing != null) {
        return await _widen(existing, scope);
      }

      // Create new tag
      return await createTag(
        domain.Tag.create(
          id: _uuid.v4(),
          diverId: diverId,
          name: name.trim(),
          colorHex: colorHex,
          scope: scope,
        ),
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get or create tag: $name',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update an existing tag.
  ///
  /// Renaming onto a name the scope already uses folds the two tags together
  /// rather than throwing on `idx_tags_diver_name_unique`: the user asked for
  /// one tag by that name, and every dive on either side keeps it. This is the
  /// same outcome the tag merge sheet produces, so it reuses [mergeTags].
  ///
  /// Scope (issue #1765): turning off dives or sites for a tag also removes
  /// it from every dive or site that carries it, each link tombstoned, so a
  /// link always implies its scope. The UI confirms before doing that.
  Future<void> updateTag(domain.Tag tag) async {
    try {
      _requireScope(tag);
      // Normalized before both the uniqueness check and the write, so a rename
      // cannot store a spelling the index would key differently.
      final name = tag.name.trim();
      final incumbent = await _tagOccupying(name, tag.diverId);
      if (incumbent != null && incumbent.id != tag.id) {
        _log.info(
          'Renaming ${tag.id} onto "$name" merges into ${incumbent.id}',
        );
        await mergeTags(
          sourceTagIds: [tag.id],
          survivingTagId: incumbent.id,
          name: name,
          colorHex: tag.colorHex,
        );
        return;
      }

      _log.info('Updating tag: ${tag.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        final stored = await getTagById(tag.id);
        await (_db.update(_db.tags)..where((t) => t.id.equals(tag.id))).write(
          TagsCompanion(
            name: Value(name),
            color: Value(tag.colorHex),
            updatedAt: Value(now),
            appliesToDives: Value(tag.appliesToDives),
            appliesToSites: Value(tag.appliesToSites),
          ),
        );
        await _syncRepository.markRecordPending(
          entityType: 'tags',
          recordId: tag.id,
          localUpdatedAt: now,
        );
        if (stored != null && stored.appliesToSites && !tag.appliesToSites) {
          await _unlinkEverySite(tag.id);
        }
        if (stored != null && stored.appliesToDives && !tag.appliesToDives) {
          await _unlinkEveryDive(tag.id);
        }
      });
      SyncEventBus.notifyLocalChange();
      _log.info('Updated tag: ${tag.id}');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update tag: ${tag.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // Scope (issue #1765)
  // ============================================================================

  void _requireScope(domain.Tag tag) {
    if (!tag.appliesToDives && !tag.appliesToSites) {
      throw ArgumentError('A tag must apply to dives, sites, or both');
    }
  }

  /// [tag] widened to also cover every scope [wanted] has.
  Future<domain.Tag> _widenTo(domain.Tag tag, domain.Tag wanted) async {
    var result = tag;
    if (wanted.appliesToDives) {
      result = await _widen(result, domain.TagScope.dives);
    }
    if (wanted.appliesToSites) {
      result = await _widen(result, domain.TagScope.sites);
    }
    return result;
  }

  /// Adds [scope] to [tag] if it lacks it, returning the stored result.
  Future<domain.Tag> _widen(domain.Tag tag, domain.TagScope scope) async {
    if (tag.appliesTo(scope)) return tag;
    final widened = tag.copyWith(
      appliesToDives: tag.appliesToDives || scope == domain.TagScope.dives,
      appliesToSites: tag.appliesToSites || scope == domain.TagScope.sites,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.tags)..where((t) => t.id.equals(tag.id))).write(
      TagsCompanion(
        appliesToDives: Value(widened.appliesToDives),
        appliesToSites: Value(widened.appliesToSites),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'tags',
      recordId: tag.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    _log.info('Widened tag ${tag.id} to ${scope.name}');
    return widened;
  }

  /// Removes [tagId] from every site, tombstoning each link. Sites are not
  /// re-stamped: the links are clockless children (#1769).
  Future<void> _unlinkEverySite(String tagId) async {
    final links = await (_db.select(
      _db.siteTags,
    )..where((t) => t.tagId.equals(tagId))).get();
    for (final link in links) {
      await (_db.delete(_db.siteTags)..where((t) => t.id.equals(link.id))).go();
      await _syncRepository.logDeletion(
        entityType: 'siteTags',
        recordId: link.id,
      );
    }
  }

  /// Removes [tagId] from every dive, tombstoning each link.
  Future<void> _unlinkEveryDive(String tagId) async {
    final links = await (_db.select(
      _db.diveTags,
    )..where((t) => t.tagId.equals(tagId))).get();
    for (final link in links) {
      await (_db.delete(_db.diveTags)..where((t) => t.id.equals(link.id))).go();
      await _syncRepository.logDeletion(
        entityType: 'diveTags',
        recordId: link.id,
      );
    }
  }

  /// How many dives and sites carry [tagId]; the scope editor confirms with
  /// these before narrowing a tag.
  Future<({int dives, int sites})> getTagUsage(String tagId) async {
    final row = await _db
        .customSelect(
          // stats-scope-exempt: usage indicator for the scope editor. Must see
          // every dive carrying the tag, excluded ones included.
          'SELECT '
          '(SELECT COUNT(*) FROM dive_tags WHERE tag_id = ?) AS dives, '
          '(SELECT COUNT(*) FROM site_tags WHERE tag_id = ?) AS sites',
          variables: [Variable.withString(tagId), Variable.withString(tagId)],
        )
        .getSingle();
    return (dives: row.read<int>('dives'), sites: row.read<int>('sites'));
  }

  /// Delete a tag
  Future<void> deleteTag(String id) async {
    try {
      _log.info('Deleting tag: $id');
      await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: 'tags', recordId: id);
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted tag: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to delete tag: $id', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // Dive-Tag Associations
  // ============================================================================

  /// Get tags for a specific dive
  Future<List<domain.Tag>> getTagsForDive(String diveId) async {
    try {
      // DISTINCT so a legacy database that has not yet been through the v149
      // collapse still renders each tag once (#1032).
      final result = await _db
          .customSelect(
            '''
        SELECT DISTINCT t.* FROM tags t
        INNER JOIN dive_tags dt ON t.id = dt.tag_id
        WHERE dt.dive_id = ?
        ORDER BY t.name
      ''',
            variables: [Variable.withString(diveId)],
          )
          .get();

      return result.map((row) => mapTagRow(_db.tags.map(row.data))).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get tags for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get tags for multiple dives (batch loading)
  Future<Map<String, List<domain.Tag>>> getTagsForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return {};

    try {
      final placeholders = diveIds.map((_) => '?').join(',');
      final result = await _db.customSelect(
        '''
        SELECT DISTINCT dt.dive_id, t.* FROM tags t
        INNER JOIN dive_tags dt ON t.id = dt.tag_id
        WHERE dt.dive_id IN ($placeholders)
        ORDER BY t.name
      ''',
        variables: diveIds.map((id) => Variable.withString(id)).toList(),
      ).get();

      final tagsByDive = <String, List<domain.Tag>>{};
      for (final row in result) {
        final diveId = row.data['dive_id'] as String;
        final tag = mapTagRow(_db.tags.map(row.data));
        tagsByDive.putIfAbsent(diveId, () => []).add(tag);
      }
      return tagsByDive;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get tags for dives',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Set tags for a dive (replaces existing tags)
  Future<void> setTagsForDive(String diveId, List<domain.Tag> tags) async {
    try {
      _log.info('Setting ${tags.length} tags for dive: $diveId');

      final existingDiveTags = await (_db.select(
        _db.diveTags,
      )..where((t) => t.diveId.equals(diveId))).get();

      // Delete existing tags for this dive
      await (_db.delete(
        _db.diveTags,
      )..where((t) => t.diveId.equals(diveId))).go();
      for (final diveTag in existingDiveTags) {
        await _syncRepository.logDeletion(
          entityType: 'diveTags',
          recordId: diveTag.id,
        );
      }

      // Insert new tags. Deduplicated by id: `dive_tags` is uniquely indexed
      // on (dive_id, tag_id) since v149, so the same tag listed twice would
      // throw rather than quietly double up.
      final now = DateTime.now().millisecondsSinceEpoch;
      final seen = <String>{};
      for (final tag in tags) {
        if (!seen.add(tag.id)) continue;
        final id = _uuid.v4();
        await _db
            .into(_db.diveTags)
            .insert(
              DiveTagsCompanion(
                id: Value(id),
                diveId: Value(diveId),
                tagId: Value(tag.id),
                createdAt: Value(now),
              ),
            );
        await _syncRepository.markRecordPending(
          entityType: 'diveTags',
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

      _log.info('Set ${tags.length} tags for dive: $diveId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set tags for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Add a tag to a dive.
  ///
  /// A no-op when the dive already carries the tag. Re-running an import used
  /// to blind-insert a second junction row under a fresh uuid, which is how
  /// one dive ended up showing the same import tag several times (#1032).
  Future<void> addTagToDive(String diveId, String tagId) async {
    try {
      _log.info('Adding tag $tagId to dive: $diveId');
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = _uuid.v4();

      // One statement rather than read-then-insert. A separate existence check
      // is both an extra round trip and still racy: two callers can each see
      // "missing" and the loser then throws on idx_dive_tags_dive_tag_unique.
      // Letting the database decide makes the duplicate a true no-op, and a
      // null return says the pair was already there (PR #1033 review).
      final inserted = await _db
          .into(_db.diveTags)
          .insertReturningOrNull(
            DiveTagsCompanion(
              id: Value(id),
              diveId: Value(diveId),
              tagId: Value(tagId),
              createdAt: Value(now),
            ),
            onConflict: DoNothing<$DiveTagsTable, DiveTag>(target: const []),
          );
      if (inserted == null) {
        _log.info('Dive $diveId already carries tag $tagId');
        return;
      }

      await _syncRepository.markRecordPending(
        entityType: 'diveTags',
        recordId: id,
        localUpdatedAt: now,
      );
      await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
        DivesCompanion(updatedAt: Value(now)),
      );
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Added tag $tagId to dive: $diveId');
    } catch (e, stackTrace) {
      _log.error('Failed to add tag to dive', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Remove a tag from a dive
  Future<void> removeTagFromDive(String diveId, String tagId) async {
    try {
      _log.info('Removing tag $tagId from dive: $diveId');
      final existing = await (_db.select(
        _db.diveTags,
      )..where((t) => t.diveId.equals(diveId) & t.tagId.equals(tagId))).get();
      await (_db.delete(
        _db.diveTags,
      )..where((t) => t.diveId.equals(diveId) & t.tagId.equals(tagId))).go();
      for (final row in existing) {
        await _syncRepository.logDeletion(
          entityType: 'diveTags',
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

      _log.info('Removed tag $tagId from dive: $diveId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to remove tag from dive',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // Statistics
  // ============================================================================

  /// Get tag statistics (usage counts)
  Future<List<TagStatistic>> getTagStatistics({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'WHERE t.diver_id = ?' : '';
      final variables = diverId != null
          ? [Variable.withString(diverId)]
          : <Variable<Object>>[];

      // Dive count first: the dive tag picker lists "tags you use most" in
      // exactly this order. Site counts (issue #1765) only break ties.
      // stats-scope-exempt: usage counts for managing tags, not a
      // statistic. A planned or stats-excluded dive still carries the tag.
      final result = await _db.customSelect('''
        SELECT t.*,
          (SELECT COUNT(*) FROM dive_tags dt WHERE dt.tag_id = t.id)
            AS dive_count,
          (SELECT COUNT(*) FROM site_tags st WHERE st.tag_id = t.id)
            AS site_count
        FROM tags t
        $diverFilter
        ORDER BY dive_count DESC, site_count DESC, t.name
      ''', variables: variables).get();

      return result
          .map(
            (row) => TagStatistic(
              tag: mapTagRow(_db.tags.map(row.data)),
              diveCount: row.data['dive_count'] as int,
              siteCount: row.data['site_count'] as int,
            ),
          )
          .toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get tag statistics',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get the number of dives using a specific tag
  Future<int> getTagUsageCount(String tagId) async {
    try {
      final result = await _db
          .customSelect(
            // stats-scope-exempt: usage/deletion indicator. Must see every
            // dive carrying the tag, excluded ones included, or removing the
            // tag would strand a reference.
            'SELECT COUNT(*) as count FROM dive_tags WHERE tag_id = ?',
            variables: [Variable.withString(tagId)],
          )
          .getSingle();
      return result.data['count'] as int;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get tag usage count: $tagId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get combined dive count for multiple tags (union, not sum)
  Future<int> getMergedDiveCount(List<String> tagIds) async {
    if (tagIds.isEmpty) return 0;
    try {
      final placeholders = tagIds.map((_) => '?').join(',');
      final result = await _db
          .customSelect(
            // stats-scope-exempt: merge preview. Tells the diver how many
            // dives the merge will rewrite, which is every one of them.
            'SELECT COUNT(DISTINCT dive_id) as count FROM dive_tags WHERE tag_id IN ($placeholders)',
            variables: tagIds.map((id) => Variable.withString(id)).toList(),
          )
          .getSingle();
      return result.data['count'] as int;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get merged dive count',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Search tags by name (for autocomplete)
  Future<List<domain.Tag>> searchTags(String query, {String? diverId}) async {
    try {
      if (query.isEmpty) return await getAllTags(diverId: diverId);

      final searchQuery = _db.select(_db.tags)
        ..where((t) => t.name.lower().contains(query.toLowerCase()))
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);

      if (diverId != null) {
        searchQuery.where((t) => t.diverId.equals(diverId));
      }

      final rows = await searchQuery.get();
      return rows.map(_mapRowToTag).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to search tags: $query',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // Merge
  // ============================================================================

  /// Merge multiple tags into one surviving tag.
  ///
  /// [sourceTagIds] are the tags to merge away (will be deleted).
  /// [survivingTagId] is the tag that remains, updated with [name] and [colorHex].
  /// All dive associations from source tags move to the surviving tag.
  /// Duplicate associations (dive already has surviving tag) are removed.
  Future<void> mergeTags({
    required List<String> sourceTagIds,
    required String survivingTagId,
    required String name,
    required String? colorHex,
  }) async {
    // Input validation
    if (sourceTagIds.contains(survivingTagId)) {
      throw ArgumentError(
        'survivingTagId ($survivingTagId) must not appear in sourceTagIds',
      );
    }
    if (sourceTagIds.isEmpty) return;

    try {
      _log.info('Merging ${sourceTagIds.length} tags into $survivingTagId');
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        // Pre-fetch all diveIds that already have the surviving tag
        final existingSurvivingDiveIds =
            (await (_db.select(
                  _db.diveTags,
                )..where((t) => t.tagId.equals(survivingTagId))).get())
                .map((dt) => dt.diveId)
                .toSet();

        // Sites that already carry the surviving tag (issue #1765)
        final existingSurvivingSiteIds =
            (await (_db.select(
                  _db.siteTags,
                )..where((t) => t.tagId.equals(survivingTagId))).get())
                .map((st) => st.siteId)
                .toSet();

        // The survivor keeps every use the merged tags had (issue #1765).
        final mergedRows = await (_db.select(
          _db.tags,
        )..where((t) => t.id.isIn([survivingTagId, ...sourceTagIds]))).get();
        final anyDives = mergedRows.any((r) => r.appliesToDives);
        final anySites = mergedRows.any((r) => r.appliesToSites);

        // Collect all affected diveIds to batch-update updatedAt once
        final affectedDiveIds = <String>{};
        // Update surviving tag name, color and scope
        await (_db.update(
          _db.tags,
        )..where((t) => t.id.equals(survivingTagId))).write(
          TagsCompanion(
            name: Value(name),
            color: Value(colorHex),
            updatedAt: Value(now),
            appliesToDives: Value(anyDives || !anySites),
            appliesToSites: Value(anySites),
          ),
        );
        await _syncRepository.markRecordPending(
          entityType: 'tags',
          recordId: survivingTagId,
          localUpdatedAt: now,
        );

        for (final sourceId in sourceTagIds) {
          // Get all dive associations for this source tag
          final sourceDiveTags = await (_db.select(
            _db.diveTags,
          )..where((t) => t.tagId.equals(sourceId))).get();

          for (final diveTag in sourceDiveTags) {
            if (!existingSurvivingDiveIds.contains(diveTag.diveId)) {
              // Move association to surviving tag
              final newId = _uuid.v4();
              await _db
                  .into(_db.diveTags)
                  .insert(
                    DiveTagsCompanion(
                      id: Value(newId),
                      diveId: Value(diveTag.diveId),
                      tagId: Value(survivingTagId),
                      createdAt: Value(now),
                    ),
                  );
              await _syncRepository.markRecordPending(
                entityType: 'diveTags',
                recordId: newId,
                localUpdatedAt: now,
              );
              // Track so subsequent source tags see this dive as covered
              existingSurvivingDiveIds.add(diveTag.diveId);
            }

            // Delete explicitly (not relying on CASCADE) so sync tracks
            // each deletion
            await (_db.delete(
              _db.diveTags,
            )..where((t) => t.id.equals(diveTag.id))).go();
            await _syncRepository.logDeletion(
              entityType: 'diveTags',
              recordId: diveTag.id,
            );

            affectedDiveIds.add(diveTag.diveId);
          }

          // Site associations follow the same way (issue #1765). Sites are
          // not re-stamped: the links are clockless children (#1769).
          final sourceSiteTags = await (_db.select(
            _db.siteTags,
          )..where((t) => t.tagId.equals(sourceId))).get();
          for (final siteTag in sourceSiteTags) {
            if (!existingSurvivingSiteIds.contains(siteTag.siteId)) {
              final newId = _uuid.v4();
              await _db
                  .into(_db.siteTags)
                  .insert(
                    SiteTagsCompanion(
                      id: Value(newId),
                      siteId: Value(siteTag.siteId),
                      tagId: Value(survivingTagId),
                      createdAt: Value(now),
                    ),
                  );
              await _syncRepository.markRecordPending(
                entityType: 'siteTags',
                recordId: newId,
                localUpdatedAt: now,
              );
              existingSurvivingSiteIds.add(siteTag.siteId);
            }
            await (_db.delete(
              _db.siteTags,
            )..where((t) => t.id.equals(siteTag.id))).go();
            await _syncRepository.logDeletion(
              entityType: 'siteTags',
              recordId: siteTag.id,
            );
          }

          // Delete the source tag (inlined to avoid SyncEventBus inside txn)
          await (_db.delete(
            _db.tags,
          )..where((t) => t.id.equals(sourceId))).go();
          await _syncRepository.logDeletion(
            entityType: 'tags',
            recordId: sourceId,
          );
        }

        // Batch-update updatedAt for all affected dives
        for (final diveId in affectedDiveIds) {
          await (_db.update(_db.dives)..where((t) => t.id.equals(diveId)))
              .write(DivesCompanion(updatedAt: Value(now)));
          await _syncRepository.markRecordPending(
            entityType: 'dives',
            recordId: diveId,
            localUpdatedAt: now,
          );
        }
      });

      SyncEventBus.notifyLocalChange();
      _log.info('Merged ${sourceTagIds.length} tags into $survivingTagId');
    } catch (e, stackTrace) {
      _log.error('Failed to merge tags', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // Mapping Helpers
  // ============================================================================

  domain.Tag _mapRowToTag(Tag row) => mapTagRow(row);
}

/// Tag usage statistics
class TagStatistic {
  final domain.Tag tag;
  final int diveCount;

  /// Sites carrying the tag (issue #1765).
  final int siteCount;

  TagStatistic({
    required this.tag,
    required this.diveCount,
    this.siteCount = 0,
  });
}
