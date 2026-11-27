import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';

/// Result of an altitude resolution.
///
/// [siteAltitudeWriteBack] is non-null only when the altitude came from a
/// lookup of the site's own coordinates: the caller should persist it so
/// future dives at that site resolve locally without a network call. It is
/// deliberately an id plus a number, not a site entity: callers must patch
/// the altitude column alone, because writing a whole entity that was
/// hydrated partially wipes every column it did not carry (issue #1187).
class AltitudeResolution {
  const AltitudeResolution({
    this.altitudeMeters,
    this.siteAltitudeWriteBack,
    this.source,
  });

  final double? altitudeMeters;
  final ({String siteId, double altitudeMeters})? siteAltitudeWriteBack;

  /// Where [altitudeMeters] came from; null when nothing was found.
  final AltitudeSource? source;

  /// Whether the altitude is the dive's own, found from its GPS fixes.
  /// Any other is the site's, which a dive reads through rather than
  /// storing (issue #5040).
  bool get isDiveOwn => source == AltitudeSource.diveLocation;
}

/// Where an [AltitudeResolution] found its altitude.
enum AltitudeSource {
  /// A lookup of the dive's own GPS fixes.
  diveLocation,

  /// The site's stored altitude.
  siteStored,

  /// A lookup of the site's coordinates, to be written back to the site.
  siteLookup,
}

/// Encodes the altitude precedence rule. The 2026-08-06 conditions spec put
/// the dive's GPS first; since a dive reads its site's altitude rather than
/// storing a copy (issue #5040), the site answers first: its stored
/// altitude, then a lookup of its coordinates with write-back. The dive's GPS
/// is looked up only when there is no site, or the site has neither, so a
/// dive at a site is never given an altitude of its own that would hide a
/// later correction to the site's. Auto-fill callers must only apply the
/// result to an empty field; manual entry always wins.
class AltitudeResolver {
  AltitudeResolver({
    required ElevationService elevationService,
    Map<String, double?>? cache,
  }) : _elevation = elevationService,
       _cache = cache;

  final ElevationService _elevation;

  /// Optional per-run lookup cache keyed by coordinates rounded to 4 decimal
  /// places (roughly 11 m) so a batch import at one location does one lookup.
  final Map<String, double?>? _cache;

  Future<AltitudeResolution> resolve({
    GeoPoint? entryLocation,
    GeoPoint? exitLocation,
    DiveSite? site,
  }) async {
    if (site != null) {
      if (site.altitude != null) {
        return AltitudeResolution(
          altitudeMeters: site.altitude,
          source: AltitudeSource.siteStored,
        );
      }
      final siteLocation = site.location;
      if (siteLocation != null) {
        final meters = await _lookup(siteLocation);
        if (meters != null) {
          return AltitudeResolution(
            altitudeMeters: meters,
            siteAltitudeWriteBack: (siteId: site.id, altitudeMeters: meters),
            source: AltitudeSource.siteLookup,
          );
        }
      }
    }

    final divePoint = entryLocation ?? exitLocation;
    if (divePoint != null) {
      final meters = await _lookup(divePoint);
      if (meters != null) {
        return AltitudeResolution(
          altitudeMeters: meters,
          source: AltitudeSource.diveLocation,
        );
      }
    }
    return const AltitudeResolution();
  }

  Future<double?> _lookup(GeoPoint point) async {
    final cache = _cache;
    final key =
        '${point.latitude.toStringAsFixed(4)},'
        '${point.longitude.toStringAsFixed(4)}';
    if (cache != null && cache.containsKey(key)) return cache[key];
    final meters = await _elevation.fetchElevation(
      latitude: point.latitude,
      longitude: point.longitude,
    );
    cache?[key] = meters;
    return meters;
  }
}
