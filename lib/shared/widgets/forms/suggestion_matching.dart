import 'package:submersion/core/text/fuzzy_match.dart';

/// The [suggestions] that contain [text], compared without case or accents
/// (so "curacao" finds "Curaçao", #4498), in their given order. Empty when
/// [text] is blank, so an untouched field offers nothing. Shared by the
/// autocomplete fields (SuggestionFormRow, the buddy Country field).
List<String> suggestionsContaining(List<String> suggestions, String text) {
  final query = foldForSearch(text.trim());
  if (query.isEmpty) return const [];
  return [
    for (final suggestion in suggestions)
      if (foldForSearch(suggestion).contains(query)) suggestion,
  ];
}
