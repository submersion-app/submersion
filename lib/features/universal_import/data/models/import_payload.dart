import 'package:equatable/equatable.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';

/// Unified import payload produced by all parsers.
///
/// Contains entities organized by type, using `Map<String, dynamic>` for each
/// item to maintain compatibility with the existing UDDF import infrastructure
/// (duplicate checker, entity importer, review UI).
///
/// The map keys match the field names expected by `UddfEntityImporter`:
/// - Dives: `dateTime`, `maxDepth`, `duration`, `siteName`, `notes`, etc.
/// - Sites: `name`, `latitude`, `longitude`, `description`, etc.
/// - Equipment: `name`, `type`, `brand`, `model`, etc.
/// - Buddies: `name`, `email`, `phone`, etc.
class ImportPayload extends Equatable {
  /// Entities organized by type. Only types with data are included.
  final Map<ImportEntityType, List<Map<String, dynamic>>> entities;

  /// Warnings encountered during parsing.
  final List<ImportWarning> warnings;

  /// Metadata about the import source.
  final Map<String, dynamic> metadata;

  /// [metadata] key for custom dive role definitions (a list of maps with
  /// `id`, `name`, `sortOrder`, `isBuiltIn`). They have no review step, so
  /// they ride here rather than as an entity type, and are restored ahead
  /// of the dive links that reference them.
  static const customDiveRolesKey = 'customDiveRoles';

  /// Metadata key for custom site type definitions (issue #1765): maps with
  /// `id`, `name` and `sortOrder`. Like dive roles they have no review step;
  /// site maps reference them by id in `siteTypeRefs`.
  static const customSiteTypesKey = 'customSiteTypes';

  /// The people the source attributes records to (issue #1893). Empty for
  /// every format that has no notion of several divers.
  final List<SourceDiver> sourceDivers;

  const ImportPayload({
    required this.entities,
    this.warnings = const [],
    this.metadata = const {},
    this.sourceDivers = const [],
  });

  /// Get entities of a specific type, or empty list if none.
  List<Map<String, dynamic>> entitiesOf(ImportEntityType type) {
    return entities[type] ?? const [];
  }

  /// Total count of all entities across all types.
  int get totalEntityCount =>
      entities.values.fold(0, (sum, list) => sum + list.length);

  /// Entity types that have data.
  List<ImportEntityType> get availableTypes => entities.entries
      .where((e) => e.value.isNotEmpty)
      .map((e) => e.key)
      .toList();

  /// Whether the payload has any data to import.
  bool get isEmpty => entities.values.every((list) => list.isEmpty);

  /// Whether the payload has any data to import.
  bool get isNotEmpty => !isEmpty;

  /// The message to show when this payload imports nothing, from
  /// [ImportFailureDetail.failureDetail]; null when nothing showable was
  /// recorded.
  String? get failureReason => warnings.failureDetail?.message;

  /// Whether two or more divers have records, so the wizard must ask where
  /// each diver's records go (issue #1893). Records with no diver do not
  /// count: in a one-diver library they are that diver's.
  bool get needsDiverMapping =>
      sourceDivers.where((d) => !d.isUnowned && d.hasRecords).length > 1;

  @override
  List<Object?> get props => [entities, warnings, metadata, sourceDivers];
}
