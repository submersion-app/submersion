import 'package:submersion/core/geography/country_code.dart';

/// A country code and the country text it came with: the geocoder's code
/// for the name it filled in, or a site's stored code for its stored name.
typedef KnownCountryCode = ({String? country, String? code});

/// The ISO code a site saves beside its [country] text (issue #4426).
///
/// Text left as it came keeps the code that came with it, so a geocoded
/// name the table cannot read ("Korea") keeps the geocoder's code. Text the
/// diver changed is read afresh with [countryCodeFor], or gets no code when
/// it names no country, so a hand edit never leaves a stale flag behind.
String? countryCodeOnSave({
  required String? country,
  required KnownCountryCode known,
}) {
  final text = country?.trim();
  if (text == null || text.isEmpty) return null;
  if (known.code != null && known.country?.trim() == text) return known.code;
  return countryCodeFor(text);
}
