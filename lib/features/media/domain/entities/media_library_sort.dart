import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/models/sort_state_codec.dart';

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
String encodeMediaSort(SortState<MediaSortField> sort) => encodeSortState(sort);

/// Decodes leniently. A value written by a newer build, or a corrupted
/// setting, yields null so the caller can fall back rather than throwing and
/// taking the library view down with it.
SortState<MediaSortField>? decodeMediaSort(String raw) =>
    decodeSortState(raw, MediaSortField.values);
