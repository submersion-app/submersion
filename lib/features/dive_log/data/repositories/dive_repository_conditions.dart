part of 'dive_repository_impl.dart';

/// The shared pieces of the conditions-fetch queries (#4329): which dives
/// are missing weather, where each one is, and how a selection is bound.
/// The public queries built on them stay on [DiveRepository] itself, so
/// generated mocks still see them.
extension DiveConditionsQueries on DiveRepository {
  /// The weather columns a conditions fetch is allowed to fill.
  ///
  /// `weatherDescription` is deliberately absent: the provider returns no
  /// prose, and the column holds the diver's own words when it holds anything.
  static Expression<bool> _hasConditionsGap(Dives t) =>
      t.windSpeed.isNull() |
      t.windDirection.isNull() |
      t.cloudCover.isNull() |
      t.precipitation.isNull() |
      t.humidity.isNull() |
      t.weatherCode.isNull() |
      t.airTemp.isNull() |
      t.surfacePressure.isNull();

  /// Whether a dive has somewhere to fetch conditions for: its site's
  /// coordinates, or failing that its own entry or exit GPS fix (#4329). Each
  /// counts only as a complete pair, in the order [_conditionsLocation] reads
  /// them, so a dive this accepts always yields a location there.
  ///
  /// Needs the sites table LEFT JOINed: a dive straight off a computer often
  /// has no site at all, and an inner join would drop it before its GPS fix
  /// is looked at. `IS NOT NULL` is never NULL itself, so the negation in
  /// [countDivesMissingConditionsWithoutLocation] is a plain boolean too.
  Expression<bool> _hasConditionsLocation($DiveSitesTable sites) {
    final dives = _db.dives;
    return (sites.latitude.isNotNull() & sites.longitude.isNotNull()) |
        (dives.entryLatitude.isNotNull() & dives.entryLongitude.isNotNull()) |
        (dives.exitLatitude.isNotNull() & dives.exitLongitude.isNotNull());
  }

  /// The location a conditions fetch uses for [row]: the first complete pair
  /// of site, entry fix and exit fix, matching [_hasConditionsLocation].
  ({double latitude, double longitude})? _conditionsLocation(
    TypedResult row,
    $DiveSitesTable sites,
  ) {
    final dives = _db.dives;
    final pairs = [
      (row.read(sites.latitude), row.read(sites.longitude)),
      (row.read(dives.entryLatitude), row.read(dives.entryLongitude)),
      (row.read(dives.exitLatitude), row.read(dives.exitLongitude)),
    ];
    for (final (latitude, longitude) in pairs) {
      if (latitude != null && longitude != null) {
        return (latitude: latitude, longitude: longitude);
      }
    }
    return null;
  }

  /// Logged dives with at least one empty weather column, narrowed to
  /// [diverId] and to [diveIds] when given.
  ///
  /// Planned dives are left out: one in the future has no archive weather
  /// yet, so it could only ever come back as "no data available".
  ///
  /// Shared by the candidate list and both counts so they can never disagree
  /// about what "missing conditions" means.
  Expression<bool> _conditionsScope({String? diverId, List<String>? diveIds}) {
    var condition =
        _hasConditionsGap(_db.dives) & _db.dives.isPlanned.equals(false);
    if (diverId != null) {
      condition = condition & _db.dives.diverId.equals(diverId);
    }
    if (diveIds != null) {
      condition = condition & _db.dives.id.isIn(diveIds);
    }
    return condition;
  }

  /// One pass per bound-variable chunk of [diveIds], or a single unrestricted
  /// pass (null) when there is no selection. A selection can be a whole
  /// "select all" logbook, past SQLite's variable limit in one statement. An
  /// empty selection yields no pass, so it matches nothing.
  Iterable<List<String>?> _conditionsIdChunks(Set<String>? diveIds) =>
      diveIds == null ? const [null] : seriesIdChunks(diveIds.toList());

  /// Counts dives missing conditions that have a location ([located]) or
  /// that do not.
  Future<int> _countConditionsGaps({
    required bool located,
    String? diverId,
    Set<String>? diveIds,
  }) async {
    final sites = _db.diveSites;
    final hasLocation = _hasConditionsLocation(sites);
    var total = 0;
    for (final chunk in _conditionsIdChunks(diveIds)) {
      final countExpr = _db.dives.id.count();
      final query = _db.selectOnly(_db.dives)
        ..addColumns([countExpr])
        ..where(
          _conditionsScope(diverId: diverId, diveIds: chunk) &
              (located ? hasLocation : hasLocation.not()),
        );
      query.join([leftOuterJoin(sites, sites.id.equalsExp(_db.dives.siteId))]);
      final row = await query.getSingle();
      total += row.read(countExpr) ?? 0;
    }
    return total;
  }
}
