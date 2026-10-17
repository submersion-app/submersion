part of 'insights_repository.dart';

/// The per-dive tank data behind the Gas page's tank configuration card
/// (issue #3421), kept beside the repository so the main file does not grow
/// further; a part shares its scope helpers.
extension InsightsRepositoryTankConfiguration on InsightsRepository {
  /// Each in-scope dive sorted by base configuration and extras.
  ///
  /// Uses the plain statistics scope, not the gas one: a dive whose gas data
  /// is excluded from SAC still carried the tanks it lists. On a dive
  /// consolidated from several recordings only the primary recording's
  /// cylinders count (see [_ownedByPrimary]), so a cylinder the merge could
  /// not match is not counted twice.
  Future<TankConfigurationStats> getTankConfigurationStats({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final variables = [
        for (final p in [?diverId, ...df.params]) Variable(p),
      ];
      final inScope =
          'SELECT d.id FROM dives d WHERE 1=1 $diverFilter ${df.clause}';

      final diveRows = await _db.customSelect('''
        SELECT d.id, d.dive_mode,
          EXISTS (SELECT 1 FROM dive_profile_series s
                  WHERE s.dive_id = d.id AND s.is_primary = 1) AS has_profile,
          p.id AS primary_source_id, p.computer_id AS primary_computer_id
        FROM dives d
        LEFT JOIN dive_data_sources p
          ON p.id = (SELECT id FROM dive_data_sources
                     WHERE dive_id = d.id AND is_primary = 1 LIMIT 1)
        WHERE 1=1 $diverFilter ${df.clause}
        ''', variables: variables).get();

      final tankRows = await _db.customSelect('''
        SELECT t.id, t.dive_id, t.tank_role, t.volume, t.start_pressure,
          t.end_pressure, t.o2_percent, t.he_percent, t.tank_order,
          t.tank_name, t.preset_name, t.computer_id, t.shared_computer_ids,
          t.source_id
        FROM dive_tanks t
        WHERE t.dive_id IN ($inScope)
        ORDER BY t.dive_id, t.tank_order
        ''', variables: variables).get();

      final switchRows = await _db.customSelect('''
        SELECT g.dive_id, g.tank_id, g.timestamp
        FROM gas_switches g
        WHERE g.dive_id IN ($inScope)
        ''', variables: variables).get();

      final tanksByDive = <String, List<domain.DiveTank>>{};
      for (final r in tankRows) {
        (tanksByDive[r.read<String>('dive_id')] ??= []).add(
          domain.DiveTank(
            id: r.read<String>('id'),
            name: r.read<String?>('tank_name'),
            presetName: r.read<String?>('preset_name'),
            volume: r.read<double?>('volume'),
            startPressure: r.read<double?>('start_pressure'),
            endPressure: r.read<double?>('end_pressure'),
            gasMix: domain.GasMix(
              o2: r.read<double>('o2_percent'),
              he: r.read<double>('he_percent'),
            ),
            role:
                _tankRolesByName[r.read<String>('tank_role')] ??
                TankRole.backGas,
            order: r.read<int>('tank_order'),
            computerId: r.read<String?>('computer_id'),
            sharedComputerIds: decodeSharedComputerIds(
              r.read<String?>('shared_computer_ids'),
            ),
            sourceId: r.read<String?>('source_id'),
          ),
        );
      }
      final switchesByDive = <String, List<({String tankId, int timestamp})>>{};
      for (final r in switchRows) {
        (switchesByDive[r.read<String>('dive_id')] ??= []).add((
          tankId: r.read<String>('tank_id'),
          timestamp: r.read<int>('timestamp'),
        ));
      }

      return TankConfigurationStats.fromDives([
        for (final r in diveRows)
          _tankConfigurationDive(r, tanksByDive, switchesByDive),
      ]);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get tank configuration statistics',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}

/// One dive's classifier input from its row, keeping only the cylinders
/// its primary recording owns. A primary that owns none (a bottom timer
/// that logs no cylinders) has no copies to double count, so the dive keeps
/// every cylinder rather than reading as no tanks.
TankConfigurationDive _tankConfigurationDive(
  QueryRow row,
  Map<String, List<domain.DiveTank>> tanksByDive,
  Map<String, List<({String tankId, int timestamp})>> switchesByDive,
) {
  final id = row.read<String>('id');
  final primarySourceId = row.read<String?>('primary_source_id');
  final primaryComputerId = row.read<String?>('primary_computer_id');
  final all = tanksByDive[id] ?? const <domain.DiveTank>[];
  final owned = [
    for (final t in all)
      if (_ownedByPrimary(
        t,
        primarySourceId: primarySourceId,
        primaryComputerId: primaryComputerId,
      ))
        t,
  ];
  return TankConfigurationDive(
    diveMode: _diveModesByName[row.read<String>('dive_mode')] ?? DiveMode.oc,
    tanks: owned.isEmpty ? all : owned,
    gasSwitches: switchesByDive[id] ?? const [],
    hasProfile: row.read<bool>('has_profile'),
  );
}

/// Whether [tank] belongs to the dive's primary recording, the rule
/// `tripCylinderIdsTakenFor` uses to tell one recording's cylinders from
/// another's copies. A tank that names a computer belongs when that is the
/// primary computer or consolidation shared it with the primary. A tank
/// that names no computer is its source's (#2716: a consolidated source
/// that names no computer), so it belongs when it has no source or the
/// primary source's; otherwise it is another recording's copy, whatever
/// the primary is. With no primary source every tank counts.
bool _ownedByPrimary(
  domain.DiveTank tank, {
  required String? primarySourceId,
  required String? primaryComputerId,
}) {
  if (primarySourceId == null) return true;
  if (tank.computerId == null) {
    final sourceId = tank.sourceId;
    return sourceId == null || sourceId == primarySourceId;
  }
  return primaryComputerId != null && tank.isUsedBy(primaryComputerId);
}

/// Stored roles by name, built once. A name this build does not know (a
/// newer peer's role) reads as back gas, the column's default.
final Map<String, TankRole> _tankRolesByName = TankRole.values.asNameMap();

/// Stored dive modes by name, built once. An unknown name reads as open
/// circuit, the column's default.
final Map<String, DiveMode> _diveModesByName = DiveMode.values.asNameMap();
