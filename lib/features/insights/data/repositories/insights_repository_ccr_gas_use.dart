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
        SELECT d.id, d.dive_date_time,
          (SELECT id FROM dive_data_sources
           WHERE dive_id = d.id AND is_primary = 1 LIMIT 1) AS primary_source_id,
          (SELECT computer_id FROM dive_data_sources
           WHERE dive_id = d.id AND is_primary = 1 LIMIT 1) AS primary_computer_id
        FROM dives d
        WHERE d.dive_mode = 'ccr' $diverFilter ${df.clause}
        ORDER BY d.dive_date_time
        ''',
            variables: [
              for (final p in [?diverId, ...df.params]) Variable(p),
            ],
          )
          .get();
      if (rows.isEmpty) return const CcrGasUseTrend(o2: [], diluent: []);
      final rowsById = {for (final row in rows) row.read<String>('id'): row};

      final o2 = <TrendDataPoint>[];
      final diluent = <TrendDataPoint>[];
      // A chunk at a time: a pressure series is a blob, and this runs over
      // every CCR dive in the logbook.
      for (final ids in seriesIdChunks(rowsById.keys.toList())) {
        final dives = {
          for (final dive in await _diveRepository.getDivesByIdsWithoutSamples(
            ids,
          ))
            dive.id: dive,
        };
        final switches = await _diveRepository.getGasSwitchesForDives(ids);
        final pressures = await _tankPressureRepository
            .getDisplayedTankPressuresForDives(ids);

        for (final id in ids) {
          final dive = dives[id];
          if (dive == null) continue;
          final row = rowsById[id]!;
          final use = _ccrUseOfPrimaryRecording(
            dive,
            switches: switches[id],
            pressures: pressures[id],
            primarySourceId: row.read<String?>('primary_source_id'),
            primaryComputerId: row.read<String?>('primary_computer_id'),
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

  /// [ccrDiveUse] over the cylinders of the dive's primary recording. A dive
  /// consolidated from two computers can keep a copy of a cylinder from each,
  /// and these rates add cylinders up, so the copies must count once.
  CcrDiveUse _ccrUseOfPrimaryRecording(
    domain.Dive dive, {
    required List<GasSwitchWithTank>? switches,
    required Map<String, List<domain.TankPressurePoint>>? pressures,
    required String? primarySourceId,
    required String? primaryComputerId,
  }) {
    bool owned(domain.DiveTank tank) => tankOwnedByPrimary(
      tank,
      primarySourceId: primarySourceId,
      primaryComputerId: primaryComputerId,
    );
    final copies = {
      for (final tank in dive.tanks)
        if (!owned(tank)) tank.id,
    };
    return ccrDiveUse(
      tanks: dive.tanks.where(owned).toList(),
      gasSwitches: switches,
      // Dropped by name, so another computer's series is not read as a stray
      // one for a cylinder here to adopt.
      tankPressures: {
        for (final entry in (pressures ?? const {}).entries)
          if (!copies.contains(entry.key)) entry.key: entry.value,
      },
      diveEnd: dive.effectiveRuntime?.inSeconds ?? 0,
      gasModel: gasModel,
    );
  }
}
