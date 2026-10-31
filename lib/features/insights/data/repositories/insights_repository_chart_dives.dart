part of 'insights_repository.dart';

/// A tank's gas type, the gas mix chart's category.
const _gasTypeSql = '''
  CASE
    WHEN t.he_percent > 0 THEN 'Trimix'
    WHEN t.o2_percent > 21.5 THEN 'Nitrox'
    ELSE 'Air'
  END
''';

/// A suit's bucket on the thickness chart, over [_suitJoinsSql].
const _suitBucketSql = '''
  CASE
    WHEN e.type = 'drysuit' THEN 'drysuit'
    WHEN ea.value_num IS NULL THEN 'unknown'
    ELSE 'mm'
  END
''';

const _suitJoinsSql = '''
  JOIN dive_equipment de ON de.dive_id = d.id
  JOIN equipment e ON e.id = de.equipment_id
    AND e.type IN ('wetsuit', 'drysuit')
  LEFT JOIN equipment_attributes ea ON ea.equipment_id = e.id
    AND e.type = 'wetsuit'
    AND ea.attr_key = 'thickness_mm'
    AND ea.is_custom = 0
    AND ea.value_num IS NOT NULL
''';

/// What `_focusBuddyKey` reads from a dive. Binds [DiveRole.soloId] first.
const _soloBuddyColumnsSql = '''
  EXISTS (SELECT 1 FROM dive_buddies db WHERE db.dive_id = d.id)
    AS has_linked,
  NULLIF(TRIM(d.buddy), '') AS buddy_text,
  COALESCE(d.diver_role = ?, 0) AS is_solo
''';

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
  }) {
    final df = _diveFilter(filter, alias: 'd', gas: gas);
    return _diveIds(
      'SELECT d.id AS id FROM dives d '
      'WHERE 1=1 ${_diverClause(diverId)} ${df.clause}',
      [?diverId, ...df.params],
    );
  }

  /// One `(id, bucket)` row per dive in scope with a visibility recorded, and
  /// the variables it binds, in order.
  ({String sql, List<Object?> params}) _visibilityBucketQuery({
    required VisibilityScale scale,
    String? diverId,
    required DiveFilterState filter,
  }) {
    final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
    final df = _diveFilter(filter, alias: 'dives');
    return (
      sql:
          '''
        SELECT id, CASE
          ${VisibilityBandSql.whenBranches('')}
          ELSE 'legacy_' || visibility
        END AS bucket
        FROM dives
        WHERE (
          visibility_meters IS NOT NULL
          OR visibility_min_meters IS NOT NULL
          OR visibility_max_meters IS NOT NULL
          OR (visibility IS NOT NULL AND visibility != '')
        ) $diverFilter ${df.clause}
      ''',
      // Threshold variables come first: they appear before the diver and
      // filter placeholders, and Drift binds positionally.
      params: [...VisibilityBandSql.params(scale), ?diverId, ...df.params],
    );
  }

  /// The dives counted under [bucket] of the visibility chart: a key
  /// `getVisibilityDistribution` emitted.
  Future<List<String>> getVisibilityDiveIds({
    required VisibilityScale scale,
    required String bucket,
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) {
    final perDive = _visibilityBucketQuery(
      scale: scale,
      diverId: diverId,
      filter: filter,
    );
    return _diveIds('SELECT id FROM (${perDive.sql}) WHERE bucket = ?', [
      ...perDive.params,
      bucket,
    ]);
  }

  /// The dives counted under one site type: the segment's `key`.
  Future<List<String>> getSiteTypeDiveIds({
    required String siteTypeId,
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) {
    final df = _diveFilter(filter, alias: 'd');
    return _diveIds(
      '''
      SELECT d.id AS id FROM dives d
      JOIN site_site_types sst ON sst.site_id = d.site_id
      WHERE sst.site_type_id = ? ${_diverClause(diverId)} ${df.clause}
      ''',
      [siteTypeId, ?diverId, ...df.params],
    );
  }

  /// The dives counted under [gasType] of the gas mix chart. A dive breathing
  /// more than one mix is counted under each.
  Future<List<String>> getGasMixDiveIds({
    required String gasType,
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) {
    final df = _diveFilter(filter, alias: 'd', gas: true);
    return _diveIds(
      '''
      SELECT DISTINCT d.id AS id FROM dives d
      JOIN dive_tanks t ON t.dive_id = d.id
      WHERE $_gasTypeSql = ? ${_diverClause(diverId)} ${df.clause}
      ''',
      [gasType, ?diverId, ...df.params],
    );
  }

  /// The dives counted under one bar of the suit thickness chart. [bucket]
  /// is `mm`, with its [mm], `unknown` or `drysuit`.
  Future<List<String>> getSuitThicknessDiveIds({
    required String bucket,
    double? mm,
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) {
    final df = _diveFilter(filter, alias: 'd');
    return _diveIds(
      '''
      SELECT DISTINCT d.id AS id FROM dives d
      $_suitJoinsSql
      WHERE $_suitBucketSql = ?
        ${mm != null ? 'AND ea.value_num = ?' : ''}
        ${_diverClause(diverId)} ${df.clause}
      ''',
      [bucket, ?mm, ?diverId, ...df.params],
    );
  }

  /// The dives behind each slice of the Solo vs Buddy chart.
  Future<({List<String> solo, List<String> buddy, List<String> notRecorded})>
  getSoloVsBuddyDiveIds({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final df = _diveFilter(filter, alias: 'd');
      final results = await _db
          .customSelect(
            '''
            SELECT d.id AS id, $_soloBuddyColumnsSql
            FROM dives d
            WHERE 1=1 ${_diverClause(diverId)} ${df.clause}
            ''',
            variables: [
              for (final p in [DiveRole.soloId, ?diverId, ...df.params])
                Variable(p),
            ],
          )
          .get();

      final solo = <String>[];
      final buddy = <String>[];
      final notRecorded = <String>[];
      for (final row in results) {
        final key = _focusBuddyKey(
          hasLinked: row.read<bool>('has_linked'),
          text: row.read<String?>('buddy_text'),
          isSolo: row.read<bool>('is_solo'),
        );
        final list = switch (key) {
          'buddy' => buddy,
          'solo' => solo,
          _ => notRecorded,
        };
        list.add(row.read<String>('id'));
      }
      return (solo: solo, buddy: buddy, notRecorded: notRecorded);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get solo vs buddy dive ids',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// The dives counted under one depth bucket, by its index in
  /// `DiveStatistics.depthDistribution`.
  Future<List<String>> getDepthBucketDiveIds({
    required int bucket,
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) {
    final df = _diveFilter(filter, alias: 'd');
    return _diveIds(
      '''
      SELECT d.id AS id FROM dives d
      WHERE d.max_depth IS NOT NULL ${_diverClause(diverId)} ${df.clause}
        AND $depthBucketSql = ?
      ''',
      [?diverId, ...df.params, bucket],
    );
  }

  String _diverClause(String? diverId) =>
      diverId != null ? 'AND d.diver_id = ?' : '';

  Future<List<String>> _diveIds(String sql, List<Object?> params) async {
    try {
      final results = await _db
          .customSelect(sql, variables: [for (final p in params) Variable(p)])
          .get();
      return [for (final row in results) row.read<String>('id')];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get a chart\'s dive ids',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
