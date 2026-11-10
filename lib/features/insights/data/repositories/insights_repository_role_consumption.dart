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

        final unkept = await _refreshRoleConsumption(rows);
        final memo = _roleConsumptionMemo;

        final rmv = <ConsumptionRoleGroup, List<TrendDataPoint>>{};
        final sac = <ConsumptionRoleGroup, List<TrendDataPoint>>{};
        var leftOutDives = 0;
        for (final row in rows) {
          final kept = memo[row.id];
          final use =
              unkept[row.id] ??
              (kept?.version == row.version ? kept?.use : null);
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

  /// Works out the dives of [rows] whose version moved since the memo last
  /// saw them, once any refresh already running has finished. Two reads at
  /// once (the Gas page and the planner's logged default) would otherwise
  /// work out the same dives side by side, and the older could store its
  /// figures over the newer's.
  ///
  /// Returns the figures of dives whose batch reads came back incomplete:
  /// this read shows them, and the memo does not keep them.
  Future<Map<String, DiveRoleConsumption>> _refreshRoleConsumption(
    List<_RoleConsumptionDiveRow> rows,
  ) {
    final previous = _roleConsumptionRefresh;
    final refresh = () async {
      try {
        await previous;
      } catch (_) {
        // That read has already reported its own failure.
      }
      final memo = _roleConsumptionMemo;
      final stale = {
        for (final row in rows)
          if (memo[row.id]?.version != row.version) row.id: row,
      };
      final unkept = <String, DiveRoleConsumption>{};
      for (final chunk in InsightsRepository._diveChunks(stale.keys.toList())) {
        final (:uses, :incomplete) = await _roleConsumptionForDives(
          chunk,
          stale,
        );
        for (final MapEntry(key: id, value: use) in uses.entries) {
          if (!incomplete.contains(id)) {
            memo[id] = (version: stale[id]!.version, use: use);
          } else {
            unkept[id] = use;
          }
        }
      }
      return unkept;
    }();
    _roleConsumptionRefresh = refresh;
    return refresh;
  }

  /// Works out consumption by cylinder role for the dives [ids], one chunk:
  /// the dive detail's own per-cylinder calculation on each, with depth from
  /// its 120-point profile summary.
  ///
  /// A dive is [incomplete] when the gas switch or profile summary read left
  /// it out although it has some. Both reads log a failure and return
  /// nothing rather than throw, and the profile read also leaves out just
  /// the dives whose series it could not decode.
  Future<({Map<String, DiveRoleConsumption> uses, Set<String> incomplete})>
  _roleConsumptionForDives(
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
      // A dive consolidated from two computers can keep a copy of a
      // cylinder from each, and these figures add cylinders up.
      final counted = countedCylinderIds(
        dive.tanks,
        primarySourceId: row.primarySourceId,
        primaryComputerId: row.primaryComputerId,
      );
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
        counted: (tank) => counted.contains(tank.id),
      );
    }
    final incomplete = {
      for (final id in uses.keys)
        if ((rowsById[id]!.hasSwitches && !switches.containsKey(id)) ||
            (rowsById[id]!.hasProfile && !profiles.containsKey(id)))
          id,
    };
    return (uses: uses, incomplete: incomplete);
  }

  /// The dives in [scope] with at least one breathing cylinder (a suit
  /// inflation bottle alone has no gas to rate, issue #4243), with their primary
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
          ${diveEffectiveWaterTypeSql('d')} AS water_type,
          (SELECT COUNT(*) || ':' ||
             COALESCE(GROUP_CONCAT(sw.timestamp || '@' || sw.tank_id), '')
           FROM gas_switches sw WHERE sw.dive_id = d.id) AS switches,
          EXISTS (SELECT 1 FROM gas_switches sw
            JOIN dive_tanks st ON st.id = sw.tank_id
            WHERE sw.dive_id = d.id) AS has_switches,
          EXISTS (SELECT 1 FROM dive_profile_series ps
            WHERE ps.dive_id = d.id AND ps.sample_count > 0) AS has_profile,
          (SELECT id FROM dive_data_sources
           WHERE dive_id = d.id AND is_primary = 1 LIMIT 1) AS primary_source_id,
          (SELECT computer_id FROM dive_data_sources
           WHERE dive_id = d.id AND is_primary = 1 LIMIT 1) AS primary_computer_id
        FROM dives d
        WHERE EXISTS (SELECT 1 FROM dive_tanks t
            WHERE t.dive_id = d.id AND ${breathingTankSql('t')})
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
          hasSwitches: row.read<bool>('has_switches'),
          hasProfile: row.read<bool>('has_profile'),
          // The dive and everything its figures read: profile and pressure
          // series and tanks (the source stamp), the water its depth is
          // measured in (a site's, which never re-stamps its dives), each gas
          // switch's time and cylinder, and which recording is primary.
          // Synced children never re-stamp the dive either.
          version: [
            row.read<int>('stamp'),
            row.read<String?>('water_type'),
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
  // Whether the dive has gas switches naming its cylinders, and a profile:
  // what the chunk's batch reads must bring back for it.
  bool hasSwitches,
  bool hasProfile,
  String version,
});
