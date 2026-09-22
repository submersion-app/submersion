import 'package:submersion/core/utils/number_utils.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';

/// The contract every importer follows for a dive's location (#2232).
///
/// Five importers independently keyed a site's identity on its name and put
/// the name check ahead of the coordinate read, so a file that recorded where
/// a dive happened but not what the place is called imported with no location
/// at all, and said nothing (#2209, #2210, #2211, #2212, #2213). The rules
/// this class exists to hold:
///
/// 1. Coordinates are never discarded because a name is missing. A site
///    without one is named from its coordinates by [named]; a parser with
///    nowhere to put a site writes the pair onto the dive itself as
///    `latitude`/`longitude`, which `UddfEntityImporter` reads into
///    [Dive.entryLocation].
/// 2. A site reference that does not resolve raises [sitesUnresolved] rather
///    than falling off the end of an if/else chain.
/// 3. Only a location with neither a name nor usable coordinates may be
///    dropped, because it carries nothing worth importing.
///
/// `test/architecture/import_site_location_contract_test.dart` is the ratchet:
/// a parser that decides a site's fate on its name alone has to go through
/// here, or the guard fails.
abstract final class ImportSiteLocation {
  /// The name a site takes when the file gave it none.
  ///
  /// This is [GeoPoint]'s own rendering, which is what the Subsurface fold
  /// has used since #2204. Sharing it matters: the same reef arriving from
  /// two files must land under one name, not two.
  static String nameFromCoordinates(double latitude, double longitude) =>
      GeoPoint(latitude, longitude).toString();

  /// [latitude] and [longitude] as a position, or null when the pair is not
  /// one worth keeping.
  ///
  /// Rejects a half pair, a non-finite value, a pair outside the valid range
  /// and the `0.0/0.0` stand-in several logbooks write for "no GPS set".
  ///
  /// A dive's own entry or exit fix is judged by this, exactly as a site's
  /// coordinates are by [coordinatesOf]. They have to agree: a Shearwater
  /// dive at 0,0 that persisted an entry location while the site built from
  /// the very same string was dropped would put the dive in the Atlantic and
  /// leave nothing in the log to explain it.
  static GeoPoint? fix(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return null;
    if (!latitude.isFinite || !longitude.isFinite) return null;
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;
    if (latitude == 0 && longitude == 0) return null;
    return GeoPoint(latitude, longitude);
  }

  /// [site]'s coordinates, or null when it has none worth keeping.
  ///
  /// The map form of [fix]. Accepts an `int` as well as a `double`, since a
  /// whole-degree cell parses as the former.
  static GeoPoint? coordinatesOf(Map<String, dynamic> site) =>
      fix(asDoubleOrNull(site['latitude']), asDoubleOrNull(site['longitude']));

  /// [site] guaranteed to carry a name, or null when it carries nothing worth
  /// importing.
  ///
  /// A site that already has one comes back unchanged, by identity, so a
  /// caller can tell whether anything happened. One without a name but with
  /// coordinates comes back as a copy named from them. One with neither is
  /// the only case a parser may drop, and the drop is then lossless.
  static Map<String, dynamic>? named(Map<String, dynamic> site) {
    final name = (site['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return site;

    final point = coordinatesOf(site);
    if (point == null) return null;

    return Map<String, dynamic>.from(site)
      ..['name'] = nameFromCoordinates(point.latitude, point.longitude);
  }

  /// The notice raised for [count] dives that were imported without the site
  /// they should have had.
  ///
  /// Aggregated into a single row: the summary groups on the code, and a
  /// logbook that lost one site reference has usually lost many. The diver
  /// sees a localized string keyed on the code, so [message] only reaches the
  /// logs; pass one when the default misdescribes what went wrong.
  static ImportWarning sitesUnresolved(int count, {String? message}) =>
      ImportWarning(
        severity: ImportWarningSeverity.warning,
        code: ImportWarningCode.sitesUnresolved,
        message:
            message ??
            '$count dives referred to a dive site the file does not describe',
        entityType: ImportEntityType.dives,
        count: count,
      );
}
