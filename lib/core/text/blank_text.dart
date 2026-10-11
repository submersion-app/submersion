/// [text] without surrounding whitespace, or null when nothing is left.
///
/// Free text that is blank counts as absent: an editor field cleared to
/// spaces stores NULL, and a detail row or PDF field for it is left out
/// (#3229).
String? trimmedOrNull(String? text) {
  final trimmed = text?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
