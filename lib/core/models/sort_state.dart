import 'package:submersion/core/constants/sort_options.dart';

/// Generic sort state that can be used across all entity types.
///
/// Type parameter [T] is the enum type representing sortable fields
/// for a specific entity (e.g., DiveSortField, SiteSortField).
class SortState<T extends Enum> {
  final T field;
  final SortDirection direction;

  const SortState({
    required this.field,
    this.direction = SortDirection.descending,
  });

  /// Create a copy with optional field/direction changes
  SortState<T> copyWith({T? field, SortDirection? direction}) {
    return SortState<T>(
      field: field ?? this.field,
      direction: direction ?? this.direction,
    );
  }

  /// Toggle the sort direction
  SortState<T> toggleDirection() {
    return copyWith(direction: direction.opposite);
  }

  /// Change to a new field with optional default direction
  SortState<T> withField(T newField, {SortDirection? defaultDirection}) {
    return SortState<T>(
      field: newField,
      direction: defaultDirection ?? SortDirection.descending,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SortState<T> &&
        other.field == field &&
        other.direction == direction;
  }

  @override
  int get hashCode => Object.hash(field, direction);

  @override
  String toString() => 'SortState<$T>(field: $field, direction: $direction)';
}
