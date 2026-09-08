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

/// The single home of the rule that decides which of the four columns a
/// reverse geocode may write (issue #1187).
///
/// Returns the values to write, with null for every field that must not
/// change, or null when nothing should change. The lookup's locality maps to
/// the site's city column.
///
/// With [overwrite] false a field is filled only when [current] is blank, so
/// manual edits and deliberate clears survive. With it true a found value
/// also replaces a differing stored one, which is how a database geocoded in
/// more than one language is brought back to a single language; a field the
/// lookup did not resolve is still never cleared, and a value that already
/// matches is reported as no change so the row is not written for nothing.
SiteLocationDetails? mergeLocationDetails({
  required SiteLocationDetails current,
  required PlaceLookup found,
  required bool overwrite,
}) {
  String? fill(String? existing, String? candidate) {
    if (_isBlank(candidate)) return null;
    final value = candidate!.trim();
    if (_isBlank(existing)) return value;
    if (!overwrite) return null;
    return existing!.trim() == value ? null : value;
  }

  final merged = SiteLocationDetails(
    country: fill(current.country, found.country),
    region: fill(current.region, found.region),
    city: fill(current.city, found.locality),
    bodyOfWater: fill(current.bodyOfWater, found.bodyOfWater),
  );
  return merged.isEmpty ? null : merged;
}
