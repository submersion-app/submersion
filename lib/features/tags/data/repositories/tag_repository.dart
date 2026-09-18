import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/tag_scope_tables.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/text/text_sort.dart';
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

  /// Emits when any tag link changes, on every junction in the tag scope
  /// registry, since each moves a count in [getTagStatistics] (#1765, #1942).
  Stream<void> watchTagLinkChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([
      for (final junction in tagScopeTables) _table(junction.junctionTable),
    ]),
  );

  /// Get all tags, ordered by name. [scope] limits the list to tags offered
  /// in that scope (issues #1765, #1942); null returns every tag.
  Future<List<domain.Tag>> getAllTags({
    String? diverId,
    domain.TagScope? scope,
  }) async {
    try {
      final query = _db.select(_db.tags)
        ..orderBy([(t) => OrderingTerm.asc(t.name.collate(Collate.noCase))]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }
      if (scope != null) {
        final column = scope.table.scopeColumn;
        query.where(
          (t) =>
              (t.columnsByName[column]! as GeneratedColumn<bool>).equals(true),
        );
      }

      final rows = await query.get();
      return sortedByText(rows, (r) => r.name).map(_mapRowToTag).toList();
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
            RawValuesInsertable<Tag>({
              ...TagsCompanion(
                id: Value(id),
                diverId: Value(tag.diverId),
                name: Value(name),
                color: Value(tag.colorHex),
                createdAt: Value(now),
                updatedAt: Value(now),
              ).toColumns(false),
              ...tagScopeColumns(tag.scopes),
            }),
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
  /// Scope (issues #1765, #1942): turning off a scope for a tag also removes
  /// it from every item of that scope carrying it, each link tombstoned, so a
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
          RawValuesInsertable<Tag>({
            ...TagsCompanion(
              name: Value(name),
              color: Value(tag.colorHex),
              updatedAt: Value(now),
            ).toColumns(false),
            ...tagScopeColumns(tag.scopes),
          }),
        );
        await _syncRepository.markRecordPending(
          entityType: 'tags',
          recordId: tag.id,
          localUpdatedAt: now,
        );
        if (stored != null) {
          for (final scope in domain.TagScope.values) {
            if (stored.appliesTo(scope) && !tag.appliesTo(scope)) {
              await _unlinkAll(scope.table, tag.id);
            }
          }
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
  // Scope (issues #1765, #1942)
  // ============================================================================

  void _requireScope(domain.Tag tag) {
    if (tag.scopes.isEmpty) {
      throw ArgumentError(
        'A tag must apply to at least one of: '
        '${domain.TagScope.values.map((s) => s.name).join(', ')}',
      );
    }
  }

  /// [tag] widened to also cover every scope [wanted] has.
  Future<domain.Tag> _widenTo(domain.Tag tag, domain.Tag wanted) async {
    var result = tag;
    for (final scope in domain.TagScope.values) {
      if (wanted.appliesTo(scope)) result = await _widen(result, scope);
    }
    return result;
  }

  /// Adds [scope] to [tag] if it lacks it, returning the stored result.
  Future<domain.Tag> _widen(domain.Tag tag, domain.TagScope scope) async {
    if (tag.appliesTo(scope)) return tag;
    final widened = tag.copyWith(scopes: {...tag.scopes, scope});
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.tags)..where((t) => t.id.equals(tag.id))).write(
      RawValuesInsertable<Tag>({
        ...tagScopeColumns(widened.scopes),
        ...TagsCompanion(updatedAt: Value(now)).toColumns(false),
      }),
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

  /// The Drift table called [name], so a registry-driven write tells Drift
  /// what it touched and stream queries over that table refresh.
  TableInfo<Table, dynamic> _table(String name) =>
      _db.allTables.firstWhere((t) => t.actualTableName == name);

  /// Every link of [tagId] in [junction], as (link id, linked item id).
  Future<List<({String id, String parentId})>> _linksOf(
    TagScopeTable junction,
    String tagId,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT id, ${junction.parentColumn} AS parent_id '
          'FROM ${junction.junctionTable} WHERE tag_id = ?',
          variables: [Variable.withString(tagId)],
        )
        .get();
    return [
      for (final row in rows)
        (id: row.read<String>('id'), parentId: row.read<String>('parent_id')),
    ];
  }

  /// Removes [tagId] from every item in [junction], tombstoning each link.
  /// No parent is re-stamped, dives included: narrowing never did, and site
  /// links are clockless children (#1769).
  Future<void> _unlinkAll(TagScopeTable junction, String tagId) async {
    final links = await _linksOf(junction, tagId);
    if (links.isEmpty) return;
    await _db.customUpdate(
      'DELETE FROM ${junction.junctionTable} WHERE tag_id = ?',
      variables: [Variable.withString(tagId)],
      updates: {_table(junction.junctionTable)},
      updateKind: UpdateKind.delete,
    );
    for (final link in links) {
      await _syncRepository.logDeletion(
        entityType: junction.syncEntity,
        recordId: link.id,
      );
    }
  }

  /// How many items of each scope carry [tagId]; the scope editor confirms
  /// with these before narrowing a tag. Every registry scope has an entry.
  Future<Map<domain.TagScope, int>> getTagUsage(String tagId) async {
    final counts = [
      for (final scope in domain.TagScope.values)
        '(SELECT COUNT(*) FROM ${scope.table.junctionTable} '
            'WHERE tag_id = ?1) AS ${scope.name}',
    ];
    final row = await _db
        .customSelect(
          // stats-scope-exempt: usage indicator for the scope editor. Must see
          // every dive carrying the tag, excluded ones included.
          'SELECT ${counts.join(', ')}',
          variables: [Variable.withString(tagId)],
        )
        .getSingle();
    return {
      for (final scope in domain.TagScope.values)
        scope: row.read<int>(scope.name),
    };
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
        ORDER BY t.name COLLATE NOCASE
      ''',
            variables: [Variable.withString(diveId)],
          )
          .get();

      return sortedByText(
        result,
        (r) => r.data['name'] as String,
      ).map((row) => mapTagRow(_db.tags.map(row.data))).toList();
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
        ORDER BY t.name COLLATE NOCASE
      ''',
        variables: diveIds.map((id) => Variable.withString(id)).toList(),
      ).get();

      final tagsByDive = <String, List<domain.Tag>>{};
      for (final row in sortedByText(result, (r) => r.data['name'] as String)) {
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

  /// Get tag statistics (usage counts per scope)
  Future<List<TagStatistic>> getTagStatistics({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'WHERE t.diver_id = ?' : '';
      final variables = diverId != null
          ? [Variable.withString(diverId)]
          : <Variable<Object>>[];
      const scopes = domain.TagScope.values;
      final countColumns = [
        for (final scope in scopes)
          '(SELECT COUNT(*) FROM ${scope.table.junctionTable} j '
              'WHERE j.tag_id = t.id) AS ${scope.name}_count',
      ];
      // Registry order, so the dive count comes first: the dive tag picker
      // lists "tags you use most" in exactly this order, and each later
      // scope's count only breaks ties (#1765, #1942).
      final order = [for (final scope in scopes) '${scope.name}_count DESC'];

      // stats-scope-exempt: usage counts for managing tags, not a
      // statistic. A planned or stats-excluded dive still carries the tag.
      final result = await _db.customSelect('''
        SELECT t.*, ${countColumns.join(', ')}
        FROM tags t
        $diverFilter
        ORDER BY ${order.join(', ')}, t.name
      ''', variables: variables).get();

      return result
          .map(
            (row) => TagStatistic(
              tag: mapTagRow(_db.tags.map(row.data)),
              counts: {
                for (final scope in scopes)
                  scope: row.read<int>('${scope.name}_count'),
              },
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

  /// How many distinct items of each scope carry any of [tagIds] (union, not
  /// sum): an item carrying two of them counts once. Previews what a bulk
  /// delete or a merge rewrites (#1902). Every registry scope has an entry.
  Future<Map<domain.TagScope, int>> getMergedUsage(List<String> tagIds) async {
    if (tagIds.isEmpty) {
      return {for (final scope in domain.TagScope.values) scope: 0};
    }
    try {
      final rows = tagIds.map((_) => '(?)').join(', ');
      final counts = [
        for (final scope in domain.TagScope.values)
          '(SELECT COUNT(DISTINCT ${scope.table.parentColumn}) '
              'FROM ${scope.table.junctionTable} '
              'WHERE tag_id IN (SELECT tag_id FROM selected)) '
              'AS ${scope.name}',
      ];
      final row = await _db
          .customSelect(
            // stats-scope-exempt: delete and merge preview. Tells the diver
            // how many items the change rewrites, which is every one of
            // them. The ids bind once, in the CTE, and every count reads
            // from it: binding them per count would divide the selection
            // SQLite's bound-variable limit allows. Chunking would not do,
            // since a union count cannot be summed across chunks.
            'WITH selected(tag_id) AS (VALUES $rows) '
            'SELECT ${counts.join(', ')}',
            variables: tagIds.map((id) => Variable.withString(id)).toList(),
          )
          .getSingle();
      return {
        for (final scope in domain.TagScope.values)
          scope: row.read<int>(scope.name),
      };
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get merged tag usage',
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
        ..orderBy([(t) => OrderingTerm.asc(t.name.collate(Collate.noCase))]);

      if (diverId != null) {
        searchQuery.where((t) => t.diverId.equals(diverId));
      }

      final rows = await searchQuery.get();
      return sortedByText(rows, (r) => r.name).map(_mapRowToTag).toList();
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
  /// Every link of a source tag, in every junction of the tag scope registry,
  /// moves to the surviving tag. A link whose item already has the surviving
  /// tag is removed.
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
        // Items that already carry the surviving tag, per junction.
        final covered = <TagScopeTable, Set<String>>{};
        for (final junction in tagScopeTables) {
          covered[junction] = {
            for (final link in await _linksOf(junction, survivingTagId))
              link.parentId,
          };
        }

        // The survivor keeps every use the merged tags had (issue #1765). A
        // merge of rows that carry no scope at all stays a dive tag.
        final mergedRows = await (_db.select(
          _db.tags,
        )..where((t) => t.id.isIn([survivingTagId, ...sourceTagIds]))).get();
        final union = {for (final row in mergedRows) ...tagScopesOf(row)};
        await (_db.update(
          _db.tags,
        )..where((t) => t.id.equals(survivingTagId))).write(
          RawValuesInsertable<Tag>({
            ...TagsCompanion(
              name: Value(name),
              color: Value(colorHex),
              updatedAt: Value(now),
            ).toColumns(false),
            ...tagScopeColumns(
              union.isEmpty ? const {domain.TagScope.dives} : union,
            ),
          }),
        );
        await _syncRepository.markRecordPending(
          entityType: 'tags',
          recordId: survivingTagId,
          localUpdatedAt: now,
        );

        // Parents to re-stamp once at the end, by table: a dive link
        // re-stamps its dive; site links are clockless children (#1769).
        final restamp = <String, Set<String>>{};
        for (final sourceId in sourceTagIds) {
          for (final junction in tagScopeTables) {
            final updates = {_table(junction.junctionTable)};
            final carried = covered[junction]!;
            for (final link in await _linksOf(junction, sourceId)) {
              if (carried.add(link.parentId)) {
                // Move the link to the surviving tag.
                final newId = _uuid.v4();
                await _db.customInsert(
                  'INSERT INTO ${junction.junctionTable} '
                  '(id, ${junction.parentColumn}, tag_id, created_at) '
                  'VALUES (?, ?, ?, ?)',
                  variables: [
                    Variable.withString(newId),
                    Variable.withString(link.parentId),
                    Variable.withString(survivingTagId),
                    Variable.withInt(now),
                  ],
                  updates: updates,
                );
                await _syncRepository.markRecordPending(
                  entityType: junction.syncEntity,
                  recordId: newId,
                  localUpdatedAt: now,
                );
              }
              // Deleted explicitly (not by CASCADE) so sync tracks each one.
              await _db.customUpdate(
                'DELETE FROM ${junction.junctionTable} WHERE id = ?',
                variables: [Variable.withString(link.id)],
                updates: updates,
                updateKind: UpdateKind.delete,
              );
              await _syncRepository.logDeletion(
                entityType: junction.syncEntity,
                recordId: link.id,
              );
              final parentTable = junction.restampedParentTable;
              if (parentTable != null) {
                restamp
                    .putIfAbsent(parentTable, () => <String>{})
                    .add(link.parentId);
              }
            }
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

        for (final entry in restamp.entries) {
          for (final parentId in entry.value) {
            await _db.customUpdate(
              'UPDATE ${entry.key} SET updated_at = ? WHERE id = ?',
              variables: [Variable.withInt(now), Variable.withString(parentId)],
              updates: {_table(entry.key)},
              updateKind: UpdateKind.update,
            );
            // The table name doubles as its sync entity type (see
            // TagScopeTable.restampedParentTable).
            await _syncRepository.markRecordPending(
              entityType: entry.key,
              recordId: parentId,
              localUpdatedAt: now,
            );
          }
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

  /// Items carrying the tag, per scope (issues #1765, #1942). The repository
  /// fills every scope; a hand-built statistic may leave some out.
  final Map<domain.TagScope, int> counts;

  TagStatistic({required this.tag, this.counts = const {}});

  /// How many items of [scope] carry the tag; 0 when [counts] lacks it.
  int count(domain.TagScope scope) => counts[scope] ?? 0;
}
