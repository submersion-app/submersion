import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tank_presets/domain/services/default_tank_preset_resolver.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
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
import 'package:submersion/features/universal_import/data/parsers/placeholder_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/shearwater_cloud_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';
import 'package:submersion/features/universal_import/data/services/format_detector.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart';
import 'package:submersion/features/universal_import/presentation/providers/import_consolidation_service.dart';
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
      final result = await FilePicker.platform.pickFiles(
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

      const detector = FormatDetector();
      var detection = detector.detect(bytes);

      if (detection.format == ImportFormat.sqlite) {
        final isShearwater = await ShearwaterDbReader.isShearwaterCloudDb(
          bytes,
        );
        if (isShearwater) {
          detection = const DetectionResult(
            format: ImportFormat.shearwaterDb,
            sourceApp: SourceApp.shearwater,
            confidence: 0.95,
          );
        }
      }

      state = state.copyWith(
        isLoading: false,
        fileBytes: bytes,
        fileName: fileName,
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

    // For non-CSV formats, parse immediately
    if (format != ImportFormat.csv) {
      _parseAndCheckDuplicates();
    }
  }

  // -- Step 2a: Additional Files (multi-file CSV presets only) --

  /// Pick a secondary file (e.g. dive profile CSV for Subsurface).
  Future<void> pickAdditionalFile() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await FilePicker.platform.pickFiles(
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

  /// Set the duplicate resolution for a specific dive index.
  ///
  /// When [resolution] is [DiveDuplicateResolution.consolidate] or
  /// [DiveDuplicateResolution.importAsNew], the dive index is added to the
  /// selection so it participates in the import step. When [resolution] is
  /// [DiveDuplicateResolution.skip], it is removed from the selection.
  void setDiveResolution(int index, DiveDuplicateResolution resolution) {
    final updatedResolutions = Map<int, DiveDuplicateResolution>.from(
      state.diveResolutions,
    )..[index] = resolution;

    final currentSelection = Set<int>.from(
      state.selectionFor(ImportEntityType.dives),
    );
    if (resolution == DiveDuplicateResolution.skip) {
      currentSelection.remove(index);
    } else {
      currentSelection.add(index);
    }

    state = state.copyWith(
      diveResolutions: updatedResolutions,
      selections: {
        ...state.selections,
        ImportEntityType.dives: currentSelection,
      },
    );
  }

  // -- Step 4: Import --

  /// Perform the import with current selections.
  Future<void> performImport() async {
    final payload = state.payload;
    if (payload == null) return;

    state = state.copyWith(
      currentStep: ImportWizardStep.importing,
      isImporting: true,
      clearError: true,
    );

    try {
      final currentDiver = await _ref.read(currentDiverProvider.future);
      if (currentDiver == null) {
        state = state.copyWith(
          isImporting: false,
          error: 'Please create a diver profile before importing',
        );
        return;
      }

      // Partition dive selections: consolidate vs normal import.
      final consolidateIndices = <int>{};
      final normalDiveSelection = Set<int>.from(
        state.selectionFor(ImportEntityType.dives),
      );
      for (final entry in state.diveResolutions.entries) {
        if (entry.value == DiveDuplicateResolution.consolidate) {
          consolidateIndices.add(entry.key);
          normalDiveSelection.remove(entry.key);
        }
      }

      // Convert to UDDF format for reuse of UddfEntityImporter
      final uddfData = _toUddfResult(payload);
      final uddfSelections = _toUddfSelections({
        ...state.selections,
        ImportEntityType.dives: normalDiveSelection,
      });

      final repos = ImportRepositories(
        tripRepository: _ref.read(tripRepositoryProvider),
        equipmentRepository: _ref.read(equipmentRepositoryProvider),
        equipmentSetRepository: _ref.read(equipmentSetRepositoryProvider),
        buddyRepository: _ref.read(buddyRepositoryProvider),
        diveCenterRepository: _ref.read(diveCenterRepositoryProvider),
        certificationRepository: _ref.read(certificationRepositoryProvider),
        tagRepository: _ref.read(tagRepositoryProvider),
        diveTypeRepository: _ref.read(diveTypeRepositoryProvider),
        siteRepository: _ref.read(siteRepositoryProvider),
        diveRepository: _ref.read(diveRepositoryProvider),
        tankPressureRepository: _ref.read(tankPressureRepositoryProvider),
        courseRepository: _ref.read(courseRepositoryProvider),
      );

      final settings = _ref.read(settingsProvider);
      final resolver = DefaultTankPresetResolver(
        repository: _ref.read(tankPresetRepositoryProvider),
      );
      final defaultTankPreset = await resolver.resolve(
        settings.defaultTankPreset,
      );
      final importer = UddfEntityImporter(
        defaultTankPreset: defaultTankPreset,
        defaultStartPressure: settings.defaultStartPressure,
        applyDefaultTankToImports: settings.applyDefaultTankToImports,
      );
      final result = await importer.import(
        data: uddfData,
        selections: uddfSelections,
        repositories: repos,
        diverId: currentDiver.id,
        onProgress: (phase, current, total) {
          state = state.copyWith(
            importPhase: phase.name,
            importCurrent: current,
            importTotal: total,
          );
        },
      );

      // Run consolidations for dives marked with the consolidate resolution.
      var consolidatedCount = 0;
      if (consolidateIndices.isNotEmpty) {
        final diveRepo = _ref.read(diveRepositoryProvider);
        final diveItems = payload.entitiesOf(ImportEntityType.dives);
        consolidatedCount = await performConsolidations(
          indices: consolidateIndices,
          diveItems: diveItems,
          duplicateResult: state.duplicateResult,
          diveRepository: diveRepo,
        );
      }

      _invalidateProviders();

      final counts = <ImportEntityType, int>{
        if ((result.dives + consolidatedCount) > 0)
          ImportEntityType.dives: result.dives + consolidatedCount,
        if (result.sites > 0) ImportEntityType.sites: result.sites,
        if (result.trips > 0) ImportEntityType.trips: result.trips,
        if (result.equipment > 0) ImportEntityType.equipment: result.equipment,
        if (result.equipmentSets > 0)
          ImportEntityType.equipmentSets: result.equipmentSets,
        if (result.buddies > 0) ImportEntityType.buddies: result.buddies,
        if (result.diveCenters > 0)
          ImportEntityType.diveCenters: result.diveCenters,
        if (result.certifications > 0)
          ImportEntityType.certifications: result.certifications,
        if (result.courses > 0) ImportEntityType.courses: result.courses,
        if (result.tags > 0) ImportEntityType.tags: result.tags,
        if (result.diveTypes > 0) ImportEntityType.diveTypes: result.diveTypes,
      };

      state = state.copyWith(
        currentStep: ImportWizardStep.summary,
        isImporting: false,
        importCounts: counts,
      );
    } catch (e) {
      state = state.copyWith(isImporting: false, error: 'Import failed: $e');
    }
  }

  // -- Adapter Helpers --

  static UddfImportResult _toUddfResult(ImportPayload payload) {
    return UddfImportResult(
      dives: payload.entitiesOf(ImportEntityType.dives),
      sites: payload.entitiesOf(ImportEntityType.sites),
      trips: payload.entitiesOf(ImportEntityType.trips),
      equipment: payload.entitiesOf(ImportEntityType.equipment),
      buddies: payload.entitiesOf(ImportEntityType.buddies),
      diveCenters: payload.entitiesOf(ImportEntityType.diveCenters),
      certifications: payload.entitiesOf(ImportEntityType.certifications),
      tags: payload.entitiesOf(ImportEntityType.tags),
      customDiveTypes: payload.entitiesOf(ImportEntityType.diveTypes),
      equipmentSets: payload.entitiesOf(ImportEntityType.equipmentSets),
      courses: payload.entitiesOf(ImportEntityType.courses),
    );
  }

  static UddfImportSelections _toUddfSelections(
    Map<ImportEntityType, Set<int>> sel,
  ) {
    return UddfImportSelections(
      trips: sel[ImportEntityType.trips] ?? const {},
      equipment: sel[ImportEntityType.equipment] ?? const {},
      buddies: sel[ImportEntityType.buddies] ?? const {},
      diveCenters: sel[ImportEntityType.diveCenters] ?? const {},
      certifications: sel[ImportEntityType.certifications] ?? const {},
      tags: sel[ImportEntityType.tags] ?? const {},
      diveTypes: sel[ImportEntityType.diveTypes] ?? const {},
      sites: sel[ImportEntityType.sites] ?? const {},
      equipmentSets: sel[ImportEntityType.equipmentSets] ?? const {},
      dives: sel[ImportEntityType.dives] ?? const {},
      courses: sel[ImportEntityType.courses] ?? const {},
    );
  }

  // -- Provider Invalidation --

  void _invalidateProviders() {
    _ref.invalidate(sitesProvider);
    _ref.invalidate(sitesWithCountsProvider);
    _ref.invalidate(siteListNotifierProvider);
    _ref.invalidate(allBuddiesProvider);
    _ref.invalidate(buddyListNotifierProvider);
    _ref.invalidate(allEquipmentProvider);
    _ref.invalidate(activeEquipmentProvider);
    _ref.invalidate(retiredEquipmentProvider);
    _ref.invalidate(serviceDueEquipmentProvider);
    _ref.invalidate(equipmentListNotifierProvider);
    _ref.invalidate(equipmentSetsProvider);
    _ref.invalidate(allTripsProvider);
    _ref.invalidate(allDiveCentersProvider);
    _ref.invalidate(allCertificationsProvider);
    _ref.invalidate(diveTypesProvider);
    _ref.invalidate(tagsProvider);
    _ref.invalidate(diveListNotifierProvider);
    _ref.invalidate(paginatedDiveListProvider);
    _ref.invalidate(diveStatisticsProvider);
    _ref.invalidate(diveRecordsProvider);
    _ref.invalidate(allBuddiesWithDiveCountProvider);
  }

  /// Reset to initial state.
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
