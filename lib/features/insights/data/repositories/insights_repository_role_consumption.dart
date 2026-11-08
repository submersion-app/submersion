part of 'insights_repository.dart';

/// The per-dive figures behind the Gas page's consumption by cylinder role
/// card and the planner's logged default SAC (issue #771), kept beside the
/// repository so the main file does not grow further; a part shares its scope
/// helpers.
extension InsightsRepositoryRoleConsumption on InsightsRepository {
  /// Consumption by cylinder role for every dive in scope, both lanes.
  ///
  /// Runs the dive detail's own per-cylinder calculation on each dive, so a
  /// role with one cylinder reads the same in both places, with depth from the
  /// dive's 120-point profile summary. Open-circuit groups use the
  /// consumption rate scope, which leaves out CCR, SCR and gauge dives. A CCR
  /// dive feeds only the bailout group, through the gas scope, as the
  /// Rebreather gas use card does.
  Future<RoleConsumptionTrend> getRoleConsumptionPerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      return await PerfTimer.measure('roleConsumptionPerDive', () async {
        final rows = [
          ...await _roleConsumptionDiveRows(
            diverId,
            _diveFilter(filter, alias: 'd', consumptionRate: true),
          ),
          ...await _roleConsumptionDiveRows(
            diverId,
            _diveFilter(filter, alias: 'd', gas: true),
            ccrOnly: true,
          ),
        ]..sort((a, b) => a.dateTime.compareTo(b.dateTime));

        final memo = _roleConsumptionMemo;
        final stale = {
          for (final row in rows)
            if (memo[row.id]?.version != row.version) row.id: row,
        };
        for (final chunk in InsightsRepository._diveChunks(
          stale.keys.toList(),
        )) {
          final uses = await _roleConsumptionForDives(chunk, stale);
          for (final MapEntry(key: id, value: use) in uses.entries) {
            memo[id] = (version: stale[id]!.version, use: use);
          }
        }

        final rmv = <ConsumptionRoleGroup, List<TrendDataPoint>>{};
        final sac = <ConsumptionRoleGroup, List<TrendDataPoint>>{};
        var leftOutDives = 0;
        for (final row in rows) {
          final use = memo[row.id]?.use;
          if (use == null) continue;
          if (use.leftOut) {
            leftOutDives++;
            continue;
          }
          for (final (figures, series) in [(use.rmv, rmv), (use.sac, sac)]) {
            for (final MapEntry(key: group, value: value) in figures.entries) {
              series
                  .putIfAbsent(group, () => [])
                  .add(
                    TrendDataPoint(
                      date: row.dateTime,
                      value: value,
                      diveId: row.id,
                    ),
                  );
            }
          }
        }
        return RoleConsumptionTrend(
          rmv: rmv,
          sac: sac,
          leftOutDives: leftOutDives,
        );
      });
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get consumption by cylinder role per dive',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Works out consumption by cylinder role for the dives [ids], one chunk:
  /// the dive detail's own per-cylinder calculation on each, with depth from
  /// its 120-point profile summary.
  Future<Map<String, DiveRoleConsumption>> _roleConsumptionForDives(
    List<String> ids,
    Map<String, _RoleConsumptionDiveRow> rowsById,
  ) async {
    final dives = {
      for (final dive in await _diveRepository.getDivesByIdsWithoutSamples(ids))
        dive.id: dive,
    };
    final switches = await _diveRepository.getGasSwitchesForDives(ids);
    final pressures = await _tankPressureRepository
        .getDisplayedTankPressuresForDives(ids);
    final profiles = await _diveRepository.getBatchProfileSummaries(ids);

    final service = GasAnalysisService(gasModel: gasModel);
    final uses = <String, DiveRoleConsumption>{};
    for (final id in ids) {
      final dive = dives[id];
      if (dive == null) continue;
      final row = rowsById[id]!;
      final profile = profiles[id] ?? const <DiveProfilePoint>[];
      uses[id] = roleConsumptionForDive(
        dive: dive,
        cylinders: service.calculateCylinderSac(
          dive: dive,
          profile: profile,
          gasSwitches: switches[id],
          tankPressures: pressures[id],
        ),
        profile: profile,
        tankPressures: pressures[id],
        // A dive consolidated from two computers can keep a copy of a
        // cylinder from each, and these figures add cylinders up.
        counted: (tank) => tankOwnedByPrimary(
          tank,
          primarySourceId: row.primarySourceId,
          primaryComputerId: row.primaryComputerId,
        ),
      );
    }
    return uses;
  }

  /// The dives in [scope] with at least one cylinder, with their primary
  /// source and computer; only CCR dives when [ccrOnly].
  Future<List<_RoleConsumptionDiveRow>> _roleConsumptionDiveRows(
    String? diverId,
    ({String clause, List<Object?> params}) scope, {
    bool ccrOnly = false,
  }) async {
    final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
    final modeFilter = ccrOnly ? "AND d.dive_mode = 'ccr'" : '';
    final rows = await _db
        .customSelect(
          '''
        SELECT d.id, d.dive_date_time,
          ${diveSourceStampSql('d')} AS stamp,
          (SELECT COUNT(*) || ':' || COALESCE(SUM(sw.timestamp), 0) || ':' ||
             COALESCE(GROUP_CONCAT(sw.tank_id), '')
           FROM gas_switches sw WHERE sw.dive_id = d.id) AS switches,
          (SELECT id FROM dive_data_sources
           WHERE dive_id = d.id AND is_primary = 1 LIMIT 1) AS primary_source_id,
          (SELECT computer_id FROM dive_data_sources
           WHERE dive_id = d.id AND is_primary = 1 LIMIT 1) AS primary_computer_id
        FROM dives d
        WHERE EXISTS (SELECT 1 FROM dive_tanks t WHERE t.dive_id = d.id)
          $modeFilter $diverFilter ${scope.clause}
        ORDER BY d.dive_date_time
        ''',
          variables: [
            for (final p in [?diverId, ...scope.params]) Variable(p),
          ],
        )
        .get();
    return [
      for (final row in rows)
        (
          id: row.read<String>('id'),
          dateTime: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('dive_date_time'),
            isUtc: true,
          ),
          primarySourceId: row.read<String?>('primary_source_id'),
          primaryComputerId: row.read<String?>('primary_computer_id'),
          // The dive and every child its figures read: profile and pressure
          // series and tanks (the source stamp), gas switches, and which
          // recording is primary. Synced children never re-stamp the dive.
          version: [
            row.read<int>('stamp'),
            row.read<String>('switches'),
            row.read<String?>('primary_source_id'),
            row.read<String?>('primary_computer_id'),
          ].join('|'),
        ),
    ];
  }
}

typedef _RoleConsumptionDiveRow = ({
  String id,
  DateTime dateTime,
  String? primarySourceId,
  String? primaryComputerId,
  String version,
});
