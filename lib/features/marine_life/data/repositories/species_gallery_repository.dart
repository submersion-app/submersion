import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/marine_life/domain/entities/species_crop.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';

/// The crops of the animals the diver has photographed, per species
/// (issue #5027).
///
/// A crop counts for a species when its identification is accepted for the
/// species and the media still carries the species' tag. Each media item
/// gives one crop per species, its largest box. Media follow the library's
/// rule (the diver's dives, or no dive at all); the practice pool is further
/// limited to species on the diver's life list.
class SpeciesGalleryRepository {
  AppDatabase get _db => DatabaseService.instance.database;

  /// Every write that can change a crop list.
  Stream<void> watchChanges() {
    final db = _db;
    return db.tableUpdates(
      TableUpdateQuery.onAllTables([
        db.mediaIdentifications,
        db.mediaSpecies,
        db.media,
        db.mediaIdentificationCrops,
      ]),
    );
  }

  /// The best crop of each species: the largest box, newest media on a tie.
  Future<Map<String, SpeciesCrop>> bestCropBySpecies({String? diverId}) async {
    final rows = await _select(
      partitionBy: 'mi.decided_species_id',
      diverId: diverId,
    );
    return {for (final row in rows) row.speciesId: row.crop};
  }

  /// One crop per media item of [speciesId], newest media first.
  Future<List<SpeciesCrop>> cropsForSpecies(
    String speciesId, {
    String? diverId,
  }) async {
    final rows = await _select(
      partitionBy: 'mi.media_id',
      diverId: diverId,
      speciesId: speciesId,
    );
    return [for (final row in rows) row.crop];
  }

  /// The confirmed crops, one per media item, of each species on the
  /// diver's life list: what practice may show.
  Future<Map<String, List<SpeciesCrop>>> practicePool({String? diverId}) async {
    final rows = await _select(
      partitionBy: 'mi.decided_species_id, mi.media_id',
      diverId: diverId,
      confirmedOnly: true,
      lifeListOnly: true,
    );
    final pool = <String, List<SpeciesCrop>>{};
    for (final row in rows) {
      pool.putIfAbsent(row.speciesId, () => []).add(row.crop);
    }
    return pool;
  }

  Future<List<({String speciesId, SpeciesCrop crop})>> _select({
    required String partitionBy,
    String? diverId,
    String? speciesId,
    bool confirmedOnly = false,
    bool lifeListOnly = false,
  }) async {
    final diverClause = diverId == null
        ? ''
        : 'AND (m.dive_id IS NULL OR d.diver_id = ?)';
    final speciesClause = speciesId == null
        ? ''
        : 'AND mi.decided_species_id = ?';
    final confirmedClause = confirmedOnly
        ? 'AND COALESCE(ms.unconfirmed, 0) = 0'
        : '';
    final lifeListClause = lifeListOnly
        ? '''
          AND EXISTS (
            SELECT 1 FROM sightings s
            JOIN dives ld ON ld.id = s.dive_id
            WHERE s.species_id = mi.decided_species_id
              ${diverId == null ? '' : 'AND ld.diver_id = ?'}
              ${DiveStatsScope.and(alias: 'ld')}
          )'''
        : '';
    final rows = await _db
        .customSelect(
          '''
      SELECT * FROM (
        SELECT mi.id, mi.media_id, mi.decided_species_id AS species_id,
               mi.box_x, mi.box_y, mi.box_width, mi.box_height,
               MIN(mi.box_pixel_width, mi.box_pixel_height) AS shorter_side,
               mi.best_ms, m.file_type, m.taken_at,
               COALESCE(ms.unconfirmed, 0) AS unconfirmed,
               ROW_NUMBER() OVER (
                 PARTITION BY $partitionBy
                 ORDER BY MIN(mi.box_pixel_width, mi.box_pixel_height) DESC,
                          m.taken_at DESC, mi.id ASC
               ) AS rn
        FROM media_identifications mi
        JOIN media m ON m.id = mi.media_id
        JOIN media_species ms
          ON ms.media_id = mi.media_id
         AND ms.species_id = mi.decided_species_id
        LEFT JOIN dives d ON d.id = m.dive_id
        WHERE mi.decision = 'accepted'
          AND mi.decided_species_id IS NOT NULL
          $diverClause $speciesClause $confirmedClause $lifeListClause
      )
      WHERE rn = 1
      ORDER BY taken_at DESC, id ASC
    ''',
          variables: [
            if (diverId != null) Variable.withString(diverId),
            if (speciesId != null) Variable.withString(speciesId),
            if (lifeListOnly && diverId != null) Variable.withString(diverId),
          ],
        )
        .get();
    return [for (final row in rows) _fromRow(row)];
  }

  ({String speciesId, SpeciesCrop crop}) _fromRow(QueryRow row) {
    final takenAt = row.readNullable<int>('taken_at');
    return (
      speciesId: row.read<String>('species_id'),
      crop: SpeciesCrop(
        identificationId: row.read<String>('id'),
        mediaId: row.read<String>('media_id'),
        box: IdentificationBox(
          x: row.read<double>('box_x'),
          y: row.read<double>('box_y'),
          width: row.read<double>('box_width'),
          height: row.read<double>('box_height'),
        ),
        shorterSide: row.read<int>('shorter_side'),
        bestMs: row.readNullable<int>('best_ms'),
        isVideo: row.read<String>('file_type') == 'video',
        // Stored as a wall clock flagged UTC, as dive times are.
        takenAt: takenAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(takenAt, isUtc: true),
        confirmed: row.read<int>('unconfirmed') == 0,
      ),
    );
  }
}
