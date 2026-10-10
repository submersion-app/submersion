part of 'insights_repository.dart';

/// The per-dive condition columns behind the Conditions tab's weather and
/// water-movement statistics (issue #3118), kept beside the repository so the
/// main file does not grow further; a part shares its scope helpers.
extension InsightsRepositoryConditions on InsightsRepository {
  /// One row per in-scope dive, recorded or not, ordered by date.
  ///
  /// Every dive is returned so the row count is the "of N dives" denominator
  /// of each chart's coverage line. Altitude and exit method are the dive's
  /// stored values: neither has a site fallback that decompression or the
  /// detail page would agree with.
  Future<List<ConditionsRow>> getConditionsRows({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND dives.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      final params = [?diverId, ...df.params];

      final results = await _db.customSelect('''
        SELECT
          id, dive_date_time, air_temp, cloud_cover, precipitation,
          wind_speed, wind_direction, humidity, surface_pressure,
          current_strength, current_direction, swell_height, altitude,
          exit_method
        FROM dives
        WHERE 1 = 1 $diverFilter ${df.clause}
        ORDER BY dive_date_time
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return [
        for (final row in results)
          ConditionsRow(
            diveId: row.read<String>('id'),
            dateTime: wallClockUtcFromMillis(row.read<int>('dive_date_time')),
            airTemp: row.read<double?>('air_temp'),
            cloudCover: parseStoredEnum(
              CloudCover.values,
              row.read<String?>('cloud_cover'),
            ),
            precipitation: parseStoredEnum(
              Precipitation.values,
              row.read<String?>('precipitation'),
            ),
            windSpeed: row.read<double?>('wind_speed'),
            windDirection: parseStoredEnum(
              CurrentDirection.values,
              row.read<String?>('wind_direction'),
            ),
            humidity: row.read<double?>('humidity'),
            surfacePressure: row.read<double?>('surface_pressure'),
            currentStrength: parseStoredEnum(
              CurrentStrength.values,
              row.read<String?>('current_strength'),
            ),
            currentDirection: parseStoredEnum(
              CurrentDirection.values,
              row.read<String?>('current_direction'),
            ),
            swellHeight: row.read<double?>('swell_height'),
            altitude: row.read<double?>('altitude'),
            exitMethod: parseStoredEnum(
              EntryMethod.values,
              row.read<String?>('exit_method'),
            ),
          ),
      ];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get conditions rows',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
