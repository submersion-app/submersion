import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Everything about [site] that typing in a site picker can match: its name
/// and every location field, so a diver who forgets a name can find the site
/// by where it is (#1080).
///
/// Blank parts are dropped and the rest joined by a space, so two adjacent
/// parts cannot run together into a match neither contains.
String siteSearchText(DiveSite site) =>
    [
          site.name,
          site.country,
          site.region,
          site.city,
          site.island,
          site.bodyOfWater,
        ]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');

/// [siteSearchText] after [normalize]. Callers filtering per keystroke compute
/// this once per site and reuse it.
String normalizedSiteSearchText(DiveSite site) =>
    normalize(siteSearchText(site));

/// One site picker query, normalized and split into words once.
///
/// A site matches when every word is a substring of its normalized search
/// text, so "blue egypt" finds Blue Hole in Dahab, Egypt.
class SiteQuery {
  SiteQuery(String query)
    : words = normalize(query)
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toList(growable: false);

  final List<String> words;

  /// True for an empty or whitespace-only query, which matches everything.
  bool get isEmpty => words.isEmpty;

  /// [normalizedSearchText] must already have been through [normalize].
  bool matches(String normalizedSearchText) =>
      words.every(normalizedSearchText.contains);

  bool matchesSite(DiveSite site) => matches(normalizedSiteSearchText(site));
}
