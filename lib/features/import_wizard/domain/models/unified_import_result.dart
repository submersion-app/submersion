import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';

/// The outcome of a completed unified import wizard run.
///
/// Holds per-entity-type import counts, the number of dives consolidated
/// with existing log entries, the number of dives whose source data was
/// replaced, skipped items, and an optional error message.
class UnifiedImportResult {
  /// Number of entities imported, keyed by [ImportEntityType].
  final Map<ImportEntityType, int> importedCounts;

  /// Number of dives that were consolidated with an existing dive log entry.
  final int consolidatedCount;

  /// Number of dives whose source data was replaced with freshly downloaded
  /// data (replaceSource duplicate action).
  final int updatedCount;

  /// Number of items that were skipped (e.g. detected duplicates the user
  /// chose not to import).
  final int skippedCount;

  /// IDs of the dives that were imported, for post-import filtering.
  final List<String> importedDiveIds;

  /// Photo references parsed from the source (MacDive XML/SQLite). Empty for
  /// formats that carry none. Drives the post-import photo-locate prompt.
  final List<ImportImageRef> imageRefs;

  /// Combined source-UUID -> dive-ID map covering both newly-created dives
  /// and matched-existing duplicates, so photos link to either.
  final Map<String, String> sourceUuidToDiveId;

  /// Non-null when the import failed with an error.
  final String? errorMessage;

  const UnifiedImportResult({
    required this.importedCounts,
    required this.consolidatedCount,
    this.updatedCount = 0,
    required this.skippedCount,
    this.importedDiveIds = const [],
    this.imageRefs = const [],
    this.sourceUuidToDiveId = const {},
    this.errorMessage,
  });
}
