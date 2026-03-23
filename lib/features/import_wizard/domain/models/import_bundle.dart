import 'package:flutter/widgets.dart';
import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';

/// The source system that produced an [ImportBundle].
enum ImportSourceType {
  /// A UDDF file import.
  uddf,

  /// A Garmin FIT file import.
  fit,

  /// An Apple HealthKit import.
  healthKit,

  /// A universal file import (Subsurface XML, etc.).
  universal,

  /// A dive computer download.
  diveComputer,
}

/// The kind of entity represented by an [EntityGroup].
enum ImportEntityType {
  /// Dive records.
  dives,

  /// Dive sites.
  sites,

  /// Buddies.
  buddies,

  /// Equipment items.
  equipment,

  /// Trips.
  trips,

  /// Certifications.
  certifications,

  /// Dive centers.
  diveCenters,

  /// Tags.
  tags,

  /// Dive types.
  diveTypes,

  /// Equipment sets.
  equipmentSets,

  /// Courses.
  courses,
}

/// Metadata about the source of an [ImportBundle].
class ImportSourceInfo {
  /// The type of source system.
  final ImportSourceType type;

  /// Human-readable name for the source (e.g. filename or device name).
  final String displayName;

  /// Optional metadata about the source (e.g. device info, file headers).
  final Map<String, dynamic>? metadata;

  const ImportSourceInfo({
    required this.type,
    required this.displayName,
    this.metadata,
  });
}

/// A single entity item within an [EntityGroup], ready for display in the
/// wizard review step.
class EntityItem {
  /// Primary display title (e.g. dive date/time or site name).
  final String title;

  /// Secondary display text (e.g. depth and duration summary).
  final String subtitle;

  /// Optional icon for display in the wizard UI.
  final IconData? icon;

  /// Normalized dive data used for duplicate comparison.
  ///
  /// Only set for [ImportEntityType.dives] items. Null for other entity types.
  final IncomingDiveData? diveData;

  const EntityItem({
    required this.title,
    required this.subtitle,
    this.icon,
    this.diveData,
  });
}

/// A group of [EntityItem]s of the same [ImportEntityType].
///
/// The entity type is the Map key in [ImportBundle.groups], not a field here.
class EntityGroup {
  /// The items belonging to this group.
  final List<EntityItem> items;

  /// Indices within [items] that are likely duplicates of existing records.
  final Set<int> duplicateIndices;

  /// Duplicate match results keyed by item index.
  ///
  /// Null when no duplicate matching has been performed.
  final Map<int, DiveMatchResult>? matchResults;

  const EntityGroup({
    required this.items,
    this.duplicateIndices = const {},
    this.matchResults,
  });
}

/// Data contract between import source adapters and the shared wizard UI.
///
/// Carries normalized, display-ready data for all entity types found in an
/// import source. The wizard consumes an [ImportBundle] and renders the
/// review step from it without knowing which source produced it.
class ImportBundle {
  /// Metadata describing where this bundle came from.
  final ImportSourceInfo source;

  /// All entity groups contained in this bundle, keyed by entity type.
  final Map<ImportEntityType, EntityGroup> groups;

  const ImportBundle({required this.source, required this.groups});

  /// Returns the [ImportEntityType]s that have at least one group in this bundle.
  List<ImportEntityType> get availableTypes => List.unmodifiable(groups.keys);

  /// Returns true if this bundle contains a group of the given [type].
  bool hasType(ImportEntityType type) => groups.containsKey(type);
}
