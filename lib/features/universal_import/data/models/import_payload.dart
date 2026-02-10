import 'package:equatable/equatable.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';

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

  const ImportPayload({
    required this.entities,
    this.warnings = const [],
    this.metadata = const {},
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

  @override
  List<Object?> get props => [entities, warnings, metadata];
}
