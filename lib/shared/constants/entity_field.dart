import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

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
  ///
  /// English fallback. UI code should prefer [localizedDisplayName]; this
  /// getter stays English so exports and stored configs remain stable.
  String get displayName;

  /// Compact label for column headers (e.g., "BT").
  ///
  /// English fallback. UI code should prefer [localizedShortLabel].
  String get shortLabel;

  /// Localized full name for picker UIs.
  String localizedDisplayName(AppLocalizations l10n);

  /// Localized compact label for column headers.
  String localizedShortLabel(AppLocalizations l10n);

  /// Optional Material icon for this field.
  IconData? get icon;

  /// Default column width in logical pixels.
  double get defaultWidth;

  /// Minimum column width when resizing.
  double get minWidth;

  /// Whether this field supports sorting.
  bool get sortable;

  /// Stable category slug for grouping fields in the column picker.
  ///
  /// This is an identifier, not display text. Render it through
  /// [localizedFieldCategory].
  String get categoryName;

  /// Whether cell content should be right-aligned (numeric fields).
  bool get isRightAligned;
}

/// The string every [EntityFieldAdapter.formatValue] renders for a value it
/// has nothing to show: a null, or a non-null but empty String.
const String kFieldValuePlaceholder = '--';

/// Whether a formatted field value carries nothing worth rendering.
///
/// A table cell wants [kFieldValuePlaceholder]: the column has a header, so
/// the placeholder marks the row as empty and keeps the grid aligned. A card
/// has no header, so the same string is noise ("Notes: --"), and card
/// renderers drop these fields instead.
bool isBlankFieldValue(String formatted) {
  final trimmed = formatted.trim();
  return trimmed.isEmpty || trimmed == kFieldValuePlaceholder;
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

/// Localized label for a field category slug.
///
/// Category slugs ([EntityField.categoryName], plus the `DiveFieldCategory`
/// and `SiteFieldCategory` enum names) are shared across entity types, so one
/// resolver serves every field enum. Unknown slugs fall back to the raw slug rather
/// than throwing, so a newly added category degrades to an untranslated
/// header instead of crashing the column picker.
String localizedFieldCategory(AppLocalizations l10n, String categoryName) {
  return switch (categoryName) {
    // The 14 DiveFieldCategory slugs already have a translated key family from
    // the dive column picker; reuse it rather than ship a second set of
    // translations for the same words.
    'core' => l10n.diveField_category_core,
    'deco' => l10n.diveField_category_deco,
    'environment' => l10n.diveField_category_environment,
    'equipment' => l10n.diveField_category_equipment,
    'gas' => l10n.diveField_category_gas,
    'location' => l10n.diveField_category_location,
    'metadata' => l10n.diveField_category_metadata,
    'people' => l10n.diveField_category_people,
    'physiology' => l10n.diveField_category_physiology,
    'rating' => l10n.diveField_category_rating,
    'rebreather' => l10n.diveField_category_rebreather,
    'tank' => l10n.diveField_category_tank,
    'trip' => l10n.diveField_category_trip,
    'weight' => l10n.diveField_category_weight,
    // Slugs introduced by the per-entity field enums and SiteFieldCategory.
    'accommodation' => l10n.enum_fieldCategory_accommodation,
    'address' => l10n.enum_fieldCategory_address,
    'certification' => l10n.enum_fieldCategory_certification,
    'conditions' => l10n.enum_fieldCategory_conditions,
    'contact' => l10n.enum_fieldCategory_contact,
    'coordinates' => l10n.enum_fieldCategory_coordinates,
    'dates' => l10n.enum_fieldCategory_dates,
    'depth' => l10n.enum_fieldCategory_depth,
    'details' => l10n.enum_fieldCategory_details,
    'instructor' => l10n.enum_fieldCategory_instructor,
    'other' => l10n.enum_fieldCategory_other,
    'purchase' => l10n.enum_fieldCategory_purchase,
    'service' => l10n.enum_fieldCategory_service,
    'statistics' => l10n.enum_fieldCategory_statistics,
    _ => categoryName,
  };
}
