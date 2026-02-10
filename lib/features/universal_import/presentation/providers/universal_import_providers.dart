import 'dart:io';
import 'dart:typed_data';

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
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
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
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';
import 'package:submersion/features/universal_import/data/services/format_detector.dart';
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
    this.options,
    this.fieldMapping,
    this.payload,
    this.duplicateResult,
    this.selections = const {},
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
    Map<ImportEntityType, int>? importCounts,
    String? importPhase,
    int? importCurrent,
    int? importTotal,
  }) {
    return UniversalImportState(
      currentStep: currentStep ?? this.currentStep,
      isLoading: isLoading ?? this.isLoading,
      isImporting: isImporting ?? this.isImporting,
      error: clearError ? null : (error ?? this.error),
      fileBytes: fileBytes ?? this.fileBytes,
      fileName: fileName ?? this.fileName,
      detectionResult: detectionResult ?? this.detectionResult,
      options: options ?? this.options,
      fieldMapping: clearFieldMapping
          ? null
          : (fieldMapping ?? this.fieldMapping),
      payload: payload ?? this.payload,
      duplicateResult: duplicateResult ?? this.duplicateResult,
      selections: selections ?? this.selections,
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
      final fileName = pickedFile.name;

      const detector = FormatDetector();
      final detection = detector.detect(bytes);

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

  /// Confirm the detected source or override with a user selection.
  void confirmSource({SourceApp? overrideApp, ImportFormat? overrideFormat}) {
    final detection = state.detectionResult;
    if (detection == null) return;

    final format = overrideFormat ?? detection.format;
    final sourceApp = overrideApp ?? detection.sourceApp ?? SourceApp.generic;

    final options = ImportOptions(
      sourceApp: sourceApp,
      format: format,
      batchTag: ImportOptions.defaultTag(sourceApp),
    );

    state = state.copyWith(
      options: options,
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
  void confirmFieldMapping() {
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
      ImportFormat.uddf || ImportFormat.subsurfaceXml => UddfImportParser(),
      ImportFormat.fit => const FitImportParser(),
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

  /// Update the batch tag.
  void updateBatchTag(String? tag) {
    if (state.options == null) return;
    state = state.copyWith(
      options: ImportOptions(
        sourceApp: state.options!.sourceApp,
        format: state.options!.format,
        batchTag: tag,
      ),
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

      // Convert to UDDF format for reuse of UddfEntityImporter
      var uddfData = _toUddfResult(payload);
      var uddfSelections = _toUddfSelections(state.selections);

      // Inject batch tag into the data so it flows through the import pipeline
      final batchTag = state.options?.batchTag;
      if (batchTag != null && batchTag.isNotEmpty) {
        final injected = _injectBatchTag(uddfData, uddfSelections, batchTag);
        uddfData = injected.$1;
        uddfSelections = injected.$2;
      }

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

      const importer = UddfEntityImporter();
      final result = await importer.import(
        data: uddfData,
        selections: uddfSelections,
        repositories: repos,
        diverId: currentDiver.id,
        onProgress: (phase, current, total) {
          state = state.copyWith(
            importPhase: phase,
            importCurrent: current,
            importTotal: total,
          );
        },
      );

      _invalidateProviders();

      final counts = <ImportEntityType, int>{
        if (result.dives > 0) ImportEntityType.dives: result.dives,
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

  /// Inject a batch tag into the UDDF data so it flows through the
  /// existing tag import and dive-tag linking pipeline.
  ///
  /// Returns a new (UddfImportResult, UddfImportSelections) pair with:
  /// - The batch tag appended to the tags list
  /// - The tag index added to the tags selection
  /// - Each selected dive's `tagRefs` updated to include the batch tag ID
  (UddfImportResult, UddfImportSelections) _injectBatchTag(
    UddfImportResult data,
    UddfImportSelections selections,
    String tagName,
  ) {
    final batchTagId = 'batch_tag_${DateTime.now().millisecondsSinceEpoch}';

    // Append the batch tag to the tags list
    final updatedTags = [
      ...data.tags,
      <String, dynamic>{'name': tagName, 'uddfId': batchTagId},
    ];
    final batchTagIndex = updatedTags.length - 1;

    // Add batchTagId to each selected dive's tagRefs
    final updatedDives = <Map<String, dynamic>>[];
    for (var i = 0; i < data.dives.length; i++) {
      if (selections.dives.contains(i)) {
        final dive = Map<String, dynamic>.from(data.dives[i]);
        final existingRefs = dive['tagRefs'] as List? ?? [];
        dive['tagRefs'] = [...existingRefs, batchTagId];
        updatedDives.add(dive);
      } else {
        updatedDives.add(data.dives[i]);
      }
    }

    final updatedData = UddfImportResult(
      dives: updatedDives,
      sites: data.sites,
      trips: data.trips,
      equipment: data.equipment,
      buddies: data.buddies,
      diveCenters: data.diveCenters,
      certifications: data.certifications,
      tags: updatedTags,
      customDiveTypes: data.customDiveTypes,
      equipmentSets: data.equipmentSets,
      courses: data.courses,
    );

    final updatedSelections = UddfImportSelections(
      trips: selections.trips,
      equipment: selections.equipment,
      buddies: selections.buddies,
      diveCenters: selections.diveCenters,
      certifications: selections.certifications,
      tags: {...selections.tags, batchTagIndex},
      diveTypes: selections.diveTypes,
      sites: selections.sites,
      equipmentSets: selections.equipmentSets,
      dives: selections.dives,
      courses: selections.courses,
    );

    return (updatedData, updatedSelections);
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
