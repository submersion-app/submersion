import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Returns whether [site] matches the site picker [query].
///
/// Matching is case-insensitive and checks site name, location text, country,
/// and region.
bool siteMatchesPickerQuery(DiveSite site, String query) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return true;

  final searchableText = [
    site.name,
    site.locationString,
    site.country ?? '',
    site.region ?? '',
  ].join(' ').toLowerCase();

  return searchableText.contains(normalizedQuery);
}
