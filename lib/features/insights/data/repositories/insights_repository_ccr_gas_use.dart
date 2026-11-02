part of 'insights_repository.dart';

/// The per-dive rates behind the Gas page's Rebreather gas use card (issue
/// #4082), kept beside the repository so the main file does not grow further;
/// a part shares its scope helpers.
extension InsightsRepositoryCcrGasUse on InsightsRepository {
  /// O2 and diluent use of every CCR dive in scope, ordered by date.
  ///
  /// Uses the gas statistics scope, not the consumption rate one, which drops
  /// rebreather dives: a loop's rate is a different figure from SAC and RMV,
  /// and the "exclude from gas statistics" tick is how a diver leaves out a
  /// dive with O2 flushes. Runs the Cylinders card's own calculation on the
  /// same inputs, so one dive reads the same in both places.
  Future<CcrGasUseTrend> getCcrGasUsePerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd', gas: true);

      final rows = await _db
          .customSelect(
            '''
        SELECT d.id, d.dive_date_time
        FROM dives d
        WHERE d.dive_mode = 'ccr' $diverFilter ${df.clause}
        ORDER BY d.dive_date_time
        ''',
            variables: [
              for (final p in [?diverId, ...df.params]) Variable(p),
            ],
          )
          .get();
      final ids = [for (final row in rows) row.read<String>('id')];
      if (ids.isEmpty) return const CcrGasUseTrend(o2: [], diluent: []);

      final dives = {
        for (final dive in await _diveRepository.getDivesByIdsWithoutSamples(
          ids,
        ))
          dive.id: dive,
      };
      final switches = await _diveRepository.getGasSwitchesForDives(ids);
      final pressures = await _tankPressureRepository
          .getDisplayedTankPressuresForDives(ids);

      final o2 = <TrendDataPoint>[];
      final diluent = <TrendDataPoint>[];
      for (final row in rows) {
        final id = row.read<String>('id');
        final dive = dives[id];
        if (dive == null) continue;
        final use = ccrDiveUse(
          tanks: dive.tanks,
          gasSwitches: switches[id],
          tankPressures: pressures[id],
          diveEnd: dive.effectiveRuntime?.inSeconds ?? 0,
          gasModel: gasModel,
        );
        final date = DateTime.fromMillisecondsSinceEpoch(
          row.read<int>('dive_date_time'),
          isUtc: true,
        );
        if (use.o2Rate case final rate?) {
          o2.add(TrendDataPoint(date: date, value: rate, diveId: id));
        }
        if (use.diluentRate case final rate?) {
          diluent.add(TrendDataPoint(date: date, value: rate, diveId: id));
        }
      }
      return CcrGasUseTrend(o2: o2, diluent: diluent);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get CCR gas use per dive',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
