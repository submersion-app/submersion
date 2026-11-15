import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_site_visibility.dart';

/// How far from a built-in record its page looks for neighbours.
const double kCatalogueNearbyRadiusMeters = 10000;

/// The most of the diver's own sites a built-in record's page lists.
const int kCatalogueNearbyOwnLimit = 5;

/// The most built-in records a built-in record's page lists.
const int kCatalogueNearbyRecordLimit = 6;

/// One of the diver's sites near a built-in record.
class NearbyOwnSite {
  const NearbyOwnSite({
    required this.site,
    required this.diveCount,
    required this.meters,
  });

  final DiveSite site;
  final int diveCount;

  /// From the record, over the ground.
  final double meters;
}

/// A built-in record near another.
class NearbyRecord {
  const NearbyRecord({required this.record, required this.meters});

  final CatalogueSite record;

  /// From the record whose page this is, over the ground.
  final double meters;
}

/// What lies near a built-in record, as its page lists it.
class CatalogueNearby {
  const CatalogueNearby({
    this.yours = const [],
    this.builtIn = const [],
    this.here,
  });

  static const empty = CatalogueNearby();

  /// The diver's sites within [kCatalogueNearbyRadiusMeters], nearest
  /// first, at most [kCatalogueNearbyOwnLimit].
  final List<NearbyOwnSite> yours;

  /// Other built-in records in the same radius the diver does not have:
  /// dive sites first, then charted wrecks and reefs, each nearest first,
  /// at most [kCatalogueNearbyRecordLimit].
  final List<NearbyRecord> builtIn;

  /// The nearest of the diver's unlinked sites within
  /// [kCataloguePairRadiusMeters] of the record: very likely the same
  /// place, and the reason the record has no pin on the map.
  final NearbyOwnSite? here;

  /// Whether there is nothing to list.
  bool get isEmpty => yours.isEmpty && builtIn.isEmpty;
}

/// What lies near [record], from [candidates] (catalogue records in any
/// order, which may include [record] itself and ones further off) and the
/// diver's [userSites].
///
/// The built-in list leaves out what the map leaves out: a record the
/// diver has, and one an unlinked site of theirs sits on. The limit is of
/// rows listed, so it is applied after those are left out.
CatalogueNearby catalogueNearby({
  required CatalogueSite record,
  required List<CatalogueSite> candidates,
  required List<SiteWithDiveCount> userSites,
}) {
  final origin = record.location;
  if (origin == null) return CatalogueNearby.empty;

  final mine = [
    for (final entry in userSites)
      if (entry.site.location case final location?)
        NearbyOwnSite(
          site: entry.site,
          diveCount: entry.diveCount,
          meters: distanceMeters(origin, location),
        ),
  ]..sort((a, b) => a.meters.compareTo(b.meters));

  final offered = offerableCatalogueSites(candidates, [
    for (final entry in userSites) entry.site,
  ], byPosition: true);
  final others =
      [
            for (final candidate in offered)
              if (candidate.id != record.id)
                if (candidate.location case final location?)
                  NearbyRecord(
                    record: candidate,
                    meters: distanceMeters(origin, location),
                  ),
          ]
          .where((other) => other.meters <= kCatalogueNearbyRadiusMeters)
          .toList()
        ..sort((a, b) => a.meters.compareTo(b.meters));

  return CatalogueNearby(
    yours: mine
        .where((site) => site.meters <= kCatalogueNearbyRadiusMeters)
        .take(kCatalogueNearbyOwnLimit)
        .toList(),
    builtIn: [
      ...others.where((other) => other.record.kind == CatalogueKind.site),
      ...others.where((other) => other.record.kind == CatalogueKind.register),
    ].take(kCatalogueNearbyRecordLimit).toList(),
    here: mine
        .where(
          (site) =>
              site.site.catalogueId == null &&
              site.meters <= kCataloguePairRadiusMeters,
        )
        .firstOrNull,
  );
}
