part of 'insights_repository.dart';

/// The dives behind one number on an Insights chart (issue #3805), resolved
/// when the diver opens them.
///
/// A mixin rather than an extension like the other parts, so a widget test
/// can stand in for the database behind a chart's link.
mixin InsightsChartDives {
  AppDatabase get _db;
  LoggerService get _log;
  ({String clause, List<Object?> params}) _diveFilter(
    DiveFilterState filter, {
    String alias,
    bool gas,
  });

  /// The ids of the dives a statistic counts under [filter]: for a chart
  /// whose category a filter can state, the Insights filter narrowed to that
  /// category. [gas] is the narrower scope the gas charts count under.
  Future<List<String>> getCountedDiveIds({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    bool gas = false,
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd', gas: gas);
      final results = await _db
          .customSelect(
            'SELECT d.id FROM dives d WHERE 1=1 $diverFilter ${df.clause}',
            variables: [
              for (final p in [?diverId, ...df.params]) Variable(p),
            ],
          )
          .get();
      return [for (final row in results) row.read<String>('id')];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get counted dive ids',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
