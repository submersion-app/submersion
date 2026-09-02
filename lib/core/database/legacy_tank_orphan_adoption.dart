/// The pressure-row orphan adoption the packer runs before it packs.
///
/// Split from `profile_series_pack.dart` to keep that file under the
/// project's 800-line limit. It is a pre-pass over the legacy table rather
/// than part of the pack: it rewrites `tank_id` in place so the rows the
/// packer then reads already name a tank the dive still has.
library;

import 'package:drift/drift.dart';
import 'package:submersion/core/database/profile_series_pack_coverage.dart';

/// Re-points pressure rows whose tank id is no longer one of the dive's
/// tanks at a tank that is, in place, before anything is packed.
///
/// `tank_pressure_series.tank_id` is a NOT NULL foreign key, so an orphan
/// cannot be packed as it stands, and after v183 every reader reads series:
/// leaving it behind drops that dive's pressure curve and per-cylinder SAC,
/// and its rows keep the legacy table alive forever, since the residue
/// count can never cover a tank that does not exist.
///
/// The rule is the v102 rung's ([AppDatabase] `_relinkStrandedTankPressures`)
/// and `GasAnalysisService`'s read-time resolver, so a dive reads the same
/// before and after packing: exact id matches are left alone, and the
/// remaining orphans, in first-sample order, are paired with the dive's
/// still-unmatched tanks in tank order. Both sides are totally ordered
/// (ties broken by id) and every device runs it over the same rows, so two
/// devices packing the same logbook reach the same tank ids and the derived
/// series ids still converge.
///
/// Healing the rows rather than remapping in memory keeps everything
/// downstream, the coverage predicate and residue count included, working
/// on ids that exist. Idempotent: a second run finds no orphans.
Future<void> adoptStrandedTankPressures(
  DatabaseConnectionUser db,
  String table,
) async {
  if (!await legacyTableExists(db, 'dive_tanks')) return;
  final tankColumns = await legacyColumnNames(db, 'dive_tanks');
  if (!tankColumns.containsAll(const {'id', 'dive_id'})) return;
  final hasOrder = tankColumns.contains('tank_order');
  final tankRows = await db
      .customSelect(
        'SELECT dive_id, id${hasOrder ? ', tank_order' : ''} FROM dive_tanks',
      )
      .get();
  final tanksByDive = <String, List<({String id, int order})>>{};
  for (final r in tankRows) {
    (tanksByDive[r.read<String>('dive_id')] ??= []).add((
      id: r.read<String>('id'),
      order: hasOrder ? (r.readNullable<int>('tank_order') ?? 0) : 0,
    ));
  }
  if (tanksByDive.isEmpty) return;

  // Filtered on storage class, not just on NULL. This is a prologue: it
  // runs before the first dive's transaction and OUTSIDE the per-dive
  // try/catch the rest of the design rests on, so a throw here costs every
  // dive rather than one, on this open and on every later one. And SQLite
  // orders storage classes, so MIN over a group whose values are all text
  // returns text; drift's `read<int>` converts by parsing, which throws a
  // FormatException on anything but a numeric string. A row this filter
  // excludes holds no readable sample anyway, and the packer's own loops
  // step over it for exactly the same reason.
  final keyRows = await db
      .customSelect(
        'SELECT dive_id, tank_id, MIN(timestamp) AS first_ts FROM $table '
        'WHERE ${readableTextSql('tank_id')} '
        'AND ${readableNumberSql('timestamp')} '
        'GROUP BY dive_id, tank_id',
      )
      .get();
  final keysByDive = <String, List<({String tankId, int firstTs})>>{};
  for (final r in keyRows) {
    (keysByDive[r.read<String>('dive_id')] ??= []).add((
      tankId: r.read<String>('tank_id'),
      firstTs: r.read<int>('first_ts'),
    ));
  }

  for (final entry in keysByDive.entries) {
    final diveId = entry.key;
    final tanks = tanksByDive[diveId];
    if (tanks == null || tanks.isEmpty) continue;
    final currentIds = {for (final t in tanks) t.id};
    final matchedIds = {
      for (final k in entry.value)
        if (currentIds.contains(k.tankId)) k.tankId,
    };
    final orphans =
        [
          for (final k in entry.value)
            if (!currentIds.contains(k.tankId)) k,
        ]..sort((a, b) {
          final byTime = a.firstTs.compareTo(b.firstTs);
          return byTime != 0 ? byTime : a.tankId.compareTo(b.tankId);
        });
    if (orphans.isEmpty) continue;
    final free =
        [
          for (final t in tanks)
            if (!matchedIds.contains(t.id)) t,
        ]..sort((a, b) {
          // id tie-break: tanks sharing the default order must still pair
          // deterministically, and Dart's sort is not stable.
          final byOrder = a.order.compareTo(b.order);
          return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
        });
    final pairs = orphans.length < free.length ? orphans.length : free.length;
    for (var i = 0; i < pairs; i++) {
      await db.customStatement(
        'UPDATE $table SET tank_id = ? WHERE dive_id = ? AND tank_id = ?',
        [free[i].id, diveId, orphans[i].tankId],
      );
    }
  }
}
