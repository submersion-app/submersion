import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/data/services/dive_parser.dart';

/// Mode for importing dives.
enum ImportMode {
  /// Only import dives that don't match existing dives
  newOnly,

  /// Import all dives, skipping exact duplicates
  all,

  /// Replace existing dive's source data with the downloaded version
  replaceSource,
}

/// How to resolve conflicts when a duplicate is detected.
enum ConflictResolution {
  /// Skip the downloaded dive, keep the existing one
  skip,

  /// Replace the existing dive's source data with the downloaded version
  replaceSource,

  /// Import as a new dive (creates duplicate)
  importAsNew,

  /// Ask the user for each conflict
  askUser,

  /// Merge as additional computer data on the matched dive
  consolidate,
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
  factory DuplicateResult.noMatch() =>
      const DuplicateResult(confidence: DuplicateConfidence.none, score: 0.0);

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

/// A skipped duplicate that can be offered to the user for consolidation.
///
/// Collected during import when a dive is skipped as a duplicate, so the
/// caller can present a post-download review step.
class DuplicateCandidate {
  /// The downloaded dive that was skipped
  final DownloadedDive dive;

  /// ID of the existing dive that matched
  final String matchedDiveId;

  /// Match quality score from 0.0 to 1.0
  final double matchScore;

  /// Confidence level of the match
  final DuplicateConfidence confidence;

  const DuplicateCandidate({
    required this.dive,
    required this.matchedDiveId,
    required this.matchScore,
    required this.confidence,
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

  /// The actual dive objects that were successfully imported
  final List<DownloadedDive> importedDives;

  /// Dives that were skipped as duplicates but could be consolidated.
  ///
  /// These are populated when [ConflictResolution.skip] is used, giving the
  /// caller an opportunity to offer a post-download consolidation review.
  final List<DuplicateCandidate> duplicateCandidates;

  /// Error message if import failed
  final String? errorMessage;

  const ImportResult({
    required this.imported,
    required this.skipped,
    required this.updated,
    required this.conflicts,
    required this.importedDiveIds,
    this.importedDives = const [],
    this.duplicateCandidates = const [],
    this.errorMessage,
  });

  /// Create a successful result
  factory ImportResult.success({
    required int imported,
    required int skipped,
    required int updated,
    required List<String> importedDiveIds,
    required List<DownloadedDive> importedDives,
    List<ImportConflict> conflicts = const [],
    List<DuplicateCandidate> duplicateCandidates = const [],
  }) => ImportResult(
    imported: imported,
    skipped: skipped,
    updated: updated,
    conflicts: conflicts,
    importedDiveIds: importedDiveIds,
    importedDives: importedDives,
    duplicateCandidates: duplicateCandidates,
  );

  /// Create a failed result
  factory ImportResult.failure(String error) => ImportResult(
    imported: 0,
    skipped: 0,
    updated: 0,
    conflicts: [],
    importedDiveIds: [],
    importedDives: [],
    duplicateCandidates: [],
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
  final DiveRepository? _diveRepository;
  final DiveParser _parser;

  DiveImportService({
    required DiveComputerRepository repository,
    DiveRepository? diveRepository,
    DiveParser? parser,
  }) : _repository = repository,
       _diveRepository = diveRepository,
       _parser = parser ?? const DiveParser();

  /// Import a list of downloaded dives.
  ///
  /// [dives] - The dives to import.
  /// [computer] - The dive computer the dives were downloaded from.
  /// [mode] - How to handle imports (newOnly, all, replace).
  /// [defaultResolution] - Default resolution for duplicates.
  /// [diverId] - Owner diver ID for new dives.
  ///
  /// When [defaultResolution] is [ConflictResolution.skip], skipped duplicates
  /// are collected into [ImportResult.duplicateCandidates] so the caller can
  /// offer a post-download consolidation review step.
  Future<ImportResult> importDives({
    required List<DownloadedDive> dives,
    required DiveComputer computer,
    ImportMode mode = ImportMode.newOnly,
    ConflictResolution defaultResolution = ConflictResolution.skip,
    String? diverId,
    String? descriptorVendor,
    String? descriptorProduct,
    int? descriptorModel,
    String? libdivecomputerVersion,
  }) async {
    int imported = 0;
    int skipped = 0;
    int updated = 0;
    final importedDiveIds = <String>[];
    final importedDives = <DownloadedDive>[];
    final conflicts = <ImportConflict>[];
    final duplicateCandidates = <DuplicateCandidate>[];

    // Sort dives chronologically (oldest first) so that sequential
    // getDiveNumberForDate() calls produce correct numbering.
    final sortedDives = List<DownloadedDive>.of(dives)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    for (final dive in sortedDives) {
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
              // Record as a consolidation candidate for post-download review.
              // Don't count as "skipped" — pending review is a distinct state.
              duplicateCandidates.add(
                DuplicateCandidate(
                  dive: dive,
                  matchedDiveId: duplicateResult.matchingDiveId!,
                  matchScore: duplicateResult.score,
                  confidence: duplicateResult.confidence,
                ),
              );
            } else if (defaultResolution == ConflictResolution.replaceSource) {
              // Update existing dive
              await _updateExistingDive(
                dive,
                duplicateResult.matchingDiveId!,
                computer.id,
                descriptorVendor: descriptorVendor,
                descriptorProduct: descriptorProduct,
                descriptorModel: descriptorModel,
                libdivecomputerVersion: libdivecomputerVersion,
              );
              updated++;
            } else {
              // Import as new (importAsNew or consolidate treated as new here;
              // consolidate at the conflict-resolution level is handled by
              // resolveConflict / DiveComputerAdapter._consolidateDive)
              final diveId = await _importNewDive(
                dive,
                computer.id,
                diverId,
                forceNew: true,
                descriptorVendor: descriptorVendor,
                descriptorProduct: descriptorProduct,
                descriptorModel: descriptorModel,
                libdivecomputerVersion: libdivecomputerVersion,
              );
              importedDiveIds.add(diveId);
              importedDives.add(dive);
              imported++;
            }
          } else if (mode == ImportMode.replaceSource) {
            // Replace existing
            await _updateExistingDive(
              dive,
              duplicateResult.matchingDiveId!,
              computer.id,
              descriptorVendor: descriptorVendor,
              descriptorProduct: descriptorProduct,
              descriptorModel: descriptorModel,
              libdivecomputerVersion: libdivecomputerVersion,
            );
            updated++;
          } else {
            // Low confidence match in 'all' mode - import as new.
            // Must pass forceNew so importProfile skips its own matching.
            final diveId = await _importNewDive(
              dive,
              computer.id,
              diverId,
              forceNew: true,
              descriptorVendor: descriptorVendor,
              descriptorProduct: descriptorProduct,
              descriptorModel: descriptorModel,
              libdivecomputerVersion: libdivecomputerVersion,
            );
            importedDiveIds.add(diveId);
            importedDives.add(dive);
            imported++;
          }
        } else {
          // No duplicate - import as new
          final diveId = await _importNewDive(
            dive,
            computer.id,
            diverId,
            descriptorVendor: descriptorVendor,
            descriptorProduct: descriptorProduct,
            descriptorModel: descriptorModel,
            libdivecomputerVersion: libdivecomputerVersion,
          );
          importedDiveIds.add(diveId);
          importedDives.add(dive);
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
      importedDives: importedDives,
      conflicts: conflicts,
      duplicateCandidates: duplicateCandidates,
    );
  }

  /// Detect if a downloaded dive matches an existing dive.
  Future<DuplicateResult> detectDuplicate(
    DownloadedDive dive, {
    double timeTolerance = 5.0, // minutes
    double depthTolerance = 0.5, // meters
    String? diverId,
  }) async {
    // Use the repository's enhanced matching with scoring
    final match = await _repository.findMatchingDiveWithScore(
      profileStartTime: dive.startTime,
      toleranceMinutes: timeTolerance.round(),
      durationSeconds: dive.durationSeconds,
      maxDepth: dive.maxDepth,
      fingerprint: dive.fingerprint,
      diverId: diverId,
    );

    if (match == null) {
      return DuplicateResult.noMatch();
    }

    // Convert score to confidence level
    final confidence = _scoreToConfidence(match.score);

    // Convert time difference from ms to seconds
    final timeDiffSeconds = match.timeDifferenceMs ~/ 1000;

    return DuplicateResult(
      matchingDiveId: match.diveId,
      confidence: confidence,
      score: match.score,
      timeDifferenceSeconds: timeDiffSeconds,
      depthDifferenceMeters: match.depthDifferenceMeters,
    );
  }

  /// Convert a numeric score to a confidence level.
  DuplicateConfidence _scoreToConfidence(double score) {
    if (score >= 0.9) return DuplicateConfidence.exact;
    if (score >= 0.7) return DuplicateConfidence.likely;
    if (score >= 0.5) return DuplicateConfidence.possible;
    return DuplicateConfidence.none;
  }

  /// Import a downloaded dive as a new dive.
  Future<String> _importNewDive(
    DownloadedDive dive,
    String computerId,
    String? diverId, {
    bool forceNew = false,
    String? descriptorVendor,
    String? descriptorProduct,
    int? descriptorModel,
    String? libdivecomputerVersion,
  }) async {
    // Calculate chronological dive number
    int? diveNumber;
    if (_diveRepository != null) {
      diveNumber = await _diveRepository.getDiveNumberForDate(
        dive.startTime,
        diverId: diverId,
      );
    }

    // Parse profile data
    final profilePoints = _parser.parseProfile(dive);

    // Convert tanks to TankData
    final tanks = _parser.parseTanks(dive);

    // Convert events to EventData
    final events = _convertEvents(dive.events);

    // Import using repository
    final diveId = await _repository.importProfile(
      computerId: computerId,
      profileStartTime: dive.startTime,
      points: profilePoints,
      durationSeconds: dive.durationSeconds,
      maxDepth: dive.maxDepth,
      avgDepth: dive.avgDepth,
      isPrimary: true,
      diverId: diverId,
      tanks: tanks,
      decoAlgorithm: dive.decoAlgorithm,
      gfLow: dive.gfLow,
      gfHigh: dive.gfHigh,
      decoConservatism: dive.decoConservatism,
      events: events,
      diveNumber: diveNumber,
      forceNew: forceNew,
      rawData: dive.rawData,
      rawFingerprint: dive.rawFingerprint,
      descriptorVendor: descriptorVendor,
      descriptorProduct: descriptorProduct,
      descriptorModel: descriptorModel,
      libdivecomputerVersion: libdivecomputerVersion,
    );

    return diveId;
  }

  /// Import a single dive as a new dive, ignoring any duplicate match.
  ///
  /// Used when the user explicitly chooses "Import as New" from the
  /// post-download consolidation review.
  Future<String> importSingleDiveAsNew(
    DownloadedDive dive, {
    required String computerId,
    String? diverId,
    String? descriptorVendor,
    String? descriptorProduct,
    int? descriptorModel,
    String? libdivecomputerVersion,
  }) async {
    return _importNewDive(
      dive,
      computerId,
      diverId,
      forceNew: true,
      descriptorVendor: descriptorVendor,
      descriptorProduct: descriptorProduct,
      descriptorModel: descriptorModel,
      libdivecomputerVersion: libdivecomputerVersion,
    );
  }

  /// Replace an existing dive's source data with a fresh download.
  ///
  /// Clears the old profile and data source rows for this computer, then
  /// re-imports so the new raw bytes and parsed data are stored.
  Future<void> _updateExistingDive(
    DownloadedDive dive,
    String existingDiveId,
    String computerId, {
    String? descriptorVendor,
    String? descriptorProduct,
    int? descriptorModel,
    String? libdivecomputerVersion,
  }) async {
    // Remove the existing profile + source row so importProfile won't
    // short-circuit on the "already exists" check.
    await _repository.clearSourceAndProfiles(
      diveId: existingDiveId,
      computerId: computerId,
    );

    final profilePoints = _parser.parseProfile(dive);
    final events = _convertEvents(dive.events);

    // Re-import using the existing dive's start time so that importProfile
    // matches it back to the same dive row.
    await _repository.importProfile(
      computerId: computerId,
      profileStartTime: dive.startTime,
      points: profilePoints,
      durationSeconds: dive.durationSeconds,
      maxDepth: dive.maxDepth,
      avgDepth: dive.avgDepth,
      isPrimary: true,
      decoAlgorithm: dive.decoAlgorithm,
      gfLow: dive.gfLow,
      gfHigh: dive.gfHigh,
      decoConservatism: dive.decoConservatism,
      events: events,
      rawData: dive.rawData,
      rawFingerprint: dive.rawFingerprint,
      descriptorVendor: descriptorVendor,
      descriptorProduct: descriptorProduct,
      descriptorModel: descriptorModel,
      libdivecomputerVersion: libdivecomputerVersion,
    );
  }

  /// Resolve a specific conflict and import the dive accordingly.
  Future<String?> resolveConflict(
    ImportConflict conflict,
    ConflictResolution resolution,
    String computerId, {
    String? diverId,
    String? descriptorVendor,
    String? descriptorProduct,
    int? descriptorModel,
    String? libdivecomputerVersion,
  }) async {
    conflict.resolution = resolution;

    switch (resolution) {
      case ConflictResolution.skip:
        return null;

      case ConflictResolution.replaceSource:
        await _updateExistingDive(
          conflict.downloaded,
          conflict.existingDiveId,
          computerId,
          descriptorVendor: descriptorVendor,
          descriptorProduct: descriptorProduct,
          descriptorModel: descriptorModel,
          libdivecomputerVersion: libdivecomputerVersion,
        );
        return conflict.existingDiveId;

      case ConflictResolution.importAsNew:
        return await _importNewDive(
          conflict.downloaded,
          computerId,
          diverId,
          descriptorVendor: descriptorVendor,
          descriptorProduct: descriptorProduct,
          descriptorModel: descriptorModel,
          libdivecomputerVersion: libdivecomputerVersion,
        );

      case ConflictResolution.askUser:
        // This shouldn't be called with askUser
        return null;

      case ConflictResolution.consolidate:
        // Consolidation is handled by DiveComputerAdapter._consolidateDive()
        // which calls DiveRepository.consolidateComputer() directly.
        return null;
    }
  }

  List<EventData> _convertEvents(List<DownloadedEvent> events) {
    return events
        .map(
          (e) => EventData(
            timestamp: e.timeSeconds,
            type: e.type,
            flags: e.flags,
            value: e.value,
          ),
        )
        .toList();
  }
}
