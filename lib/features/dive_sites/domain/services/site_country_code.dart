import 'package:submersion/core/geography/country_code.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

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

/// The code to store for [site] as it is written (issue #4426), the one
/// place every write through the repository passes.
///
/// Writers that change the country text but carry the old code over (a
/// `copyWith` that sets only `country`) would leave the old country's flag
/// beside the new name, and writers that rebuild a site without knowing the
/// field would erase a geocoder's code. So: a changed country whose code did
/// not change with it is read afresh; an unchanged country written without a
/// code keeps the stored one; a new site with no code gets one from its
/// text; any other code is the writer's and is kept. [before] is the row as
/// stored, null for a new site.
String? reconciledCountryCode(DiveSite site, {DiveSite? before}) {
  if (before == null) return site.countryCode ?? countryCodeFor(site.country);
  final textChanged = site.country?.trim() != before.country?.trim();
  if (textChanged && site.countryCode == before.countryCode) {
    return countryCodeFor(site.country);
  }
  if (!textChanged && site.countryCode == null) {
    final text = site.country?.trim();
    return text == null || text.isEmpty ? null : before.countryCode;
  }
  return site.countryCode;
}
