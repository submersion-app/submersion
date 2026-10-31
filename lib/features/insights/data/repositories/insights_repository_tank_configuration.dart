part of 'insights_repository.dart';

/// The per-dive tank data behind the Gas page's tank configuration card
/// (issue #3421), kept beside the repository so the main file does not grow
/// further; a part shares its scope helpers.
extension InsightsRepositoryTankConfiguration on InsightsRepository {
  /// Each in-scope dive sorted by base configuration and extras.
  ///
  /// Uses the plain statistics scope, not the gas one: a dive whose gas data
  /// is excluded from SAC still carried the tanks it lists. Reads through
  /// the SQL functions the dive filters use, so a bar and the list it opens
  /// classify a dive the same way (#3804). On a dive consolidated from
  /// several recordings only the primary recording's cylinders count, so a
  /// cylinder the merge could not match is not counted twice.
  Future<TankConfigurationStats> getTankConfigurationStats({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');

      final rows = await _db
          .customSelect(
            '''
        SELECT ${tankConfigBaseSql('d')} AS base,
          ${tankConfigExtrasSql('d')} AS extras,
          COUNT(*) AS dives
        FROM dives d
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY base, extras
        ''',
            variables: [
              for (final p in [?diverId, ...df.params]) Variable(p),
            ],
          )
          .get();

      return TankConfigurationStats.fromGroups([
        for (final r in rows)
          (
            result: (
              base: TankBaseConfiguration.values.byName(r.read<String>('base')),
              extras: decodeTankConfigExtras(r.read<String>('extras')),
            ),
            dives: r.read<int>('dives'),
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
