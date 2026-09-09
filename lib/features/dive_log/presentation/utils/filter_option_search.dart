import 'package:submersion/core/text/fuzzy_match.dart';

/// Whether [searchText] matches the type-ahead [query] typed into a filter
/// dropdown.
///
/// Matching is a substring test on both sides normalized (trimmed, lowercased,
/// diacritics stripped), so "cancun" finds "Cancún" and "hole" finds
/// "Blue Hole". An empty or whitespace-only query matches everything, which is
/// what keeps the full option list visible before the diver types.
bool filterOptionMatches(String searchText, String query) {
  final normalizedQuery = normalize(query);
  if (normalizedQuery.isEmpty) return true;

  return normalize(searchText).contains(normalizedQuery);
}

/// Joins the searchable [parts] of one option into the single haystack that
/// [filterOptionMatches] tests against.
///
/// Null and blank parts are dropped, and the rest are separated by a space so
/// two adjacent parts cannot run together and produce a match that neither
/// part contains on its own.
String buildFilterSearchText(Iterable<String?> parts) {
  return parts
      .whereType<String>()
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join(' ');
}
