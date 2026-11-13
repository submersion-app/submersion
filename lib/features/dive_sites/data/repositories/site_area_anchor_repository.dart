import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    show GeoPoint;
import 'package:submersion/features/dive_sites/domain/models/site_area_anchor.dart';

/// Finds the area of a dive that has no GPS, from the dives around it.
///
/// A trip's dives cluster: once one dive of a trip has a named site, the
/// rest were very likely nearby. So the site picker measures "near here"
/// from the site of the nearest dive in time, and a diver naming a trip's
/// sites types the first one and taps the rest.
class SiteAreaAnchorRepository {
  SiteAreaAnchorRepository({AppDatabase? database}) : _database = database;

  /// How far in time a dive outside the trip may be and still say where
  /// this one was.
  static const Duration window = Duration(days: 3);

  final AppDatabase? _database;

  AppDatabase get _db => _database ?? DatabaseService.instance.database;

  /// The area of a dive at [at]: the located site of the nearest dive in
  /// time that shares its trip, else of the nearest dive within [window]
  /// either side. Null when there is none.
  ///
  /// [at] is the dive's wall-clock time stamped as UTC, as dive times are
  /// stored. [excludeDiveIds] leaves out the dive being edited. With no
  /// [diverId] dives of every diver are considered.
  ///
  /// The trip is matched by exact id: a side trip's dives are reached by
  /// the [window] rule.
  Future<SiteAreaAnchor?> forDive({
    required DateTime at,
    String? tripId,
    String? diverId,
    List<String> excludeDiveIds = const [],
  }) async {
    final target = at.millisecondsSinceEpoch;
    final dives = _db.dives;
    final sites = _db.diveSites;
    // A dive's own time: its entry time when it has one, else its date.
    final when = coalesce<int>([dives.entryTime, dives.diveDateTime]);
    final gap = (when - Variable<int>(target)).abs();
    final inWindow = gap.isSmallerOrEqualValue(window.inMilliseconds);
    // Null when the dive has no trip: a constant here would read, in an
    // ORDER BY, as a column number.
    final sameTrip = tripId == null ? null : dives.tripId.equals(tripId);

    final query =
        _db.selectOnly(dives).join([
            innerJoin(sites, sites.id.equalsExp(dives.siteId)),
          ])
          ..addColumns([
            sites.latitude,
            sites.longitude,
            sites.island,
            sites.region,
            sites.country,
          ])
          ..where(sites.latitude.isNotNull() & sites.longitude.isNotNull())
          ..where(sameTrip == null ? inWindow : sameTrip | inWindow);
    if (diverId != null) query.where(dives.diverId.equals(diverId));
    if (excludeDiveIds.isNotEmpty) {
      query.where(dives.id.isNotIn(excludeDiveIds));
    }
    query
      ..orderBy([
        // Trip matches first, then nearest in time; the id keeps the
        // answer stable when two dives are equally near.
        if (sameTrip != null)
          OrderingTerm(expression: sameTrip, mode: OrderingMode.desc),
        OrderingTerm(expression: gap),
        OrderingTerm(expression: dives.id),
      ])
      ..limit(1);

    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return SiteAreaAnchor(
      point: GeoPoint(row.read(sites.latitude)!, row.read(sites.longitude)!),
      placeLabel: _firstNonBlank([
        row.read(sites.island),
        row.read(sites.region),
        row.read(sites.country),
      ]),
    );
  }

  /// The area of a selection of dives edited together: that of the
  /// earliest of them, with every selected dive left out. Null for an
  /// empty selection or one whose dives are gone.
  Future<SiteAreaAnchor?> forDives(
    List<String> diveIds, {
    String? diverId,
  }) async {
    if (diveIds.isEmpty) return null;
    final dives = _db.dives;
    final when = coalesce<int>([dives.entryTime, dives.diveDateTime]);
    final earliest =
        await (_db.selectOnly(dives)
              ..addColumns([when, dives.tripId])
              ..where(dives.id.isIn(diveIds))
              ..orderBy([
                OrderingTerm(expression: when),
                OrderingTerm(expression: dives.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (earliest == null) return null;
    return forDive(
      at: DateTime.fromMillisecondsSinceEpoch(
        earliest.read(when)!,
        isUtc: true,
      ),
      tripId: earliest.read(dives.tripId),
      diverId: diverId,
      excludeDiveIds: diveIds,
    );
  }
}

String? _firstNonBlank(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}
