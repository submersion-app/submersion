part of 'insights_repository.dart';

/// The Time patterns "Calendar days" matrix (issue #3127), kept beside the
/// repository so the main file does not grow further; a part shares its
/// scope helpers.
extension InsightsRepositoryCalendarDays on InsightsRepository {
  /// In-scope dives counted by the calendar date they were logged on, across
  /// all years.
  ///
  /// `dive_date_time` is the wall clock flagged as UTC, so `strftime` in UTC
  /// reads the diver's own date: a dive at 23:30 on 6 May counts on 6 May
  /// wherever the device is, as the weekday and month cards count.
  Future<CalendarDayMatrix> getCalendarDayMatrix({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'dives');
      final params = [?diverId, ...df.params];

      final results = await _db.customSelect('''
        SELECT
          CAST(strftime('%m', dive_date_time / 1000, 'unixepoch') AS INTEGER) AS month,
          CAST(strftime('%d', dive_date_time / 1000, 'unixepoch') AS INTEGER) AS day,
          COUNT(*) AS count
        FROM dives
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY month, day
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return CalendarDayMatrix.fromCounts([
        for (final row in results)
          (
            month: row.read<int>('month'),
            day: row.read<int>('day'),
            count: row.read<int>('count'),
          ),
      ]);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dives by calendar day',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
