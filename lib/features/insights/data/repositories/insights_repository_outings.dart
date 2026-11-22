part of 'insights_repository.dart';

/// The columns and joins every outings read shares; the caller adds the
/// rest of the WHERE clause, the order and any limit.
String _outingDivesSelect(String where) =>
    '''
        SELECT
          d.id AS id,
          d.dive_date_time AS at,
          d.trip_id AS trip_id,
          t.name AS trip_name,
          s.name AS site_name,
          s.latitude AS site_latitude,
          s.longitude AS site_longitude,
          d.max_depth AS max_depth,
          (SELECT group_concat(DISTINCT g.species_id)
             FROM sightings g WHERE g.dive_id = d.id) AS species
        FROM dives d
        LEFT JOIN trips t ON t.id = d.trip_id
        LEFT JOIN dive_sites s ON s.id = d.site_id
        WHERE 1 = 1 $where${DiveStatsScope.and(alias: 'd')}
        ''';

OutingDive _outingDiveFromRow(QueryRow row) => OutingDive(
  id: row.read<String>('id'),
  dateTime: wallClockUtcFromMillis(row.read<int>('at')),
  tripId: row.readNullable<String>('trip_id'),
  tripName: row.readNullable<String>('trip_name'),
  siteName: row.readNullable<String>('site_name'),
  maxDepth: row.readNullable<double>('max_depth'),
  siteLatitude: row.readNullable<double>('site_latitude'),
  siteLongitude: row.readNullable<double>('site_longitude'),
  speciesIds: {
    for (final id in (row.readNullable<String>('species') ?? '').split(','))
      if (id.isNotEmpty) id,
  },
);

/// The reads behind the Home Recent outings panel (issue #4898).
///
/// Both apply the stats scope (no planned, draft or excluded dives), as
/// every other Home number does, and take no filter.
extension InsightsRepositoryOutings on InsightsRepository {
  /// Fires when anything an outing shows can have changed: the dives
  /// themselves, a trip's or a site's name, or the species seen. Narrower
  /// than [InsightsRepository.watchInsightsChanges], which also follows
  /// profiles, cylinders and equipment that no outing reads.
  Stream<void> watchOutingChanges() => _db
      .tableUpdates(
        TableUpdateQuery.allOf([
          TableUpdateQuery.onTable(_db.dives),
          TableUpdateQuery.onTable(_db.trips),
          TableUpdateQuery.onTable(_db.diveSites),
          TableUpdateQuery.onTable(_db.sightings),
        ]),
      )
      .debounce(DiveRepository.changeTickDebounce);

  /// The diver's newest [limit] dives with what grouping them into outings
  /// needs: trip, site, maximum depth and the species seen.
  Future<List<OutingDive>> getOutingDives({
    String? diverId,
    int limit = 300,
  }) async {
    try {
      final rows = await _db
          .customSelect(
            '''
        ${_outingDivesSelect(diverId != null ? 'AND d.diver_id = ?' : '')}
        ORDER BY d.dive_date_time DESC
        LIMIT ?
        ''',
            variables: [
              if (diverId != null) Variable<String>(diverId),
              Variable<int>(limit),
            ],
          )
          .get();
      return [for (final row in rows) _outingDiveFromRow(row)];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dives for outings',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Every in-scope dive of the diver on [tripIds], however old, so a trip
  /// that a limited read cut through can be shown whole.
  Future<List<OutingDive>> getOutingDivesForTrips(
    List<String> tripIds, {
    String? diverId,
  }) async {
    if (tripIds.isEmpty) return const [];
    try {
      final trips = List.filled(tripIds.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            _outingDivesSelect(
              'AND d.trip_id IN ($trips)'
              '${diverId != null ? ' AND d.diver_id = ?' : ''}',
            ),
            variables: [
              for (final id in tripIds) Variable<String>(id),
              if (diverId != null) Variable<String>(diverId),
            ],
          )
          .get();
      return [for (final row in rows) _outingDiveFromRow(row)];
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get trip dives for outings',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
