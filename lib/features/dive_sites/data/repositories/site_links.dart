import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';

/// The dives logged and dive plans set at a set of sites, read before a
/// delete clears them (issue #1952), so a confirmation can say how many rows
/// lose their site and an undo can point them back.
class SiteLinks {
  /// Dive id -> the site it was logged at.
  final Map<String, String> diveSiteIds;

  /// Dive plan id -> the site it was set at.
  final Map<String, String> planSiteIds;

  const SiteLinks({this.diveSiteIds = const {}, this.planSiteIds = const {}});
}

/// Reads the links every dive and plan holds to [siteIds]. Every dive
/// counts, excluded and planned ones included: the delete clears them all.
Future<SiteLinks> readLinksToSites(AppDatabase db, List<String> siteIds) async {
  if (siteIds.isEmpty) return const SiteLinks();
  final dives = await (db.select(
    db.dives,
  )..where((t) => t.siteId.isIn(siteIds))).get();
  final plans = await (db.select(
    db.divePlans,
  )..where((t) => t.siteId.isIn(siteIds))).get();
  return SiteLinks(
    diveSiteIds: {
      for (final d in dives)
        if (d.siteId != null) d.id: d.siteId!,
    },
    planSiteIds: {
      for (final p in plans)
        if (p.siteId != null) p.id: p.siteId!,
    },
  );
}

/// Points the dives and plans of [links] back at their sites, which must
/// exist again, stamping and marking each row it changes. A row deleted
/// since, or given another site since, is left alone: the undo must not
/// overwrite a newer choice.
Future<void> restoreLinksToSites(
  AppDatabase db,
  SyncRepository syncRepository,
  SiteLinks links, {
  required int now,
}) => db.transaction(() async {
  for (final MapEntry(key: id, value: siteId) in links.diveSiteIds.entries) {
    final changed =
        await (db.update(
          db.dives,
        )..where((t) => t.id.equals(id) & t.siteId.isNull())).write(
          DivesCompanion(siteId: Value(siteId), updatedAt: Value(now)),
        );
    if (changed == 0) continue;
    await syncRepository.markRecordPending(
      entityType: 'dives',
      recordId: id,
      localUpdatedAt: now,
    );
  }
  for (final MapEntry(key: id, value: siteId) in links.planSiteIds.entries) {
    final changed =
        await (db.update(
          db.divePlans,
        )..where((t) => t.id.equals(id) & t.siteId.isNull())).write(
          DivePlansCompanion(siteId: Value(siteId), updatedAt: Value(now)),
        );
    if (changed == 0) continue;
    await syncRepository.markRecordPending(
      entityType: 'divePlans',
      recordId: id,
      localUpdatedAt: now,
    );
  }
});
