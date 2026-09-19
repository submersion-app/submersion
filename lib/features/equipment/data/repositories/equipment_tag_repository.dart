import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/tags/data/mappers/tag_row_mapper.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;

/// Reads and writes an equipment item's tags (issue #1942): the
/// `equipment_tags` junction, the equipment twin of `site_tags`.
///
/// The links are clockless children of the item. A write marks only the
/// junction rows it inserts pending and tombstones the rows it deletes. It
/// never touches the `equipment` row, neither its `updated_at` nor a pending
/// mark: a stale whole-row equipment snapshot from a peer must not be able
/// to beat a newer edit to the same item (#1769).
///
/// Every insert is `DoNothing`-guarded: the (equipment, tag) unique index
/// makes an unguarded duplicate throw. Writers take `notify: false` when
/// they run inside a caller's transaction; the caller notifies once
/// afterwards.
class EquipmentTagRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  static const String _entityType = 'equipmentTags';

  /// Ids bound per `IN (...)` list: under SQLite's 999-variable floor, with
  /// room for the one tag id [removeTags] binds beside them.
  static const int _idChunk = 900;

  /// Emits when an item gains or loses a tag, or when a tag itself changes
  /// (a rename or a new color shows on every item carrying it).
  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([_db.equipmentTags, _db.tags]),
  );

  /// [equipmentId]'s tags, by name.
  Future<List<domain.Tag>> getTagsForEquipment(String equipmentId) async {
    final rows = await _db
        .customSelect(
          'SELECT t.* FROM equipment_tags et JOIN tags t ON t.id = et.tag_id '
          'WHERE et.equipment_id = ? ORDER BY t.name COLLATE NOCASE',
          variables: [Variable.withString(equipmentId)],
          readsFrom: {_db.equipmentTags, _db.tags},
        )
        .get();
    return [
      for (final r in sortedByText(rows, (r) => r.data['name'] as String))
        mapTagRow(_db.tags.map(r.data)),
    ];
  }

  /// Every item's tags, by name, in one query. An item with no tags has no
  /// entry.
  Future<Map<String, List<domain.Tag>>> getTagsByEquipment() async {
    final rows = await _db
        .customSelect(
          'SELECT et.equipment_id AS link_equipment_id, t.* '
          'FROM equipment_tags et JOIN tags t ON t.id = et.tag_id '
          'ORDER BY et.equipment_id, t.name COLLATE NOCASE',
          readsFrom: {_db.equipmentTags, _db.tags},
        )
        .get();
    final byItem = <String, List<domain.Tag>>{};
    for (final r in sortedByText(
      rows,
      (r) => r.data['name'] as String,
      groupOf: (r) => r.read<String>('link_equipment_id'),
    )) {
      byItem
          .putIfAbsent(r.read<String>('link_equipment_id'), () => [])
          .add(mapTagRow(_db.tags.map(r.data)));
    }
    return byItem;
  }

  /// Raw tag ids per item for [equipmentIds], oldest link first, for bulk
  /// edit snapshots and exports. An item with no tags has no entry.
  Future<Map<String, List<String>>> getTagIdsByEquipment(
    List<String> equipmentIds,
  ) async {
    final byItem = <String, List<String>>{};
    for (final chunk in _chunks(equipmentIds.toSet().toList())) {
      final rows =
          await (_db.select(_db.equipmentTags)
                ..where((t) => t.equipmentId.isIn(chunk))
                ..orderBy([
                  (t) => OrderingTerm.asc(t.createdAt),
                  (t) => OrderingTerm.asc(t.id),
                ]))
              .get();
      for (final r in rows) {
        byItem.putIfAbsent(r.equipmentId, () => []).add(r.tagId);
      }
    }
    return byItem;
  }

  /// How many of [equipmentIds] carry each tag, keyed by tag id: the
  /// tri-state seed of the bulk tag editor. The unique index allows one row
  /// per (item, tag), so the per-chunk counts sum exactly.
  Future<Map<String, int>> tagCountsForEquipment(
    List<String> equipmentIds,
  ) async {
    final counts = <String, int>{};
    for (final chunk in _chunks(equipmentIds.toSet().toList())) {
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            'SELECT tag_id, COUNT(*) AS n FROM equipment_tags '
            'WHERE equipment_id IN ($placeholders) GROUP BY tag_id',
            variables: [for (final id in chunk) Variable.withString(id)],
            readsFrom: {_db.equipmentTags},
          )
          .get();
      for (final r in rows) {
        final tagId = r.read<String>('tag_id');
        counts[tagId] = (counts[tagId] ?? 0) + r.read<int>('n');
      }
    }
    return counts;
  }

  /// Makes [equipmentId]'s tags exactly [tagIds]. A pair that stays keeps
  /// its row, so its id and clock survive the save.
  Future<void> replaceTags(
    String equipmentId,
    List<String> tagIds, {
    bool notify = true,
  }) async {
    await _db.transaction(() async {
      final wanted = tagIds.toSet();
      final existing = await (_db.select(
        _db.equipmentTags,
      )..where((t) => t.equipmentId.equals(equipmentId))).get();
      for (final row in existing) {
        if (wanted.contains(row.tagId)) continue;
        await (_db.delete(
          _db.equipmentTags,
        )..where((t) => t.id.equals(row.id))).go();
        await _syncRepository.logDeletion(
          entityType: _entityType,
          recordId: row.id,
        );
      }
      final have = {for (final r in existing) r.tagId};
      await _insertTags(equipmentId, [
        for (final id in wanted)
          if (!have.contains(id)) id,
      ]);
    });
    if (notify) SyncEventBus.notifyLocalChange();
  }

  /// Adds every tag in [tagIds] to every item in [equipmentIds]; never
  /// removes one. A pair that already exists is skipped.
  Future<void> addTags(
    List<String> equipmentIds,
    List<String> tagIds, {
    bool notify = true,
  }) async {
    final items = equipmentIds.toSet().toList();
    final tags = tagIds.toSet().toList();
    if (items.isEmpty || tags.isEmpty) return;
    await _db.transaction(() async {
      final have = <(String, String)>{};
      for (final chunk in _chunks(items)) {
        final rows = await (_db.select(
          _db.equipmentTags,
        )..where((t) => t.equipmentId.isIn(chunk))).get();
        for (final r in rows) {
          have.add((r.equipmentId, r.tagId));
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

  /// Removes every tag in [tagIds] from every item in [equipmentIds],
  /// tombstoning each removed link. A pair that does not exist is ignored.
  Future<void> removeTags(
    List<String> equipmentIds,
    List<String> tagIds, {
    bool notify = true,
  }) async {
    final items = equipmentIds.toSet().toList();
    final tags = tagIds.toSet().toList();
    if (items.isEmpty || tags.isEmpty) return;
    await _db.transaction(() async {
      for (final tagId in tags) {
        for (final chunk in _chunks(items)) {
          final rows =
              await (_db.select(_db.equipmentTags)..where(
                    (t) => t.tagId.equals(tagId) & t.equipmentId.isIn(chunk),
                  ))
                  .get();
          if (rows.isEmpty) continue;
          await (_db.delete(_db.equipmentTags)..where(
                (t) => t.tagId.equals(tagId) & t.equipmentId.isIn(chunk),
              ))
              .go();
          for (final row in rows) {
            await _syncRepository.logDeletion(
              entityType: _entityType,
              recordId: row.id,
            );
          }
        }
      }
    });
    if (notify) SyncEventBus.notifyLocalChange();
  }

  /// Deletes and tombstones every tag link of [equipmentId], for
  /// `EquipmentRepository.deleteEquipment`. SQLite's cascade would remove
  /// the rows as well, but a cascade writes no tombstone, so a peer would
  /// keep them. Runs inside the caller's transaction and does not notify.
  Future<void> deleteLinksForEquipment(String equipmentId) async {
    final rows = await (_db.select(
      _db.equipmentTags,
    )..where((t) => t.equipmentId.equals(equipmentId))).get();
    if (rows.isEmpty) return;
    await (_db.delete(
      _db.equipmentTags,
    )..where((t) => t.equipmentId.equals(equipmentId))).go();
    for (final row in rows) {
      await _syncRepository.logDeletion(
        entityType: _entityType,
        recordId: row.id,
      );
    }
  }

  /// Inserts in the given order: `created_at` is `now + index`, because the
  /// raw read order is `created_at, id` and a shared timestamp would leave
  /// the order to random uuids. A pair that raced in since the caller's read
  /// comes back null from the guarded insert and is not marked pending.
  Future<void> _insertTags(String equipmentId, List<String> tagIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < tagIds.length; i++) {
      final id = _uuid.v4();
      final inserted = await _db
          .into(_db.equipmentTags)
          .insertReturningOrNull(
            EquipmentTagsCompanion.insert(
              id: id,
              equipmentId: equipmentId,
              tagId: tagIds[i],
              createdAt: now + i,
            ),
            onConflict: DoNothing<$EquipmentTagsTable, EquipmentTag>(
              target: const [],
            ),
          );
      if (inserted == null) continue;
      await _syncRepository.markRecordPending(
        entityType: _entityType,
        recordId: id,
        localUpdatedAt: now,
      );
    }
  }

  static Iterable<List<String>> _chunks(List<String> ids) sync* {
    for (var i = 0; i < ids.length; i += _idChunk) {
      yield ids.sublist(
        i,
        i + _idChunk < ids.length ? i + _idChunk : ids.length,
      );
    }
  }
}
