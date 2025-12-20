import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Tag entity for organizing dives
class Tag extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final String? colorHex; // Hex color code like '#FF5733'
  final DateTime createdAt;
  final DateTime updatedAt;

  const Tag({
    required this.id,
    this.diverId,
    required this.name,
    this.colorHex,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get the color as a Flutter Color object
  Color get color {
    if (colorHex == null || colorHex!.isEmpty) {
      return Colors.blue; // Default color
    }
    try {
      final hex = colorHex!.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  /// Create a new tag with a default color
  factory Tag.create({
    required String id,
    required String name,
    String? diverId,
    String? colorHex,
  }) {
    final now = DateTime.now();
    return Tag(
      id: id,
      diverId: diverId,
      name: name,
      colorHex: colorHex,
      createdAt: now,
      updatedAt: now,
    );
  }

  Tag copyWith({
    String? id,
    String? diverId,
    String? name,
    String? colorHex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tag(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, diverId, name, colorHex, createdAt, updatedAt];
}

/// Predefined tag colors for selection
class TagColors {
  static const List<String> predefined = [
    '#EF4444', // Red
    '#F97316', // Orange
    '#F59E0B', // Amber
    '#EAB308', // Yellow
    '#84CC16', // Lime
    '#22C55E', // Green
    '#10B981', // Emerald
    '#14B8A6', // Teal
    '#06B6D4', // Cyan
    '#0EA5E9', // Sky
    '#3B82F6', // Blue
    '#6366F1', // Indigo
    '#8B5CF6', // Violet
    '#A855F7', // Purple
    '#D946EF', // Fuchsia
    '#EC4899', // Pink
    '#F43F5E', // Rose
    '#78716C', // Stone
    '#71717A', // Zinc
    '#64748B', // Slate
  ];

  static Color fromHex(String hex) {
    final cleanHex = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleanHex', radix: 16));
  }
}
