part of 'insights_repository.dart';

/// One breathed open-circuit cylinder behind the SAC by tank role rates:
/// its logged drop, and the breathing time and ambient pressure to divide
/// that drop by.
typedef _RoleCylinder = ({
  String role,
  double startPressure,
  double endPressure,
  double? volume,
  double o2Percent,
  double hePercent,
  double minutes,
  double ambientBar,
});

/// The cylinders behind [InsightsRepository.getSacVolumeByTankRole] and
/// [InsightsRepository.getSacPressureByTankRole], kept beside the repository
/// so the main file does not grow further; a part shares its scope helpers.
extension _InsightsRepositoryTankRoleSac on InsightsRepository {
  /// Every breathed cylinder of the open-circuit and SCR dives in scope, each
  /// with the breathing time and depth the dive's Cylinders card gives it
  /// (issue #4315).
  ///
  /// A cylinder of a dive whose gas switches say when each was breathed is
  /// read over its own windows, through [cylinderUsage] on the card's own
  /// inputs. Dividing every cylinder's gas by the whole dive instead halved
  /// the rate of each of two cylinders breathed in turn, and the planner's
  /// logged default read that halved figure. Only multi-cylinder dives with a
  /// switch naming one of their cylinders before the dive ended take that
  /// path, since they are the only ones whose windows differ from the whole
  /// dive, and it reads their series. Every other cylinder stays in SQL over
  /// the whole dive at its average depth, or over a breathing time the source
  /// log recorded for it (issue #1496), as the card reads one; an unswitched
  /// stage on a multi-cylinder dive keeps its whole-dive figure there.
  ///
  /// A CCR dive is left out: this divides by depth, which means nothing for a
  /// loop, and its rates are in [getCcrGasUsePerDive] (issue #4082).
  Future<List<_RoleCylinder>> _tankRoleCylinders({
    String? diverId,
    required DiveFilterState filter,
  }) async {
    final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
    final df = _diveFilter(filter, alias: 'd', gas: true);
    final runtime = measuredRuntimeSecondsSql('d');
    // A switch that says when a cylinder of the dive was breathed, as
    // [knownGasSwitches] reads one: naming a current cylinder, before the end.
    final knownSwitch =
        'EXISTS (SELECT 1 FROM gas_switches g '
        'JOIN dive_tanks gt ON gt.id = g.tank_id AND gt.dive_id = d.id '
        'WHERE g.dive_id = d.id AND g.timestamp < $runtime)';

    final rows = await _db
        .customSelect(
          '''
        SELECT
          d.id AS dive_id,
          t.id AS tank_id,
          t.tank_role,
          t.start_pressure,
          t.end_pressure,
          ${consumptionVolumeSql('t')} AS volume,
          t.o2_percent,
          t.he_percent,
          d.avg_depth,
          ${diveAmbientBarSql('d', 'd.avg_depth')} AS ambient_bar,
          t.usage_duration,
          $runtime AS runtime_sec,
          $knownSwitch AS known_switch,
          (SELECT COUNT(*) FROM dive_tanks c
            WHERE c.dive_id = d.id) AS tank_count
        FROM dives d
        INNER JOIN dive_tanks t ON t.dive_id = d.id
        WHERE t.start_pressure IS NOT NULL
          AND t.end_pressure IS NOT NULL
          AND t.start_pressure > t.end_pressure
          -- A duration recorded for the cylinder is enough on its own, as
          -- the Cylinders card reads one when the dive has no runtime.
          AND ($runtime > 0 OR t.usage_duration > 0)
          AND d.dive_mode <> 'ccr'
          $diverFilter ${df.clause}
        ''',
          variables: [
            for (final p in [?diverId, ...df.params]) Variable(p),
          ],
        )
        .get();

    _RoleCylinder cylinderOf(
      QueryRow row, {
      required double minutes,
      required double ambientBar,
    }) => (
      role: row.read<String>('tank_role'),
      startPressure: row.read<double>('start_pressure'),
      endPressure: row.read<double>('end_pressure'),
      volume: row.read<double?>('volume'),
      o2Percent: row.read<double>('o2_percent'),
      hePercent: row.read<double>('he_percent'),
      minutes: minutes,
      ambientBar: ambientBar,
    );

    final cylinders = <_RoleCylinder>[];
    final windowedByDive = <String, List<QueryRow>>{};
    for (final row in rows) {
      final knownSwitch = row.read<bool>('known_switch');
      // A switched dive's depth comes from its profile within each window,
      // falling back to the average when there is none.
      if (knownSwitch && row.read<int>('tank_count') >= 2) {
        windowedByDive
            .putIfAbsent(row.read<String>('dive_id'), () => [])
            .add(row);
        continue;
      }
      // A single cylinder is rated at the dive's average depth, so a dive
      // without one has nothing to divide by.
      final avgDepth = row.read<double?>('avg_depth');
      if (avgDepth == null || avgDepth <= 0) continue;
      final ambientBar = row.read<double>('ambient_bar');
      // Without switches a breathing time the log recorded wins.
      final recorded = knownSwitch ? null : row.read<int?>('usage_duration');
      final seconds = recorded != null && recorded > 0
          ? recorded
          : row.read<int>('runtime_sec');
      cylinders.add(
        cylinderOf(row, minutes: seconds / 60.0, ambientBar: ambientBar),
      );
    }

    for (final ids in InsightsRepository._diveChunks(
      windowedByDive.keys.toList(),
    )) {
      final dives = {
        for (final dive in await _diveRepository.getDivesByIdsWithoutSamples(
          ids,
        ))
          dive.id: dive,
      };
      final switches = await _diveRepository.getGasSwitchesForDives(ids);
      final profiles = await _diveRepository.getMergedProfilesForDives(ids);

      for (final id in ids) {
        final dive = dives[id];
        if (dive == null) continue;
        final profile = profiles[id] ?? const <DiveProfilePoint>[];
        // A known switch falls before the measured runtime, so every dive
        // here has one.
        final diveEnd = dive.measuredRuntime?.inSeconds ?? 0;
        for (final row in windowedByDive[id]!) {
          final tankId = row.read<String>('tank_id');
          final tank = dive.tanks.where((t) => t.id == tankId).firstOrNull;
          if (tank == null) continue;
          final usage = cylinderUsage(
            tank: tank,
            tanks: dive.tanks,
            profile: profile,
            gasSwitches: switches[id],
            diveEnd: diveEnd,
          );
          // The switches name other cylinders and never this one.
          if (usage == null || usage.seconds <= 0) continue;
          final depth = usage.avgDepth ?? dive.avgDepth;
          if (depth == null) continue;
          cylinders.add(
            cylinderOf(
              row,
              minutes: usage.seconds / 60.0,
              ambientBar: dive.environment.pressureAtDepth(depth),
            ),
          );
        }
      }
    }
    return cylinders;
  }
}
