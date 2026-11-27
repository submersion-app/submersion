import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/equipment/data/repositories/dive_gear_usage_sql.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Gear items linked to photos and videos (issue #5046): "this photo shows
/// my drysuit". Reads and writes the `media_equipment` junction only.
///
/// Like TagLinkRepository, a write marks only the junction rows it inserts
/// pending and tombstones the rows it deletes; it never touches the photo's
/// or the gear's own row (#1769). Inserts are conflict-guarded against the
/// (media, equipment) unique key. Writers take `notify: false` inside a
/// caller's transaction; the caller notifies once afterwards.
///
/// A linked photo stays an ordinary photo: nothing here writes
/// `media.equipment_id`, which is what makes a row a gear photo.
class MediaGearRepository {
  MediaGearRepository({AppDatabase? db, SyncRepository? syncRepository})
    : _dbOverride = db,
      _syncRepository = syncRepository ?? SyncRepository();

  final AppDatabase? _dbOverride;
  final SyncRepository _syncRepository;
  final _uuid = const Uuid();

  static const _entityType = 'mediaEquipment';

  /// The media a link may name: photos and videos that are neither a
  /// signature nor a gear photo, as `m`.
  static const linkableSql =
      "m.file_type IN ('photo', 'video') "
      "AND m.source_type <> 'signature' "
      'AND m.equipment_id IS NULL';

  AppDatabase get _db => _dbOverride ?? DatabaseService.instance.database;

  /// Emits when a link is made or removed.
  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.mediaEquipment));

  /// Every gear id linked to [mediaId], oldest link first. Unscoped: the
  /// caller hides gear the diver cannot see.
  Future<List<String>> gearIdsFor(String mediaId) async => [
    for (final r in await _linksOfMedia([mediaId]))
      r.read<String>('equipment_id'),
  ];

  /// The linked gear ids of each of [mediaIds] that has any.
  Future<Map<String, Set<String>>> gearIdsByMedia(List<String> mediaIds) async {
    final out = <String, Set<String>>{};
    for (final chunk in seriesIdChunks(mediaIds.toSet().toList())) {
      for (final r in await _linksOfMedia(chunk)) {
        out
            .putIfAbsent(r.read<String>('media_id'), () => <String>{})
            .add(r.read<String>('equipment_id'));
      }
    }
    return out;
  }

  /// For each gear id linked to any of [mediaIds], how many of them it is
  /// linked to.
  Future<Map<String, int>> gearCountsFor(List<String> mediaIds) async {
    final counts = <String, int>{};
    for (final ids in (await gearIdsByMedia(mediaIds)).values) {
      for (final id in ids) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Makes [mediaId]'s gear exactly [equipmentIds]. A pair that stays keeps
  /// its row, so its id and clock survive the save.
  Future<void> replaceGear(
    String mediaId,
    List<String> equipmentIds, {
    bool notify = true,
  }) async {
    await _db.transaction(() async {
      final wanted = equipmentIds.toSet();
      final existing = await _linksOfMedia([mediaId]);
      await _deleteLinks([
        for (final r in existing)
          if (!wanted.contains(r.read<String>('equipment_id')))
            r.read<String>('id'),
      ]);
      final have = {for (final r in existing) r.read<String>('equipment_id')};
      await _insertPairs([
        for (final id in wanted)
          if (!have.contains(id)) (mediaId: mediaId, equipmentId: id),
      ]);
    });
    if (notify) SyncEventBus.notifyLocalChange();
  }

  /// Links every item in [equipmentIds] to every photo in [mediaIds]; never
  /// removes one. A pair that already exists is skipped.
  Future<void> addGear(
    List<String> mediaIds,
    List<String> equipmentIds, {
    bool notify = true,
  }) async {
    final gear = equipmentIds.toSet();
    if (mediaIds.isEmpty || gear.isEmpty) return;
    await _db.transaction(() async {
      final have = await gearIdsByMedia(mediaIds);
      await _insertPairs([
        for (final media in mediaIds.toSet())
          for (final id in gear)
            if (!(have[media]?.contains(id) ?? false))
              (mediaId: media, equipmentId: id),
      ]);
    });
    if (notify) SyncEventBus.notifyLocalChange();
  }

  /// Unlinks every item in [equipmentIds] from every photo in [mediaIds],
  /// tombstoning each removed link. A pair that does not exist is ignored.
  Future<void> removeGear(
    List<String> mediaIds,
    List<String> equipmentIds, {
    bool notify = true,
  }) async {
    final gear = equipmentIds.toSet();
    if (mediaIds.isEmpty || gear.isEmpty) return;
    await _db.transaction(() async {
      for (final chunk in seriesIdChunks(mediaIds.toSet().toList())) {
        await _deleteLinks([
          for (final r in await _linksOfMedia(chunk))
            if (gear.contains(r.read<String>('equipment_id')))
              r.read<String>('id'),
        ]);
      }
    });
    if (notify) SyncEventBus.notifyLocalChange();
  }

  /// The linkable photos linked to [equipmentId] that [diverId] can see,
  /// newest first: a photo on another diver's dive is left out, a photo on
  /// no dive is kept, as the Library scopes them. A null [diverId] sees all.
  Future<List<MediaItem>> linkedMediaFor(
    String equipmentId, {
    required String? diverId,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT m.* FROM media m '
          'JOIN media_equipment l ON l.media_id = m.id '
          'LEFT JOIN dives d ON d.id = m.dive_id '
          'WHERE l.equipment_id = ?1 AND $linkableSql '
          'AND (?2 IS NULL OR m.dive_id IS NULL OR d.diver_id = ?2) '
          'ORDER BY m.taken_at DESC, m.id',
          variables: [
            Variable.withString(equipmentId),
            Variable<String>(diverId),
          ],
          readsFrom: {_db.media, _db.mediaEquipment, _db.dives},
        )
        .get();
    return [for (final r in rows) mediaItemFromRow(_db.media.map(r.data))];
  }

  /// Every photo id linked to [equipmentId]. Unscoped.
  Future<List<String>> mediaIdsFor(String equipmentId) async => [
    for (final r in await _linksOfEquipment(equipmentId))
      r.read<String>('media_id'),
  ];

  /// Makes [equipmentId]'s photos exactly [mediaIds]. The caller merges
  /// what it could not see into [mediaIds] first.
  Future<void> replaceMedia(
    String equipmentId,
    List<String> mediaIds, {
    bool notify = true,
  }) async {
    await _db.transaction(() async {
      final wanted = mediaIds.toSet();
      final existing = await _linksOfEquipment(equipmentId);
      await _deleteLinks([
        for (final r in existing)
          if (!wanted.contains(r.read<String>('media_id')))
            r.read<String>('id'),
      ]);
      final have = {for (final r in existing) r.read<String>('media_id')};
      await _insertPairs([
        for (final id in wanted)
          if (!have.contains(id)) (mediaId: id, equipmentId: equipmentId),
      ]);
    });
    if (notify) SyncEventBus.notifyLocalChange();
  }

  /// The linkable photos on [diveIds], newest first.
  Future<List<MediaItem>> linkableMediaOnDives(List<String> diveIds) async {
    final out = <MediaItem>[];
    for (final chunk in seriesIdChunks(diveIds.toSet().toList())) {
      final rows = await _db
          .customSelect(
            'SELECT m.* FROM media m '
            'WHERE m.dive_id IN (${_marks(chunk)}) AND $linkableSql',
            variables: _vars(chunk),
            readsFrom: {_db.media},
          )
          .get();
      out.addAll([
        for (final r in rows) mediaItemFromRow(_db.media.map(r.data)),
      ]);
    }
    out.sort((a, b) {
      final byTime = b.takenAt.compareTo(a.takenAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return out;
  }

  /// The gear used on [diveId], every way gear reaches a dive.
  Future<Set<String>> gearOnDive(String diveId) async => {
    for (final row in await gearUsageForDives(_db, [diveId])) row.equipmentId,
  };

  /// Deletes and tombstones every link of [mediaIds], for the photos' own
  /// delete: a cascade writes no tombstone, so a peer would keep the links.
  /// Runs inside the caller's transaction and does not notify.
  Future<void> deleteForMedia(List<String> mediaIds) async {
    for (final chunk in seriesIdChunks(mediaIds.toSet().toList())) {
      await _deleteLinks([
        for (final r in await _linksOfMedia(chunk)) r.read<String>('id'),
      ]);
    }
  }

  /// Deletes and tombstones every link of [equipmentId], for the item's own
  /// delete. Runs inside the caller's transaction and does not notify.
  Future<void> deleteForEquipment(String equipmentId) async {
    await _deleteLinks([
      for (final r in await _linksOfEquipment(equipmentId))
        r.read<String>('id'),
    ]);
  }

  Future<List<QueryRow>> _linksOfMedia(List<String> mediaIds) => _db
      .customSelect(
        'SELECT id, media_id, equipment_id FROM media_equipment '
        'WHERE media_id IN (${_marks(mediaIds)}) ORDER BY created_at, id',
        variables: _vars(mediaIds),
        readsFrom: {_db.mediaEquipment},
      )
      .get();

  Future<List<QueryRow>> _linksOfEquipment(String equipmentId) => _db
      .customSelect(
        'SELECT id, media_id, equipment_id FROM media_equipment '
        'WHERE equipment_id = ? ORDER BY created_at, id',
        variables: [Variable.withString(equipmentId)],
        readsFrom: {_db.mediaEquipment},
      )
      .get();

  Future<void> _deleteLinks(List<String> linkIds) async {
    for (final chunk in seriesIdChunks(linkIds)) {
      await _db.customUpdate(
        'DELETE FROM media_equipment WHERE id IN (${_marks(chunk)})',
        variables: _vars(chunk),
        updates: {_db.mediaEquipment},
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

  /// Inserts in the given order, `created_at` is `now + index` so the read
  /// order never falls to random uuids. A pair that raced in since the
  /// caller's read inserts nothing and is not marked pending.
  Future<void> _insertPairs(
    List<({String mediaId, String equipmentId})> pairs,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < pairs.length; i++) {
      final id = _uuid.v4();
      final inserted = await _db.customUpdate(
        'INSERT INTO media_equipment (id, media_id, equipment_id, created_at) '
        'VALUES (?, ?, ?, ?) ON CONFLICT DO NOTHING',
        variables: [
          Variable.withString(id),
          Variable.withString(pairs[i].mediaId),
          Variable.withString(pairs[i].equipmentId),
          Variable.withInt(now + i),
        ],
        updates: {_db.mediaEquipment},
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
