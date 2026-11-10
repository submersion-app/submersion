import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/database/tag_scope_tables.dart';
import 'package:submersion/features/tags/domain/tag_palette.dart';

/// Where a tag is offered (issues #1765, #1942, #1970). A tag applies to at
/// least one. Member order follows [tagScopeTables], which is the display order.
enum TagScope {
  dives,
  sites,
  equipment,
  media,
  documents;

  /// Every scope: where a tag the user creates is offered, so it can be
  /// reused on dives, sites, media and the rest alike (issue #4407).
  /// Narrowing it is a choice made afterwards in Manage Tags.
  static Set<TagScope> get everywhere => values.toSet();

  /// Where this scope stores its flag and its links.
  TagScopeTable get table => switch (this) {
    TagScope.dives => diveTagScopeTable,
    TagScope.sites => siteTagScopeTable,
    TagScope.equipment => equipmentTagScopeTable,
    TagScope.media => mediaTagScopeTable,
    TagScope.documents => documentTagScopeTable,
  };
}

/// Tag entity for organizing dives, dive sites, equipment, media and
/// documents
class Tag extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final String? colorHex; // Hex color code like '#FF5733'
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Where the tag is offered (issues #1765, #1942, #1970). Never empty once
  /// stored:
  /// TagRepository rejects a tag with no scope. Treat as read-only.
  final Set<TagScope> scopes;

  const Tag({
    required this.id,
    this.diverId,
    required this.name,
    this.colorHex,
    required this.createdAt,
    required this.updatedAt,
    this.scopes = const {TagScope.dives},
  });

  /// The colour the tag is drawn in. A tag with no usable colour (one an
  /// import created, say) is drawn as the palette Blue (issue #4384).
  Color get color => drawnTagColor(colorHex);

  /// Whether the tag is offered where [scope] is.
  bool appliesTo(TagScope scope) => scopes.contains(scope);

  /// Create a new tag with a default color, offered in [scope] only.
  factory Tag.create({
    required String id,
    required String name,
    String? diverId,
    String? colorHex,
    TagScope scope = TagScope.dives,
  }) {
    final now = DateTime.now();
    return Tag(
      id: id,
      diverId: diverId,
      name: name,
      colorHex: colorHex,
      createdAt: now,
      updatedAt: now,
      scopes: {scope},
    );
  }

  Tag copyWith({
    String? id,
    String? diverId,
    String? name,
    String? colorHex,
    DateTime? createdAt,
    DateTime? updatedAt,
    Set<TagScope>? scopes,
  }) {
    return Tag(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      scopes: scopes ?? this.scopes,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    colorHex,
    createdAt,
    updatedAt,
    scopes,
  ];
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
