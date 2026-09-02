import 'package:equatable/equatable.dart';

/// Domain entity for dive types (both built-in and custom)
class DiveTypeEntity extends Equatable {
  final String id; // Unique identifier (slug format)
  final String? diverId; // null for built-in types, set for custom types
  final String name; // Display name
  final bool isBuiltIn; // System type (cannot be deleted)
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Abbreviated form for space-constrained surfaces like the dive detail
  /// header's type badges (e.g. "Wreck" -> "Wreck", "Search & Recovery" ->
  /// "S&R"). Only settable on custom types -- built-ins use the fixed
  /// translated abbreviation in [builtInDiveTypeShortName] instead. Null
  /// means the diver hasn't set one, so callers fall back to [name].
  final String? shortName;

  /// Whether this type's badge appears in the dive detail header's
  /// type-badge row. Defaults to shown.
  final bool showInDetailHeader;

  /// Whether this type's badge appears in the dive list card's type-badge
  /// row. Independent of [showInDetailHeader]. Defaults to shown.
  final bool showInListView;

  const DiveTypeEntity({
    required this.id,
    this.diverId,
    required this.name,
    this.isBuiltIn = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.shortName,
    this.showInDetailHeader = true,
    this.showInListView = true,
  });

  /// Create a new custom dive type
  factory DiveTypeEntity.create({
    required String id,
    required String name,
    String? diverId,
    int sortOrder = 0,
    String? shortName,
    bool showInDetailHeader = true,
    bool showInListView = true,
  }) {
    final now = DateTime.now();
    return DiveTypeEntity(
      id: id,
      diverId: diverId,
      name: name,
      isBuiltIn: false,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
      shortName: shortName,
      showInDetailHeader: showInDetailHeader,
      showInListView: showInListView,
    );
  }

  /// Generate a slug from a display name
  static String generateSlug(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  /// Sentinel marking a `copyWith` parameter as "not provided". Lets callers
  /// distinguish omitting [shortName] (keep the current value) from passing
  /// `null` (clear it) -- plain `value ?? this.value` cannot express a clear,
  /// which broke the edit dialog's "remove an existing short name" flow.
  /// Mirrors [Diver.copyWith]'s `_unset`/`_resolve` pattern.
  static const Object _unset = Object();

  static T _resolve<T>(Object? value, T current) =>
      identical(value, _unset) ? current : value as T;

  DiveTypeEntity copyWith({
    String? id,
    String? diverId,
    String? name,
    bool? isBuiltIn,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? shortName = _unset,
    bool? showInDetailHeader,
    bool? showInListView,
  }) {
    return DiveTypeEntity(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      name: name ?? this.name,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      shortName: _resolve<String?>(shortName, this.shortName),
      showInDetailHeader: showInDetailHeader ?? this.showInDetailHeader,
      showInListView: showInListView ?? this.showInListView,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    isBuiltIn,
    sortOrder,
    createdAt,
    updatedAt,
    shortName,
    showInDetailHeader,
    showInListView,
  ];
}
