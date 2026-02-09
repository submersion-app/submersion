import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_import/data/services/uddf_duplicate_checker.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_import/data/services/uddf_parser_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

// ============================================================================
// Entity type identifiers for selection management
// ============================================================================

/// Identifies entity types in the UDDF import wizard.
enum UddfEntityType {
  trips,
  equipment,
  buddies,
  diveCenters,
  certifications,
  courses,
  tags,
  diveTypes,
  sites,
  equipmentSets,
  dives,
}

// ============================================================================
// State
// ============================================================================

/// State for the UDDF import wizard.
class UddfImportState {
  const UddfImportState({
    this.currentStep = 0,
    this.isLoading = false,
    this.isImporting = false,
    this.error,
    this.parsedData,
    this.duplicateCheckResult,
    this.selectedTrips = const {},
    this.selectedEquipment = const {},
    this.selectedBuddies = const {},
    this.selectedDiveCenters = const {},
    this.selectedCertifications = const {},
    this.selectedTags = const {},
    this.selectedDiveTypes = const {},
    this.selectedSites = const {},
    this.selectedEquipmentSets = const {},
    this.selectedDives = const {},
    this.selectedCourses = const {},
    this.importResult,
    this.importPhase = '',
    this.importCurrent = 0,
    this.importTotal = 0,
  });

  /// Current wizard step: 0=file, 1=review, 2=importing, 3=summary.
  final int currentStep;
  final bool isLoading;
  final bool isImporting;
  final String? error;

  /// Parsed UDDF data (set after step 0).
  final UddfImportResult? parsedData;

  /// Duplicate check results (set after step 0, before step 1).
  final UddfDuplicateCheckResult? duplicateCheckResult;

  /// Selected indices per entity type.
  final Set<int> selectedTrips;
  final Set<int> selectedEquipment;
  final Set<int> selectedBuddies;
  final Set<int> selectedDiveCenters;
  final Set<int> selectedCertifications;
  final Set<int> selectedTags;
  final Set<int> selectedDiveTypes;
  final Set<int> selectedSites;
  final Set<int> selectedEquipmentSets;
  final Set<int> selectedDives;
  final Set<int> selectedCourses;

  /// Import result (set after step 2).
  final UddfEntityImportResult? importResult;

  /// Progress tracking.
  final String importPhase;
  final int importCurrent;
  final int importTotal;

  UddfImportState copyWith({
    int? currentStep,
    bool? isLoading,
    bool? isImporting,
    String? error,
    bool clearError = false,
    UddfImportResult? parsedData,
    UddfDuplicateCheckResult? duplicateCheckResult,
    Set<int>? selectedTrips,
    Set<int>? selectedEquipment,
    Set<int>? selectedBuddies,
    Set<int>? selectedDiveCenters,
    Set<int>? selectedCertifications,
    Set<int>? selectedTags,
    Set<int>? selectedDiveTypes,
    Set<int>? selectedSites,
    Set<int>? selectedEquipmentSets,
    Set<int>? selectedDives,
    Set<int>? selectedCourses,
    UddfEntityImportResult? importResult,
    String? importPhase,
    int? importCurrent,
    int? importTotal,
  }) {
    return UddfImportState(
      currentStep: currentStep ?? this.currentStep,
      isLoading: isLoading ?? this.isLoading,
      isImporting: isImporting ?? this.isImporting,
      error: clearError ? null : (error ?? this.error),
      parsedData: parsedData ?? this.parsedData,
      duplicateCheckResult: duplicateCheckResult ?? this.duplicateCheckResult,
      selectedTrips: selectedTrips ?? this.selectedTrips,
      selectedEquipment: selectedEquipment ?? this.selectedEquipment,
      selectedBuddies: selectedBuddies ?? this.selectedBuddies,
      selectedDiveCenters: selectedDiveCenters ?? this.selectedDiveCenters,
      selectedCertifications:
          selectedCertifications ?? this.selectedCertifications,
      selectedTags: selectedTags ?? this.selectedTags,
      selectedDiveTypes: selectedDiveTypes ?? this.selectedDiveTypes,
      selectedSites: selectedSites ?? this.selectedSites,
      selectedEquipmentSets:
          selectedEquipmentSets ?? this.selectedEquipmentSets,
      selectedDives: selectedDives ?? this.selectedDives,
      selectedCourses: selectedCourses ?? this.selectedCourses,
      importResult: importResult ?? this.importResult,
      importPhase: importPhase ?? this.importPhase,
      importCurrent: importCurrent ?? this.importCurrent,
      importTotal: importTotal ?? this.importTotal,
    );
  }

  /// Get the selection set for a given entity type.
  Set<int> selectionFor(UddfEntityType type) {
    return switch (type) {
      UddfEntityType.trips => selectedTrips,
      UddfEntityType.equipment => selectedEquipment,
      UddfEntityType.buddies => selectedBuddies,
      UddfEntityType.diveCenters => selectedDiveCenters,
      UddfEntityType.certifications => selectedCertifications,
      UddfEntityType.courses => selectedCourses,
      UddfEntityType.tags => selectedTags,
      UddfEntityType.diveTypes => selectedDiveTypes,
      UddfEntityType.sites => selectedSites,
      UddfEntityType.equipmentSets => selectedEquipmentSets,
      UddfEntityType.dives => selectedDives,
    };
  }

  /// Total count of items in parsedData for a given entity type.
  int totalCountFor(UddfEntityType type) {
    final data = parsedData;
    if (data == null) return 0;
    return switch (type) {
      UddfEntityType.trips => data.trips.length,
      UddfEntityType.equipment => data.equipment.length,
      UddfEntityType.buddies => data.buddies.length,
      UddfEntityType.diveCenters => data.diveCenters.length,
      UddfEntityType.certifications => data.certifications.length,
      UddfEntityType.courses => data.courses.length,
      UddfEntityType.tags => data.tags.length,
      UddfEntityType.diveTypes => data.customDiveTypes.length,
      UddfEntityType.sites => data.sites.length,
      UddfEntityType.equipmentSets => data.equipmentSets.length,
      UddfEntityType.dives => data.dives.length,
    };
  }

  /// Total selected items across all entity types.
  int get totalSelected =>
      selectedTrips.length +
      selectedEquipment.length +
      selectedBuddies.length +
      selectedDiveCenters.length +
      selectedCertifications.length +
      selectedTags.length +
      selectedDiveTypes.length +
      selectedSites.length +
      selectedEquipmentSets.length +
      selectedDives.length +
      selectedCourses.length;

  /// Build [UddfImportSelections] from current selection state.
  UddfImportSelections toSelections() {
    return UddfImportSelections(
      trips: selectedTrips,
      equipment: selectedEquipment,
      buddies: selectedBuddies,
      diveCenters: selectedDiveCenters,
      certifications: selectedCertifications,
      tags: selectedTags,
      diveTypes: selectedDiveTypes,
      sites: selectedSites,
      equipmentSets: selectedEquipmentSets,
      dives: selectedDives,
      courses: selectedCourses,
    );
  }
}

// ============================================================================
// Notifier
// ============================================================================

/// Manages the UDDF import wizard flow.
class UddfImportNotifier extends StateNotifier<UddfImportState> {
  UddfImportNotifier(this._ref) : super(const UddfImportState());

  final Ref _ref;

  /// Step 0: Pick a file, parse it, run duplicate check, advance to step 1.
  Future<void> pickAndParseFile() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Use FileType.any on iOS/macOS since custom extensions don't work
      // reliably in sandboxed apps.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final pickedFile = result.files.first;

      // Validate extension using PlatformFile.extension (derived from the
      // original filename) rather than the full path, which may lose the
      // extension on macOS/iOS sandboxed apps.
      final ext = pickedFile.extension?.toLowerCase();
      if (ext != 'uddf' && ext != 'xml') {
        state = state.copyWith(
          isLoading: false,
          error: 'Please select a UDDF or XML file',
        );
        return;
      }

      final filePath = pickedFile.path;
      if (filePath == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Could not access file',
        );
        return;
      }

      await parseFile(filePath);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to pick file: $e',
      );
    }
  }

  /// Parse a UDDF file at [filePath], run duplicate check, and set up
  /// default selections (all selected except duplicates).
  ///
  /// Reads the file content directly and uses [UddfParserService.parseContent]
  /// to avoid the path-based extension check, which can fail on macOS/iOS
  /// sandboxed apps where the file picker returns temporary paths.
  Future<void> parseFile(String filePath) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        state = state.copyWith(isLoading: false, error: 'File not found');
        return;
      }
      final content = await file.readAsString();

      final exportService = _ref.read(exportServiceProvider);
      final parser = UddfParserService(exportService);
      final data = await parser.parseContent(content);

      // Run duplicate check against existing entities
      final dupResult = await _checkDuplicates(data);

      // Build default selections: all selected, minus duplicates
      final selections = UddfImportSelections.selectAll(data);

      state = state.copyWith(
        isLoading: false,
        parsedData: data,
        duplicateCheckResult: dupResult,
        selectedTrips: selections.trips.difference(dupResult.duplicateTrips),
        selectedEquipment: selections.equipment.difference(
          dupResult.duplicateEquipment,
        ),
        selectedBuddies: selections.buddies.difference(
          dupResult.duplicateBuddies,
        ),
        selectedDiveCenters: selections.diveCenters.difference(
          dupResult.duplicateDiveCenters,
        ),
        selectedCertifications: selections.certifications.difference(
          dupResult.duplicateCertifications,
        ),
        selectedTags: selections.tags.difference(dupResult.duplicateTags),
        selectedDiveTypes: selections.diveTypes.difference(
          dupResult.duplicateDiveTypes,
        ),
        selectedSites: selections.sites.difference(dupResult.duplicateSites),
        selectedEquipmentSets: selections.equipmentSets,
        selectedCourses: selections.courses,
        selectedDives: selections.dives.difference(
          Set<int>.from(dupResult.diveMatches.keys),
        ),
        currentStep: 1,
      );
    } on UddfParseException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to parse file: $e',
      );
    }
  }

  /// Run duplicate checking against all existing entities.
  Future<UddfDuplicateCheckResult> _checkDuplicates(
    UddfImportResult data,
  ) async {
    const checker = UddfDuplicateChecker();

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
      importData: data,
      existingTrips: existingTrips,
      existingSites: existingSites,
      existingEquipment: existingEquipment,
      existingBuddies: existingBuddies,
      existingDiveCenters: existingDiveCenters,
      existingCertifications: existingCertifications,
      existingTags: existingTags,
      existingDiveTypes: existingDiveTypes,
      existingDives: existingDives,
    );
  }

  /// Toggle selection of a single item.
  void toggleSelection(UddfEntityType type, int index) {
    final current = state.selectionFor(type);
    final updated = Set<int>.from(current);
    if (updated.contains(index)) {
      updated.remove(index);
    } else {
      updated.add(index);
    }
    _updateSelection(type, updated);
  }

  /// Select all items of a given entity type.
  void selectAll(UddfEntityType type) {
    final count = state.totalCountFor(type);
    _updateSelection(type, Set<int>.from(List.generate(count, (i) => i)));
  }

  /// Deselect all items of a given entity type.
  void deselectAll(UddfEntityType type) {
    _updateSelection(type, const {});
  }

  void _updateSelection(UddfEntityType type, Set<int> selection) {
    state = switch (type) {
      UddfEntityType.trips => state.copyWith(selectedTrips: selection),
      UddfEntityType.equipment => state.copyWith(selectedEquipment: selection),
      UddfEntityType.buddies => state.copyWith(selectedBuddies: selection),
      UddfEntityType.diveCenters => state.copyWith(
        selectedDiveCenters: selection,
      ),
      UddfEntityType.certifications => state.copyWith(
        selectedCertifications: selection,
      ),
      UddfEntityType.courses => state.copyWith(selectedCourses: selection),
      UddfEntityType.tags => state.copyWith(selectedTags: selection),
      UddfEntityType.diveTypes => state.copyWith(selectedDiveTypes: selection),
      UddfEntityType.sites => state.copyWith(selectedSites: selection),
      UddfEntityType.equipmentSets => state.copyWith(
        selectedEquipmentSets: selection,
      ),
      UddfEntityType.dives => state.copyWith(selectedDives: selection),
    };
  }

  /// Step 1->2->3: Perform the import with current selections.
  Future<void> performImport() async {
    final data = state.parsedData;
    if (data == null) return;

    state = state.copyWith(currentStep: 2, isImporting: true, clearError: true);

    try {
      final currentDiver = await _ref.read(currentDiverProvider.future);
      if (currentDiver == null) {
        state = state.copyWith(
          isImporting: false,
          error: 'Please create a diver profile before importing',
        );
        return;
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
        data: data,
        selections: state.toSelections(),
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

      // Invalidate providers so lists refresh
      _invalidateProviders();

      state = state.copyWith(
        currentStep: 3,
        isImporting: false,
        importResult: result,
      );
    } catch (e) {
      state = state.copyWith(isImporting: false, error: 'Import failed: $e');
    }
  }

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
    state = const UddfImportState();
  }
}

// ============================================================================
// Provider
// ============================================================================

final uddfImportNotifierProvider =
    StateNotifierProvider<UddfImportNotifier, UddfImportState>((ref) {
      return UddfImportNotifier(ref);
    });
