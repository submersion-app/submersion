import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/marine_life/domain/species_grouping.dart';

/// The facts of the life list the Species pages group and chart by
/// (issue #5027): where each species was seen, in which months, and at what
/// depth the diver photographed it.
///
/// Scoped like the life list: the diver's dives under [DiveStatsScope].
class SpeciesFactsRepository {
  AppDatabase get _db => DatabaseService.instance.database;

  /// The trips and sites each species was seen on, and those of its first
  /// sighting. A dive without a trip or site gives a place with a null id.
  /// Aggregated in SQL by (species, trip, site), so a long log returns one
  /// row per place, not one per sighting.
  Future<SpeciesPlaces> places({String? diverId}) async {
    final rows = await _db.customSelect('''
      SELECT s.species_id, MIN(d.dive_date_time) AS first_at,
             d.trip_id, MAX(t.name) AS trip_name,
             MAX(t.start_date) AS trip_start,
             d.site_id, MAX(ds.name) AS site_name
      FROM sightings s
      JOIN dives d ON d.id = s.dive_id
      LEFT JOIN trips t ON t.id = d.trip_id
      LEFT JOIN dive_sites ds ON ds.id = d.site_id
      WHERE 1=1 ${_diverClause(diverId)}${DiveStatsScope.and(alias: 'd')}
      GROUP BY s.species_id, d.trip_id, d.site_id
      ORDER BY first_at ASC
    ''', variables: _diverVariables(diverId)).get();
    final trips = <String, Map<String?, SpeciesPlace>>{};
    final sites = <String, Map<String?, SpeciesPlace>>{};
    final firstTrip = <String, String?>{};
    final firstSite = <String, String?>{};
    for (final row in rows) {
      final species = row.read<String>('species_id');
      final tripId = row.readNullable<String>('trip_id');
      final siteId = row.readNullable<String>('site_id');
      final tripStart = row.readNullable<int>('trip_start');
      trips
          .putIfAbsent(species, () => {})
          .putIfAbsent(
            tripId,
            () => SpeciesPlace(
              id: tripId,
              name: row.readNullable<String>('trip_name') ?? '',
              sortDate: tripStart == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(tripStart, isUtc: true),
            ),
          );
      sites
          .putIfAbsent(species, () => {})
          .putIfAbsent(
            siteId,
            () => SpeciesPlace(
              id: siteId,
              name: row.readNullable<String>('site_name') ?? '',
            ),
          );
      // Rows come oldest first by each place's first sighting, so the first
      // row of a species is where it was first seen.
      if (!firstTrip.containsKey(species)) {
        firstTrip[species] = tripId;
        firstSite[species] = siteId;
      }
    }
    return SpeciesPlaces(
      tripsBySpecies: {
        for (final e in trips.entries) e.key: e.value.values.toList(),
      },
      sitesBySpecies: {
        for (final e in sites.entries) e.key: e.value.values.toList(),
      },
      firstTripBySpecies: firstTrip,
      firstSiteBySpecies: firstSite,
    );
  }

  /// Dives that saw [speciesId] in each calendar month, January first,
  /// across every year. Months come from the stored wall clock.
  Future<List<int>> monthCounts(String speciesId, {String? diverId}) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT CAST(strftime('%m', d.dive_date_time / 1000, 'unixepoch')
                  AS INTEGER) AS month,
             COUNT(DISTINCT d.id) AS dives
      FROM sightings s
      JOIN dives d ON d.id = s.dive_id
      WHERE s.species_id = ?
        ${_diverClause(diverId)}${DiveStatsScope.and(alias: 'd')}
      GROUP BY month
    ''',
          variables: [
            Variable.withString(speciesId),
            ..._diverVariables(diverId),
          ],
        )
        .get();
    final counts = List<int>.filled(12, 0);
    for (final row in rows) {
      final month = row.read<int>('month');
      counts[month - 1] = row.read<int>('dives');
    }
    return counts;
  }

  /// The depths, in meters, at which media tagged with [speciesId] were
  /// taken on the diver's dives (from the profile match), shallowest first.
  /// One depth per photo: a photo enriched on two devices averages them.
  Future<List<double>> photoDepths(String speciesId, {String? diverId}) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT me.media_id, AVG(me.depth_meters) AS depth_meters
      FROM media_species ms
      JOIN media m ON m.id = ms.media_id
      JOIN dives d ON d.id = m.dive_id
      JOIN media_enrichment me ON me.media_id = m.id
      WHERE ms.species_id = ?
        AND me.depth_meters IS NOT NULL
        ${_diverClause(diverId)}${DiveStatsScope.and(alias: 'd')}
      GROUP BY me.media_id
      ORDER BY depth_meters ASC
    ''',
          variables: [
            Variable.withString(speciesId),
            ..._diverVariables(diverId),
          ],
        )
        .get();
    return [for (final row in rows) row.read<double>('depth_meters')];
  }

  /// Ticks when a photo's depth, tags or dive change.
  Stream<void> watchDepthChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([
      _db.mediaEnrichment,
      _db.mediaSpecies,
      _db.media,
    ]),
  );

  /// Ticks when a trip or site is renamed, moved or removed: what the Trip
  /// and Site groupings show beyond the sightings themselves.
  Stream<void> watchPlaceChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([_db.trips, _db.diveSites]),
  );

  String _diverClause(String? diverId) =>
      diverId == null ? '' : 'AND d.diver_id = ?';

  List<Variable<Object>> _diverVariables(String? diverId) => [
    if (diverId != null) Variable.withString(diverId),
  ];
}
