import 'package:submersion/core/geography/country_code.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The site columns a reverse geocode can fill: four place names and the
/// country's ISO code (issue #4426).
class SiteLocationDetails {
  const SiteLocationDetails({
    this.country,
    this.countryCode,
    this.clearCountryCode = false,
    this.region,
    this.city,
    this.bodyOfWater,
  });

  factory SiteLocationDetails.ofSite(DiveSite site) => SiteLocationDetails(
    country: site.country,
    countryCode: site.countryCode,
    region: site.region,
    city: site.city,
    bodyOfWater: site.bodyOfWater,
  );

  final String? country;
  final String? countryCode;

  /// In a merge result, whether the stored code must be cleared: the
  /// country was replaced by one that names no code, so the old code would
  /// put the previous country's flag beside it.
  final bool clearCountryCode;
  final String? region;
  final String? city;
  final String? bodyOfWater;

  bool get isEmpty =>
      country == null &&
      countryCode == null &&
      !clearCountryCode &&
      region == null &&
      city == null &&
      bodyOfWater == null;
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

  final country = fill(current.country, found.country);
  final code = _mergeCode(current, country, found);
  final merged = SiteLocationDetails(
    country: country,
    countryCode: code.code,
    clearCountryCode: code.clear,
    region: fill(current.region, found.region),
    city: fill(current.city, found.locality),
    bodyOfWater: fill(current.bodyOfWater, found.bodyOfWater),
  );
  return merged.isEmpty ? null : merged;
}

/// The code to write beside [writtenCountry] (null when the code stays),
/// and whether the stored code must be cleared instead.
///
/// A written country brings the geocoder's code with it, or the code its
/// name reads as; when it has neither, a stored code is cleared rather than
/// left beside a country it no longer names. A kept country (the diver's own
/// text) gains the geocoder's code only when it has none stored and its text
/// names no other country, so geocoding never contradicts what the diver
/// wrote.
({String? code, bool clear}) _mergeCode(
  SiteLocationDetails current,
  String? writtenCountry,
  PlaceLookup found,
) {
  if (writtenCountry != null) {
    final code = found.countryCode ?? countryCodeFor(writtenCountry);
    if (code == null) {
      return (code: null, clear: !_isBlank(current.countryCode));
    }
    return (code: code == current.countryCode ? null : code, clear: false);
  }
  // A code never stands without a country beside it: the site editor drops
  // one on save, so writing it here would only leave the two disagreeing.
  if (_isBlank(current.country)) return (code: null, clear: false);
  final foundCode = found.countryCode ?? countryCodeFor(found.country);
  if (foundCode == null || !_isBlank(current.countryCode)) {
    return (code: null, clear: false);
  }
  final readAs = countryCodeFor(current.country);
  return (
    code: readAs == null || readAs == foundCode ? foundCode : null,
    clear: false,
  );
}
