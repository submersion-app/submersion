import 'package:submersion/core/text/fuzzy_match.dart';

/// One type-ahead query, normalized once so that testing it against a long
/// option list does not re-normalize it per option.
///
/// Matching is a substring test with both sides normalized (trimmed,
/// lowercased, diacritics stripped), so "cancun" finds "Cancún" and "hole"
/// finds "Blue Hole". An empty or whitespace-only query matches everything,
/// which is what keeps the full option list visible before the diver types.
class FilterOptionQuery {
  FilterOptionQuery(String query) : normalizedQuery = normalize(query);

  final String normalizedQuery;

  /// Tests one option. [normalizedSearchText] must already have been through
  /// [normalize]; normalizing it here would put the cost back on every
  /// keystroke, which is the whole reason this type exists.
  bool matches(String normalizedSearchText) =>
      normalizedQuery.isEmpty || normalizedSearchText.contains(normalizedQuery);
}

/// Whether [searchText] matches the type-ahead [query], normalizing both.
///
/// Convenient for one-off checks. Filtering a list per keystroke should build
/// a [FilterOptionQuery] once and match against search text normalized ahead
/// of time instead.
bool filterOptionMatches(String searchText, String query) =>
    FilterOptionQuery(query).matches(normalize(searchText));

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
