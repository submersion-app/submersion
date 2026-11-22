part of 'insights_repository.dart';

/// The read behind the Home Recent outings panel (issue #4898).
extension InsightsRepositoryOutings on InsightsRepository {
  /// The diver's newest [limit] dives with what grouping them into outings
  /// needs: trip, site, maximum depth and the species seen. Applies the
  /// stats scope (no planned, draft or excluded dives), as every other Home
  /// number does, and takes no filter.
  Future<List<OutingDive>> getOutingDives({
    String? diverId,
    int limit = 300,
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final rows = await _db
          .customSelect(
            '''
        SELECT
          d.id AS id,
          d.dive_date_time AS at,
          d.trip_id AS trip_id,
          t.name AS trip_name,
          s.name AS site_name,
          d.max_depth AS max_depth,
          (SELECT group_concat(DISTINCT g.species_id)
             FROM sightings g WHERE g.dive_id = d.id) AS species
        FROM dives d
        LEFT JOIN trips t ON t.id = d.trip_id
        LEFT JOIN dive_sites s ON s.id = d.site_id
        WHERE 1 = 1 $diverFilter${DiveStatsScope.and(alias: 'd')}
        ORDER BY d.dive_date_time DESC
        LIMIT ?
        ''',
            variables: [
              if (diverId != null) Variable<String>(diverId),
              Variable<int>(limit),
            ],
          )
          .get();
      return [
        for (final row in rows)
          OutingDive(
            id: row.read<String>('id'),
            dateTime: wallClockUtcFromMillis(row.read<int>('at')),
            tripId: row.readNullable<String>('trip_id'),
            tripName: row.readNullable<String>('trip_name'),
            siteName: row.readNullable<String>('site_name'),
            maxDepth: row.readNullable<double>('max_depth'),
            speciesIds: {
              for (final id
                  in (row.readNullable<String>('species') ?? '').split(','))
                if (id.isNotEmpty) id,
            },
          ),
      ];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dives for outings',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
