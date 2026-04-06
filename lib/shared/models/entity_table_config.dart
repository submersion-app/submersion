import 'package:equatable/equatable.dart';

import 'package:submersion/shared/constants/entity_field.dart';

/// Configuration for a single column in a generic entity table view.
class EntityTableColumnConfig<F extends EntityField> extends Equatable {
  final F field;
  final double width;
  final bool isPinned;

  EntityTableColumnConfig({
    required this.field,
    double? width,
    this.isPinned = false,
  }) : width = width ?? field.defaultWidth;

  EntityTableColumnConfig<F> copyWith({
    F? field,
    double? width,
    bool? isPinned,
  }) {
    return EntityTableColumnConfig<F>(
      field: field ?? this.field,
      width: width ?? this.width,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toJson() {
    return {'field': field.name, 'width': width, 'isPinned': isPinned};
  }

  /// Deserialize from JSON. Requires [fieldFromName] to resolve the field enum.
  static EntityTableColumnConfig<F> fromJson<F extends EntityField>(
    Map<String, dynamic> json,
    F Function(String) fieldFromName,
  ) {
    return EntityTableColumnConfig<F>(
      field: fieldFromName(json['field'] as String),
      width: (json['width'] as num).toDouble(),
      isPinned: json['isPinned'] as bool,
    );
  }

  @override
  List<Object?> get props => [field, width, isPinned];
}

/// Configuration for a generic entity table view, including column order,
/// widths, pinning, and sort state.
class EntityTableViewConfig<F extends EntityField> extends Equatable {
  final List<EntityTableColumnConfig<F>> columns;
  final F? sortField;
  final bool sortAscending;

  const EntityTableViewConfig({
    required this.columns,
    this.sortField,
    this.sortAscending = true,
  });

  EntityTableViewConfig<F> copyWith({
    List<EntityTableColumnConfig<F>>? columns,
    F? sortField,
    bool? sortAscending,
    bool clearSortField = false,
  }) {
    return EntityTableViewConfig<F>(
      columns: columns ?? this.columns,
      sortField: clearSortField ? null : (sortField ?? this.sortField),
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'columns': columns.map((c) => c.toJson()).toList(),
      'sortField': sortField?.name,
      'sortAscending': sortAscending,
    };
  }

  /// Deserialize from JSON. Requires [fieldFromName] to resolve field enums.
  static EntityTableViewConfig<F> fromJson<F extends EntityField>(
    Map<String, dynamic> json,
    F Function(String) fieldFromName,
  ) {
    final sortFieldName = json['sortField'] as String?;
    return EntityTableViewConfig<F>(
      columns: (json['columns'] as List<dynamic>)
          .map(
            (c) => EntityTableColumnConfig.fromJson<F>(
              c as Map<String, dynamic>,
              fieldFromName,
            ),
          )
          .toList(),
      sortField: sortFieldName != null ? fieldFromName(sortFieldName) : null,
      sortAscending: json['sortAscending'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [columns, sortField, sortAscending];
}
