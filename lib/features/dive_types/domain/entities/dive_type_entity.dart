import 'package:equatable/equatable.dart';

/// Domain entity for dive types (both built-in and custom)
class DiveTypeEntity extends Equatable {
  final String id; // Unique identifier (slug format)
  final String name; // Display name
  final bool isBuiltIn; // System type (cannot be deleted)
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DiveTypeEntity({
    required this.id,
    required this.name,
    this.isBuiltIn = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a new custom dive type
  factory DiveTypeEntity.create({
    required String id,
    required String name,
    int sortOrder = 0,
  }) {
    final now = DateTime.now();
    return DiveTypeEntity(
      id: id,
      name: name,
      isBuiltIn: false,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
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

  DiveTypeEntity copyWith({
    String? id,
    String? name,
    bool? isBuiltIn,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiveTypeEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, name, isBuiltIn, sortOrder, createdAt, updatedAt];
}
