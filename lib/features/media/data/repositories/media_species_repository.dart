import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/species_tag_candidate_group.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';

/// Species tags on photos: the `media_species` link table.
///
/// A tag sits on a photo that already belongs to a dive or a site; this
/// repository never creates media rows. The table has no `hlc` column, so
/// like `site_species` it syncs as a clockless child: add marks the row
/// pending, remove tombstones it by id, and the incremental export keys off
/// the parent `media.hlc`.
class MediaSpeciesRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  static const Uuid _uuid = Uuid();

  /// Bound-variable budget per `isIn` chunk, well under SQLite's 999 limit.
  static const int _chunkSize = 500;

  /// Ticks whenever `media_species` changes, from any writer.
  Stream<void> watchTagChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.mediaSpecies));

  Future<List<MediaSpeciesTag>> getTagsForMedia(String mediaId) async {
    final rows =
        await (_db.select(_db.mediaSpecies)
              ..where((t) => t.mediaId.equals(mediaId))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    return rows.map(_tagFromRow).toList();
  }

  /// Tags for many photos in one pass, keyed by media id. Photos without a
  /// tag are absent from the map.
  Future<Map<String, List<MediaSpeciesTag>>> getTagsForMediaIds(
    List<String> mediaIds,
  ) async {
    final result = <String, List<MediaSpeciesTag>>{};
    for (var i = 0; i < mediaIds.length; i += _chunkSize) {
      final chunk = mediaIds.sublist(i, min(i + _chunkSize, mediaIds.length));
      final rows = await (_db.select(
        _db.mediaSpecies,
      )..where((t) => t.mediaId.isIn(chunk))).get();
      for (final row in rows) {
        result.putIfAbsent(row.mediaId, () => []).add(_tagFromRow(row));
      }
    }
    return result;
  }

  /// Tags [mediaId] with [speciesId]. Returns the existing tag when the pair
  /// is already linked: uniqueness lives here, not in a schema constraint.
  Future<MediaSpeciesTag> addTag({
    required String mediaId,
    required String speciesId,
    String? sightingId,
  }) async {
    final existing = await _findTag(mediaId, speciesId);
    if (existing != null) return _tagFromRow(existing);

    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.mediaSpecies)
        .insert(
          MediaSpeciesCompanion(
            id: Value(id),
            mediaId: Value(mediaId),
            speciesId: Value(speciesId),
            sightingId: Value(sightingId),
            createdAt: Value(now),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: 'mediaSpecies',
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();

    return MediaSpeciesTag(
      id: id,
      mediaId: mediaId,
      speciesId: speciesId,
      sightingId: sightingId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  /// Removes the tag linking [mediaId] and [speciesId], tombstoning it by
  /// row id so other devices drop the same row. No-op when absent.
  Future<void> removeTag({
    required String mediaId,
    required String speciesId,
  }) async {
    final existing = await _findTag(mediaId, speciesId);
    if (existing == null) return;

    await (_db.delete(
      _db.mediaSpecies,
    )..where((t) => t.id.equals(existing.id))).go();
    await _syncRepository.logDeletion(
      entityType: 'mediaSpecies',
      recordId: existing.id,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Every photo tagged with [speciesId], newest first, once each.
  ///
  /// Scoped to [diverId] through the photo's dive while keeping site-only
  /// photos, the library's own rule (`media.dive_id IS NULL OR
  /// dives.diver_id = ?`). [diveId] narrows to that dive's photos in SQL,
  /// same ordering, for the viewer a sighting row opens.
  Future<List<MediaItem>> getMediaForSpecies(
    String speciesId, {
    String? diverId,
    String? diveId,
  }) async {
    final m = _db.media;
    final query =
        _db.select(m, distinct: true).join([
            innerJoin(
              _db.mediaSpecies,
              _db.mediaSpecies.mediaId.equalsExp(m.id),
              useColumns: false,
            ),
            leftOuterJoin(
              _db.mediaEnrichment,
              _db.mediaEnrichment.mediaId.equalsExp(m.id),
            ),
            leftOuterJoin(
              _db.dives,
              _db.dives.id.equalsExp(m.diveId),
              useColumns: false,
            ),
          ])
          ..where(
            _db.mediaSpecies.speciesId.equals(speciesId) &
                _diverScope(diverId) &
                (diveId == null
                    ? const Constant(true)
                    : m.diveId.equals(diveId)),
          )
          ..orderBy([OrderingTerm.desc(m.takenAt), OrderingTerm.asc(m.id)]);
    final rows = await query.get();
    return rows
        .map(
          (row) => mediaItemFromRow(
            row.readTable(m),
            row.readTableOrNull(_db.mediaEnrichment),
          ),
        )
        .toList();
  }

  /// Photos the diver could tag with [speciesId]: the photos and videos on
  /// dives with a sighting of it that carry no tag for it yet, grouped by
  /// dive, newest dive first. Documents are not candidates.
  Future<List<SpeciesTagCandidateGroup>> getTagCandidatesForSpecies(
    String speciesId, {
    String? diverId,
  }) async {
    final diverClause = diverId != null ? 'AND d.diver_id = ?' : '';
    final diveRows = await _db
        .customSelect(
          '''
      SELECT s.id AS sighting_id, d.id AS dive_id, d.dive_number,
             d.dive_date_time, ds.name AS site_name
      FROM sightings s
      JOIN dives d ON d.id = s.dive_id
      LEFT JOIN dive_sites ds ON ds.id = d.site_id
      WHERE s.species_id = ? $diverClause
      ORDER BY d.dive_date_time DESC, s.id ASC
    ''',
          variables: [
            Variable.withString(speciesId),
            if (diverId != null) Variable.withString(diverId),
          ],
        )
        .get();
    if (diveRows.isEmpty) return const [];

    // One group per dive even if the dive logged the species twice.
    final seenDives = <String>{};
    final headers = diveRows
        .where((r) => seenDives.add(r.read<String>('dive_id')))
        .toList();
    final diveIds = headers.map((r) => r.read<String>('dive_id')).toList();

    final taggedIds = _db.selectOnly(_db.mediaSpecies)
      ..addColumns([_db.mediaSpecies.mediaId])
      ..where(_db.mediaSpecies.speciesId.equals(speciesId));
    final m = _db.media;
    // Chunked like the id lookups above: a species logged on many dives
    // would otherwise push `IN (...)` past SQLite's bound-variable limit.
    final byDive = <String, List<MediaItem>>{};
    for (var i = 0; i < diveIds.length; i += _chunkSize) {
      final chunk = diveIds.sublist(i, min(i + _chunkSize, diveIds.length));
      final mediaQuery =
          _db.select(m).join([
              leftOuterJoin(
                _db.mediaEnrichment,
                _db.mediaEnrichment.mediaId.equalsExp(m.id),
              ),
            ])
            ..where(m.diveId.isIn(chunk) & m.id.isNotInQuery(taggedIds))
            ..orderBy([OrderingTerm.asc(m.takenAt), OrderingTerm.asc(m.id)]);
      for (final row in await mediaQuery.get()) {
        final item = mediaItemFromRow(
          row.readTable(m),
          row.readTableOrNull(_db.mediaEnrichment),
        );
        if (item.isDocument) continue;
        byDive.putIfAbsent(item.diveId!, () => []).add(item);
      }
    }

    return [
      for (final r in headers)
        if (byDive[r.read<String>('dive_id')] case final items?
            when items.isNotEmpty)
          SpeciesTagCandidateGroup(
            diveId: r.read<String>('dive_id'),
            diveNumber: r.read<int?>('dive_number'),
            diveDateTime: DateTime.fromMillisecondsSinceEpoch(
              r.read<int>('dive_date_time'),
            ),
            siteName: r.read<String?>('site_name'),
            sightingId: r.read<String>('sighting_id'),
            items: items,
          ),
    ];
  }

  /// The species tagged on one photo, in tag order, with what a chip needs.
  /// `rowid` breaks same-millisecond ties in insertion order; the uuid id
  /// would shuffle them.
  Future<List<SpeciesTagChip>> getTagChipsForMedia(String mediaId) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT sp.id, sp.common_name, sp.category, sp.is_built_in
      FROM media_species ms
      JOIN species sp ON sp.id = ms.species_id
      WHERE ms.media_id = ?
      ORDER BY ms.created_at ASC, ms.rowid ASC
    ''',
          variables: [Variable.withString(mediaId)],
        )
        .get();
    return rows.map((row) {
      final categoryName = row.read<String>('category');
      return SpeciesTagChip(
        speciesId: row.read<String>('id'),
        storedName: row.read<String>('common_name'),
        category: SpeciesCategory.values.firstWhere(
          (c) => c.name == categoryName,
          orElse: () => SpeciesCategory.other,
        ),
        isBuiltIn: row.read<bool>('is_built_in'),
      );
    }).toList();
  }

  /// How many distinct photos on [diveId] are tagged with each species.
  Future<Map<String, int>> getPhotoCountsBySpeciesForDive(String diveId) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT ms.species_id, COUNT(DISTINCT ms.media_id) AS n
      FROM media_species ms
      JOIN media m ON m.id = ms.media_id
      WHERE m.dive_id = ?
      GROUP BY ms.species_id
    ''',
          variables: [Variable.withString(diveId)],
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('species_id'): row.read<int>('n'),
    };
  }

  /// The newest tagged photo per species, for cover thumbnails. Derived,
  /// never chosen: a chosen cover would live on the species row, and
  /// built-in species rows never sync.
  Future<Map<String, MediaItem>> getCoverMediaBySpecies({
    String? diverId,
  }) async {
    final diverClause = diverId != null
        ? 'AND (m.dive_id IS NULL OR d.diver_id = ?)'
        : '';
    final rows = await _db
        .customSelect(
          '''
      SELECT species_id, media_id FROM (
        SELECT ms.species_id, ms.media_id,
               ROW_NUMBER() OVER (
                 PARTITION BY ms.species_id
                 ORDER BY m.taken_at DESC, m.id ASC
               ) AS rn
        FROM media_species ms
        JOIN media m ON m.id = ms.media_id
        LEFT JOIN dives d ON d.id = m.dive_id
        WHERE 1=1 $diverClause
      ) WHERE rn = 1
    ''',
          variables: [if (diverId != null) Variable.withString(diverId)],
        )
        .get();
    if (rows.isEmpty) return const {};
    final coverIdBySpecies = {
      for (final row in rows)
        row.read<String>('species_id'): row.read<String>('media_id'),
    };
    final items = await _getMediaByIds(coverIdBySpecies.values.toList());
    return {
      for (final entry in coverIdBySpecies.entries)
        entry.key: ?items[entry.value],
    };
  }

  /// Tag rows per species, the photo-side twin of
  /// `SpeciesRepository.sightingCountsBySpecies`.
  Future<Map<String, int>> tagCountsBySpecies() async {
    final rows = await _db
        .customSelect(
          'SELECT species_id, COUNT(*) AS n FROM media_species '
          'GROUP BY species_id',
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('species_id'): row.read<int>('n'),
    };
  }

  Future<Map<String, MediaItem>> _getMediaByIds(List<String> ids) async {
    final m = _db.media;
    final result = <String, MediaItem>{};
    for (var i = 0; i < ids.length; i += _chunkSize) {
      final chunk = ids.sublist(i, min(i + _chunkSize, ids.length));
      final query = _db.select(m).join([
        leftOuterJoin(
          _db.mediaEnrichment,
          _db.mediaEnrichment.mediaId.equalsExp(m.id),
        ),
      ])..where(m.id.isIn(chunk));
      for (final row in await query.get()) {
        final item = mediaItemFromRow(
          row.readTable(m),
          row.readTableOrNull(_db.mediaEnrichment),
        );
        result[item.id] = item;
      }
    }
    return result;
  }

  Expression<bool> _diverScope(String? diverId) {
    if (diverId == null) return const Constant(true);
    return _db.media.diveId.isNull() | _db.dives.diverId.equals(diverId);
  }

  Future<MediaSpecy?> _findTag(String mediaId, String speciesId) =>
      (_db.select(_db.mediaSpecies)
            ..where(
              (t) => t.mediaId.equals(mediaId) & t.speciesId.equals(speciesId),
            )
            ..limit(1))
          .getSingleOrNull();

  MediaSpeciesTag _tagFromRow(MediaSpecy row) => MediaSpeciesTag(
    id: row.id,
    mediaId: row.mediaId,
    speciesId: row.speciesId,
    sightingId: row.sightingId,
    bboxX: row.bboxX,
    bboxY: row.bboxY,
    bboxWidth: row.bboxWidth,
    bboxHeight: row.bboxHeight,
    notes: row.notes,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
  );
}
