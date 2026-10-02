import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/existing_row_ids.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';

/// Media rows a delete is about to remove, with the rows that hang off
/// them, so an undo can put them back (issue #2718). Enrichment is
/// deleted and tombstoned explicitly; species tags go by the foreign-key
/// cascade, which writes no tombstone.
class MediaRowsSnapshot {
  final List<MediaData> rows;
  final List<MediaSpecy> species;
  final List<MediaEnrichmentData> enrichment;

  const MediaRowsSnapshot({
    this.rows = const [],
    this.species = const [],
    this.enrichment = const [],
  });
}

/// Reads media [ids] and their species tags and enrichment. Read it before
/// the delete, while the rows still exist.
Future<MediaRowsSnapshot> readMediaRows(
  AppDatabase db,
  List<String> ids,
) async {
  if (ids.isEmpty) return const MediaRowsSnapshot();
  final rows = <MediaData>[];
  final species = <MediaSpecy>[];
  final enrichment = <MediaEnrichmentData>[];
  for (final chunk in seriesIdChunks(ids)) {
    rows.addAll(
      await (db.select(db.media)..where((t) => t.id.isIn(chunk))).get(),
    );
    species.addAll(
      await (db.select(
        db.mediaSpecies,
      )..where((t) => t.mediaId.isIn(chunk))).get(),
    );
    enrichment.addAll(
      await (db.select(
        db.mediaEnrichment,
      )..where((t) => t.mediaId.isIn(chunk))).get(),
    );
  }
  return MediaRowsSnapshot(
    rows: rows,
    species: species,
    enrichment: enrichment,
  );
}

/// The site each media row at [siteIds] is linked to, read before a site
/// delete clears or removes them, so an undo can link them back.
Future<Map<String, String>> readMediaSiteIds(
  AppDatabase db,
  List<String> siteIds,
) async {
  if (siteIds.isEmpty) return const {};
  final rows =
      await (db.selectOnly(db.media)
            ..addColumns([db.media.id, db.media.siteId])
            ..where(db.media.siteId.isIn(siteIds)))
          .get();
  return {
    for (final row in rows) row.read(db.media.id)!: row.read(db.media.siteId)!,
  };
}

/// Puts the rows of [snapshot] back under their own ids, drops their
/// tombstones and marks them pending with fresh clocks, facts included, as
/// [MediaRepository.createMedia] does for a new row. A link whose target
/// was deleted since is cleared, as its foreign key's SET NULL would have;
/// a species tag or enrichment row whose parent is gone is skipped. A row
/// already present is left alone. Returns the media rows it put back.
Future<List<MediaData>> restoreMediaRows(
  AppDatabase db,
  SyncRepository syncRepository,
  MediaRowsSnapshot snapshot, {
  required int now,
}) => db.transaction(() async {
  final rows = snapshot.rows;
  final dives = await existingRowIds(db, db.dives, {
    for (final r in rows) ?r.diveId,
    for (final r in snapshot.enrichment) r.diveId,
  });
  final sites = await existingRowIds(db, db.diveSites, {
    for (final r in rows) ?r.siteId,
  });
  final buddies = await existingRowIds(db, db.buddies, {
    for (final r in rows) ?r.signerId,
  });
  final gear = await existingRowIds(db, db.equipment, {
    for (final r in rows) ?r.equipmentId,
  });
  String? kept(String? id, Set<String> existing) =>
      id != null && existing.contains(id) ? id : null;

  final restored = <MediaData>[];
  for (final row in rows) {
    final inserted = await db
        .into(db.media)
        .insertReturningOrNull(
          row.copyWith(
            diveId: Value(kept(row.diveId, dives)),
            siteId: Value(kept(row.siteId, sites)),
            signerId: Value(kept(row.signerId, buddies)),
            equipmentId: Value(kept(row.equipmentId, gear)),
          ),
          onConflict: DoNothing<$MediaTable, MediaData>(target: const []),
        );
    if (inserted == null) continue;
    // Left in place, the delete's tombstone would ride the next changeset
    // beside the row and delete it on every peer.
    await syncRepository.removeDeletion(entityType: 'media', recordId: row.id);
    await syncRepository.markRecordPending(
      entityType: 'media',
      recordId: row.id,
      localUpdatedAt: now,
      alsoStamp: SyncFactGroups.of('media'),
    );
    restored.add(inserted);
  }

  final back = {for (final r in restored) r.id};
  final species = await existingRowIds(db, db.species, {
    for (final r in snapshot.species) r.speciesId,
  });
  final sightings = await existingRowIds(db, db.sightings, {
    for (final r in snapshot.species) ?r.sightingId,
  });
  for (final r in snapshot.species) {
    if (!back.contains(r.mediaId) || !species.contains(r.speciesId)) continue;
    final inserted = await db
        .into(db.mediaSpecies)
        .insertReturningOrNull(
          r.copyWith(sightingId: Value(kept(r.sightingId, sightings))),
          onConflict: DoNothing<$MediaSpeciesTable, MediaSpecy>(
            target: const [],
          ),
        );
    if (inserted == null) continue;
    await syncRepository.markRecordPending(
      entityType: 'mediaSpecies',
      recordId: r.id,
      localUpdatedAt: now,
    );
  }
  for (final r in snapshot.enrichment) {
    if (!back.contains(r.mediaId) || !dives.contains(r.diveId)) continue;
    final inserted = await db
        .into(db.mediaEnrichment)
        .insertReturningOrNull(
          r,
          onConflict: DoNothing<$MediaEnrichmentTable, MediaEnrichmentData>(
            target: const [],
          ),
        );
    if (inserted == null) continue;
    await syncRepository.removeDeletion(
      entityType: 'mediaEnrichment',
      recordId: r.id,
    );
    await syncRepository.markRecordPending(
      entityType: 'mediaEnrichment',
      recordId: r.id,
      localUpdatedAt: now,
    );
  }
  return restored;
});

/// Links each media row of [siteIds] (media id -> site id) back to its
/// site, stamped and marked pending. Only a row with no site is changed:
/// one linked elsewhere since carries a newer choice. A site that does not
/// exist is skipped.
Future<void> relinkMediaToSites(
  AppDatabase db,
  SyncRepository syncRepository,
  Map<String, String> siteIds, {
  required int now,
}) => db.transaction(() async {
  final sites = await existingRowIds(db, db.diveSites, siteIds.values.toSet());
  for (final MapEntry(key: id, value: siteId) in siteIds.entries) {
    if (!sites.contains(siteId)) continue;
    final changed =
        await (db.update(
          db.media,
        )..where((t) => t.id.equals(id) & t.siteId.isNull())).write(
          MediaCompanion(siteId: Value(siteId), updatedAt: Value(now)),
        );
    if (changed == 0) continue;
    await syncRepository.markRecordPending(
      entityType: 'media',
      recordId: id,
      localUpdatedAt: now,
    );
  }
});
