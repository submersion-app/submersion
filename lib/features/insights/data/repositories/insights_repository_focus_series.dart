part of 'insights_repository.dart';

/// Per-dive series for the Dive focus metrics that have no trend chart of
/// their own. Each reads one column of `dives`, scoped like every other
/// descriptive aggregate, and skips dives without the value.
extension InsightsRepositoryFocusSeries on InsightsRepository {
  Future<List<TrendDataPoint>> getAvgDepthPerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) => _columnSeries('d.avg_depth', 'average depth', diverId, filter);

  /// Minutes, from the stored seconds.
  Future<List<TrendDataPoint>> getSurfaceIntervalPerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) => _columnSeries(
    'd.surface_interval_seconds / 60.0',
    'surface interval',
    diverId,
    filter,
  );

  Future<List<TrendDataPoint>> getAirTempPerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) => _columnSeries('d.air_temp', 'air temperature', diverId, filter);

  /// Metres typed by the diver; a dive logged only with a band has none.
  Future<List<TrendDataPoint>> getVisibilityPerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) => _columnSeries('d.visibility_meters', 'visibility', diverId, filter);

  Future<List<TrendDataPoint>> getAltitudePerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) => _columnSeries('d.altitude', 'altitude', diverId, filter);

  Future<List<TrendDataPoint>> getCnsPerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) => _columnSeries('d.cns_end', 'CNS', diverId, filter);

  Future<List<TrendDataPoint>> getOtuPerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) => _columnSeries('d.otu', 'OTU', diverId, filter);

  /// Litres breathed over the dive, summed across its tanks with the same
  /// per-tank volume rule and gas model the RMV series uses, before any
  /// division by time or depth. Scoped like RMV, so a dive excluded from gas
  /// statistics or logged in gauge mode is absent here too.
  Future<List<TrendDataPoint>> getGasUsedPerDive({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd', gas: true);
      final params = [?diverId, ...df.params];
      final results = await _db.customSelect('''
        SELECT d.id AS dive_id,
               d.dive_date_time AS dive_date_time,
               t.start_pressure,
               t.end_pressure,
               ${consumptionVolumeSql('t')} AS volume,
               t.o2_percent,
               t.he_percent
        FROM dives d
        JOIN dive_tanks t ON t.dive_id = d.id
        WHERE t.start_pressure > t.end_pressure
          $diverFilter ${df.clause}
        ORDER BY d.dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      // Sum gas across each dive's tanks, so a twinset is one value.
      final litres = <String, double>{};
      final dates = <String, DateTime>{};
      for (final row in results) {
        final vol = row.read<double?>('volume');
        if (vol == null) continue;
        final diveId = row.read<String>('dive_id');
        final o2 = row.read<double>('o2_percent');
        final he = row.read<double>('he_percent');
        double at(double bar) => gasVolume(
          tankSizeLiters: vol,
          pressureBar: bar,
          o2Percent: o2,
          hePercent: he,
          model: gasModel,
        );
        final used =
            at(row.read<double>('start_pressure')) -
            at(row.read<double>('end_pressure'));
        if (used <= 0) continue;
        litres[diveId] = (litres[diveId] ?? 0) + used;
        dates[diveId] ??= DateTime.fromMillisecondsSinceEpoch(
          row.read<int>('dive_date_time'),
          isUtc: true,
        );
      }
      return [
        for (final e in litres.entries)
          TrendDataPoint(date: dates[e.key]!, value: e.value, diveId: e.key),
      ];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get per-dive gas used',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// One value per dive from [expression] over alias `d`, dives without it
  /// skipped, oldest first. [what] names the series in the error log.
  Future<List<TrendDataPoint>> _columnSeries(
    String expression,
    String what,
    String? diverId,
    DiveFilterState filter,
  ) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = [?diverId, ...df.params];
      final results = await _db.customSelect('''
        SELECT d.id AS dive_id, d.dive_date_time AS dive_date_time,
               ($expression) AS value
        FROM dives d
        WHERE ($expression) IS NOT NULL $diverFilter ${df.clause}
        ORDER BY d.dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();
      return [
        for (final row in results)
          TrendDataPoint(
            date: DateTime.fromMillisecondsSinceEpoch(
              row.read<int>('dive_date_time'),
              isUtc: true,
            ),
            value: row.read<double>('value'),
            diveId: row.read<String>('dive_id'),
          ),
      ];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get per-dive $what',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
