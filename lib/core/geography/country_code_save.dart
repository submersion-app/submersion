import 'package:submersion/core/geography/country_code.dart';

/// A country code and the country text it came with: the geocoder's code
/// for the name it filled in, or a record's stored code for its stored name.
typedef KnownCountryCode = ({String? country, String? code});

/// The ISO code a record saves beside its [country] text (issue #4426).
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

/// The code to store for a record whose [country] and [code] are being
/// written (issues #4426, #4457), the rule every whole-record write of a
/// site or a buddy passes. A buddy's partial write (agent access) has no
/// stored row in hand and reads the code from the text it sets instead
/// (`BuddyCountryColumns.withDerivedCode`).
///
/// Writers that change the country text but carry the old code over (a
/// `copyWith` that sets only the country) would leave the old country's
/// flag beside the new name, and writers that rebuild a record without
/// knowing the field would erase a geocoder's code. So: a changed country
/// whose code did not change with it is read afresh; an unchanged country
/// written without a code keeps the stored one; a new record with no code
/// gets one from its text; any other code is the writer's and is kept.
/// [before] is the stored row's country and code, null for a new record.
String? reconcileCountryCode({
  required String? country,
  required String? code,
  KnownCountryCode? before,
}) {
  if (before == null) return code ?? countryCodeFor(country);
  final textChanged = country?.trim() != before.country?.trim();
  if (textChanged && code == before.code) return countryCodeFor(country);
  if (!textChanged && code == null) {
    final text = country?.trim();
    return text == null || text.isEmpty ? null : before.code;
  }
  return code;
}
