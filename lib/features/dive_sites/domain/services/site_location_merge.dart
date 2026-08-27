import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The four site columns a reverse geocode can fill.
class SiteLocationDetails {
  const SiteLocationDetails({
    this.country,
    this.region,
    this.city,
    this.bodyOfWater,
  });

  factory SiteLocationDetails.ofSite(DiveSite site) => SiteLocationDetails(
    country: site.country,
    region: site.region,
    city: site.city,
    bodyOfWater: site.bodyOfWater,
  );

  final String? country;
  final String? region;
  final String? city;
  final String? bodyOfWater;

  bool get isEmpty =>
      country == null && region == null && city == null && bodyOfWater == null;
}

bool _isBlank(String? value) => value == null || value.trim().isEmpty;

/// The single home of the "only fill empty fields" rule (issue #1187).
///
/// Returns the values to write, with null for every field that must not
/// change, or null when nothing should change. A field is filled only when
/// [current] is blank and [found] has a non-blank value for it; manual edits
/// and deliberate clears are never overwritten here. The lookup's locality
/// maps to the site's city column.
SiteLocationDetails? mergeMissingLocationDetails({
  required SiteLocationDetails current,
  required PlaceLookup found,
}) {
  String? fill(String? existing, String? candidate) =>
      _isBlank(existing) && !_isBlank(candidate) ? candidate!.trim() : null;

  final merged = SiteLocationDetails(
    country: fill(current.country, found.country),
    region: fill(current.region, found.region),
    city: fill(current.city, found.locality),
    bodyOfWater: fill(current.bodyOfWater, found.bodyOfWater),
  );
  return merged.isEmpty ? null : merged;
}
