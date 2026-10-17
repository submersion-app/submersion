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
            role: _tankRoleByName(r.read<String>('tank_role')),
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
          TankConfigurationDive(
            diveMode: _diveModeByName(r.read<String>('dive_mode')),
            tanks: [
              for (final t in tanksByDive[r.read<String>('id')] ?? const [])
                if (_ownedByPrimary(
                  t,
                  primarySourceId: r.read<String?>('primary_source_id'),
                  primaryComputerId: r.read<String?>('primary_computer_id'),
                ))
                  t,
            ],
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

/// Whether [tank] belongs to the dive's primary recording, the rule
/// `tripCylinderIdsTakenFor` uses to tell one recording's cylinders from
/// another's copies. With a primary computer, the tank is its own, shared
/// with it by consolidation, or unattributed ([domain.DiveTank.isUsedBy]).
/// With a primary source that names no computer (#2716), the tank names no
/// computer and is that source's or the dive's own. With no primary source
/// every tank counts.
bool _ownedByPrimary(
  domain.DiveTank tank, {
  required String? primarySourceId,
  required String? primaryComputerId,
}) {
  if (primarySourceId == null) return true;
  if (primaryComputerId != null) return tank.isUsedBy(primaryComputerId);
  final sourceId = tank.sourceId;
  return tank.computerId == null &&
      (sourceId == null || sourceId == primarySourceId);
}

/// A stored role, or back gas for a name this build does not know (a newer
/// peer's role), matching the column's default.
TankRole _tankRoleByName(String name) =>
    TankRole.values.asNameMap()[name] ?? TankRole.backGas;

/// A stored dive mode, or open circuit for an unknown name, matching the
/// column's default.
DiveMode _diveModeByName(String name) =>
    DiveMode.values.asNameMap()[name] ?? DiveMode.oc;
