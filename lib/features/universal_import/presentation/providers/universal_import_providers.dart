import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:submersion/core/database/database.dart'
    show DiveDataSourcesCompanion, DiveProfilesCompanion;
import 'package:uuid/uuid.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
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

// ============================================================================
// Wizard Steps
// ============================================================================

/// Steps in the universal import wizard.
enum ImportWizardStep {
  fileSelection,
  sourceConfirmation,
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
    this.detectionResult,
    this.pendingSourceOverride,
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

  /// Format detection result (set after file selection).
  final DetectionResult? detectionResult;

  /// Source app override chosen by the user but not yet confirmed.
  ///
  /// Stored here so the wizard's [onBeforeAdvance] callback can pass it to
  /// [confirmSource] when the user taps "Next".
  final SourceApp? pendingSourceOverride;

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
    DetectionResult? detectionResult,
    ImportOptions? options,
    FieldMapping? fieldMapping,
    bool clearFieldMapping = false,
    ImportPayload? payload,
    ImportDuplicateResult? duplicateResult,
    Map<ImportEntityType, Set<int>>? selections,
    Map<int, DiveDuplicateResolution>? diveResolutions,
    Map<ImportEntityType, int>? importCounts,
    String? importPhase,
    int? importCurrent,
    int? importTotal,
    SourceApp? pendingSourceOverride,
    bool clearPendingSourceOverride = false,
  }) {
    return UniversalImportState(
      currentStep: currentStep ?? this.currentStep,
      isLoading: isLoading ?? this.isLoading,
      isImporting: isImporting ?? this.isImporting,
      error: clearError ? null : (error ?? this.error),
      fileBytes: fileBytes ?? this.fileBytes,
      fileName: fileName ?? this.fileName,
      detectionResult: detectionResult ?? this.detectionResult,
      pendingSourceOverride: clearPendingSourceOverride
          ? null
          : (pendingSourceOverride ?? this.pendingSourceOverride),
      options: options ?? this.options,
      fieldMapping: clearFieldMapping
          ? null
          : (fieldMapping ?? this.fieldMapping),
      payload: payload ?? this.payload,
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

// ============================================================================
// Notifier
// ============================================================================

/// Manages the universal import wizard flow.
class UniversalImportNotifier extends StateNotifier<UniversalImportState> {
  UniversalImportNotifier(this._ref) : super(const UniversalImportState());

  final Ref _ref;

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

  /// Store a pending source-app override chosen by the user.
  ///
  /// This is persisted in state so the wizard's [onBeforeAdvance] callback
  /// can pass it through to [confirmSource] when the user taps "Next".
  void setPendingSourceOverride(SourceApp? app) {
    state = app == null
        ? state.copyWith(clearPendingSourceOverride: true)
        : state.copyWith(pendingSourceOverride: app);
  }

  /// Confirm the detected source or override with a user selection.
  ///
  /// When [overrideApp] is null the pending override from state is used.
  void confirmSource({SourceApp? overrideApp, ImportFormat? overrideFormat}) {
    final detection = state.detectionResult;
    if (detection == null) return;

    // Reset to sourceConfirmation so the canAdvance provider transitions
    // false -> true, enabling auto-advance even when re-confirming.
    state = state.copyWith(currentStep: ImportWizardStep.sourceConfirmation);

    final effectiveOverride = overrideApp ?? state.pendingSourceOverride;

    final format = overrideFormat ?? detection.format;
    final sourceApp =
        effectiveOverride ?? detection.sourceApp ?? SourceApp.generic;

    final options = ImportOptions(sourceApp: sourceApp, format: format);

    state = state.copyWith(
      options: options,
      clearPendingSourceOverride: true,
      currentStep: format == ImportFormat.csv
          ? ImportWizardStep.fieldMapping
          : ImportWizardStep.review,
    );

    // For non-CSV formats, parse immediately
    if (format != ImportFormat.csv) {
      _parseAndCheckDuplicates();
    }
  }

  // -- Step 2: Field Mapping (CSV only) --

  /// Update the field mapping for CSV imports.
  void updateFieldMapping(FieldMapping mapping) {
    state = state.copyWith(fieldMapping: mapping);
  }

  /// Confirm field mapping and proceed to parsing.
  ///
  /// This is a no-op if the payload has already been produced (e.g. for
  /// non-CSV formats where parsing happens immediately after source
  /// confirmation).
  void confirmFieldMapping() {
    if (state.payload != null) return;
    state = state.copyWith(currentStep: ImportWizardStep.review);
    _parseAndCheckDuplicates();
  }

  // -- Parsing + Duplicate Check --

  Future<void> _parseAndCheckDuplicates() async {
    final bytes = state.fileBytes;
    final opts = state.options;
    if (bytes == null || opts == null) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final parser = _parserFor(opts.format);
      final payload = await parser.parse(bytes, options: opts);

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

  ImportParser _parserFor(ImportFormat format) {
    return switch (format) {
      ImportFormat.csv => CsvImportParser(customMapping: state.fieldMapping),
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
        final dupResult = state.duplicateResult;
        consolidatedCount = await _performConsolidations(
          indices: consolidateIndices,
          diveItems: diveItems,
          diveResolutions: state.diveResolutions,
          duplicateResult: dupResult,
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

  // -- Consolidation --

  /// Attaches each consolidate-flagged imported dive as a secondary computer
  /// reading on the matched existing dive.
  ///
  /// Returns the number of successful consolidations.
  Future<int> _performConsolidations({
    required Set<int> indices,
    required List<Map<String, dynamic>> diveItems,
    required Map<int, DiveDuplicateResolution> diveResolutions,
    required ImportDuplicateResult? duplicateResult,
    required DiveRepository diveRepository,
  }) async {
    const uuid = Uuid();
    final now = DateTime.now();
    var count = 0;

    for (final index in indices) {
      final matchResult = duplicateResult?.diveMatchFor(index);
      if (matchResult == null) continue;

      final diveData = diveItems[index];
      final dateTime = diveData['dateTime'] as DateTime? ?? now;
      final runtime = diveData['runtime'] as Duration?;
      final duration = diveData['duration'] as Duration?;
      final effectiveDuration = runtime ?? duration;
      final exitTime = runtime != null ? dateTime.add(runtime) : null;

      final secondaryReading = DiveDataSourcesCompanion.insert(
        id: uuid.v4(),
        diveId: matchResult.diveId,
        isPrimary: const Value(false),
        computerModel: Value(diveData['diveComputerModel'] as String?),
        computerSerial: Value(diveData['diveComputerSerial'] as String?),
        sourceFormat: Value(diveData['sourceFormat'] as String?),
        maxDepth: Value(diveData['maxDepth'] as double?),
        avgDepth: Value(diveData['avgDepth'] as double?),
        duration: Value(effectiveDuration?.inSeconds),
        waterTemp: Value(diveData['waterTemp'] as double?),
        entryTime: Value(dateTime),
        exitTime: Value(exitTime),
        importedAt: now,
        createdAt: now,
      );

      final profileData =
          diveData['profile'] as List<Map<String, dynamic>>? ?? [];
      final secondaryProfile = profileData
          .map(
            (p) => DiveProfilesCompanion.insert(
              id: uuid.v4(),
              diveId: matchResult.diveId,
              isPrimary: const Value(false),
              timestamp: p['timestamp'] as int? ?? 0,
              depth: p['depth'] as double? ?? 0.0,
              temperature: Value(p['temperature'] as double?),
              pressure: Value(p['pressure'] as double?),
              setpoint: Value(p['setpoint'] as double?),
              ppO2: Value(p['ppO2'] as double?),
            ),
          )
          .toList();

      await diveRepository.consolidateComputer(
        targetDiveId: matchResult.diveId,
        secondaryReading: secondaryReading,
        secondaryProfile: secondaryProfile,
      );
      count++;
    }

    return count;
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
