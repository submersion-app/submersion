part of 'insights_repository.dart';

/// The per-dive tank data behind the Gas page's tank configuration card
/// (issue #3421), kept beside the repository so the main file does not grow
/// further; a part shares its scope helpers.
extension InsightsRepositoryTankConfiguration on InsightsRepository {
  /// Each in-scope dive sorted by base configuration and extras.
  ///
  /// Uses the plain statistics scope, not the gas one: a dive whose gas data
  /// is excluded from SAC still carried the tanks it lists. On a dive
  /// consolidated from several computers only the primary computer's
  /// cylinders count, plus any with no computer (added by hand), so a
  /// cylinder the merge could not match is not counted twice.
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
                  WHERE s.dive_id = d.id AND s.is_primary = 1) AS has_profile
        FROM dives d
        WHERE 1=1 $diverFilter ${df.clause}
        ''', variables: variables).get();

      final tankRows = await _db.customSelect('''
        SELECT t.id, t.dive_id, t.tank_role, t.volume, t.start_pressure,
          t.end_pressure, t.o2_percent, t.he_percent, t.tank_order,
          t.tank_name, t.preset_name
        FROM dive_tanks t
        WHERE t.dive_id IN ($inScope)
          AND (
            t.computer_id IS NULL
            OR NOT EXISTS (
              SELECT 1 FROM dive_data_sources p
              WHERE p.dive_id = t.dive_id AND p.is_primary = 1
                AND p.computer_id IS NOT NULL
            )
            OR t.computer_id IN (
              SELECT p.computer_id FROM dive_data_sources p
              WHERE p.dive_id = t.dive_id AND p.is_primary = 1
            )
          )
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
            role: _tankRoleByName(r.read<String>('tank_role')),
            order: r.read<int>('tank_order'),
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
          TankConfigurationDive(
            diveMode: _diveModeByName(r.read<String>('dive_mode')),
            tanks: tanksByDive[r.read<String>('id')] ?? const [],
            gasSwitches: switchesByDive[r.read<String>('id')] ?? const [],
            hasProfile: r.read<bool>('has_profile'),
          ),
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

/// A stored role, or back gas for a name this build does not know (a newer
/// peer's role), matching the column's default.
TankRole _tankRoleByName(String name) =>
    TankRole.values.asNameMap()[name] ?? TankRole.backGas;

/// A stored dive mode, or open circuit for an unknown name, matching the
/// column's default.
DiveMode _diveModeByName(String name) =>
    DiveMode.values.asNameMap()[name] ?? DiveMode.oc;
