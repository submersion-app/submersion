/// The [suggestions] that contain [text], compared without case, in their
/// given order. Empty when [text] is blank, so an untouched field offers
/// nothing. Shared by the autocomplete fields (SuggestionFormRow, the buddy
/// Country field).
List<String> suggestionsContaining(List<String> suggestions, String text) {
  final query = text.trim().toLowerCase();
  if (query.isEmpty) return const [];
  return [
    for (final suggestion in suggestions)
      if (suggestion.toLowerCase().contains(query)) suggestion,
  ];
}
