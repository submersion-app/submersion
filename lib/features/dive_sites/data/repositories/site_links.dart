import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';

/// How many dives and dive plans a delete of some sites would leave without
/// a site (issue #1952), for its confirmation.
class SiteUsage {
  final int dives;
  final int plans;

  const SiteUsage({this.dives = 0, this.plans = 0});
}

/// The links a site delete cleared, so an undo can point them back.
class SiteLinks {
  /// Dive id -> the site it was logged at.
  final Map<String, String> diveSiteIds;

  /// Dive plan id -> the site it was set at.
  final Map<String, String> planSiteIds;

  /// The `updated_at` the delete stamped on every row it cleared. A row
  /// whose stamp differs was edited since, and the undo leaves it alone.
  final int clearedAt;

  const SiteLinks({
    this.diveSiteIds = const {},
    this.planSiteIds = const {},
    this.clearedAt = 0,
  });
}

/// Counts every dive and plan at [siteIds]. Every dive counts, excluded and
/// planned ones included: the delete clears them all.
Future<SiteUsage> countLinksToSites(
  AppDatabase db,
  List<String> siteIds,
) async {
  if (siteIds.isEmpty) return const SiteUsage();
  final diveCount = db.dives.id.count();
  final planCount = db.divePlans.id.count();
  final dives =
      await (db.selectOnly(db.dives)
            ..addColumns([diveCount])
            ..where(db.dives.siteId.isIn(siteIds)))
          .map((row) => row.read(diveCount))
          .getSingle();
  final plans =
      await (db.selectOnly(db.divePlans)
            ..addColumns([planCount])
            ..where(db.divePlans.siteId.isIn(siteIds)))
          .map((row) => row.read(planCount))
          .getSingle();
  return SiteUsage(dives: dives ?? 0, plans: plans ?? 0);
}

/// Reads the links every dive and plan holds to [siteIds], as a delete that
/// stamps its clears with [clearedAt] is about to clear them. Run it inside
/// the delete's transaction, so the undo covers exactly the rows cleared.
Future<SiteLinks> readLinksToSites(
  AppDatabase db,
  List<String> siteIds, {
  required int clearedAt,
}) async {
  if (siteIds.isEmpty) return SiteLinks(clearedAt: clearedAt);
  final dives =
      await (db.selectOnly(db.dives)
            ..addColumns([db.dives.id, db.dives.siteId])
            ..where(db.dives.siteId.isIn(siteIds)))
          .get();
  final plans =
      await (db.selectOnly(db.divePlans)
            ..addColumns([db.divePlans.id, db.divePlans.siteId])
            ..where(db.divePlans.siteId.isIn(siteIds)))
          .get();
  return SiteLinks(
    diveSiteIds: {
      for (final row in dives)
        row.read(db.dives.id)!: row.read(db.dives.siteId)!,
    },
    planSiteIds: {
      for (final row in plans)
        row.read(db.divePlans.id)!: row.read(db.divePlans.siteId)!,
    },
    clearedAt: clearedAt,
  );
}

/// Points the dives and plans of [links] back at their sites, which must
/// exist again, stamping and marking each row it changes. Only a row still
/// exactly as the delete left it is restored: one deleted, given another
/// site, or saved again since carries a newer choice the undo must not
/// overwrite.
Future<void> restoreLinksToSites(
  AppDatabase db,
  SyncRepository syncRepository,
  SiteLinks links, {
  required int now,
}) => db.transaction(() async {
  for (final MapEntry(key: id, value: siteId) in links.diveSiteIds.entries) {
    final changed =
        await (db.update(db.dives)..where(
              (t) =>
                  t.id.equals(id) &
                  t.siteId.isNull() &
                  t.updatedAt.equals(links.clearedAt),
            ))
            .write(
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
        await (db.update(db.divePlans)..where(
              (t) =>
                  t.id.equals(id) &
                  t.siteId.isNull() &
                  t.updatedAt.equals(links.clearedAt),
            ))
            .write(
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
