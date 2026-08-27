import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
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

  /// Get all tags, ordered by name
  Future<List<domain.Tag>> getAllTags({String? diverId}) async {
    try {
      final query = _db.select(_db.tags)
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
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
  Future<domain.Tag> createTag(domain.Tag tag) async {
    try {
      final incumbent = await _tagOccupying(tag.name, tag.diverId);
      if (incumbent != null) {
        _log.info('Tag "${tag.name}" already exists as ${incumbent.id}');
        return incumbent;
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
            ),
            onConflict: DoNothing<$TagsTable, Tag>(target: const []),
          );
      if (created == null) {
        final winner = await _tagOccupying(name, tag.diverId);
        _log.info('Tag "$name" was created concurrently as ${winner?.id}');
        if (winner != null) return winner;
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

  /// Create a tag or get existing if name already exists
  Future<domain.Tag> getOrCreateTag(
    String name, {
    String? colorHex,
    String? diverId,
  }) async {
    try {
      // Check if tag with this name exists for this diver
      final existing = await getTagByName(name, diverId: diverId);
      if (existing != null) {
        return existing;
      }

      // Create new tag
      final now = DateTime.now();
      return await createTag(
        domain.Tag(
          id: _uuid.v4(),
          diverId: diverId,
          name: name.trim(),
          colorHex: colorHex,
          createdAt: now,
          updatedAt: now,
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
  Future<void> updateTag(domain.Tag tag) async {
    try {
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

      await (_db.update(_db.tags)..where((t) => t.id.equals(tag.id))).write(
        TagsCompanion(
          name: Value(name),
          color: Value(tag.colorHex),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'tags',
        recordId: tag.id,
        localUpdatedAt: now,
      );
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

      return result
          .map(
            (row) => domain.Tag(
              id: row.data['id'] as String,
              name: row.data['name'] as String,
              colorHex: row.data['color'] as String?,
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                row.data['created_at'] as int,
              ),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(
                row.data['updated_at'] as int,
              ),
            ),
          )
          .toList();
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
        final tag = domain.Tag(
          id: row.data['id'] as String,
          name: row.data['name'] as String,
          colorHex: row.data['color'] as String?,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row.data['created_at'] as int,
          ),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            row.data['updated_at'] as int,
          ),
        );
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

      final result = await _db.customSelect('''
        SELECT t.*, COUNT(dt.dive_id) as dive_count
        FROM tags t
        LEFT JOIN dive_tags dt ON t.id = dt.tag_id
        $diverFilter
        GROUP BY t.id
        ORDER BY dive_count DESC, t.name
      ''', variables: variables).get();

      return result
          .map(
            (row) => TagStatistic(
              tag: domain.Tag(
                id: row.data['id'] as String,
                diverId: row.data['diver_id'] as String?,
                name: row.data['name'] as String,
                colorHex: row.data['color'] as String?,
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                  row.data['created_at'] as int,
                ),
                updatedAt: DateTime.fromMillisecondsSinceEpoch(
                  row.data['updated_at'] as int,
                ),
              ),
              diveCount: row.data['dive_count'] as int,
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

        // Collect all affected diveIds to batch-update updatedAt once
        final affectedDiveIds = <String>{};
        // Update surviving tag name and color
        await (_db.update(
          _db.tags,
        )..where((t) => t.id.equals(survivingTagId))).write(
          TagsCompanion(
            name: Value(name),
            color: Value(colorHex),
            updatedAt: Value(now),
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

  domain.Tag _mapRowToTag(Tag row) {
    return domain.Tag(
      id: row.id,
      diverId: row.diverId,
      name: row.name,
      colorHex: row.color,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}

/// Tag usage statistics
class TagStatistic {
  final domain.Tag tag;
  final int diveCount;

  TagStatistic({required this.tag, required this.diveCount});
}
