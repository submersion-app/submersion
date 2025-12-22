import '../../../../features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import '../../../../features/dive_log/domain/entities/dive_computer.dart';
import '../../domain/services/download_manager.dart';
import 'dive_parser.dart';

/// Mode for importing dives.
enum ImportMode {
  /// Only import dives that don't match existing dives
  newOnly,

  /// Import all dives, skipping exact duplicates
  all,

  /// Replace existing dives with downloaded versions
  replace,
}

/// How to resolve conflicts when a duplicate is detected.
enum ConflictResolution {
  /// Skip the downloaded dive, keep the existing one
  skip,

  /// Replace the existing dive with the downloaded one
  replace,

  /// Import as a new dive (creates duplicate)
  importAsNew,

  /// Ask the user for each conflict
  askUser,
}

/// Confidence level for duplicate detection.
enum DuplicateConfidence {
  /// Exact match (same fingerprint or very close match)
  exact,

  /// Very likely the same dive (time and depth match closely)
  likely,

  /// Possibly the same dive (time matches but depth differs)
  possible,

  /// No match found
  none,
}

/// Result of duplicate detection for a single dive.
class DuplicateResult {
  /// ID of the matching dive (null if no match)
  final String? matchingDiveId;

  /// Confidence level of the match
  final DuplicateConfidence confidence;

  /// Score from 0.0 to 1.0 indicating match quality
  final double score;

  /// Time difference in seconds (if matched)
  final int? timeDifferenceSeconds;

  /// Depth difference in meters (if matched)
  final double? depthDifferenceMeters;

  const DuplicateResult({
    this.matchingDiveId,
    required this.confidence,
    required this.score,
    this.timeDifferenceSeconds,
    this.depthDifferenceMeters,
  });

  /// No duplicate found
  factory DuplicateResult.noMatch() => const DuplicateResult(
        confidence: DuplicateConfidence.none,
        score: 0.0,
      );

  /// Whether a duplicate was found
  bool get isDuplicate => matchingDiveId != null;

  /// Whether this is a high-confidence match
  bool get isHighConfidence =>
      confidence == DuplicateConfidence.exact ||
      confidence == DuplicateConfidence.likely;
}

/// A conflict between a downloaded dive and an existing dive.
class ImportConflict {
  /// The downloaded dive
  final DownloadedDive downloaded;

  /// ID of the existing dive that matches
  final String existingDiveId;

  /// Duplicate detection result
  final DuplicateResult duplicateResult;

  /// User's resolution choice (null if not yet resolved)
  ConflictResolution? resolution;

  ImportConflict({
    required this.downloaded,
    required this.existingDiveId,
    required this.duplicateResult,
    this.resolution,
  });
}

/// Result of an import operation.
class ImportResult {
  /// Number of dives successfully imported
  final int imported;

  /// Number of dives skipped (duplicates)
  final int skipped;

  /// Number of existing dives updated/replaced
  final int updated;

  /// Conflicts that require user resolution
  final List<ImportConflict> conflicts;

  /// IDs of the dives that were imported
  final List<String> importedDiveIds;

  /// Error message if import failed
  final String? errorMessage;

  const ImportResult({
    required this.imported,
    required this.skipped,
    required this.updated,
    required this.conflicts,
    required this.importedDiveIds,
    this.errorMessage,
  });

  /// Create a successful result
  factory ImportResult.success({
    required int imported,
    required int skipped,
    required int updated,
    required List<String> importedDiveIds,
    List<ImportConflict> conflicts = const [],
  }) =>
      ImportResult(
        imported: imported,
        skipped: skipped,
        updated: updated,
        conflicts: conflicts,
        importedDiveIds: importedDiveIds,
      );

  /// Create a failed result
  factory ImportResult.failure(String error) => ImportResult(
        imported: 0,
        skipped: 0,
        updated: 0,
        conflicts: [],
        importedDiveIds: [],
        errorMessage: error,
      );

  /// Whether the import was successful
  bool get isSuccess => errorMessage == null;

  /// Whether there are unresolved conflicts
  bool get hasUnresolvedConflicts => conflicts.any((c) => c.resolution == null);

  /// Total dives processed
  int get totalProcessed => imported + skipped + updated;
}

/// Service for importing downloaded dives into the app's database.
class DiveImportService {
  final DiveComputerRepository _repository;
  final DiveParser _parser;

  DiveImportService({
    required DiveComputerRepository repository,
    DiveParser? parser,
  })  : _repository = repository,
        _parser = parser ?? const DiveParser();

  /// Import a list of downloaded dives.
  ///
  /// [dives] - The dives to import.
  /// [computer] - The dive computer the dives were downloaded from.
  /// [mode] - How to handle imports (newOnly, all, replace).
  /// [defaultResolution] - Default resolution for duplicates.
  /// [diverId] - Owner diver ID for new dives.
  Future<ImportResult> importDives({
    required List<DownloadedDive> dives,
    required DiveComputer computer,
    ImportMode mode = ImportMode.newOnly,
    ConflictResolution defaultResolution = ConflictResolution.skip,
    String? diverId,
  }) async {
    int imported = 0;
    int skipped = 0;
    int updated = 0;
    final importedDiveIds = <String>[];
    final conflicts = <ImportConflict>[];

    for (final dive in dives) {
      try {
        // Check for duplicates
        final duplicateResult = await detectDuplicate(dive);

        if (duplicateResult.isDuplicate) {
          // Handle based on mode and confidence
          if (mode == ImportMode.newOnly ||
              (mode == ImportMode.all && duplicateResult.isHighConfidence)) {
            if (defaultResolution == ConflictResolution.askUser) {
              // Add to conflicts for user resolution
              conflicts.add(
                ImportConflict(
                  downloaded: dive,
                  existingDiveId: duplicateResult.matchingDiveId!,
                  duplicateResult: duplicateResult,
                ),
              );
            } else if (defaultResolution == ConflictResolution.skip) {
              skipped++;
            } else if (defaultResolution == ConflictResolution.replace) {
              // Update existing dive
              await _updateExistingDive(
                dive,
                duplicateResult.matchingDiveId!,
                computer.id,
              );
              updated++;
            } else {
              // Import as new
              final diveId = await _importNewDive(dive, computer.id, diverId);
              importedDiveIds.add(diveId);
              imported++;
            }
          } else if (mode == ImportMode.replace) {
            // Replace existing
            await _updateExistingDive(
              dive,
              duplicateResult.matchingDiveId!,
              computer.id,
            );
            updated++;
          } else {
            // Low confidence match in 'all' mode - import as new
            final diveId = await _importNewDive(dive, computer.id, diverId);
            importedDiveIds.add(diveId);
            imported++;
          }
        } else {
          // No duplicate - import as new
          final diveId = await _importNewDive(dive, computer.id, diverId);
          importedDiveIds.add(diveId);
          imported++;
        }
      } catch (e) {
        // Log error but continue with other dives
        skipped++;
      }
    }

    return ImportResult.success(
      imported: imported,
      skipped: skipped,
      updated: updated,
      importedDiveIds: importedDiveIds,
      conflicts: conflicts,
    );
  }

  /// Detect if a downloaded dive matches an existing dive.
  Future<DuplicateResult> detectDuplicate(
    DownloadedDive dive, {
    double timeTolerance = 5.0, // minutes
    double depthTolerance = 0.5, // meters
  }) async {
    // Use the repository's findMatchingDive with enhanced logic
    final matchingDiveId = await _repository.findMatchingDive(
      profileStartTime: dive.startTime,
      toleranceMinutes: timeTolerance.round(),
      durationSeconds: dive.durationSeconds,
    );

    if (matchingDiveId == null) {
      return DuplicateResult.noMatch();
    }

    // Calculate match score
    // For now, we return a likely match since we found something
    // In a full implementation, we'd compare more fields
    return DuplicateResult(
      matchingDiveId: matchingDiveId,
      confidence: DuplicateConfidence.likely,
      score: 0.8,
    );
  }

  /// Import a downloaded dive as a new dive.
  Future<String> _importNewDive(
    DownloadedDive dive,
    String computerId,
    String? diverId,
  ) async {
    // Parse profile data
    final profilePoints = _parser.parseProfile(dive);

    // Convert tanks to TankData
    final tanks = _parser.parseTanks(dive);

    // Import using repository
    final diveId = await _repository.importProfile(
      computerId: computerId,
      profileStartTime: dive.startTime,
      points: profilePoints,
      durationSeconds: dive.durationSeconds,
      maxDepth: dive.maxDepth,
      isPrimary: true,
      diverId: diverId,
      tanks: tanks,
    );

    return diveId;
  }

  /// Update an existing dive with downloaded data.
  Future<void> _updateExistingDive(
    DownloadedDive dive,
    String existingDiveId,
    String computerId,
  ) async {
    // Parse profile data
    final profilePoints = _parser.parseProfile(dive);

    // Clear existing profile for this computer and add new one
    // Note: This is a simplified implementation
    // A full implementation would update dive metadata as well

    // Import the profile (will associate with existing dive)
    await _repository.importProfile(
      computerId: computerId,
      profileStartTime: dive.startTime,
      points: profilePoints,
      durationSeconds: dive.durationSeconds,
      maxDepth: dive.maxDepth,
      isPrimary: false, // Keep existing primary
    );
  }

  /// Resolve a specific conflict and import the dive accordingly.
  Future<String?> resolveConflict(
    ImportConflict conflict,
    ConflictResolution resolution,
    String computerId, {
    String? diverId,
  }) async {
    conflict.resolution = resolution;

    switch (resolution) {
      case ConflictResolution.skip:
        return null;

      case ConflictResolution.replace:
        await _updateExistingDive(
          conflict.downloaded,
          conflict.existingDiveId,
          computerId,
        );
        return conflict.existingDiveId;

      case ConflictResolution.importAsNew:
        return await _importNewDive(
          conflict.downloaded,
          computerId,
          diverId,
        );

      case ConflictResolution.askUser:
        // This shouldn't be called with askUser
        return null;
    }
  }
}
