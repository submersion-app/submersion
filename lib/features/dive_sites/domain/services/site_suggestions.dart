import 'package:submersion/core/geography/country_code.dart';
import 'package:submersion/core/geography/country_display_names.generated.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/dive_sites/domain/constants/iso_countries.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Distinct, alpha-sorted site names from [sites], optionally excluding the
/// site with [excludeId] (so a site being edited never suggests/flags itself).
List<String> suggestedSiteNames(List<DiveSite> sites, {String? excludeId}) {
  final seen = <String>{};
  final names = <String>[];
  for (final site in sites) {
    if (excludeId != null && site.id == excludeId) continue;
    final name = site.name.trim();
    if (name.isEmpty) continue;
    if (seen.add(name.toLowerCase())) names.add(name);
  }
  names.sort((a, b) => compareTextForSort(a, b));
  return names;
}

/// Hybrid country suggestions: the user's distinct countries first (alpha),
/// then the countries not already used, named in [language] (alpha).
List<String> suggestedCountries(
  List<DiveSite> sites, {
  required String language,
}) => suggestedCountryNames(
  sites.map((site) => site.country),
  language: language,
);

/// Country suggestions from any [used] country texts, such as buddies' and
/// sites' (issue #4457): the distinct used names first (alpha, compared
/// without case), then the countries of [isoCountryNames] not already used,
/// named in the diver's place-name [language] (issue #5019).
///
/// A country counts as used whatever language its text is in, so a stored
/// "Frankreich" keeps "France" out of the list rather than beside it.
List<String> suggestedCountryNames(
  Iterable<String?> used, {
  required String language,
}) {
  final seen = <String>{};
  final usedCodes = <String>{};
  final userCountries = <String>[];
  for (final value in used) {
    final country = value?.trim() ?? '';
    if (country.isEmpty) continue;
    if (!seen.add(country.toLowerCase())) continue;
    userCountries.add(country);
    final code = countryCodeFor(country);
    if (code != null) usedCodes.add(code);
  }
  userCountries.sort((a, b) => compareTextForSort(a, b));
  final extras = [
    for (final (:code, :name) in _isoCountriesIn(language))
      if (!usedCodes.contains(code) && !seen.contains(name.toLowerCase())) name,
  ];
  return [...userCountries, ...extras];
}

/// [isoCountryNames] with each country's code, named in [language] and
/// sorted: the generated CLDR name, or the English one for English, for a
/// language the table lacks, and for a country it has no name for. Built
/// once per language.
List<({String code, String name})> _isoCountriesIn(String language) =>
    _isoCountriesByLanguage[language] ??= () {
      final names = cldrCountryDisplayNames[language];
      final countries = [
        for (final english in isoCountryNames)
          if (countryCodeFor(english) case final code?)
            (code: code, name: names?[code] ?? english),
      ];
      countries.sort((a, b) => compareTextForSort(a.name, b.name));
      return List<({String code, String name})>.unmodifiable(countries);
    }();

final Map<String, List<({String code, String name})>> _isoCountriesByLanguage =
    {};

/// Distinct, alpha-sorted regions from [sites]. When [country] is non-empty,
/// only regions used with that country (case-insensitive) are returned;
/// otherwise all distinct regions.
List<String> suggestedRegions(List<DiveSite> sites, String country) {
  final wanted = country.trim().toLowerCase();
  final seen = <String>{};
  final regions = <String>[];
  for (final site in sites) {
    final region = site.region?.trim() ?? '';
    if (region.isEmpty) continue;
    if (wanted.isNotEmpty &&
        (site.country?.trim().toLowerCase() ?? '') != wanted) {
      continue;
    }
    if (seen.add(region.toLowerCase())) regions.add(region);
  }
  regions.sort((a, b) => compareTextForSort(a, b));
  return regions;
}

/// Distinct, alpha-sorted cities. When [country] and/or [region] are non-empty,
/// only cities used with that country (and region) are returned.
List<String> suggestedCities(
  List<DiveSite> sites,
  String country,
  String region,
) {
  final wantCountry = country.trim().toLowerCase();
  final wantRegion = region.trim().toLowerCase();
  final seen = <String>{};
  final cities = <String>[];
  for (final site in sites) {
    final city = site.city?.trim() ?? '';
    if (city.isEmpty) continue;
    if (wantCountry.isNotEmpty &&
        (site.country?.trim().toLowerCase() ?? '') != wantCountry) {
      continue;
    }
    if (wantRegion.isNotEmpty &&
        (site.region?.trim().toLowerCase() ?? '') != wantRegion) {
      continue;
    }
    if (seen.add(city.toLowerCase())) cities.add(city);
  }
  cities.sort((a, b) => compareTextForSort(a, b));
  return cities;
}

/// Distinct, alpha-sorted islands. When [country] is non-empty, only islands
/// used with that country are returned.
List<String> suggestedIslands(List<DiveSite> sites, String country) {
  final want = country.trim().toLowerCase();
  final seen = <String>{};
  final islands = <String>[];
  for (final site in sites) {
    final island = site.island?.trim() ?? '';
    if (island.isEmpty) continue;
    if (want.isNotEmpty && (site.country?.trim().toLowerCase() ?? '') != want) {
      continue;
    }
    if (seen.add(island.toLowerCase())) islands.add(island);
  }
  islands.sort((a, b) => compareTextForSort(a, b));
  return islands;
}

/// Distinct, alpha-sorted bodies of water. When [country] is non-empty, only
/// bodies of water used with that country are returned.
List<String> suggestedBodiesOfWater(List<DiveSite> sites, String country) {
  final want = country.trim().toLowerCase();
  final seen = <String>{};
  final bodies = <String>[];
  for (final site in sites) {
    final body = site.bodyOfWater?.trim() ?? '';
    if (body.isEmpty) continue;
    if (want.isNotEmpty && (site.country?.trim().toLowerCase() ?? '') != want) {
      continue;
    }
    if (seen.add(body.toLowerCase())) bodies.add(body);
  }
  bodies.sort((a, b) => compareTextForSort(a, b));
  return bodies;
}
