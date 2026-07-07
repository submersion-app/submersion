import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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
import 'package:submersion/features/universal_import/data/parsers/fit_import_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_sqlite_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/macdive_xml_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/placeholder_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/shearwater_cloud_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';
import 'package:submersion/features/universal_import/data/services/format_detector.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/data/services/macdive_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_state.dart';

export 'package:submersion/features/universal_import/presentation/providers/universal_import_state.dart';

// ============================================================================
// Notifier
// ============================================================================

/// Manages the universal import wizard flow.
class UniversalImportNotifier extends StateNotifier<UniversalImportState> {
  UniversalImportNotifier(this._ref) : super(const UniversalImportState());

  final Ref _ref;

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
    state = const UniversalImportState().copyWith(isLoading: true);

    try {
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

  /// Pick a file and run format detection.
  Future<void> pickFile() async {
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
      final fileName = pickedFile.name;
      final detection = await _detectFormat(bytes);

      state = state.copyWith(
        isLoading: false,
        files: [
          PickedImportFile(
            name: fileName,
            path: filePath,
            bytes: bytes,
            detection: detection,
            status: ImportFileStatus.pending,
          ),
        ],
        detectionResult: detection,
        currentStep: ImportWizardStep.sourceConfirmation,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to pick file: $e',
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

    final options = ImportOptions(sourceApp: sourceApp, format: format);

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
    return switch (format) {
      ImportFormat.csv => CsvImportParser(
        customMapping: state.fieldMapping,
        pipeline: registry != null ? CsvPipeline(registry: registry) : null,
      ),
      ImportFormat.uddf => UddfImportParser(),
      ImportFormat.macdiveXml => const MacDiveXmlParser(),
      ImportFormat.macdiveSqlite => const MacDiveSqliteParser(),
      ImportFormat.subsurfaceXml => SubsurfaceXmlParser(),
      ImportFormat.fit => const FitImportParser(),
      ImportFormat.shearwaterDb => ShearwaterCloudParser(),
      _ => const PlaceholderParser(),
    };
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

  void reset() {
    state = const UniversalImportState();
  }
}

// ============================================================================
// Provider
// ============================================================================

final universalImportNotifierProvider =
    StateNotifierProvider<UniversalImportNotifier, UniversalImportState>((ref) {
      return UniversalImportNotifier(ref);
    });
