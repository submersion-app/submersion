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
  names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return names;
}

/// Hybrid country suggestions: the user's distinct countries first (alpha),
/// then ISO 3166 country names not already used (alpha).
List<String> suggestedCountries(List<DiveSite> sites) {
  final seen = <String>{};
  final userCountries = <String>[];
  for (final site in sites) {
    final country = site.country?.trim() ?? '';
    if (country.isEmpty) continue;
    if (seen.add(country.toLowerCase())) userCountries.add(country);
  }
  userCountries.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  final extras = isoCountryNames
      .where((c) => !seen.contains(c.toLowerCase()))
      .toList();
  return [...userCountries, ...extras];
}

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
  regions.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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
  cities.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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
    if (want.isNotEmpty &&
        (site.country?.trim().toLowerCase() ?? '') != want) {
      continue;
    }
    if (seen.add(island.toLowerCase())) islands.add(island);
  }
  islands.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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
    if (want.isNotEmpty &&
        (site.country?.trim().toLowerCase() ?? '') != want) {
      continue;
    }
    if (seen.add(body.toLowerCase())) bodies.add(body);
  }
  bodies.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return bodies;
}
