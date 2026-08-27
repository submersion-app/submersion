import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';

/// The library's sort vocabulary, in the domain layer because both the
/// repository (which compiles it to SQL) and the presentation providers
/// (which persist and edit it) depend on it. A data-layer class importing a
/// presentation provider would invert the dependency direction.

/// Newest first, matching the ordering the library shipped with before a sort
/// control existed. Also the fallback whenever a persisted value cannot be
/// read.
const SortState<MediaSortField> kDefaultMediaSort = SortState(
  field: MediaSortField.dateTaken,
  direction: SortDirection.descending,
);

/// Persisted form: `<field>:<direction>`, both enum names. Names are stable
/// across locales and devices, which is what makes the stored value portable.
String encodeMediaSort(SortState<MediaSortField> sort) =>
    '${sort.field.name}:${sort.direction.name}';

/// Decodes leniently. A value written by a newer build, or a corrupted
/// setting, yields null so the caller can fall back rather than throwing and
/// taking the library view down with it.
SortState<MediaSortField>? decodeMediaSort(String raw) {
  final parts = raw.split(':');
  if (parts.length != 2) return null;
  final field = MediaSortField.values
      .where((f) => f.name == parts[0])
      .firstOrNull;
  final direction = SortDirection.values
      .where((d) => d.name == parts[1])
      .firstOrNull;
  if (field == null || direction == null) return null;
  return SortState(field: field, direction: direction);
}
