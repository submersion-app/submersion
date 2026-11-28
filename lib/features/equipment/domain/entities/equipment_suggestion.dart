import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// What a diver proposes when their gear fits no existing type (issue #5103).
enum EquipmentSuggestionKind {
  /// A new `EquipmentType`: a new entry in the type list.
  category,

  /// A new style choice inside an existing type, such as an SPG under
  /// Instrument / Gauge.
  subcategory,
}

/// A suggestion for a new equipment category or subcategory, filed as a
/// GitHub issue from the gear editor.
class EquipmentSuggestion extends Equatable {
  const EquipmentSuggestion({
    required this.kind,
    required this.name,
    this.parent,
    required this.reason,
    this.example,
  });

  final EquipmentSuggestionKind kind;

  /// What the diver calls the new category or subcategory.
  final String name;

  /// The existing type it sits under (a subcategory) or sits closest to (a
  /// category). Null only for a category with no close relative.
  final EquipmentType? parent;

  /// Why the existing types do not fit.
  final String reason;

  /// The diver's own item as a real-world example (brand and model), sent
  /// only when they tick the box for it.
  final String? example;

  EquipmentSuggestion copyWith({
    EquipmentSuggestionKind? kind,
    String? name,
    EquipmentType? parent,
    String? reason,
    String? example,
    bool clearParent = false,
    bool clearExample = false,
  }) => EquipmentSuggestion(
    kind: kind ?? this.kind,
    name: name ?? this.name,
    parent: clearParent ? null : parent ?? this.parent,
    reason: reason ?? this.reason,
    example: clearExample ? null : example ?? this.example,
  );

  @override
  List<Object?> get props => [kind, name, parent, reason, example];
}
