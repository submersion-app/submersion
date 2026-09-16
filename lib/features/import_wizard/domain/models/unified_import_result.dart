import 'package:submersion/features/dive_computer/data/services/planned_dive_fill_service.dart';
import 'package:submersion/features/import_wizard/domain/models/diver_import_outcome.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_file_outcome.dart';
import 'package:submersion/features/import_wizard/domain/models/import_notice.dart';

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

  /// Planned dives filled from a download and promoted (issue #2002).
  final int filledCount;

  /// One outcome per filled planned dive, so the summary can undo them.
  final List<PlannedDiveFillOutcome> fillOutcomes;

  /// Number of items that were skipped (e.g. detected duplicates the user
  /// chose not to import).
  final int skippedCount;

  /// IDs of the dives that were imported, for post-import filtering.
  final List<String> importedDiveIds;

  /// Non-null when the import failed with an error.
  final String? errorMessage;

  /// Per-file outcomes for bulk imports; empty for single-file/DC imports.
  final List<ImportFileOutcome> fileOutcomes;

  /// Number of photos attached to imported dives (ZIP imports only).
  final int attachedPhotoCount;

  /// Photos in an imported archive that matched no dive file — surfaced in
  /// the summary so photos are never silently dropped.
  final int unmatchedPhotoCount;

  /// Data the source files did not contain, grouped by kind. The import still
  /// succeeded; these explain why an expected figure is blank.
  final List<ImportNotice> notices;

  /// What each profile received when one import wrote to several
  /// (issue #1893). Empty for an import into the active profile alone.
  final List<DiverImportOutcome> diverOutcomes;

  const UnifiedImportResult({
    required this.importedCounts,
    required this.consolidatedCount,
    this.updatedCount = 0,
    this.filledCount = 0,
    this.fillOutcomes = const [],
    required this.skippedCount,
    this.importedDiveIds = const [],
    this.errorMessage,
    this.fileOutcomes = const [],
    this.attachedPhotoCount = 0,
    this.unmatchedPhotoCount = 0,
    this.notices = const [],
    this.diverOutcomes = const [],
  });
}
