import 'package:equatable/equatable.dart';

/// A dive site type (issue #1765): a built-in (reef, wall, wreck, ...) or a
/// custom type a diver created. Named `SiteTypeEntity` because Drift already
/// generates `SiteType` for the table row.
class SiteTypeEntity extends Equatable {
  final String id; // Slug
  final String? diverId; // null for built-ins
  final String name;
  final bool isBuiltIn;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SiteTypeEntity({
    required this.id,
    this.diverId,
    required this.name,
    this.isBuiltIn = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SiteTypeEntity.create({
    required String id,
    required String name,
    String? diverId,
    int sortOrder = 0,
  }) {
    final now = DateTime.now();
    return SiteTypeEntity(
      id: id,
      diverId: diverId,
      name: name,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Same slug rules as `DiveTypeEntity.generateSlug`.
  static String generateSlug(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  SiteTypeEntity copyWith({
    String? id,
    String? diverId,
    String? name,
    bool? isBuiltIn,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SiteTypeEntity(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      name: name ?? this.name,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
  ];
}
