/// Resolves [text] to the enum value whose display name it is, falling back
/// to the value's `.name`. Both comparisons ignore case and surrounding
/// whitespace. Returns null for blank or unknown text.
///
/// The CSV exports write enums by their English display name ("Boat Entry",
/// "First Stage"); every importer elsewhere matches `.name` only, so reading
/// a Submersion CSV back needs this reverse lookup.
T? enumByDisplayName<T extends Enum>(
  List<T> values,
  String Function(T) displayNameOf,
  String? text,
) {
  final wanted = text?.trim().toLowerCase() ?? '';
  if (wanted.isEmpty) return null;
  for (final value in values) {
    if (displayNameOf(value).toLowerCase() == wanted) return value;
  }
  for (final value in values) {
    if (value.name.toLowerCase() == wanted) return value;
  }
  return null;
}
