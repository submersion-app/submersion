import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';

/// The data source of each tank of [diveId] (v251, issue #2716): the one it
/// records, else the one the v251 backfill's rules make unambiguous: the
/// dive has a single source; exactly one of its sources is the tank's
/// computer; or every pressure series of the tank carries one and the same
/// source of this dive. A merged cylinder (series from two sources) and a
/// tank with nothing to go on are left out, which readers take as the
/// dive's primary source. Read-only.
///
/// The source-moving paths (consolidation, split, uncombine) read it for a
/// dive they are about to take apart, whose rows they must not stage.
Future<Map<String, String>> resolveTankSources(
  AppDatabase db,
  String diveId,
) async {
  final tanks = await (db.select(
    db.diveTanks,
  )..where((t) => t.diveId.equals(diveId))).get();
  if (tanks.isEmpty) return const {};
  final sources = await (db.select(
    db.diveDataSources,
  )..where((s) => s.diveId.equals(diveId))).get();
  final sourceIds = {for (final s in sources) s.id};
  final unattributed = [
    for (final t in tanks)
      if (t.sourceId == null) t.id,
  ];
  final series = unattributed.isEmpty || sources.isEmpty
      ? const <TankPressureSeriesRow>[]
      : await (db.select(
          db.tankPressureSeries,
        )..where((p) => p.tankId.isIn(unattributed))).get();

  String? sourceOf(DiveTank tank) {
    if (tank.sourceId case final recorded?) return recorded;
    if (sources.isEmpty) return null;
    final computerId = tank.computerId;
    // The only source claims a tank of its own computer or of none, never
    // one that names another computer.
    if (sources.length == 1) {
      final only = sources.single;
      return computerId == null || computerId == only.computerId
          ? only.id
          : null;
    }
    if (computerId != null) {
      final ofComputer = [
        for (final s in sources)
          if (s.computerId == computerId) s.id,
      ];
      if (ofComputer.length == 1) return ofComputer.single;
    }
    final seriesSources = {
      for (final p in series)
        if (p.tankId == tank.id) p.sourceId,
    };
    if (seriesSources.length != 1) return null;
    final only = seriesSources.single;
    return only != null && sourceIds.contains(only) ? only : null;
  }

  return {for (final t in tanks) t.id: ?sourceOf(t)};
}

/// Stamps on each tank of [diveId] with no data source the one
/// [resolveTankSources] makes unambiguous, staging each for sync. Returns
/// the number stamped.
///
/// The writers call it once the dive's source rows exist: an import writes
/// its tanks before its source row, and a dive that is about to gain
/// another source (consolidation's target) is attributed while its own
/// tanks can still be told apart.
Future<int> attributeTankSources(
  AppDatabase db,
  SyncRepository syncRepository,
  String diveId, {
  required int now,
}) async {
  final unattributed = {
    for (final t in await (db.select(
      db.diveTanks,
    )..where((t) => t.diveId.equals(diveId) & t.sourceId.isNull())).get())
      t.id,
  };
  if (unattributed.isEmpty) return 0;
  final resolved = await resolveTankSources(db, diveId);
  var stamped = 0;
  await db.transaction(() async {
    for (final MapEntry(key: tankId, value: sourceId) in resolved.entries) {
      if (!unattributed.contains(tankId)) continue;
      await (db.update(db.diveTanks)..where((t) => t.id.equals(tankId))).write(
        DiveTanksCompanion(sourceId: Value(sourceId)),
      );
      await syncRepository.markRecordPending(
        entityType: 'diveTanks',
        recordId: tankId,
        localUpdatedAt: now,
      );
      stamped++;
    }
  });
  return stamped;
}

/// Nulls `source_id` on every tank [where] selects and stages those tanks,
/// like `clearTankComputerLinks`. Returns the number cleared.
///
/// Call it before deleting the sources the tanks name. The schema's ON
/// DELETE SET NULL would clear them too, but that write moves no clock, so
/// no peer would learn of it. The parent dive is deliberately NOT staged
/// (#1769).
Future<int> clearTankSourceLinks(
  AppDatabase db,
  SyncRepository syncRepository,
  Expression<bool> Function($DiveTanksTable t) where, {
  required int now,
}) async {
  final ids =
      await (db.selectOnly(db.diveTanks)
            ..addColumns([db.diveTanks.id])
            ..where(where(db.diveTanks)))
          .map((r) => r.read(db.diveTanks.id)!)
          .get();
  if (ids.isEmpty) return 0;
  await (db.update(
    db.diveTanks,
  )..where(where)).write(const DiveTanksCompanion(sourceId: Value(null)));
  for (final id in ids) {
    await syncRepository.markRecordPending(
      entityType: 'diveTanks',
      recordId: id,
      localUpdatedAt: now,
    );
  }
  return ids.length;
}
