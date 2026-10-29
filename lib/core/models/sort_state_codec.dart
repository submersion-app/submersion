import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';

/// Encodes [sort] as `field:direction`, the form a list's saved sort is
/// stored in (issue #3748) and the media library sort has always used.
String encodeSortState<T extends Enum>(SortState<T> sort) =>
    '${sort.field.name}:${sort.direction.name}';

/// Decodes a value written by [encodeSortState], leniently.
///
/// Null for a missing value, a malformed one, or a field or direction this
/// build does not know: a newer build may add a sort field, and its synced
/// choice must fall back to the list's starting order here rather than
/// throwing and taking the list down with it.
SortState<T>? decodeSortState<T extends Enum>(String? raw, List<T> values) {
  if (raw == null) return null;
  final parts = raw.split(':');
  if (parts.length != 2) return null;
  final field = decodeEnumName(parts[0], values);
  final direction = decodeEnumName(parts[1], SortDirection.values);
  if (field == null || direction == null) return null;
  return SortState(field: field, direction: direction);
}

/// The value of [values] named [raw], or null when there is none.
T? decodeEnumName<T extends Enum>(String? raw, List<T> values) =>
    raw == null ? null : values.asNameMap()[raw];
