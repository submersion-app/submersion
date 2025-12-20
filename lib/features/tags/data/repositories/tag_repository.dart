import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../domain/entities/tag.dart' as domain;

class TagRepository {
  final AppDatabase _db = DatabaseService.instance.database;
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(TagRepository);

  // ============================================================================
  // CRUD Operations
  // ============================================================================

  /// Get all tags, ordered by name
  Future<List<domain.Tag>> getAllTags({String? diverId}) async {
    try {
      final query = _db.select(_db.tags)..orderBy([(t) => OrderingTerm.asc(t.name)]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return rows.map(_mapRowToTag).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get all tags', e, stackTrace);
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
      _log.error('Failed to get tag by id: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Get a tag by name (case-insensitive)
  Future<domain.Tag?> getTagByName(String name, {String? diverId}) async {
    try {
      final query = _db.select(_db.tags)
        ..where((t) => t.name.lower().equals(name.toLowerCase()));

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToTag(row) : null;
    } catch (e, stackTrace) {
      _log.error('Failed to get tag by name: $name', e, stackTrace);
      rethrow;
    }
  }

  /// Create a new tag
  Future<domain.Tag> createTag(domain.Tag tag) async {
    try {
      _log.info('Creating tag: ${tag.name}');
      final id = tag.id.isEmpty ? _uuid.v4() : tag.id;
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.into(_db.tags).insert(TagsCompanion(
        id: Value(id),
        diverId: Value(tag.diverId),
        name: Value(tag.name),
        color: Value(tag.colorHex),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),);

      _log.info('Created tag with id: $id');
      return tag.copyWith(id: id);
    } catch (e, stackTrace) {
      _log.error('Failed to create tag', e, stackTrace);
      rethrow;
    }
  }

  /// Create a tag or get existing if name already exists
  Future<domain.Tag> getOrCreateTag(String name, {String? colorHex, String? diverId}) async {
    try {
      // Check if tag with this name exists for this diver
      final existing = await getTagByName(name, diverId: diverId);
      if (existing != null) {
        return existing;
      }

      // Create new tag
      final now = DateTime.now();
      return createTag(domain.Tag(
        id: _uuid.v4(),
        diverId: diverId,
        name: name.trim(),
        colorHex: colorHex,
        createdAt: now,
        updatedAt: now,
      ),);
    } catch (e, stackTrace) {
      _log.error('Failed to get or create tag: $name', e, stackTrace);
      rethrow;
    }
  }

  /// Update an existing tag
  Future<void> updateTag(domain.Tag tag) async {
    try {
      _log.info('Updating tag: ${tag.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(_db.tags)..where((t) => t.id.equals(tag.id))).write(
        TagsCompanion(
          name: Value(tag.name),
          color: Value(tag.colorHex),
          updatedAt: Value(now),
        ),
      );
      _log.info('Updated tag: ${tag.id}');
    } catch (e, stackTrace) {
      _log.error('Failed to update tag: ${tag.id}', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a tag
  Future<void> deleteTag(String id) async {
    try {
      _log.info('Deleting tag: $id');
      await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
      _log.info('Deleted tag: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to delete tag: $id', e, stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // Dive-Tag Associations
  // ============================================================================

  /// Get tags for a specific dive
  Future<List<domain.Tag>> getTagsForDive(String diveId) async {
    try {
      final result = await _db.customSelect('''
        SELECT t.* FROM tags t
        INNER JOIN dive_tags dt ON t.id = dt.tag_id
        WHERE dt.dive_id = ?
        ORDER BY t.name
      ''', variables: [Variable.withString(diveId)],).get();

      return result.map((row) => domain.Tag(
        id: row.data['id'] as String,
        name: row.data['name'] as String,
        colorHex: row.data['color'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.data['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row.data['updated_at'] as int),
      ),).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get tags for dive: $diveId', e, stackTrace);
      rethrow;
    }
  }

  /// Get tags for multiple dives (batch loading)
  Future<Map<String, List<domain.Tag>>> getTagsForDives(List<String> diveIds) async {
    if (diveIds.isEmpty) return {};

    try {
      final placeholders = diveIds.map((_) => '?').join(',');
      final result = await _db.customSelect('''
        SELECT dt.dive_id, t.* FROM tags t
        INNER JOIN dive_tags dt ON t.id = dt.tag_id
        WHERE dt.dive_id IN ($placeholders)
        ORDER BY t.name
      ''', variables: diveIds.map((id) => Variable.withString(id)).toList(),).get();

      final tagsByDive = <String, List<domain.Tag>>{};
      for (final row in result) {
        final diveId = row.data['dive_id'] as String;
        final tag = domain.Tag(
          id: row.data['id'] as String,
          name: row.data['name'] as String,
          colorHex: row.data['color'] as String?,
          createdAt: DateTime.fromMillisecondsSinceEpoch(row.data['created_at'] as int),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(row.data['updated_at'] as int),
        );
        tagsByDive.putIfAbsent(diveId, () => []).add(tag);
      }
      return tagsByDive;
    } catch (e, stackTrace) {
      _log.error('Failed to get tags for dives', e, stackTrace);
      rethrow;
    }
  }

  /// Set tags for a dive (replaces existing tags)
  Future<void> setTagsForDive(String diveId, List<domain.Tag> tags) async {
    try {
      _log.info('Setting ${tags.length} tags for dive: $diveId');

      // Get existing tag IDs before deletion to check for cleanup later
      final existingTags = await getTagsForDive(diveId);
      final existingTagIds = existingTags.map((t) => t.id).toSet();
      final newTagIds = tags.map((t) => t.id).toSet();
      final removedTagIds = existingTagIds.difference(newTagIds);

      // Delete existing tags for this dive
      await (_db.delete(_db.diveTags)..where((t) => t.diveId.equals(diveId))).go();

      // Insert new tags
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final tag in tags) {
        await _db.into(_db.diveTags).insert(DiveTagsCompanion(
          id: Value(_uuid.v4()),
          diveId: Value(diveId),
          tagId: Value(tag.id),
          createdAt: Value(now),
        ),);
      }

      // Clean up any tags that are no longer used
      for (final tagId in removedTagIds) {
        await _deleteTagIfUnused(tagId);
      }

      _log.info('Set ${tags.length} tags for dive: $diveId');
    } catch (e, stackTrace) {
      _log.error('Failed to set tags for dive: $diveId', e, stackTrace);
      rethrow;
    }
  }

  /// Add a tag to a dive
  Future<void> addTagToDive(String diveId, String tagId) async {
    try {
      _log.info('Adding tag $tagId to dive: $diveId');
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.into(_db.diveTags).insert(DiveTagsCompanion(
        id: Value(_uuid.v4()),
        diveId: Value(diveId),
        tagId: Value(tagId),
        createdAt: Value(now),
      ),);

      _log.info('Added tag $tagId to dive: $diveId');
    } catch (e, stackTrace) {
      _log.error('Failed to add tag to dive', e, stackTrace);
      rethrow;
    }
  }

  /// Remove a tag from a dive
  Future<void> removeTagFromDive(String diveId, String tagId) async {
    try {
      _log.info('Removing tag $tagId from dive: $diveId');
      await (_db.delete(_db.diveTags)
            ..where((t) => t.diveId.equals(diveId) & t.tagId.equals(tagId)))
          .go();
      
      // Clean up the tag if it's no longer used
      await _deleteTagIfUnused(tagId);
      
      _log.info('Removed tag $tagId from dive: $diveId');
    } catch (e, stackTrace) {
      _log.error('Failed to remove tag from dive', e, stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // Cleanup
  // ============================================================================

  /// Delete a tag if it's no longer used by any dive
  Future<void> _deleteTagIfUnused(String tagId) async {
    try {
      final usageCount = await _getTagUsageCount(tagId);
      if (usageCount == 0) {
        _log.info('Deleting unused tag: $tagId');
        await deleteTag(tagId);
      }
    } catch (e, stackTrace) {
      _log.error('Failed to check/delete unused tag: $tagId', e, stackTrace);
      // Don't rethrow - cleanup failure shouldn't break the main operation
    }
  }

  /// Get the number of dives using a specific tag
  Future<int> _getTagUsageCount(String tagId) async {
    final result = await _db.customSelect('''
      SELECT COUNT(*) as count FROM dive_tags WHERE tag_id = ?
    ''', variables: [Variable.withString(tagId)],).getSingle();
    return result.data['count'] as int;
  }

  /// Delete all tags that are not used by any dive
  Future<void> deleteUnusedTags() async {
    try {
      _log.info('Cleaning up unused tags');
      await _db.customStatement('''
        DELETE FROM tags WHERE id NOT IN (
          SELECT DISTINCT tag_id FROM dive_tags
        )
      ''');
      _log.info('Deleted unused tags');
    } catch (e, stackTrace) {
      _log.error('Failed to delete unused tags', e, stackTrace);
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
      final variables = diverId != null ? [Variable.withString(diverId)] : <Variable<Object>>[];

      final result = await _db.customSelect('''
        SELECT t.*, COUNT(dt.dive_id) as dive_count
        FROM tags t
        LEFT JOIN dive_tags dt ON t.id = dt.tag_id
        $diverFilter
        GROUP BY t.id
        ORDER BY dive_count DESC, t.name
      ''', variables: variables).get();

      return result.map((row) => TagStatistic(
        tag: domain.Tag(
          id: row.data['id'] as String,
          diverId: row.data['diver_id'] as String?,
          name: row.data['name'] as String,
          colorHex: row.data['color'] as String?,
          createdAt: DateTime.fromMillisecondsSinceEpoch(row.data['created_at'] as int),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(row.data['updated_at'] as int),
        ),
        diveCount: row.data['dive_count'] as int,
      ),).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get tag statistics', e, stackTrace);
      rethrow;
    }
  }

  /// Search tags by name (for autocomplete)
  Future<List<domain.Tag>> searchTags(String query, {String? diverId}) async {
    try {
      if (query.isEmpty) return getAllTags(diverId: diverId);

      final searchQuery = _db.select(_db.tags)
        ..where((t) => t.name.lower().contains(query.toLowerCase()))
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);

      if (diverId != null) {
        searchQuery.where((t) => t.diverId.equals(diverId));
      }

      final rows = await searchQuery.get();
      return rows.map(_mapRowToTag).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to search tags: $query', e, stackTrace);
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
