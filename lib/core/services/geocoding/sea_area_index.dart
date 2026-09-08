import 'package:submersion/core/services/geocoding/sea_area.dart';

/// Resolves a coordinate to the name of the ocean or sea it lies in.
///
/// This exists because OpenStreetMap has no ocean or sea polygons at all: a
/// Nominatim reverse geocode in open salt water answers "Unable to geocode",
/// and one near a coast snaps to the closest land feature instead (a
/// peninsula, a mountain range, a stream). Almost every dive happens in salt
/// water, so the body-of-water field stayed empty for most sites. The table
/// behind this index is the IHO's own "Limits of Oceans & Seas", generated
/// by `scripts/sea_area_harvester.py`.
///
/// Being asset-resident, it also answers on a boat with no signal.
class SeaAreaIndex {
  const SeaAreaIndex(this.areas);

  factory SeaAreaIndex.fromJson(Map<String, dynamic> json) => SeaAreaIndex([
    for (final a in json['areas'] as List)
      SeaArea.fromJson(a as Map<String, dynamic>),
  ]);

  /// Ascending by [SeaArea.areaSquareDegrees], so the first area containing
  /// a point is also the most specific name for it. The generator writes
  /// them in this order and `sea_area_asset_test.dart` holds it to that.
  final List<SeaArea> areas;

  /// How far outside a sea's limit a point still counts as being in it.
  ///
  /// IHO limits stop at the legal boundary of a sea, which routinely runs
  /// outside an archipelago or a fringing reef, and dive-site coordinates
  /// are routinely recorded from a beach, a jetty or a moored boat. Without
  /// this slack, famous sites in plain salt water (Ras Mohammed, Sipadan,
  /// Bonaire, Santorini) resolve to nothing.
  ///
  /// Four kilometres was measured against the 3,256 bundled dive sites and
  /// a curated set of inland ones: it is the widest slack that still named
  /// nothing for any site in a landlocked country, and for no Yucatan
  /// cenote. Five kilometres starts claiming cenotes for the Caribbean.
  static const double nearShoreKm = 4.0;

  /// The sea or ocean at this coordinate, or null when the point is inland
  /// or in fresh water.
  ///
  /// Cheap enough to run per site in a backfill. Containment rejects on the
  /// bounding box before touching a ring, and the distance walk only runs
  /// when nothing contained the point: measured at roughly 5us for a point
  /// at sea and 11us for the worst case, a point in no area at all, against
  /// the shipped 93,000-vertex table.
  ///
  /// Answers in [languageCode] where the table has that language, and in
  /// English otherwise. Every other geocoded field already honours the
  /// diver's place-name setting, so a sea that stayed English would leave
  /// one column holding two languages: a German diver would read
  /// "Vierwaldstättersee" from the online lookup next to "Red Sea" from
  /// here.
  ///
  /// Returning null is a real answer, not a failure: lakes, quarries,
  /// cenotes and fjord interiors are not in the IHO table, and the caller
  /// falls back to the online lookup, which is good at exactly those.
  ///
  /// A few narrow bands of open water answer null too, because IHO assigns
  /// them to no sea at all. The archipelagic waters inside Fiji are the
  /// one that touches diving: around 16.8 degrees south, the source itself
  /// leaves roughly 180.0E to 179.87W unassigned. That is the dataset, not
  /// the simplification -- the raw layer has the same gap -- so it is
  /// documented rather than papered over.
  String? nameAt(
    double latitude,
    double longitude, {
    String languageCode = 'en',
  }) {
    for (final area in areas) {
      if (area.contains(longitude, latitude)) return area.nameIn(languageCode);
    }

    SeaArea? nearest;
    var nearestKm = double.infinity;
    for (final area in areas) {
      if (!area.isNear(longitude, latitude, nearShoreKm)) continue;
      final distance = area.distanceKm(longitude, latitude);
      if (distance <= nearShoreKm && distance < nearestKm) {
        nearest = area;
        nearestKm = distance;
      }
    }
    return nearest?.nameIn(languageCode);
  }
}
