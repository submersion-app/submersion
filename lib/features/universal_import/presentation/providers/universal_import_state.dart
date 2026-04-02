import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
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
    this.fileBytes,
    this.fileName,
    this.additionalFileBytes,
    this.additionalFileName,
    this.detectionResult,
    this.pendingSourceOverride,
    this.pendingFormatOverride,
    this.detectedCsvPreset,
    this.parsedCsv,
    this.options,
    this.fieldMapping,
    this.payload,
    this.duplicateResult,
    this.selections = const {},
    this.diveResolutions = const {},
    this.importCounts = const {},
    this.importPhase = '',
    this.importCurrent = 0,
    this.importTotal = 0,
  });

  final ImportWizardStep currentStep;
  final bool isLoading;
  final bool isImporting;
  final String? error;

  /// Raw file bytes (kept for re-parsing if field mapping changes).
  final Uint8List? fileBytes;
  final String? fileName;

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

  /// Per-dive duplicate resolution choices (keyed by dive index).
  ///
  /// Only present for dives that were flagged as potential duplicates.
  /// Absent entries default to [DiveDuplicateResolution.skip].
  final Map<int, DiveDuplicateResolution> diveResolutions;

  /// Import result counts per entity type.
  final Map<ImportEntityType, int> importCounts;

  /// Progress tracking.
  final String importPhase;
  final int importCurrent;
  final int importTotal;

  UniversalImportState copyWith({
    ImportWizardStep? currentStep,
    bool? isLoading,
    bool? isImporting,
    String? error,
    bool clearError = false,
    Uint8List? fileBytes,
    String? fileName,
    Uint8List? additionalFileBytes,
    bool clearAdditionalFileBytes = false,
    String? additionalFileName,
    bool clearAdditionalFileName = false,
    DetectionResult? detectionResult,
    ImportOptions? options,
    FieldMapping? fieldMapping,
    bool clearFieldMapping = false,
    ImportPayload? payload,
    bool clearPayload = false,
    ImportDuplicateResult? duplicateResult,
    Map<ImportEntityType, Set<int>>? selections,
    Map<int, DiveDuplicateResolution>? diveResolutions,
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
  }) {
    return UniversalImportState(
      currentStep: currentStep ?? this.currentStep,
      isLoading: isLoading ?? this.isLoading,
      isImporting: isImporting ?? this.isImporting,
      error: clearError ? null : (error ?? this.error),
      fileBytes: fileBytes ?? this.fileBytes,
      fileName: fileName ?? this.fileName,
      additionalFileBytes: clearAdditionalFileBytes
          ? null
          : (additionalFileBytes ?? this.additionalFileBytes),
      additionalFileName: clearAdditionalFileName
          ? null
          : (additionalFileName ?? this.additionalFileName),
      detectionResult: detectionResult ?? this.detectionResult,
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
      diveResolutions: diveResolutions ?? this.diveResolutions,
      importCounts: importCounts ?? this.importCounts,
      importPhase: importPhase ?? this.importPhase,
      importCurrent: importCurrent ?? this.importCurrent,
      importTotal: importTotal ?? this.importTotal,
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
