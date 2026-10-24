import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/tags/data/mappers/tag_row_mapper.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;

/// Reads and writes the tags of one scope's items through that scope's
/// junction (issue #1970): the media and document tags. Every table and
/// column name comes from the scope's registry entry, as in TagRepository,
/// so the class serves any scope whose links are clockless children.
///
/// A write marks only the junction rows it inserts pending and tombstones
/// the rows it deletes. It never touches the item's own row, neither its
/// `updated_at` nor a pending mark: a stale whole-row snapshot from a peer
/// must not be able to beat a newer edit to the same item (#1769).
///
/// Every insert is conflict-guarded: the (item, tag) unique index makes an
/// unguarded duplicate throw. Writers take `notify: false` when they run
/// inside a caller's transaction; the caller notifies once afterwards.
class TagLinkRepository {
  TagLinkRepository(this.scope);

  final domain.TagScope scope;

  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  String get _junction => scope.table.junctionTable;
  String get _item => scope.table.parentColumn;
  String get _entityType => scope.table.syncEntity;

  TableInfo<Table, dynamic> get _junctionTable =>
      _db.allTables.firstWhere((t) => t.actualTableName == _junction);

  /// Emits when an item gains or loses a tag, or when a tag itself changes
  /// (a rename or a new color shows on every item carrying it).
  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([_junctionTable, _db.tags]),
  );

  /// [itemId]'s tags, by name.
  Future<List<domain.Tag>> getTagsFor(String itemId) async {
    final rows = await _db
        .customSelect(
          'SELECT t.* FROM $_junction l JOIN tags t ON t.id = l.tag_id '
          'WHERE l.$_item = ? ORDER BY t.name COLLATE NOCASE',
          variables: [Variable.withString(itemId)],
          readsFrom: {_junctionTable, _db.tags},
        )
        .get();
    return [
      for (final r in sortedByText(rows, (r) => r.data['name'] as String))
        mapTagRow(_db.tags.map(r.data)),
    ];
  }

  /// Every item's tags, by name, in one query. An item with no tags has no
  /// entry.
  Future<Map<String, List<domain.Tag>>> getTagsByItem() async {
    final rows = await _db
        .customSelect(
          'SELECT l.$_item AS link_item_id, t.* '
          'FROM $_junction l JOIN tags t ON t.id = l.tag_id '
          'ORDER BY l.$_item, t.name COLLATE NOCASE',
          readsFrom: {_junctionTable, _db.tags},
        )
        .get();
    final byItem = <String, List<domain.Tag>>{};
    for (final r in sortedByText(
      rows,
      (r) => r.data['name'] as String,
      groupOf: (r) => r.read<String>('link_item_id'),
    )) {
      byItem
          .putIfAbsent(r.read<String>('link_item_id'), () => [])
          .add(mapTagRow(_db.tags.map(r.data)));
    }
    return byItem;
  }

  /// Raw tag ids per item for [itemIds], oldest link first, for bulk edit
  /// snapshots. An item with no tags has no entry.
  Future<Map<String, List<String>>> getTagIdsByItem(
    List<String> itemIds,
  ) async {
    final byItem = <String, List<String>>{};
    for (final chunk in seriesIdChunks(itemIds.toSet().toList())) {
      for (final r in await _linksIn(chunk)) {
        byItem
            .putIfAbsent(r.read<String>('item_id'), () => [])
            .add(r.read<String>('tag_id'));
      }
    }
    return byItem;
  }

  /// How many of [itemIds] carry each tag, keyed by tag id: the tri-state
  /// seed of the bulk tag editor. The unique index allows one row per (item,
  /// tag), so the per-chunk counts sum exactly.
  Future<Map<String, int>> tagCountsFor(List<String> itemIds) async {
    final counts = <String, int>{};
    for (final chunk in seriesIdChunks(itemIds.toSet().toList())) {
      final rows = await _db
          .customSelect(
            'SELECT tag_id, COUNT(*) AS n FROM $_junction '
            'WHERE $_item IN (${_marks(chunk)}) GROUP BY tag_id',
            variables: _vars(chunk),
            readsFrom: {_junctionTable},
          )
          .get();
      for (final r in rows) {
        final tagId = r.read<String>('tag_id');
        counts[tagId] = (counts[tagId] ?? 0) + r.read<int>('n');
      }
    }
    return counts;
  }

  /// Makes [itemId]'s tags exactly [tagIds]. A pair that stays keeps its
  /// row, so its id and clock survive the save.
  Future<void> replaceTags(
    String itemId,
    List<String> tagIds, {
    bool notify = true,
  }) async {
    await _db.transaction(() async {
      final wanted = tagIds.toSet();
      final existing = await _linksIn([itemId]);
      await _deleteLinks([
        for (final r in existing)
          if (!wanted.contains(r.read<String>('tag_id'))) r.read<String>('id'),
      ]);
      final have = {for (final r in existing) r.read<String>('tag_id')};
      await _insertTags(itemId, [
        for (final id in tagIds.toSet())
          if (!have.contains(id)) id,
      ]);
    });
    if (notify) SyncEventBus.notifyLocalChange();
  }

  /// Adds every tag in [tagIds] to every item in [itemIds]; never removes
  /// one. A pair that already exists is skipped.
  Future<void> addTags(
    List<String> itemIds,
    List<String> tagIds, {
    bool notify = true,
  }) async {
    final items = itemIds.toSet().toList();
    final tags = tagIds.toSet().toList();
    if (items.isEmpty || tags.isEmpty) return;
    await _db.transaction(() async {
      final have = <(String, String)>{};
      for (final chunk in seriesIdChunks(items)) {
        for (final r in await _linksIn(chunk)) {
          have.add((r.read<String>('item_id'), r.read<String>('tag_id')));
        }
      }
      for (final item in items) {
        await _insertTags(item, [
          for (final tag in tags)
            if (!have.contains((item, tag))) tag,
        ]);
      }
    });
    if (notify) SyncEventBus.notifyLocalChange();
  }

  /// Removes every tag in [tagIds] from every item in [itemIds], tombstoning
  /// each removed link. A pair that does not exist is ignored.
  Future<void> removeTags(
    List<String> itemIds,
    List<String> tagIds, {
    bool notify = true,
  }) async {
    final items = itemIds.toSet().toList();
    final tags = tagIds.toSet();
    if (items.isEmpty || tags.isEmpty) return;
    await _db.transaction(() async {
      for (final chunk in seriesIdChunks(items)) {
        await _deleteLinks([
          for (final r in await _linksIn(chunk))
            if (tags.contains(r.read<String>('tag_id'))) r.read<String>('id'),
        ]);
      }
    });
    if (notify) SyncEventBus.notifyLocalChange();
  }

  /// Deletes and tombstones every tag link of [itemIds], for the items' own
  /// delete. SQLite's cascade would remove the rows as well, but a cascade
  /// writes no tombstone, so a peer would keep them. Runs inside the
  /// caller's transaction and does not notify.
  Future<void> deleteLinksFor(List<String> itemIds) async {
    for (final chunk in seriesIdChunks(itemIds.toSet().toList())) {
      await _deleteLinks([
        for (final r in await _linksIn(chunk)) r.read<String>('id'),
      ]);
    }
  }

  /// The links of [itemIds] (one chunk at most), oldest first.
  Future<List<QueryRow>> _linksIn(List<String> itemIds) => _db
      .customSelect(
        'SELECT id, $_item AS item_id, tag_id FROM $_junction '
        'WHERE $_item IN (${_marks(itemIds)}) ORDER BY created_at, id',
        variables: _vars(itemIds),
        readsFrom: {_junctionTable},
      )
      .get();

  /// Deletes the links with [linkIds] and tombstones each.
  Future<void> _deleteLinks(List<String> linkIds) async {
    for (final chunk in seriesIdChunks(linkIds)) {
      await _db.customUpdate(
        'DELETE FROM $_junction WHERE id IN (${_marks(chunk)})',
        variables: _vars(chunk),
        updates: {_junctionTable},
        updateKind: UpdateKind.delete,
      );
      for (final id in chunk) {
        await _syncRepository.logDeletion(
          entityType: _entityType,
          recordId: id,
        );
      }
    }
  }

  /// Inserts in the given order: `created_at` is `now + index`, because the
  /// raw read order is `created_at, id` and a shared timestamp would leave
  /// the order to random uuids. A pair that raced in since the caller's read
  /// inserts nothing and is not marked pending.
  Future<void> _insertTags(String itemId, List<String> tagIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < tagIds.length; i++) {
      final id = _uuid.v4();
      final inserted = await _db.customUpdate(
        'INSERT INTO $_junction (id, $_item, tag_id, created_at) '
        'VALUES (?, ?, ?, ?) ON CONFLICT DO NOTHING',
        variables: [
          Variable.withString(id),
          Variable.withString(itemId),
          Variable.withString(tagIds[i]),
          Variable.withInt(now + i),
        ],
        updates: {_junctionTable},
        updateKind: UpdateKind.insert,
      );
      if (inserted == 0) continue;
      await _syncRepository.markRecordPending(
        entityType: _entityType,
        recordId: id,
        localUpdatedAt: now,
      );
    }
  }

  static String _marks(List<String> ids) =>
      List.filled(ids.length, '?').join(', ');

  static List<Variable<String>> _vars(List<String> ids) => [
    for (final id in ids) Variable.withString(id),
  ];
}
