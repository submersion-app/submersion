import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';

/// Interface that all entity field enums implement, providing uniform metadata
/// for the generic table view infrastructure.
///
/// Each entity type (Dive, Site, Trip, etc.) defines its own enum that
/// implements this interface. The generic [EntityTableView] widget uses this
/// interface to render column headers, determine alignment, and check
/// sortability without knowing the concrete entity type.
///
abstract interface class EntityField {
  /// Enum value name, used for JSON serialization of column configs.
  String get name;

  /// Full human-readable name for picker UIs (e.g., "Bottom Time").
  String get displayName;

  /// Compact label for column headers (e.g., "BT").
  String get shortLabel;

  /// Optional Material icon for this field.
  IconData? get icon;

  /// Default column width in logical pixels.
  double get defaultWidth;

  /// Minimum column width when resizing.
  double get minWidth;

  /// Whether this field supports sorting.
  bool get sortable;

  /// Category name for grouping fields in the column picker.
  String get categoryName;

  /// Whether cell content should be right-aligned (numeric fields).
  bool get isRightAligned;
}

/// Adapter that bridges an entity type [T] with its field enum [F],
/// providing entity-specific value extraction and formatting.
///
/// Each entity type provides one adapter. The generic table widget uses
/// this adapter to extract cell values from entities and format them
/// for display, without knowing the concrete entity or field types.
abstract class EntityFieldAdapter<T, F extends EntityField> {
  /// All fields available for this entity type.
  List<F> get allFields;

  /// Fields grouped by category name, for the column picker UI.
  Map<String, List<F>> get fieldsByCategory;

  /// Extract the raw value of [field] from [entity].
  dynamic extractValue(F field, T entity);

  /// Format a raw [value] (from [extractValue]) into a display string.
  String formatValue(F field, dynamic value, UnitFormatter units);

  /// Resolve a field enum value from its [name] string (for JSON deserialization).
  F fieldFromName(String name);
}
