import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_pipeline.dart';
import 'package:submersion/features/universal_import/data/csv/presets/built_in_presets.dart';
import 'package:submersion/features/universal_import/data/csv/presets/preset_registry.dart';
import 'package:submersion/features/universal_import/presentation/providers/csv_preset_providers.dart';
import 'package:submersion/features/universal_import/data/parsers/csv_import_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/services/format_detector.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';
import 'package:submersion/features/universal_import/data/services/batch_parse_service.dart';
import 'package:submersion/features/universal_import/data/services/macdive_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/payload_merger.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart';
import 'package:submersion/features/universal_import/data/services/zip_expansion_service.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_state.dart';

export 'package:submersion/features/universal_import/presentation/providers/universal_import_state.dart';

// ============================================================================
// Notifier
// ============================================================================

/// Manages the universal import wizard flow.
class UniversalImportNotifier extends StateNotifier<UniversalImportState> {
  UniversalImportNotifier(
    this._ref, {
    BatchParseService batchParseService = const BatchParseService(),
    ZipExpansionService zipExpansionService = const ZipExpansionService(),
  }) : _batchParseService = batchParseService,
       _zipExpansion = zipExpansionService,
       super(const UniversalImportState());

  final Ref _ref;

  /// Injectable so tests can drive deterministic batch-parse outcomes
  /// (progress, cancellation) without real file timing.
  final BatchParseService _batchParseService;

  /// Expands ZIP archives (DiveCloud exports) into their member files at
  /// intake so members flow through normal detection and batching.
  final ZipExpansionService _zipExpansion;

  /// Build a [PresetRegistry] that includes both built-in and user-saved
  /// presets so auto-detection scores against all of them.
  Future<PresetRegistry> _buildPresetRegistry() async {
    final registry = PresetRegistry(builtInPresets: builtInCsvPresets);
    try {
      final userPresets = await _ref.read(userCsvPresetsProvider.future);
      for (final preset in userPresets) {
        registry.addUserPreset(preset);
      }
    } catch (_) {
      // If loading user presets fails, proceed with built-ins only.
    }
    return registry;
  }

  // -- Format Detection --

  /// Run format detection and normalize SQLite → Shearwater when appropriate.
  ///
  /// Shared by [loadFileFromBytes] and [pickFile] to avoid duplicating the
  /// detection + Shearwater special-casing logic.
  Future<DetectionResult> _detectFormat(Uint8List bytes) async {
    const detector = FormatDetector();
    var detection = detector.detect(bytes);

    if (detection.format == ImportFormat.sqlite) {
      // Probe the SQLite table set once and reuse for each DB flavor
      // check. Without this, every flavor would re-write the full byte
      // array to its own temp file and re-open sqlite — wasteful for
      // large dive databases on mobile/low-end devices.
      final tables = await ShearwaterDbReader.probeSqliteTableNames(bytes);
      if (ShearwaterDbReader.matchesTables(tables)) {
        detection = const DetectionResult(
          format: ImportFormat.shearwaterDb,
          sourceApp: SourceApp.shearwater,
          confidence: 0.95,
        );
      } else if (MacDiveDbReader.matchesTables(tables)) {
        detection = const DetectionResult(
          format: ImportFormat.macdiveSqlite,
          sourceApp: SourceApp.macdive,
          confidence: 0.95,
        );
      }
    }

    return detection;
  }

  /// Stores photo/temp-dir bookkeeping from a ZIP expansion into state.
  ///
  /// Always overwrites, even for a non-ZIP (empty) expansion: otherwise the
  /// photo map from a previous ZIP import would linger through a subsequent
  /// non-ZIP import (pickFiles/pickFolder do not fully reset state) and its
  /// photos could be misattached to the new dives. Temp dirs superseded by
  /// this expansion are deleted so extracted data does not accumulate.
  void _applyExpansionExtras(ArchiveExpansion expansion) {
    final superseded = [
      for (final dir in state.zipTempDirPaths)
        if (!expansion.tempDirPaths.contains(dir)) dir,
    ];
    state = state.copyWith(
      photoPathsByBaseName: expansion.photoPathsByBaseName,
      unmatchedPhotoCount: expansion.unmatchedPhotoPaths.length,
      zipTempDirPaths: expansion.tempDirPaths,
    );
    _deleteTempDirs(superseded);
  }

  /// Best-effort, fire-and-forget deletion of extracted-ZIP temp directories.
  void _deleteTempDirs(List<String> paths) {
    if (paths.isEmpty) return;
    unawaited(() async {
      for (final path in paths) {
        try {
          final dir = Directory(path);
          if (dir.existsSync()) await dir.delete(recursive: true);
        } catch (_) {
          // Temp cleanup is best-effort; the OS reclaims systemTemp anyway.
        }
      }
    }());
  }

  /// Single-file load by path (used when a ZIP expands to exactly one
  /// member and by the classic picker path).
  Future<void> _loadSingleFromFilePath(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final detection = await _detectFormat(bytes);
    state = state.copyWith(
      isLoading: false,
      files: [
        PickedImportFile(
          name: p.basename(filePath),
          path: filePath,
          bytes: bytes,
          detection: detection,
          status: ImportFileStatus.pending,
        ),
      ],
      detectionResult: detection,
      currentStep: ImportWizardStep.sourceConfirmation,
    );
  }

  // -- External File Loading (drag-and-drop / sharing intents) --

  /// Load a file from raw bytes, bypassing the file picker.
  ///
  /// Used by drag-and-drop on desktop and file sharing intents on mobile.
  /// Runs format detection and advances to [ImportWizardStep.sourceConfirmation]
  /// only when the format is supported. Returns the [DetectionResult] so
  /// callers can check for unsupported formats before navigating.
  Future<DetectionResult> loadFileFromBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    // Reset to a clean slate so stale fileBytes/detectionResult from a
    // previous run don't leak through if detection fails or is unsupported.
    final staleTempDirs = state.zipTempDirPaths;
    state = const UniversalImportState().copyWith(isLoading: true);
    _deleteTempDirs(staleTempDirs);

    try {
      if (ZipExpansionService.isZipBytes(bytes)) {
        final expansion = await _zipExpansion.expandZipBytes(bytes, fileName);
        _applyExpansionExtras(expansion);
        if (expansion.filePaths.isEmpty) {
          state = state.copyWith(
            isLoading: false,
            error: 'No importable files found in archive',
          );
          return const DetectionResult(
            format: ImportFormat.unknown,
            confidence: 0.0,
            warnings: ['No importable files found in archive'],
          );
        }
        if (expansion.filePaths.length == 1) {
          await _loadSingleFromFilePath(expansion.filePaths.first);
        } else {
          await _loadBatchFromPaths(expansion.filePaths);
        }
        state = state.copyWith(wasLoadedExternally: true);
        return state.detectionResult ??
            const DetectionResult(format: ImportFormat.unknown, confidence: 0);
      }

      final detection = await _detectFormat(bytes);

      // Don't advance to sourceConfirmation for unsupported formats so the
      // wizard isn't left holding stale bytes if the caller shows a snackbar
      // and doesn't navigate.
      if (!detection.format.isSupported) {
        state = state.copyWith(isLoading: false);
        return detection;
      }

      state = state.copyWith(
        isLoading: false,
        files: [
          PickedImportFile(
            name: fileName,
            bytes: bytes,
            detection: detection,
            status: ImportFileStatus.pending,
          ),
        ],
        detectionResult: detection,
        currentStep: ImportWizardStep.sourceConfirmation,
        wasLoadedExternally: true,
      );

      return detection;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load file: $e',
      );
      return const DetectionResult(
        format: ImportFormat.unknown,
        confidence: 0.0,
        warnings: ['Failed to detect file format'],
      );
    }
  }

  // -- Step 0: File Selection --

  /// Pick one or more files and run format detection.
  ///
  /// A single selection keeps the classic wizard flow (Confirm Source, CSV
  /// mapping); multiple selections enter the batch triage flow.
  Future<void> pickFiles() async {
    // Reset to fileSelection so the canAdvance provider transitions
    // false -> true when detection completes, enabling auto-advance
    // even when re-selecting a file.
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      currentStep: ImportWizardStep.fileSelection,
    );

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final pickedPaths = [
        for (final f in result.files)
          if (f.path != null) f.path!,
      ];
      final expansion = await _zipExpansion.expandAll(pickedPaths);
      _applyExpansionExtras(expansion);

      if (expansion.filePaths.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'No importable files found in archive',
        );
        return;
      }
      if (expansion.filePaths.length == 1) {
        await _loadSingleFromFilePath(expansion.filePaths.first);
        return;
      }
      await _loadBatchFromPaths(expansion.filePaths);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to pick file: $e',
      );
    }
  }

  /// Load many files by path: detect each (bytes read then discarded),
  /// classify CSV/unsupported as excluded, and enter the triage step.
  Future<void> _loadBatchFromPaths(List<String> paths) async {
    final files = <PickedImportFile>[];
    for (final path in paths) {
      final name = p.basename(path);
      try {
        final bytes = await File(path).readAsBytes();
        final detection = await _detectFormat(bytes);
        final status = detection.format == ImportFormat.csv
            ? ImportFileStatus.excludedCsv
            : detection.format.isSupported
            ? ImportFileStatus.pending
            : ImportFileStatus.unsupported;
        files.add(
          PickedImportFile(
            name: name,
            path: path,
            detection: detection,
            status: status,
          ),
        );
      } catch (e) {
        files.add(
          PickedImportFile(
            name: name,
            path: path,
            detection: const DetectionResult(
              format: ImportFormat.unknown,
              confidence: 0,
            ),
            status: ImportFileStatus.failed,
            error: e.toString(),
          ),
        );
      }
    }

    final firstPending = files.where(
      (f) => f.status == ImportFileStatus.pending,
    );
    state = state.copyWith(
      isLoading: false,
      files: files,
      // Gate providers key off detectionResult; use the first importable
      // file's detection so canAdvance behaves for batches too. When the
      // batch has no importable file, CLEAR any stale detection so the
      // wizard cannot advance past triage.
      detectionResult: firstPending.isNotEmpty
          ? firstPending.first.detection
          : null,
      clearDetectionResult: firstPending.isEmpty,
      currentStep: ImportWizardStep.sourceConfirmation,
    );
  }

  /// Load multiple files by path (drag-and-drop). Resets prior state and
  /// enters the triage step. Marks the load as external so the wizard does
  /// not reset it on init.
  Future<void> loadFilesFromPaths(List<String> paths) async {
    final staleTempDirs = state.zipTempDirPaths;
    state = const UniversalImportState().copyWith(isLoading: true);
    _deleteTempDirs(staleTempDirs);
    final expansion = await _zipExpansion.expandAll(paths);
    _applyExpansionExtras(expansion);
    if (expansion.filePaths.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'No importable files found in archive',
      );
      return;
    }
    if (expansion.filePaths.length == 1) {
      await _loadSingleFromFilePath(expansion.filePaths.first);
    } else {
      await _loadBatchFromPaths(expansion.filePaths);
    }
    state = state.copyWith(wasLoadedExternally: true);
  }

  /// Desktop only: pick a folder and recursively gather importable files.
  Future<void> pickFolder() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      currentStep: ImportWizardStep.fileSelection,
    );

    try {
      final dirPath = await FilePicker.getDirectoryPath();
      if (dirPath == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final paths = await scanFolderForImportableFiles(dirPath);
      if (paths.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'No importable files found in the selected folder',
        );
        return;
      }

      // Folder scans surface ZIPs (DiveCloud exports); expand them so
      // members flow through the batch like directly picked files.
      final expansion = await _zipExpansion.expandAll(paths);
      _applyExpansionExtras(expansion);
      final expandedPaths = expansion.filePaths;

      if (expandedPaths.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'No importable files found in the selected folder',
        );
        return;
      }

      if (expandedPaths.length == 1) {
        // Single hit: behave exactly like a single-file pick.
        await _loadSingleFromFilePath(expandedPaths.first);
        return;
      }

      await _loadBatchFromPaths(expandedPaths);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to scan folder: $e',
      );
    }
  }

  // -- Step 1: Source Confirmation --

  /// Store a pending source-app and format override chosen by the user.
  ///
  /// This is persisted in state so the wizard's [onBeforeAdvance] callback
  /// can pass it through to [confirmSource] when the user taps "Next".
  void setPendingSourceOverride(SourceApp? app, {ImportFormat? format}) {
    state = app == null
        ? state.copyWith(
            clearPendingSourceOverride: true,
            clearPendingFormatOverride: true,
          )
        : state.copyWith(
            pendingSourceOverride: app,
            pendingFormatOverride: format,
            clearPendingFormatOverride: format == null,
          );
  }

  /// Confirm the detected source or override with a user selection.
  ///
  /// When [overrideApp] is null the pending override from state is used.
  Future<void> confirmSource({
    SourceApp? overrideApp,
    ImportFormat? overrideFormat,
  }) async {
    if (state.isBatch) {
      await _parseBatch();
      return;
    }

    final detection = state.detectionResult;
    if (detection == null) return;

    // Reset to sourceConfirmation so the canAdvance provider transitions
    // false -> true, enabling auto-advance even when re-confirming.
    state = state.copyWith(currentStep: ImportWizardStep.sourceConfirmation);

    final effectiveOverride = overrideApp ?? state.pendingSourceOverride;

    final format =
        overrideFormat ?? state.pendingFormatOverride ?? detection.format;
    final sourceApp =
        effectiveOverride ?? detection.sourceApp ?? SourceApp.generic;

    final options = ImportOptions(
      sourceApp: sourceApp,
      format: format,
      fileName: state.fileName,
    );

    // For CSV files, run pipeline detection to check for multi-file presets.
    if (format == ImportFormat.csv && state.fileBytes != null) {
      final pipeline = CsvPipeline(registry: await _buildPresetRegistry());
      try {
        final parsedCsv = pipeline.parse(state.fileBytes!);
        final csvDetection = pipeline.detect(parsedCsv);

        final nextStep = csvDetection.hasAdditionalFileRoles
            ? ImportWizardStep.additionalFiles
            : ImportWizardStep.fieldMapping;

        state = state.copyWith(
          options: options,
          clearPendingSourceOverride: true,
          clearPendingFormatOverride: true,
          detectedCsvPreset: csvDetection.matchedPreset,
          parsedCsv: parsedCsv,
          currentStep: nextStep,
        );
        return;
      } catch (_) {
        // If pipeline detection fails, fall through to normal CSV flow.
      }
    }

    state = state.copyWith(
      options: options,
      clearPendingSourceOverride: true,
      clearPendingFormatOverride: true,
      currentStep: format == ImportFormat.csv
          ? ImportWizardStep.fieldMapping
          : ImportWizardStep.review,
    );

    // For non-CSV formats, parse immediately and await so payload is ready
    // before the wizard advances past the Map Fields step.
    if (format != ImportFormat.csv) {
      await _parseAndCheckDuplicates();
    }
  }

  // -- Step 2a: Additional Files (multi-file CSV presets only) --

  /// Pick a secondary file (e.g. dive profile CSV for Subsurface).
  Future<void> pickAdditionalFile() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final pickedFile = result.files.first;
      final filePath = pickedFile.path;
      if (filePath == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Could not access file',
        );
        return;
      }

      final bytes = await File(filePath).readAsBytes();

      state = state.copyWith(
        isLoading: false,
        additionalFileBytes: bytes,
        additionalFileName: pickedFile.name,
        currentStep: ImportWizardStep.fieldMapping,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to pick additional file: $e',
      );
    }
  }

  /// Skip the optional additional file and proceed to field mapping.
  void skipAdditionalFile() {
    state = state.copyWith(currentStep: ImportWizardStep.fieldMapping);
  }

  // -- Step 2b: Field Mapping (CSV only) --

  /// Update the field mapping for CSV imports.
  ///
  /// Clears any previously produced payload so it will be regenerated from
  /// the updated mapping when the user advances past the Map Fields step.
  void updateFieldMapping(FieldMapping mapping) {
    state = state.copyWith(fieldMapping: mapping, clearPayload: true);
  }

  /// Confirm field mapping and proceed to parsing.
  ///
  /// This is a no-op if the payload has already been produced (e.g. for
  /// non-CSV formats where parsing happens immediately after source
  /// confirmation).
  Future<void> confirmFieldMapping() async {
    if (state.payload != null) return;
    state = state.copyWith(currentStep: ImportWizardStep.review);
    await _parseAndCheckDuplicates();
  }

  // -- Batch Parsing (multi-file imports) --

  bool _batchParseCancelled = false;

  /// Cooperative cancel; takes effect at the next file boundary.
  void cancelBatchParse() {
    _batchParseCancelled = true;
  }

  Future<void> _parseBatch() async {
    _batchParseCancelled = false;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      parseTotal: state.pendingFiles.length,
      parseCurrent: 0,
    );

    final result = await _batchParseService.parseAll(
      state.files,
      onProgress: (current, total) {
        state = state.copyWith(parseCurrent: current, parseTotal: total);
      },
      isCancelled: () => _batchParseCancelled,
    );

    if (result.cancelled) {
      // Stay on triage; reset parse bookkeeping so a re-run starts clean.
      // Files already parsed this run must be reset to pending: their
      // FilePayloads (result.parsed) are not retained in state, and
      // parseAll skips non-pending files, so on a re-run they would be
      // silently dropped from the merged import. Resetting makes a re-run
      // re-parse and merge them.
      final resetFiles = [
        for (final f in result.files)
          f.status == ImportFileStatus.parsed
              ? f.copyWith(status: ImportFileStatus.pending, diveCount: 0)
              : f,
      ];
      state = state.copyWith(
        isLoading: false,
        files: resetFiles,
        parseCurrent: 0,
        parseTotal: 0,
        currentStep: ImportWizardStep.sourceConfirmation,
      );
      return;
    }

    if (result.parsed.isEmpty) {
      // Clear the detection result so the Confirm Source / triage step's
      // canAdvance gate (universalAdapterSourceReadyProvider, which only checks
      // detectionResult.isFormatSupported) goes false -- there is no payload to
      // review, so Next must not stay enabled.
      state = state.copyWith(
        isLoading: false,
        files: result.files,
        clearDetectionResult: true,
        error: 'No data could be parsed from the selected files',
      );
      return;
    }

    final payload = const PayloadMerger().merge(result.parsed);
    final dupResult = await _checkDuplicates(payload);
    final selections = _defaultSelections(payload, dupResult);

    state = state.copyWith(
      isLoading: false,
      files: result.files,
      payload: payload,
      duplicateResult: dupResult,
      selections: selections,
      currentStep: ImportWizardStep.review,
    );
  }

  // -- Parsing + Duplicate Check --

  Future<void> _parseAndCheckDuplicates() async {
    final bytes = state.fileBytes;
    final opts = state.options;
    if (bytes == null || opts == null) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final registry = opts.format == ImportFormat.csv
          ? await _buildPresetRegistry()
          : null;
      final parser = _parserFor(opts.format, registry: registry);
      final ImportPayload payload;
      if (parser is CsvImportParser) {
        payload = await parser.parse(
          bytes,
          options: opts,
          customMappingOverride: state.fieldMapping,
          profileFileBytes: state.additionalFileBytes,
        );
      } else {
        payload = await parser.parse(bytes, options: opts);
      }

      if (payload.isEmpty) {
        final errorMsg = payload.warnings.isNotEmpty
            ? payload.warnings.first.message
            : 'No data could be parsed from the file';
        state = state.copyWith(isLoading: false, error: errorMsg);
        return;
      }

      // Run duplicate checking
      final dupResult = await _checkDuplicates(payload);

      // Build default selections: all selected, minus duplicates
      final selections = _defaultSelections(payload, dupResult);

      state = state.copyWith(
        isLoading: false,
        payload: payload,
        duplicateResult: dupResult,
        selections: selections,
        currentStep: ImportWizardStep.review,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to parse file: $e',
      );
    }
  }

  ImportParser _parserFor(ImportFormat format, {PresetRegistry? registry}) {
    if (format == ImportFormat.csv) {
      return CsvImportParser(
        customMapping: state.fieldMapping,
        pipeline: registry != null ? CsvPipeline(registry: registry) : null,
      );
    }
    return parserForFormat(format);
  }

  /// Default review selections: everything selected, minus duplicates.
  Map<ImportEntityType, Set<int>> _defaultSelections(
    ImportPayload payload,
    ImportDuplicateResult dupResult,
  ) {
    final selections = <ImportEntityType, Set<int>>{};
    for (final type in payload.availableTypes) {
      final items = payload.entitiesOf(type);
      final allIndices = Set<int>.from(List.generate(items.length, (i) => i));

      if (type == ImportEntityType.dives) {
        // Exclude dives matched as duplicates
        selections[type] = allIndices.difference(
          Set<int>.from(dupResult.diveMatches.keys),
        );
      } else {
        // Exclude items flagged as duplicates
        final dups = dupResult.duplicates[type] ?? const {};
        selections[type] = allIndices.difference(dups);
      }
    }
    return selections;
  }

  Future<ImportDuplicateResult> _checkDuplicates(ImportPayload payload) async {
    const checker = ImportDuplicateChecker();

    final existingTrips = await _ref.read(allTripsProvider.future);
    final existingSites = await _ref.read(sitesProvider.future);
    final existingEquipment = await _ref.read(allEquipmentProvider.future);
    final existingBuddies = await _ref.read(allBuddiesProvider.future);
    final existingDiveCenters = await _ref.read(allDiveCentersProvider.future);
    final existingCertifications = await _ref.read(
      allCertificationsProvider.future,
    );
    final existingTags = await _ref.read(tagsProvider.future);
    final existingDiveTypes = await _ref.read(diveTypesProvider.future);
    final diveRepo = _ref.read(diveRepositoryProvider);
    final existingDives = await diveRepo.getAllDives();
    final existingSourceUuidByDiveId = await diveRepo.getSourceUuidByDiveId();

    return checker.check(
      payload: payload,
      existingDives: existingDives,
      existingSites: existingSites,
      existingTrips: existingTrips,
      existingEquipment: existingEquipment,
      existingBuddies: existingBuddies,
      existingDiveCenters: existingDiveCenters,
      existingCertifications: existingCertifications,
      existingTags: existingTags,
      existingDiveTypes: existingDiveTypes,
      existingSourceUuidByDiveId: existingSourceUuidByDiveId,
      checkIntraBatch: (payload.metadata['batchFileCount'] as int? ?? 1) > 1,
    );
  }

  // -- Step 3: Review (Selection Management) --

  /// Toggle selection of a single item.
  void toggleSelection(ImportEntityType type, int index) {
    final current = Set<int>.from(state.selectionFor(type));
    if (current.contains(index)) {
      current.remove(index);
    } else {
      current.add(index);
    }
    state = state.copyWith(selections: {...state.selections, type: current});
  }

  /// Select all items of a given entity type.
  void selectAll(ImportEntityType type) {
    final count = state.totalCountFor(type);
    state = state.copyWith(
      selections: {
        ...state.selections,
        type: Set<int>.from(List.generate(count, (i) => i)),
      },
    );
  }

  /// Deselect all items of a given entity type.
  void deselectAll(ImportEntityType type) {
    state = state.copyWith(
      selections: {...state.selections, type: const <int>{}},
    );
  }

  /// Clear the external-load flag after the wizard has consumed it.
  void clearExternalLoadFlag() {
    state = state.copyWith(wasLoadedExternally: false);
  }

  @visibleForTesting
  void debugSetFilesForTest(List<PickedImportFile> files) {
    state = state.copyWith(
      files: files,
      currentStep: ImportWizardStep.sourceConfirmation,
    );
  }

  void reset() {
    final staleTempDirs = state.zipTempDirPaths;
    state = const UniversalImportState();
    _deleteTempDirs(staleTempDirs);
  }
}

// ============================================================================
// Provider
// ============================================================================

final universalImportNotifierProvider =
    StateNotifierProvider<UniversalImportNotifier, UniversalImportState>((ref) {
      return UniversalImportNotifier(ref);
    });
