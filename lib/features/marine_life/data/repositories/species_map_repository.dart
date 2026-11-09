import 'package:drift/drift.dart';

import 'package:submersion/core/data/visibility/visibility_filter.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/marine_life/domain/entities/species_map_pins.dart';

/// Read-only queries behind the species map (issue #4358).
///
/// Scoped like the Species page (`SeenSpeciesRepository`): to [diverId] when
/// given, every diver otherwise, through `DiveStatsScope`, and never through
/// the Insights filter. Errors propagate so the page can show an error
/// state instead of a map that silently lies.
///
/// A sighting is "placed" when its dive has a site with valid coordinates
/// (both set, latitude in [-90, 90], longitude in [-180, 180]). Unplaced
/// sightings never become pins; [countUnplacedSightings] reports them so the
/// map can say so.
class SpeciesMapRepository {
  AppDatabase get _db => DatabaseService.instance.database;

  static const String _validCoordinates =
      'ds.latitude IS NOT NULL AND ds.longitude IS NOT NULL '
      'AND ds.latitude BETWEEN -90 AND 90 '
      'AND ds.longitude BETWEEN -180 AND 180';

  /// Every site where the diver logged at least one placed sighting, with
  /// the number of distinct species and the summed sighting count.
  Future<List<SiteSpeciesPin>> getSitePins({String? diverId}) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT ds.id, ds.name, ds.latitude, ds.longitude,
             COUNT(DISTINCT s.species_id) AS species_count,
             SUM(s.count) AS sighting_count
      FROM sightings s
      JOIN dives d ON d.id = s.dive_id
      JOIN dive_sites ds ON ds.id = d.site_id
      WHERE $_validCoordinates ${_diverClause(diverId)}
            ${DiveStatsScope.and(alias: 'd')}
      GROUP BY ds.id
    ''',
          variables: [?_diverVariable(diverId)],
        )
        .get();
    return [
      for (final row in rows)
        SiteSpeciesPin(
          siteId: row.read<String>('id'),
          siteName: row.read<String>('name'),
          latitude: row.read<double>('latitude'),
          longitude: row.read<double>('longitude'),
          speciesCount: row.read<int>('species_count'),
          sightingCount: row.read<int>('sighting_count'),
        ),
    ];
  }

  /// The sites on [speciesId]'s map: a logged pin wherever the diver logged
  /// it, and an expected pin wherever a site's expected list names it and
  /// the diver has not logged it there. [scope] chooses whose expected lists
  /// count; it never narrows the logged pins.
  Future<List<SpeciesSitePin>> getPinsForSpecies(
    String speciesId, {
    String? diverId,
    ExpectedSiteScope scope = ExpectedSiteScope.mine,
  }) async {
    final loggedRows = await _db
        .customSelect(
          '''
      SELECT ds.id, ds.name, ds.latitude, ds.longitude,
             SUM(s.count) AS sighting_count
      FROM sightings s
      JOIN dives d ON d.id = s.dive_id
      JOIN dive_sites ds ON ds.id = d.site_id
      WHERE s.species_id = ? AND $_validCoordinates ${_diverClause(diverId)}
            ${DiveStatsScope.and(alias: 'd')}
      GROUP BY ds.id
    ''',
          variables: [Variable.withString(speciesId), ?_diverVariable(diverId)],
        )
        .get();
    final logged = [
      for (final row in loggedRows)
        SpeciesSitePin(
          siteId: row.read<String>('id'),
          siteName: row.read<String>('name'),
          latitude: row.read<double>('latitude'),
          longitude: row.read<double>('longitude'),
          kind: SpeciesPinKind.logged,
          sightingCount: row.read<int>('sighting_count'),
        ),
    ];
    final loggedIds = {for (final pin in logged) pin.siteId};

    final expectedRows = await _db
        .customSelect(
          '''
      SELECT DISTINCT ds.id, ds.name, ds.latitude, ds.longitude
      FROM site_species ss
      JOIN dive_sites ds ON ds.id = ss.site_id
      WHERE ss.species_id = ? AND $_validCoordinates
    ''',
          variables: [Variable.withString(speciesId)],
        )
        .get();
    final candidates = [
      for (final row in expectedRows)
        if (!loggedIds.contains(row.read<String>('id'))) row,
    ];
    if (candidates.isEmpty) return logged;

    final allowed = await _allowedSiteIds(
      candidates.map((row) => row.read<String>('id')).toList(),
      diverId: diverId,
      scope: scope,
    );
    return [
      ...logged,
      for (final row in candidates)
        if (allowed.contains(row.read<String>('id')))
          SpeciesSitePin(
            siteId: row.read<String>('id'),
            siteName: row.read<String>('name'),
            latitude: row.read<double>('latitude'),
            longitude: row.read<double>('longitude'),
            kind: SpeciesPinKind.expected,
            sightingCount: 0,
          ),
    ];
  }

  /// The summed count of sightings that cannot be drawn: on a dive with no
  /// site, or at a site without valid coordinates. Every species when
  /// [speciesId] is null.
  Future<int> countUnplacedSightings({
    String? speciesId,
    String? diverId,
  }) async {
    final speciesClause = speciesId == null ? '' : 'AND s.species_id = ?';
    final row = await _db
        .customSelect(
          '''
      SELECT COALESCE(SUM(s.count), 0) AS unplaced
      FROM sightings s
      JOIN dives d ON d.id = s.dive_id
      LEFT JOIN dive_sites ds ON ds.id = d.site_id
      WHERE NOT (ds.id IS NOT NULL AND $_validCoordinates)
            $speciesClause ${_diverClause(diverId)}
            ${DiveStatsScope.and(alias: 'd')}
    ''',
          variables: [
            if (speciesId != null) Variable.withString(speciesId),
            ?_diverVariable(diverId),
          ],
        )
        .getSingle();
    return row.read<int>('unplaced');
  }

  /// The species the diver logged at [siteId], most seen first, then by id
  /// so ties keep a stable order.
  Future<List<LoggedSpeciesAtSite>> getLoggedSpeciesAtSite(
    String siteId, {
    String? diverId,
  }) async {
    final rows = await _db
        .customSelect(
          '''
      SELECT s.species_id, SUM(s.count) AS sighting_count
      FROM sightings s
      JOIN dives d ON d.id = s.dive_id
      WHERE d.site_id = ? ${_diverClause(diverId)}
            ${DiveStatsScope.and(alias: 'd')}
      GROUP BY s.species_id
      ORDER BY sighting_count DESC, s.species_id ASC
    ''',
          variables: [Variable.withString(siteId), ?_diverVariable(diverId)],
        )
        .get();
    return [
      for (final row in rows)
        LoggedSpeciesAtSite(
          speciesId: row.read<String>('species_id'),
          sightingCount: row.read<int>('sighting_count'),
        ),
    ];
  }

  /// Which of [siteIds] the scope admits. With no diver there is no scope.
  ///
  /// "Mine" is a site the diver owns or has logged a (not planned) dive at.
  /// "All visible" is the app's visibility rule
  /// ([VisibilityFilter.applyToDiveSites]) plus the "mine" sites, so it is
  /// never narrower: a site the diver dived but does not own and nobody
  /// shared is theirs to see on this map. A site the diver hid is left out
  /// of both.
  Future<Set<String>> _allowedSiteIds(
    List<String> siteIds, {
    required String? diverId,
    required ExpectedSiteScope scope,
  }) async {
    if (diverId == null) return siteIds.toSet();

    final mineRows = await _db
        .customSelect(
          '''
      SELECT id FROM dive_sites
      WHERE id IN (${List.filled(siteIds.length, '?').join(', ')})
        AND (diver_id = ?
             OR id IN (SELECT site_id FROM dives
                       WHERE diver_id = ? AND site_id IS NOT NULL
                         AND is_planned = 0))
    ''',
          variables: [
            ...siteIds.map(Variable.withString),
            Variable.withString(diverId),
            Variable.withString(diverId),
          ],
        )
        .get();
    final mine = {for (final row in mineRows) row.read<String>('id')};
    final hiddenRows = await (_db.select(
      _db.siteHides,
    )..where((t) => t.diverId.equals(diverId) & t.siteId.isIn(siteIds))).get();
    final hidden = {for (final row in hiddenRows) row.siteId};
    if (scope == ExpectedSiteScope.mine) return mine.difference(hidden);

    final query = _db.select(_db.diveSites)..where((t) => t.id.isIn(siteIds));
    VisibilityFilter.applyToDiveSites(_db, query, diverId);
    final visible = await query.get();
    // A site the diver hid stays hidden here even if they dived it.
    return {...mine, for (final site in visible) site.id}.difference(hidden);
  }

  static String _diverClause(String? diverId) =>
      diverId == null ? '' : 'AND d.diver_id = ?';

  static Variable<String>? _diverVariable(String? diverId) =>
      diverId == null ? null : Variable.withString(diverId);
}
