import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/data/csv/models/parsed_csv.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart';

// ============================================================================
// Wizard Steps
// ============================================================================

/// Steps in the universal import wizard.
enum ImportWizardStep {
  fileSelection,
  sourceConfirmation,
  additionalFiles,
  fieldMapping,
  review,
  importing,
  summary,
}

// ============================================================================
// State
// ============================================================================

/// State for the universal import wizard.
class UniversalImportState {
  const UniversalImportState({
    this.currentStep = ImportWizardStep.fileSelection,
    this.isLoading = false,
    this.isImporting = false,
    this.error,
    this.files = const [],
    this.photoPathsByBaseName = const {},
    this.unmatchedPhotoCount = 0,
    this.zipTempDirPaths = const [],
    this.additionalFileBytes,
    this.additionalFileName,
    this.detectionResult,
    this.parseCurrent = 0,
    this.parseTotal = 0,
    this.pendingSourceOverride,
    this.pendingFormatOverride,
    this.detectedCsvPreset,
    this.parsedCsv,
    this.options,
    this.fieldMapping,
    this.payload,
    this.duplicateResult,
    this.selections = const {},
    this.importCounts = const {},
    this.importPhase = '',
    this.importCurrent = 0,
    this.importTotal = 0,
    this.wasLoadedExternally = false,
  });

  final ImportWizardStep currentStep;
  final bool isLoading;
  final bool isImporting;
  final String? error;

  /// The selected files. One element for classic single-file imports;
  /// multiple for a bulk batch. Path-backed entries drop their bytes after
  /// detection and re-read them lazily at parse time.
  final List<PickedImportFile> files;

  /// Photos extracted from an imported ZIP, keyed by the dive file's
  /// basename (without extension) they belong to. Consumed post-commit by
  /// the adapter to attach photos to the created dives.
  final Map<String, List<String>> photoPathsByBaseName;

  /// Photos in an imported ZIP that matched no dive file (surfaced as an
  /// import warning count).
  final int unmatchedPhotoCount;

  /// Temp directories holding files extracted from imported ZIP archives.
  /// The notifier deletes these on reset or when superseded by a new import,
  /// so extracted dive data and photos do not accumulate on disk.
  final List<String> zipTempDirPaths;

  /// Batch parse progress (files parsed so far / files pending).
  final int parseCurrent;
  final int parseTotal;

  /// Raw file bytes for the classic single-file flow (kept for re-parsing if
  /// field mapping changes). Null for batches: batch parsing re-reads bytes
  /// per file from [PickedImportFile.path].
  Uint8List? get fileBytes => files.length == 1 ? files.first.bytes : null;

  /// The single selected file's name; null when nothing is selected or a
  /// batch is active. Batch UIs render a localized count from
  /// [selectedFileCount] instead of a hardcoded English label.
  String? get fileName => files.length == 1 ? files.first.name : null;

  /// Number of files currently selected.
  int get selectedFileCount => files.length;

  /// True when more than one file was selected (batch import path).
  bool get isBatch => files.length > 1;

  /// Files awaiting batch parse.
  List<PickedImportFile> get pendingFiles => [
    for (final f in files)
      if (f.status == ImportFileStatus.pending) f,
  ];

  /// Profile CSV bytes for multi-file presets (e.g. Subsurface).
  final Uint8List? additionalFileBytes;
  final String? additionalFileName;

  /// Format detection result (set after file selection).
  final DetectionResult? detectionResult;

  /// Source app override chosen by the user but not yet confirmed.
  ///
  /// Stored here so the wizard's [onBeforeAdvance] callback can pass it to
  /// [confirmSource] when the user taps "Next".
  final SourceApp? pendingSourceOverride;

  /// Format override paired with [pendingSourceOverride].
  final ImportFormat? pendingFormatOverride;

  /// Detected CSV preset from the pipeline Detect stage.
  final CsvPreset? detectedCsvPreset;

  /// Parsed primary CSV for sample values in mapping UI.
  final ParsedCsv? parsedCsv;

  /// Confirmed import options (set after source confirmation).
  final ImportOptions? options;

  /// Column mapping for CSV imports (null for non-CSV formats).
  final FieldMapping? fieldMapping;

  /// Parsed import data (set after parsing).
  final ImportPayload? payload;

  /// Duplicate check results (set before review step).
  final ImportDuplicateResult? duplicateResult;

  /// Selected indices per entity type.
  final Map<ImportEntityType, Set<int>> selections;

  /// Import result counts per entity type.
  final Map<ImportEntityType, int> importCounts;

  /// Progress tracking.
  final String importPhase;
  final int importCurrent;
  final int importTotal;

  /// True when the file was loaded externally (drag-and-drop / share intent)
  /// rather than via the in-wizard file picker. Consumed once by the wizard
  /// to skip resetState on init, then cleared.
  final bool wasLoadedExternally;

  UniversalImportState copyWith({
    ImportWizardStep? currentStep,
    bool? isLoading,
    bool? isImporting,
    String? error,
    bool clearError = false,
    List<PickedImportFile>? files,
    bool clearFiles = false,
    Map<String, List<String>>? photoPathsByBaseName,
    int? unmatchedPhotoCount,
    List<String>? zipTempDirPaths,
    int? parseCurrent,
    int? parseTotal,
    Uint8List? additionalFileBytes,
    bool clearAdditionalFileBytes = false,
    String? additionalFileName,
    bool clearAdditionalFileName = false,
    DetectionResult? detectionResult,
    bool clearDetectionResult = false,
    ImportOptions? options,
    FieldMapping? fieldMapping,
    bool clearFieldMapping = false,
    ImportPayload? payload,
    bool clearPayload = false,
    ImportDuplicateResult? duplicateResult,
    Map<ImportEntityType, Set<int>>? selections,
    Map<ImportEntityType, int>? importCounts,
    String? importPhase,
    int? importCurrent,
    int? importTotal,
    SourceApp? pendingSourceOverride,
    bool clearPendingSourceOverride = false,
    ImportFormat? pendingFormatOverride,
    bool clearPendingFormatOverride = false,
    CsvPreset? detectedCsvPreset,
    bool clearDetectedCsvPreset = false,
    ParsedCsv? parsedCsv,
    bool clearParsedCsv = false,
    bool? wasLoadedExternally,
  }) {
    return UniversalImportState(
      currentStep: currentStep ?? this.currentStep,
      isLoading: isLoading ?? this.isLoading,
      isImporting: isImporting ?? this.isImporting,
      error: clearError ? null : (error ?? this.error),
      files: clearFiles ? const [] : (files ?? this.files),
      photoPathsByBaseName: photoPathsByBaseName ?? this.photoPathsByBaseName,
      unmatchedPhotoCount: unmatchedPhotoCount ?? this.unmatchedPhotoCount,
      zipTempDirPaths: zipTempDirPaths ?? this.zipTempDirPaths,
      parseCurrent: parseCurrent ?? this.parseCurrent,
      parseTotal: parseTotal ?? this.parseTotal,
      additionalFileBytes: clearAdditionalFileBytes
          ? null
          : (additionalFileBytes ?? this.additionalFileBytes),
      additionalFileName: clearAdditionalFileName
          ? null
          : (additionalFileName ?? this.additionalFileName),
      detectionResult: clearDetectionResult
          ? null
          : (detectionResult ?? this.detectionResult),
      pendingSourceOverride: clearPendingSourceOverride
          ? null
          : (pendingSourceOverride ?? this.pendingSourceOverride),
      pendingFormatOverride: clearPendingFormatOverride
          ? null
          : (pendingFormatOverride ?? this.pendingFormatOverride),
      detectedCsvPreset: clearDetectedCsvPreset
          ? null
          : (detectedCsvPreset ?? this.detectedCsvPreset),
      parsedCsv: clearParsedCsv ? null : (parsedCsv ?? this.parsedCsv),
      options: options ?? this.options,
      fieldMapping: clearFieldMapping
          ? null
          : (fieldMapping ?? this.fieldMapping),
      payload: clearPayload ? null : (payload ?? this.payload),
      duplicateResult: duplicateResult ?? this.duplicateResult,
      selections: selections ?? this.selections,
      importCounts: importCounts ?? this.importCounts,
      importPhase: importPhase ?? this.importPhase,
      importCurrent: importCurrent ?? this.importCurrent,
      importTotal: importTotal ?? this.importTotal,
      wasLoadedExternally: wasLoadedExternally ?? this.wasLoadedExternally,
    );
  }

  /// Get the selection set for a given entity type.
  Set<int> selectionFor(ImportEntityType type) {
    return selections[type] ?? const {};
  }

  /// Total count of items for a given entity type.
  int totalCountFor(ImportEntityType type) {
    return payload?.entitiesOf(type).length ?? 0;
  }

  /// Total selected items across all entity types.
  int get totalSelected =>
      selections.values.fold(0, (sum, s) => sum + s.length);

  /// Entity types that have data in the payload.
  List<ImportEntityType> get availableTypes => payload?.availableTypes ?? [];

  /// Whether the format requires a field mapping step.
  bool get needsFieldMapping => detectionResult?.format == ImportFormat.csv;

  /// Summary of import results.
  String get importSummary {
    final parts = <String>[];
    for (final type in ImportEntityType.values) {
      final count = importCounts[type] ?? 0;
      if (count > 0) {
        parts.add('$count ${type.displayName.toLowerCase()}');
      }
    }
    return parts.isEmpty ? 'No data imported' : 'Imported ${parts.join(', ')}';
  }
}
