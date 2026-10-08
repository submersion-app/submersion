import 'dart:convert';

import 'package:drift/drift.dart';

/// A dive_tanks row as the v260 backfill sees it. [role] is the stored
/// `tank_role` name.
typedef BackfillTank = ({
  String id,
  String? computerId,
  double o2,
  double he,
  String role,
  String? sharedComputerIds,
});

/// A computer that recorded pressures on a tank: a tank pressure series of
/// that computer (or of one of its data sources) sits on it.
typedef TankLoggedBy = ({String tankId, String computerId});

/// Same-gas tolerance the consolidation merge uses
/// (DiveConsolidationBuilder._gasTolerancePct).
const double _gasTolerancePct = 0.5;

/// The O2 share from which a cylinder is a deco gas rather than a bottom gas,
/// as the download path infers roles (parsed_tank_resolver's
/// _decoMinO2Percent).
const double _decoMinO2Percent = 41.0;

/// The `tank_role` names of a cylinder the diver starts the dive on.
const Set<String> _bottomGasRoles = {
  'backGas',
  'sidemountLeft',
  'sidemountRight',
};

/// Which computers share which of the primary's cylinders on one dive
/// consolidated before v260 recorded it: tank id -> computer ids.
///
/// Consolidation merges a secondary's cylinder only into a PRIMARY tank,
/// moves the secondary's pressure series onto it, and drops the secondary's
/// row. A secondary shares a primary tank when:
///
/// 1. Its pressure series sits on the tank ([loggedOn]): proof it logged
///    that cylinder.
/// 2. Otherwise, it has no cylinder of its own on the tank's gas, so one
///    was most likely merged away. This cannot tell a merged cylinder from
///    one the secondary never had, so it is held back where a wrong guess
///    changes the analysis: a bottom-gas tank is never shared with a
///    secondary that still has a bottom gas of its own, or the secondary
///    would start the dive on the primary's mix instead of its own (a backup
///    left on 21% beside a primary on 32% merged nothing). A deco or travel
///    gas shared by mistake only applies where a switch to it does, which
///    is the gas the diver breathed.
///
/// Tanks of other secondaries are never merge targets, so they are never
/// shared. A tank that already records its sharers is left alone.
Map<String, List<String>> inferSharedComputers({
  required String primaryComputerId,
  required Set<String> secondaryComputerIds,
  required List<BackfillTank> tanks,
  Set<TankLoggedBy> loggedOn = const {},
}) {
  bool sameGas(BackfillTank a, BackfillTank b) =>
      (a.o2 - b.o2).abs() <= _gasTolerancePct &&
      (a.he - b.he).abs() <= _gasTolerancePct;
  // Back gas and sidemount cylinders are bottom gas, unless at deco
  // strength: an import without roles labels every cylinder back gas.
  bool isBottomGas(BackfillTank t) =>
      _bottomGasRoles.contains(t.role) && t.o2 < _decoMinO2Percent;

  bool shares(String computer, BackfillTank tank) {
    if (loggedOn.contains((tankId: tank.id, computerId: computer))) {
      return true;
    }
    final own = [
      for (final t in tanks)
        if (t.computerId == computer) t,
    ];
    if (own.any((t) => sameGas(t, tank))) return false;
    return !(isBottomGas(tank) && own.any(isBottomGas));
  }

  final result = <String, List<String>>{};
  for (final tank in tanks) {
    if (tank.computerId != primaryComputerId) continue;
    if (tank.sharedComputerIds?.trim().isNotEmpty ?? false) continue;
    final sharers = [
      for (final computer in secondaryComputerIds.toList()..sort())
        if (shares(computer, tank)) computer,
    ];
    if (sharers.isNotEmpty) result[tank.id] = sharers;
  }
  return result;
}

/// The stored value of a cylinder recorded as shared with nobody; the same
/// marker as tank_shared_computers.dart's noSharedComputersRecorded, which
/// this layer does not import.
const String _recordedNobody = '[]';

/// v260: fills `dive_tanks.shared_computer_ids` on every consolidated dive
/// nothing has recorded it for yet (see [inferSharedComputers]).
///
/// Runs on upgrade and on every open, so a consolidated dive that arrives
/// after the upgrade (folded on a pre-v260 peer, or synced into a fresh
/// install, which runs no rungs) is inferred too. A dive is a candidate
/// while any cylinder of its primary computer, the only merge targets, is
/// unrecorded (null), and only those cylinders are inferred: a fold records
/// every cylinder it handled, and this records the rest of a dive it
/// infers, so a cylinder is never guessed twice and an open with nothing
/// new costs one query. A dive whose rows arrive partly recorded still has
/// its unrecorded primary cylinders inferred.
///
/// Local-only: deterministic from rows every device holds, so no HLC bump
/// and nothing marked pending.
Future<void> backfillTankSharedComputers(DatabaseConnectionUser db) async {
  Future<Set<String>> columnsOf(String table) async => {
    for (final c in await db.customSelect("PRAGMA table_info('$table')").get())
      c.read<String>('name'),
  };

  // A no-op until the column exists, and on a partial-schema fixture that
  // lacks what the inference reads.
  final tankCols = await columnsOf('dive_tanks');
  if (!tankCols.containsAll([
        'shared_computer_ids',
        'computer_id',
        'o2_percent',
        'he_percent',
      ]) ||
      !(await columnsOf(
        'dive_data_sources',
      )).containsAll(['id', 'computer_id', 'is_primary'])) {
    return;
  }
  final hasRole = tankCols.contains('tank_role');
  final seriesCols = await columnsOf('tank_pressure_series');
  final hasSeries = seriesCols.containsAll(['dive_id', 'tank_id']);

  // Consolidated dives (a primary computer plus another) with a primary
  // cylinder nothing has recorded yet.
  final sources = await db.customSelect('''
    SELECT id, dive_id, computer_id, is_primary FROM dive_data_sources
    WHERE computer_id IS NOT NULL AND dive_id IN (
      SELECT p.dive_id FROM dive_data_sources p
      WHERE p.is_primary = 1 AND p.computer_id IS NOT NULL
        AND EXISTS (
          SELECT 1 FROM dive_tanks t
          WHERE t.dive_id = p.dive_id
            AND t.computer_id = p.computer_id
            AND t.shared_computer_ids IS NULL
        )
        AND EXISTS (
          SELECT 1 FROM dive_data_sources o
          WHERE o.dive_id = p.dive_id
            AND o.computer_id IS NOT NULL
            AND o.computer_id <> p.computer_id
        )
    )
  ''').get();
  final primaryByDive = <String, String>{};
  final computersByDive = <String, Set<String>>{};
  final computerBySource = <String, String>{};
  for (final row in sources) {
    final diveId = row.read<String>('dive_id');
    final computerId = row.read<String>('computer_id');
    computersByDive.putIfAbsent(diveId, () => <String>{}).add(computerId);
    computerBySource[row.read<String>('id')] = computerId;
    if (row.read<bool>('is_primary')) primaryByDive[diveId] = computerId;
  }

  for (final entry in primaryByDive.entries) {
    final diveId = entry.key;
    final tankRows = await db
        .customSelect(
          'SELECT id, computer_id, o2_percent, he_percent, '
          '${hasRole ? 'tank_role' : "'backGas' AS tank_role"}, '
          'shared_computer_ids FROM dive_tanks WHERE dive_id = ?',
          variables: [Variable<String>(diveId)],
        )
        .get();
    final loggedOn = <TankLoggedBy>{};
    if (hasSeries) {
      final hasComputer = seriesCols.contains('computer_id');
      final hasSource = seriesCols.contains('source_id');
      final seriesRows = await db
          .customSelect(
            'SELECT tank_id, '
            '${hasComputer ? 'computer_id' : 'NULL AS computer_id'}, '
            '${hasSource ? 'source_id' : 'NULL AS source_id'} '
            'FROM tank_pressure_series WHERE dive_id = ?',
            variables: [Variable<String>(diveId)],
          )
          .get();
      for (final r in seriesRows) {
        final computer =
            r.read<String?>('computer_id') ??
            computerBySource[r.read<String?>('source_id')];
        if (computer != null) {
          loggedOn.add((
            tankId: r.read<String>('tank_id'),
            computerId: computer,
          ));
        }
      }
    }
    final shared = inferSharedComputers(
      primaryComputerId: entry.value,
      secondaryComputerIds: computersByDive[diveId]!.difference({entry.value}),
      tanks: [
        for (final r in tankRows)
          (
            id: r.read<String>('id'),
            computerId: r.read<String?>('computer_id'),
            o2: r.read<double>('o2_percent'),
            he: r.read<double>('he_percent'),
            role: r.read<String>('tank_role'),
            sharedComputerIds: r.read<String?>('shared_computer_ids'),
          ),
      ],
      loggedOn: loggedOn,
    );
    for (final tank in shared.entries) {
      await db.customUpdate(
        'UPDATE dive_tanks SET shared_computer_ids = ? WHERE id = ?',
        variables: [
          Variable<String>(jsonEncode(tank.value)),
          Variable<String>(tank.key),
        ],
      );
    }
  }

  // Every other unrecorded cylinder of each candidate is recorded as shared
  // with nobody, so the next open skips the dive.
  final candidates = computersByDive.keys.toList();
  const chunk = 500;
  for (var i = 0; i < candidates.length; i += chunk) {
    final ids = candidates.sublist(
      i,
      i + chunk > candidates.length ? candidates.length : i + chunk,
    );
    await db.customUpdate(
      'UPDATE dive_tanks SET shared_computer_ids = ? '
      'WHERE shared_computer_ids IS NULL '
      'AND dive_id IN (${List.filled(ids.length, '?').join(', ')})',
      variables: [
        const Variable<String>(_recordedNobody),
        for (final id in ids) Variable<String>(id),
      ],
    );
  }
}
