import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/existing_row_ids.dart';

/// The rows a site delete removes through the `dive_sites` foreign-key
/// cascade: expected species, features, types and tags. The cascade writes
/// no tombstones, so an undo only has to put the rows back (issue #2718).
class SiteChildren {
  final List<SiteSpecy> species;
  final List<SiteFeature> features;
  final List<SiteSiteType> types;
  final List<SiteTag> tags;

  const SiteChildren({
    this.species = const [],
    this.features = const [],
    this.types = const [],
    this.tags = const [],
  });
}

/// Reads every child row of [siteIds] the delete is about to cascade away.
/// Run it inside the delete's transaction, so the undo covers exactly the
/// rows removed.
Future<SiteChildren> readSiteChildren(
  AppDatabase db,
  List<String> siteIds,
) async {
  if (siteIds.isEmpty) return const SiteChildren();
  return SiteChildren(
    species: await (db.select(
      db.siteSpecies,
    )..where((t) => t.siteId.isIn(siteIds))).get(),
    features: await (db.select(
      db.siteFeatures,
    )..where((t) => t.siteId.isIn(siteIds))).get(),
    types: await (db.select(
      db.siteSiteTypes,
    )..where((t) => t.siteId.isIn(siteIds))).get(),
    tags: await (db.select(
      db.siteTags,
    )..where((t) => t.siteId.isIn(siteIds))).get(),
  );
}

/// Puts [children] back under their own ids, each marked pending so its
/// clock is fresh and peers that cascaded it away take it back. The sites
/// must exist again. A row is skipped when its site is gone, when what it
/// points at (a species, a tag) was deleted since, or when a row with its
/// id is already there.
Future<void> restoreSiteChildren(
  AppDatabase db,
  SyncRepository syncRepository,
  SiteChildren children, {
  required int now,
}) => db.transaction(() async {
  final siteIds = await existingRowIds(db, db.diveSites, {
    for (final r in children.species) r.siteId,
    for (final r in children.features) r.siteId,
    for (final r in children.types) r.siteId,
    for (final r in children.tags) r.siteId,
  });
  final speciesIds = await existingRowIds(db, db.species, {
    for (final r in children.species) r.speciesId,
  });
  final tagIds = await existingRowIds(db, db.tags, {
    for (final r in children.tags) r.tagId,
  });

  Future<void> restore<T extends Table, D>(
    TableInfo<T, D> table,
    Insertable<D> row,
    String entityType,
    String id,
  ) async {
    final inserted = await db
        .into(table)
        .insertReturningOrNull(
          row,
          onConflict: DoNothing<T, D>(target: const []),
        );
    if (inserted == null) return;
    await syncRepository.markRecordPending(
      entityType: entityType,
      recordId: id,
      localUpdatedAt: now,
    );
  }

  for (final r in children.species) {
    if (!siteIds.contains(r.siteId) || !speciesIds.contains(r.speciesId)) {
      continue;
    }
    await restore(db.siteSpecies, r, 'siteSpecies', r.id);
  }
  for (final r in children.features) {
    if (!siteIds.contains(r.siteId)) continue;
    await restore(db.siteFeatures, r, 'siteFeatures', r.id);
  }
  // A type id has no foreign key (a custom type can arrive by sync after
  // its junction row), so only the site is checked.
  for (final r in children.types) {
    if (!siteIds.contains(r.siteId)) continue;
    await restore(db.siteSiteTypes, r, 'siteSiteTypes', r.id);
  }
  for (final r in children.tags) {
    if (!siteIds.contains(r.siteId) || !tagIds.contains(r.tagId)) continue;
    await restore(db.siteTags, r, 'siteTags', r.id);
  }
});
