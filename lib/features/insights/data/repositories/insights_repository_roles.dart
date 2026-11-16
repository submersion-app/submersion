part of 'insights_repository.dart';

/// The My role card (issue #4409), kept beside the repository so the main
/// file does not grow further; a part shares its scope helpers.
extension InsightsRepositoryRoles on InsightsRepository {
  /// Dives per role the diver held, most common first, then a trailing
  /// [kNotRecordedDistributionKey] segment for dives with no role.
  ///
  /// A dive's roles are read by `diverRoleIdsOfDiveSql`, the rule the
  /// `myRole` query relation uses, so a dive holding several roles counts
  /// once under each (the counts can sum past the dive total, as the dive
  /// types list does) and every bar equals the dives its drill-in opens.
  /// A role id with no `dive_roles` row, or another diver's custom role
  /// (`diveRoleVisibleSql`), is not a bar: the relation cannot match it
  /// either. Each segment also sums the dives' measured runtime.
  Future<List<DistributionSegment>> getDiverRoleDistribution({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final variables = [
        for (final p in [?diverId, ...df.params]) Variable(p),
      ];
      final roles = diverRoleIdsOfDiveSql(
        diveId: 'd.id',
        scalar: 'd.diver_role',
      );
      final runtime = measuredRuntimeSecondsSql('d');

      final roleQuery = _db.customSelect('''
        SELECT
          dr.id AS role_id,
          COUNT(*) AS count,
          SUM($runtime) AS total_time
        FROM dives d
        JOIN dive_roles dr ON dr.id IN ($roles)
          AND ${diveRoleVisibleSql(role: 'dr', diveDiverId: 'd.diver_id')}
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY dr.id
        ORDER BY count DESC, dr.sort_order, dr.id
        ''', variables: variables).get();
      final notSetQuery = _db.customSelect('''
        SELECT COUNT(*) AS count, SUM($runtime) AS total_time
        FROM dives d
        WHERE ${diverRoleUnsetSql('d.diver_role')}
          $diverFilter ${df.clause}
        ''', variables: variables).getSingle();

      // Independent reads: issue them together.
      final (roleRows, notSet) = await (roleQuery, notSetQuery).wait;
      final rows = [
        for (final row in roleRows)
          (
            label: row.read<String>('role_id'),
            count: row.read<int>('count'),
            time: row.readNullable<int>('total_time') ?? 0,
          ),
        if (notSet.read<int>('count') > 0)
          (
            label: kNotRecordedDistributionKey,
            count: notSet.read<int>('count'),
            time: notSet.readNullable<int>('total_time') ?? 0,
          ),
      ];
      final total = rows.fold<int>(0, (sum, r) => sum + r.count);
      if (total == 0) return [];
      return [
        for (final r in rows)
          DistributionSegment(
            label: r.label,
            count: r.count,
            percentage: r.count / total * 100,
            totalDurationSeconds: r.time,
          ),
      ];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get diver role distribution',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
