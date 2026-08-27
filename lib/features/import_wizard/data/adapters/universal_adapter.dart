import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_utils.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/entity_match_result.dart';
import 'package:submersion/features/import_wizard/domain/models/import_file_outcome.dart';
// Import wizard bundle types: hide ImportEntityType to avoid name clash with
// universal_import's same-named enum. Access it via the ImportSourceAdapter
// interface which already uses the wizard's ImportEntityType.
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart'
    hide ImportEntityType;
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart'
    as wizard
    show ImportEntityType;
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/import_wizard/data/adapters/import_notice_grouper.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tank_presets/domain/services/default_tank_preset_resolver.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart'
    as ui;
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart';
import 'package:submersion/features/universal_import/presentation/providers/import_consolidation_service.dart'
    show performConsolidations;
import 'package:submersion/features/import_wizard/presentation/widgets/photo_folder_step.dart';
import 'package:submersion/features/universal_import/domain/services/import_media_resolver.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/features/universal_import/presentation/widgets/field_mapping_step.dart';
import 'package:submersion/features/universal_import/presentation/widgets/file_selection_step.dart';
import 'package:submersion/features/universal_import/presentation/widgets/file_triage_step.dart';

/// True once a file has been detected and the wizard moved past file selection.
final universalAdapterFileSelectedProvider = Provider<bool>((ref) {
  final state = ref.watch(universalImportNotifierProvider);
  return state.detectionResult != null &&
      state.currentStep != ImportWizardStep.fileSelection;
});

/// True once detection completed and the format is supported.
final universalAdapterSourceReadyProvider = Provider<bool>((ref) {
  final state = ref.watch(universalImportNotifierProvider);
  final detection = state.detectionResult;
  return detection != null && detection.isFormatSupported;
});

/// True once the Next button should be enabled on the Map Fields step.
///
/// Satisfied when: payload is already produced (non-CSV), or at least one
/// column has been mapped (CSV with preset or manual mapping).
final universalAdapterMappingReadyProvider = Provider<bool>((ref) {
  final state = ref.watch(universalImportNotifierProvider);
  if (state.payload != null) return true;
  final mapping = state.fieldMapping;
  return mapping != null && mapping.columns.isNotEmpty;
});

/// Stricter condition used only for auto-advance on the Map Fields step.
///
/// Auto-advances for non-CSV (payload produced) and preset-detected CSVs
/// (mapping auto-populated in one batch). Manual CSV mapping never
/// auto-advances — the user must tap Next.
final _universalAdapterMappingAutoAdvanceProvider = Provider<bool>((ref) {
  final state = ref.watch(universalImportNotifierProvider);
  if (state.payload != null) return true;
  if (state.detectedCsvPreset != null) {
    final mapping = state.fieldMapping;
    return mapping != null && mapping.columns.isNotEmpty;
  }
  return false;
});

/// True when the parsed payload references no photos at all.
///
/// Used as the Photos step's auto-advance condition, so the step is invisible
/// for every import that has nothing to resolve.
final universalAdapterNoPhotosProvider = Provider<bool>((ref) {
  final payload = ref.watch(
    universalImportNotifierProvider.select((s) => s.payload),
  );
  return (payload?.entitiesOf(ui.ImportEntityType.media) ?? const []).isEmpty;
});

/// True when the Photos step has nothing left to ask.
///
/// Deliberately looser than [universalAdapterNoPhotosProvider]: a user who
/// picked a folder or chose to skip may advance, but the step is never
/// auto-advanced past a decision they have not made.
final universalAdapterPhotosReadyProvider = Provider<bool>((ref) {
  if (ref.watch(universalAdapterNoPhotosProvider)) return true;
  final state = ref.watch(universalImportNotifierProvider);
  return state.photosSkipped || state.photoResolution != null;
});

/// Import source adapter for universal file imports (CSV, Subsurface XML,
/// UDDF, auto-detected formats). Wraps [UniversalImportNotifier] into the
/// unified import wizard framework.
class UniversalAdapter implements ImportSourceAdapter {
  static const _log = LoggerService('UniversalAdapter');

  UniversalAdapter({required WidgetRef ref, String displayName = 'File Import'})
    : _ref = ref,
      _displayName = displayName;

  final WidgetRef _ref;
  final String _displayName;

  bool get hasPreloadedState {
    final state = _ref.read(universalImportNotifierProvider);
    return state.wasLoadedExternally;
  }

  /// Clear the external-load flag so subsequent wizard opens reset normally.
  void consumePreloadedState() {
    _ref.read(universalImportNotifierProvider.notifier).clearExternalLoadFlag();
  }

  @override
  void resetState() {
    _ref.read(universalImportNotifierProvider.notifier).reset();
  }

  // ---------------------------------------------------------------------------
  // ImportSourceAdapter interface
  // ---------------------------------------------------------------------------

  @override
  ImportSourceType get sourceType => ImportSourceType.universal;

  @override
  String get displayName => _displayName;

  @override
  String get defaultTagName {
    final state = _ref.read(universalImportNotifierProvider);
    final name = state.fileName ?? _displayName;
    final now = DateTime.now();
    final date =
        '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final base = name.toLowerCase().endsWith('import') ? name : '$name Import';
    return '$base $date';
  }

  @override
  Set<DuplicateAction> get supportedDuplicateActions => const {
    DuplicateAction.skip,
    DuplicateAction.importAsNew,
    // File imports offer MANUAL consolidation only (no auto-consolidate: a
    // file has no single "current computer" to prove a cross-computer match).
    DuplicateAction.consolidate,
    // Union across entity types. Overwrite-in-place is implemented for sites
    // only -- see [duplicateActionsFor], which is what the review UI and the
    // wizard notifier actually gate on.
    DuplicateAction.replaceSource,
  };

  /// Overwrite-in-place ([DuplicateAction.replaceSource]) is only implemented
  /// for sites: [UddfImportSelections.siteOverrides] is the sole override
  /// channel the importer understands. Offering it on the buddies/equipment/
  /// trips tabs would let the user mark a duplicate "decided" and then have it
  /// silently dropped, so those tabs get the base set without it.
  @override
  Set<DuplicateAction> duplicateActionsFor(wizard.ImportEntityType type) {
    if (type == wizard.ImportEntityType.sites) return supportedDuplicateActions;
    return supportedDuplicateActions.difference(const {
      DuplicateAction.replaceSource,
    });
  }

  @override
  List<WizardStepDef> get acquisitionSteps => [
    WizardStepDef(
      label: 'Select File',
      icon: Icons.file_open,
      builder: (context) => const FileSelectionStep(),
      canAdvance: universalAdapterFileSelectedProvider,
      autoAdvance: true,
    ),
    WizardStepDef(
      label: 'Confirm Source',
      icon: Icons.check_circle_outline,
      builder: (context) => const SourceConfirmationOrTriageStep(),
      canAdvance: universalAdapterSourceReadyProvider,
      onBeforeAdvance: () async {
        await _ref
            .read(universalImportNotifierProvider.notifier)
            .confirmSource();
      },
    ),
    WizardStepDef(
      label: 'Map Fields',
      icon: Icons.table_chart_outlined,
      builder: (context) => const FieldMappingStep(),
      canAdvance: universalAdapterMappingReadyProvider,
      canAutoAdvance: _universalAdapterMappingAutoAdvanceProvider,
      autoAdvance: true,
      onBeforeAdvance: () async {
        final notifier = _ref.read(universalImportNotifierProvider.notifier);
        await notifier.confirmFieldMapping();
      },
    ),
    WizardStepDef(
      label: 'Photos',
      icon: Icons.photo_library_outlined,
      builder: (context) => const PhotoFolderStep(),
      canAdvance: universalAdapterPhotosReadyProvider,
      // Stricter than canAdvance on purpose: the step auto-skips only when
      // the logbook references no photos at all, never past a decision the
      // user has not made.
      canAutoAdvance: universalAdapterNoPhotosProvider,
      autoAdvance: true,
    ),
  ];

  @override
  Future<ImportBundle> buildBundle() async {
    final notifierState = _ref.read(universalImportNotifierProvider);
    final payload = notifierState.payload;

    if (payload == null) {
      return const ImportBundle(
        source: ImportSourceInfo(
          type: ImportSourceType.universal,
          displayName: 'File Import',
        ),
        groups: {},
      );
    }

    final groups = <wizard.ImportEntityType, EntityGroup>{};
    _addGroupIfNotEmpty(
      groups,
      wizard.ImportEntityType.dives,
      payload.entitiesOf(ui.ImportEntityType.dives),
      _diveToEntityItem,
    );
    _addGroupIfNotEmpty(
      groups,
      wizard.ImportEntityType.sites,
      payload.entitiesOf(ui.ImportEntityType.sites),
      _siteToEntityItem,
    );
    _addGroupIfNotEmpty(
      groups,
      wizard.ImportEntityType.buddies,
      payload.entitiesOf(ui.ImportEntityType.buddies),
      _buddyToEntityItem,
    );
    _addGroupIfNotEmpty(
      groups,
      wizard.ImportEntityType.equipment,
      payload.entitiesOf(ui.ImportEntityType.equipment),
      _equipmentToEntityItem,
    );
    _addGroupIfNotEmpty(
      groups,
      wizard.ImportEntityType.trips,
      payload.entitiesOf(ui.ImportEntityType.trips),
      _tripToEntityItem,
    );
    _addGroupIfNotEmpty(
      groups,
      wizard.ImportEntityType.certifications,
      payload.entitiesOf(ui.ImportEntityType.certifications),
      _certificationToEntityItem,
    );
    _addGroupIfNotEmpty(
      groups,
      wizard.ImportEntityType.diveCenters,
      payload.entitiesOf(ui.ImportEntityType.diveCenters),
      _diveCenterToEntityItem,
    );
    _addGroupIfNotEmpty(
      groups,
      wizard.ImportEntityType.tags,
      payload.entitiesOf(ui.ImportEntityType.tags),
      _tagToEntityItem,
    );
    _addGroupIfNotEmpty(
      groups,
      wizard.ImportEntityType.diveTypes,
      payload.entitiesOf(ui.ImportEntityType.diveTypes),
      _diveTypeToEntityItem,
    );
    _addGroupIfNotEmpty(
      groups,
      wizard.ImportEntityType.equipmentSets,
      payload.entitiesOf(ui.ImportEntityType.equipmentSets),
      _equipmentSetToEntityItem,
    );
    _addGroupIfNotEmpty(
      groups,
      wizard.ImportEntityType.courses,
      payload.entitiesOf(ui.ImportEntityType.courses),
      _courseToEntityItem,
    );
    _addGroupIfNotEmpty(
      groups,
      wizard.ImportEntityType.media,
      payload.entitiesOf(ui.ImportEntityType.media),
      _mediaToEntityItem,
    );

    return ImportBundle(
      source: ImportSourceInfo(
        type: ImportSourceType.universal,
        displayName: _displayName,
      ),
      groups: groups,
    );
  }

  @override
  Future<ImportBundle> checkDuplicates(ImportBundle bundle) async {
    final notifierState = _ref.read(universalImportNotifierProvider);
    final payload = notifierState.payload;
    if (payload == null) return bundle;

    const checker = ImportDuplicateChecker();

    // Scope duplicate detection to the current diver's data only.
    final currentDiver = await _ref.read(currentDiverProvider.future);
    final diverId = currentDiver?.id;

    // Use refresh() to force re-fetch from the database. read() may return
    // stale cached data if a provider was invalidated but not yet re-fetched.
    final existingTrips = await _ref.refresh(allTripsProvider.future);
    final existingSites = await _ref.refresh(sitesProvider.future);
    final existingEquipment = await _ref.refresh(allEquipmentProvider.future);
    final existingBuddies = await _ref.refresh(allBuddiesProvider.future);
    final existingDiveCenters = await _ref.refresh(
      allDiveCentersProvider.future,
    );
    final existingCertifications = await _ref.refresh(
      allCertificationsProvider.future,
    );
    final existingTags = await _ref.refresh(tagsProvider.future);
    final existingDiveTypes = await _ref.refresh(diveTypesProvider.future);
    final diveRepo = _ref.read(diveRepositoryProvider);
    final existingDives = await diveRepo.getAllDives(diverId: diverId);
    final existingSourceUuidByDiveId = await diveRepo.getSourceUuidByDiveId(
      diverId: diverId,
    );

    final dupResult = checker.check(
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
      units: UnitFormatter(_ref.read(settingsProvider)),
    );

    final updatedGroups = Map<wizard.ImportEntityType, EntityGroup>.from(
      bundle.groups,
    );

    _applyDuplicateIndices(
      updatedGroups,
      wizard.ImportEntityType.dives,
      Set<int>.from(dupResult.diveMatches.keys),
      matchResults: dupResult.diveMatches,
    );
    _applyDuplicateIndices(
      updatedGroups,
      wizard.ImportEntityType.trips,
      dupResult.duplicates[ui.ImportEntityType.trips] ?? const {},
      entityMatches: dupResult.entityMatches[ui.ImportEntityType.trips],
    );
    _applyDuplicateIndices(
      updatedGroups,
      wizard.ImportEntityType.sites,
      dupResult.duplicates[ui.ImportEntityType.sites] ?? const {},
      entityMatches: dupResult.entityMatches[ui.ImportEntityType.sites],
    );
    _applyDuplicateIndices(
      updatedGroups,
      wizard.ImportEntityType.equipment,
      dupResult.duplicates[ui.ImportEntityType.equipment] ?? const {},
      entityMatches: dupResult.entityMatches[ui.ImportEntityType.equipment],
    );
    _applyDuplicateIndices(
      updatedGroups,
      wizard.ImportEntityType.buddies,
      dupResult.duplicates[ui.ImportEntityType.buddies] ?? const {},
      entityMatches: dupResult.entityMatches[ui.ImportEntityType.buddies],
    );
    _applyDuplicateIndices(
      updatedGroups,
      wizard.ImportEntityType.diveCenters,
      dupResult.duplicates[ui.ImportEntityType.diveCenters] ?? const {},
      entityMatches: dupResult.entityMatches[ui.ImportEntityType.diveCenters],
    );
    _applyDuplicateIndices(
      updatedGroups,
      wizard.ImportEntityType.certifications,
      dupResult.duplicates[ui.ImportEntityType.certifications] ?? const {},
      entityMatches:
          dupResult.entityMatches[ui.ImportEntityType.certifications],
    );
    _applyDuplicateIndices(
      updatedGroups,
      wizard.ImportEntityType.tags,
      dupResult.duplicates[ui.ImportEntityType.tags] ?? const {},
      entityMatches: dupResult.entityMatches[ui.ImportEntityType.tags],
    );
    _applyDuplicateIndices(
      updatedGroups,
      wizard.ImportEntityType.diveTypes,
      dupResult.duplicates[ui.ImportEntityType.diveTypes] ?? const {},
      entityMatches: dupResult.entityMatches[ui.ImportEntityType.diveTypes],
    );

    return ImportBundle(source: bundle.source, groups: updatedGroups);
  }

  @override
  Future<UnifiedImportResult> performImport(
    ImportBundle bundle,
    Map<wizard.ImportEntityType, Set<int>> selections,
    Map<wizard.ImportEntityType, Map<int, DuplicateAction>> duplicateActions, {
    bool retainSourceDiveNumbers = false,
    ImportProgressCallback? onProgress,
    ImportCancellationToken? cancelToken,
  }) async {
    final notifierState = _ref.read(universalImportNotifierProvider);
    final payload = notifierState.payload;

    if (payload == null) {
      return const UnifiedImportResult(
        importedCounts: {},
        consolidatedCount: 0,
        skippedCount: 0,
        errorMessage: 'No parsed data available',
      );
    }

    final currentDiver = await _ref.read(currentDiverProvider.future);
    if (currentDiver == null) {
      return const UnifiedImportResult(
        importedCounts: {},
        consolidatedCount: 0,
        skippedCount: 0,
        errorMessage: 'Please create a diver profile before importing',
      );
    }

    final skipped = _countSkipped(selections, duplicateActions);

    // Resolve selections for all entity types: include duplicate items
    // whose action is importAsNew (not just the base selection set).
    Set<int> resolve(wizard.ImportEntityType type) =>
        _resolveSelections(type, selections, duplicateActions);

    final uddfData = _payloadToUddfResult(payload);

    // #756: flagged duplicates whose action is skip (or explicit link via
    // consolidate) must LINK the dive to the matched existing record rather
    // than dropping the association or creating a twin. Build source-ref ->
    // existing-id seeds for the importer's id mappings.
    Map<String, String> preResolvedIdsFor(
      wizard.ImportEntityType type,
      List<Map<String, dynamic>> items,
    ) {
      final matches = bundle.groups[type]?.entityMatches;
      if (matches == null || matches.isEmpty) return const {};
      final actions = duplicateActions[type] ?? const {};
      final map = <String, String>{};
      for (final entry in matches.entries) {
        final action = actions[entry.key];
        // Seed for skip and consolidate (both mean "do not create a new
        // row"), and for an undecided duplicate as a safety net -- the
        // wizard gates advancement on pending decisions, so that state is
        // not reachable today, but dropping the association silently is the
        // exact defect this fix exists to prevent. A seed is harmless when
        // the entity IS imported: _importBuddies/_importTags overwrite the
        // mapping with the newly created id.
        final links =
            action == null ||
            action == DuplicateAction.skip ||
            action == DuplicateAction.consolidate;
        if (!links) continue;
        if (entry.key < 0 || entry.key >= items.length) continue;
        final item = items[entry.key];
        final ref = (item['uddfId'] as String?) ?? (item['name'] as String?);
        if (ref != null) map[ref] = entry.value.existingId;
      }
      return map;
    }

    final uddfSelections = UddfImportSelections(
      dives: resolve(wizard.ImportEntityType.dives),
      sites: resolve(wizard.ImportEntityType.sites),
      siteOverrides: _resolveSiteOverrides(duplicateActions, bundle),
      buddies: resolve(wizard.ImportEntityType.buddies),
      equipment: resolve(wizard.ImportEntityType.equipment),
      trips: resolve(wizard.ImportEntityType.trips),
      certifications: resolve(wizard.ImportEntityType.certifications),
      diveCenters: resolve(wizard.ImportEntityType.diveCenters),
      tags: resolve(wizard.ImportEntityType.tags),
      diveTypes: resolve(wizard.ImportEntityType.diveTypes),
      equipmentSets: resolve(wizard.ImportEntityType.equipmentSets),
      courses: resolve(wizard.ImportEntityType.courses),
    );

    final repos = ImportRepositories(
      tripRepository: _ref.read(tripRepositoryProvider),
      equipmentRepository: _ref.read(equipmentRepositoryProvider),
      equipmentSetRepository: _ref.read(equipmentSetRepositoryProvider),
      buddyRepository: _ref.read(buddyRepositoryProvider),
      diveCenterRepository: _ref.read(diveCenterRepositoryProvider),
      certificationRepository: _ref.read(certificationRepositoryProvider),
      tagRepository: _ref.read(tagRepositoryProvider),
      diveTypeRepository: _ref.read(diveTypeRepositoryProvider),
      diveRoleRepository: _ref.read(diveRoleRepositoryProvider),
      siteRepository: _ref.read(siteRepositoryProvider),
      diveRepository: _ref.read(diveRepositoryProvider),
      tankPressureRepository: _ref.read(tankPressureRepositoryProvider),
      courseRepository: _ref.read(courseRepositoryProvider),
      serviceRecordRepository: _ref.read(serviceRecordRepositoryProvider),
      diveComputerRepository: _ref.read(diveComputerRepositoryProvider),
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
      placeNameLanguage: settings.placeNameLanguage,
    );

    final result = await importer.import(
      data: uddfData,
      selections: uddfSelections,
      repositories: repos,
      diverId: currentDiver.id,
      retainSourceDiveNumbers: retainSourceDiveNumbers,
      preResolvedBuddyIds: preResolvedIdsFor(
        wizard.ImportEntityType.buddies,
        uddfData.buddies,
      ),
      preResolvedTagIds: preResolvedIdsFor(
        wizard.ImportEntityType.tags,
        uddfData.tags,
      ),
      onProgress: onProgress,
      cancelToken: cancelToken,
    );

    // Fold consolidate-flagged dives (imported as standalone above) into their
    // matched existing dive. These indices come only from an explicit user
    // choice in the review step, and each has a match result (the UI offers
    // Consolidate only on matches).
    final diveActions =
        duplicateActions[wizard.ImportEntityType.dives] ?? const {};
    final consolidateIndices = <int>{
      for (final entry in diveActions.entries)
        if (entry.value == DuplicateAction.consolidate) entry.key,
    };

    var consolidated = 0;
    var removedDiveIds = const <String>{};
    if (consolidateIndices.isNotEmpty) {
      final matchResults =
          bundle.groups[wizard.ImportEntityType.dives]?.matchResults ??
          const <int, DiveMatchResult>{};
      final summary = await performConsolidations(
        indices: consolidateIndices,
        diveIdByIndex: result.diveIdByIndex,
        duplicateResult: ImportDuplicateResult(diveMatches: matchResults),
        consolidationService: _ref.read(diveConsolidationServiceProvider),
        diveRepository: repos.diveRepository,
      );
      consolidated = summary.consolidated;
      removedDiveIds = summary.removedDiveIds;
    }

    // Attach ZIP-bundled photos to the dives that survived import (skipping
    // any that were folded away by consolidation).
    final attachedPhotos = await attachImportedPhotos(
      photoPathsByBaseName: notifierState.photoPathsByBaseName,
      diveIdByIndex: result.diveIdByIndex,
      removedDiveIds: removedDiveIds,
      dives: payload.entitiesOf(ui.ImportEntityType.dives),
      files: notifierState.files,
      singleFileName: notifierState.fileName,
      attach: (file, diveId, takenAt) async {
        await _ref
            .read(mediaImportServiceProvider)
            .importLocalFileForDive(
              sourceFile: file,
              diveId: diveId,
              takenAt: takenAt,
            );
      },
    );

    // Attach photos the logbook referenced by absolute path, resolved against
    // the folder picked in the Photos step. This and the ZIP path above cover
    // different sources and cannot double-count: a ZIP sidecar and a
    // <picture> reference never describe the same file.
    final resolution = notifierState.photoResolution;
    final resolvedPhotos = resolution == null
        ? 0
        : await attachResolvedPhotos(
            media: payload.entitiesOf(ui.ImportEntityType.media),
            resolvedPathByIndex: resolution.resolvedPathByIndex,
            diveIdByIndex: result.diveIdByIndex,
            removedDiveIds: removedDiveIds,
            dives: payload.entitiesOf(ui.ImportEntityType.dives),
            selectedIndices: selections[wizard.ImportEntityType.media],
            attach: (file, diveId, takenAt, latitude, longitude) async {
              await _ref
                  .read(mediaImportServiceProvider)
                  .importLocalFileForDive(
                    sourceFile: file,
                    diveId: diveId,
                    takenAt: takenAt,
                    latitude: latitude,
                    longitude: longitude,
                    subdirectory: 'imported_photos',
                  );
            },
          );

    // `importer.import` counted folded/removed dives as imported; subtract only
    // the dives that were ACTUALLY removed (folded, or compensating-deleted).
    // A dive whose fold AND cleanup both failed is still standalone in the DB,
    // so it stays counted as imported rather than being hidden.
    final counts = _convertImportCounts(result);
    final netDives = result.dives - removedDiveIds.length;
    if (netDives > 0) {
      counts[wizard.ImportEntityType.dives] = netDives;
    } else {
      counts.remove(wizard.ImportEntityType.dives);
    }

    final netImportedDiveIds = [
      for (final id in result.diveIds)
        if (!removedDiveIds.contains(id)) id,
    ];

    // Removed-but-not-folded dives were consolidation attempts that failed and
    // were cleaned up; report them as skipped (as the download adapter does).
    final cleanedUpFailures = removedDiveIds.length - consolidated;

    // Per-file outcomes for the bulk summary. Imported dive counts are
    // attributed through each payload dive's `_sourceFileId` stamp — the
    // display name can collide when two folders hold same-named files, the
    // id (`f<index>` from BatchParseService) cannot.
    final pickedFiles = notifierState.files;
    var fileOutcomes = const <ImportFileOutcome>[];
    if (pickedFiles.length > 1) {
      final dives = payload.entitiesOf(ui.ImportEntityType.dives);
      final importedByFileId = <String, int>{};
      result.diveIdByIndex.forEach((index, diveId) {
        if (removedDiveIds.contains(diveId)) return;
        if (index < 0 || index >= dives.length) return;
        final sourceId = dives[index]['_sourceFileId'] as String?;
        if (sourceId != null) {
          importedByFileId[sourceId] = (importedByFileId[sourceId] ?? 0) + 1;
        }
      });

      fileOutcomes = [
        for (final (i, f) in pickedFiles.indexed)
          ImportFileOutcome(
            fileName: f.name,
            formatName: f.detection.format.displayName,
            status: switch (f.status) {
              ImportFileStatus.parsed ||
              ImportFileStatus.pending => ImportFileOutcomeStatus.imported,
              ImportFileStatus.failed => ImportFileOutcomeStatus.parseFailed,
              ImportFileStatus.excludedCsv =>
                ImportFileOutcomeStatus.needsIndividualImport,
              ImportFileStatus.unsupported =>
                ImportFileOutcomeStatus.unsupported,
            },
            importedDives: importedByFileId['f$i'] ?? 0,
            error: f.error,
          ),
      ];
    }

    // Queue a data-quality scan of the imported dives (fire-and-forget).
    scheduleQualityScan(netImportedDiveIds);

    final notices = groupImportNotices(payload.warnings, netDives);

    return UnifiedImportResult(
      notices: notices,
      importedCounts: counts,
      consolidatedCount: consolidated,
      skippedCount: skipped + cleanedUpFailures,
      importedDiveIds: netImportedDiveIds,
      fileOutcomes: fileOutcomes,
      attachedPhotoCount: attachedPhotos + resolvedPhotos,
      unmatchedPhotoCount:
          notifierState.unmatchedPhotoCount + (resolution?.notFoundCount ?? 0),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers — entity item conversion
  // ---------------------------------------------------------------------------

  static final _dateFormatter = DateFormat('MMM d, yyyy');
  static final _timeFormatter = DateFormat('h:mm a');

  void _addGroupIfNotEmpty(
    Map<wizard.ImportEntityType, EntityGroup> groups,
    wizard.ImportEntityType type,
    List<Map<String, dynamic>> items,
    EntityItem Function(Map<String, dynamic>) converter,
  ) {
    if (items.isEmpty) return;
    groups[type] = EntityGroup(items: items.map(converter).toList());
  }

  EntityItem _diveToEntityItem(Map<String, dynamic> data) {
    final dateTime = data['dateTime'] as DateTime?;
    final maxDepth = asDoubleOrNull(data['maxDepth']);
    final runtime = data['runtime'] as Duration?;
    final duration = data['duration'] as Duration?;
    final effectiveDuration = runtime ?? duration;
    final siteName =
        data['siteName'] as String? ??
        (data['site'] as Map<String, dynamic>?)?['name'] as String?;

    String title;
    if (dateTime != null) {
      final dateStr = _dateFormatter.format(dateTime);
      final timeStr = _timeFormatter.format(dateTime);
      title = '$dateStr \u2014 $timeStr';
    } else {
      title = 'Unknown date';
    }

    final parts = <String>[];
    if (siteName != null && siteName.isNotEmpty) parts.add(siteName);
    if (maxDepth != null) {
      final settings = _ref.read(settingsProvider);
      final units = UnitFormatter(settings);
      parts.add('${units.formatDepth(maxDepth)} max');
    }
    if (effectiveDuration != null) {
      parts.add('${effectiveDuration.inMinutes} min');
    }
    // Only merged batch payloads carry `_sourceFile`; single-file review
    // subtitles are unchanged.
    final sourceFile = data['_sourceFile'] as String?;
    if (sourceFile != null && sourceFile.isNotEmpty) parts.add(sourceFile);
    final subtitle = parts.isEmpty ? '' : parts.join(' \u00b7 ');

    final diveData = IncomingDiveData.fromImportMap(data);

    return EntityItem(title: title, subtitle: subtitle, diveData: diveData);
  }

  EntityItem _siteToEntityItem(Map<String, dynamic> data) {
    final name = (data['name'] as String?) ?? 'Unnamed';
    final lat = data['latitude'] as double?;
    final lon = data['longitude'] as double?;
    final location = data['location'] as String?;

    String subtitle;
    if (location != null && location.isNotEmpty) {
      subtitle = location;
    } else if (lat != null && lon != null) {
      subtitle = UnitFormatter(
        _ref.read(settingsProvider),
      ).formatCoordinates(lat, lon);
    } else {
      subtitle = '';
    }

    return EntityItem(title: name, subtitle: subtitle);
  }

  EntityItem _buddyToEntityItem(Map<String, dynamic> data) {
    final firstName = data['firstName'] as String?;
    final lastName = data['lastName'] as String?;
    final name = data['name'] as String?;

    String title;
    if (firstName != null || lastName != null) {
      title = [firstName, lastName].whereType<String>().join(' ').trim();
    } else if (name != null) {
      title = name;
    } else {
      title = 'Unnamed';
    }

    return EntityItem(title: title, subtitle: '');
  }

  EntityItem _equipmentToEntityItem(Map<String, dynamic> data) {
    final name = (data['name'] as String?) ?? 'Unnamed';
    final typeValue = data['type'];
    final String subtitle;
    if (typeValue is EquipmentType) {
      subtitle = typeValue.displayName;
    } else if (typeValue is String) {
      subtitle = typeValue;
    } else {
      subtitle = '';
    }
    return EntityItem(title: name, subtitle: subtitle);
  }

  EntityItem _tripToEntityItem(Map<String, dynamic> data) {
    final name = (data['name'] as String?) ?? 'Unnamed';
    final startDate = data['startDate'] as DateTime?;
    final endDate = data['endDate'] as DateTime?;

    String subtitle;
    if (startDate != null && endDate != null) {
      subtitle =
          '${_dateFormatter.format(startDate)} - '
          '${_dateFormatter.format(endDate)}';
    } else if (startDate != null) {
      subtitle = _dateFormatter.format(startDate);
    } else {
      subtitle = '';
    }

    return EntityItem(title: name, subtitle: subtitle);
  }

  EntityItem _certificationToEntityItem(Map<String, dynamic> data) {
    final levelValue = data['level'];
    final name = data['name'] as String?;
    final agencyValue = data['agency'];

    final String? level;
    if (levelValue is CertificationLevel) {
      level = levelValue.displayName;
    } else if (levelValue is String) {
      level = levelValue;
    } else {
      level = null;
    }

    final title = level ?? name ?? 'Unnamed';

    final String subtitle;
    if (agencyValue is CertificationAgency) {
      subtitle = agencyValue.displayName;
    } else if (agencyValue is String) {
      subtitle = agencyValue;
    } else {
      subtitle = '';
    }

    return EntityItem(title: title, subtitle: subtitle);
  }

  EntityItem _diveCenterToEntityItem(Map<String, dynamic> data) {
    final name = (data['name'] as String?) ?? 'Unnamed';
    final location = data['location'] as String?;
    final country = data['country'] as String?;
    final city = data['city'] as String?;

    String subtitle;
    if (location != null && location.isNotEmpty) {
      subtitle = location;
    } else if (country != null) {
      subtitle = city != null ? '$city, $country' : country;
    } else if (city != null) {
      subtitle = city;
    } else {
      subtitle = '';
    }

    return EntityItem(title: name, subtitle: subtitle);
  }

  EntityItem _tagToEntityItem(Map<String, dynamic> data) {
    final name = (data['name'] as String?) ?? 'Unnamed';
    return EntityItem(title: name, subtitle: '');
  }

  EntityItem _diveTypeToEntityItem(Map<String, dynamic> data) {
    final name = (data['name'] as String?) ?? 'Unnamed';
    return EntityItem(title: name, subtitle: '');
  }

  EntityItem _equipmentSetToEntityItem(Map<String, dynamic> data) {
    final name = (data['name'] as String?) ?? 'Unnamed';
    return EntityItem(title: name, subtitle: '');
  }

  EntityItem _mediaToEntityItem(Map<String, dynamic> data) {
    final filename = (data['filename'] as String?) ?? '';
    // The foreign path may use either separator, so basename it accordingly.
    final base = filename.isEmpty ? 'Unnamed' : foreignBasename(filename);
    return EntityItem(title: base, subtitle: filename);
  }

  EntityItem _courseToEntityItem(Map<String, dynamic> data) {
    final name = (data['name'] as String?) ?? 'Unnamed';
    final agency = data['agency'] as String?;
    return EntityItem(title: name, subtitle: agency ?? '');
  }

  // ---------------------------------------------------------------------------
  // Helpers — photo attachment
  // ---------------------------------------------------------------------------

  /// Attaches ZIP-bundled photos to newly created dives.
  ///
  /// Photos are keyed by their source file's basename; a file's photos are
  /// attached only when that file produced exactly one imported dive (the
  /// DiveCloud shape) so a multi-dive file never duplicates photos across
  /// its dives. Attach failures are swallowed: the dive import already
  /// succeeded and a failed photo copy must not fail the wizard.
  ///
  /// Returns the number of photos attached.
  static Future<int> attachImportedPhotos({
    required Map<String, List<String>> photoPathsByBaseName,
    required Map<int, String> diveIdByIndex,
    required Set<String> removedDiveIds,
    required List<Map<String, dynamic>> dives,
    required List<PickedImportFile> files,
    required String? singleFileName,
    required Future<void> Function(File file, String diveId, DateTime? takenAt)
    attach,
  }) async {
    if (photoPathsByBaseName.isEmpty || diveIdByIndex.isEmpty) return 0;

    String? baseNameForIndex(int index) {
      if (index < 0 || index >= dives.length) return null;
      final sourceId = dives[index]['_sourceFileId'] as String?;
      if (sourceId == null) {
        // Single-file flow: payloads carry no source stamp.
        return singleFileName == null
            ? null
            : p.basenameWithoutExtension(singleFileName);
      }
      final fileIndex = int.tryParse(sourceId.substring(1));
      if (fileIndex == null || fileIndex < 0 || fileIndex >= files.length) {
        return null;
      }
      return p.basenameWithoutExtension(files[fileIndex].name);
    }

    // Group surviving imported dives by their source file's base name.
    final divesByBase = <String, List<MapEntry<int, String>>>{};
    for (final entry in diveIdByIndex.entries) {
      if (removedDiveIds.contains(entry.value)) continue;
      final base = baseNameForIndex(entry.key);
      if (base == null) continue;
      (divesByBase[base] ??= []).add(entry);
    }

    var attachedCount = 0;
    for (final entry in divesByBase.entries) {
      final photos = photoPathsByBaseName[entry.key];
      // Photos only attach when the file produced exactly one dive.
      if (photos == null || entry.value.length != 1) continue;
      final diveIndex = entry.value.single.key;
      final diveId = entry.value.single.value;
      final takenAt = dives[diveIndex]['dateTime'] as DateTime?;
      for (final photoPath in photos) {
        try {
          await attach(File(photoPath), diveId, takenAt);
          attachedCount++;
        } catch (_) {
          // Best-effort: see doc comment.
        }
      }
    }
    return attachedCount;
  }

  /// Attaches resolved photos to the dives that survived import.
  ///
  /// Each payload media entry names its dive by `_diveIndex`, so unlike
  /// [attachImportedPhotos] this needs no one-dive-per-file rule: a
  /// multi-dive logbook attaches each photo to exactly the dive that
  /// referenced it.
  ///
  /// [selectedIndices] is the review step's selection for the media group;
  /// null means every resolved photo is attached.
  ///
  /// A copy failure is counted and skipped rather than thrown: the dive
  /// import has already succeeded and must not be undone by a photo. Unlike
  /// [attachImportedPhotos] the failure is not silent, because the caller
  /// reports the shortfall against the resolved count.
  ///
  /// Returns the number of photos actually attached.
  static Future<int> attachResolvedPhotos({
    required List<Map<String, dynamic>> media,
    required Map<int, String> resolvedPathByIndex,
    required Map<int, String> diveIdByIndex,
    required Set<String> removedDiveIds,
    required List<Map<String, dynamic>> dives,
    Set<int>? selectedIndices,
    required Future<void> Function(
      File file,
      String diveId,
      DateTime? takenAt,
      double? latitude,
      double? longitude,
    )
    attach,
  }) async {
    var attachedCount = 0;

    for (final entry in resolvedPathByIndex.entries) {
      final mediaIndex = entry.key;
      if (mediaIndex < 0 || mediaIndex >= media.length) continue;
      // Photos appear in review like any other entity, so a deselected one
      // must actually be left out rather than quietly imported anyway.
      if (selectedIndices != null && !selectedIndices.contains(mediaIndex)) {
        continue;
      }
      final picture = media[mediaIndex];

      final diveIndex = picture['_diveIndex'];
      if (diveIndex is! int) continue;
      final diveId = diveIdByIndex[diveIndex];
      if (diveId == null || removedDiveIds.contains(diveId)) continue;

      DateTime? takenAt;
      if (diveIndex >= 0 && diveIndex < dives.length) {
        final start = dives[diveIndex]['dateTime'] as DateTime?;
        final offsetSeconds = picture['offsetSeconds'];
        takenAt = start == null
            ? null
            : (offsetSeconds is int
                  ? start.add(Duration(seconds: offsetSeconds))
                  : start);
      }

      try {
        await attach(
          File(entry.value),
          diveId,
          takenAt,
          asDoubleOrNull(picture['latitude']),
          asDoubleOrNull(picture['longitude']),
        );
        attachedCount++;
      } catch (e) {
        _log.warning('Failed to attach imported photo ${entry.value}: $e');
      }
    }

    return attachedCount;
  }

  // ---------------------------------------------------------------------------
  // Helpers — duplicate application
  // ---------------------------------------------------------------------------

  void _applyDuplicateIndices(
    Map<wizard.ImportEntityType, EntityGroup> groups,
    wizard.ImportEntityType type,
    Set<int> duplicateIndices, {
    Map<int, DiveMatchResult>? matchResults,
    Map<int, EntityMatchResult>? entityMatches,
  }) {
    final group = groups[type];
    if (group == null || duplicateIndices.isEmpty) return;

    groups[type] = EntityGroup(
      items: group.items,
      duplicateIndices: duplicateIndices,
      matchResults: matchResults,
      entityMatches: entityMatches,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers — import
  // ---------------------------------------------------------------------------

  /// Build a map of import-list index → existing site ID for sites the user
  /// chose to overwrite ([DuplicateAction.replaceSource]).
  Map<int, String> _resolveSiteOverrides(
    Map<wizard.ImportEntityType, Map<int, DuplicateAction>> duplicateActions,
    ImportBundle bundle,
  ) {
    final actions = duplicateActions[wizard.ImportEntityType.sites] ?? const {};
    final entityMatches =
        bundle.groups[wizard.ImportEntityType.sites]?.entityMatches ?? const {};
    final overrides = <int, String>{};
    for (final entry in actions.entries) {
      if (entry.value == DuplicateAction.replaceSource) {
        final existingId = entityMatches[entry.key]?.existingId;
        if (existingId != null) {
          overrides[entry.key] = existingId;
        }
      }
    }
    return overrides;
  }

  /// Resolve the final selection set for [type] by merging the base
  /// selections with duplicate actions. Duplicate items whose action is
  /// [DuplicateAction.importAsNew] are added; items in the base set whose
  /// action is [DuplicateAction.skip] are removed.
  Set<int> _resolveSelections(
    wizard.ImportEntityType type,
    Map<wizard.ImportEntityType, Set<int>> selections,
    Map<wizard.ImportEntityType, Map<int, DuplicateAction>> duplicateActions,
  ) {
    final baseSelections = Set<int>.from(selections[type] ?? <int>{});
    final actions = duplicateActions[type] ?? {};
    final resolved = <int>{};

    for (final index in baseSelections) {
      final action = actions[index];
      if (action == DuplicateAction.skip) continue;
      // For non-dive entities consolidate means "link to the existing
      // record": nothing is imported. It has to be excluded here too, or a
      // duplicate that is ALSO in the base selection set gets imported as a
      // new row anyway -- the twin the action exists to avoid (#756).
      if (action == DuplicateAction.consolidate &&
          type != wizard.ImportEntityType.dives) {
        continue;
      }
      // Same trap for replaceSource: it means "overwrite the matched record
      // in place", which travels via UddfImportSelections.siteOverrides, not
      // the create path. ImportWizardNotifier.setDuplicateAction adds every
      // non-skip index to the base selection set, so without this guard the
      // site would be overwritten AND re-created as a twin from the same
      // payload.
      if (action == DuplicateAction.replaceSource &&
          type != wizard.ImportEntityType.dives) {
        continue;
      }
      resolved.add(index);
    }

    for (final entry in actions.entries) {
      // Consolidate-flagged DIVES are imported as standalone dives first
      // (like importAsNew); performImport folds them into their match
      // afterwards. For non-dive entities, consolidate means "link to the
      // existing record" (#756): nothing is imported, the association is
      // resolved through the pre-seeded id mappings instead.
      if (entry.value == DuplicateAction.importAsNew ||
          (type == wizard.ImportEntityType.dives &&
              entry.value == DuplicateAction.consolidate)) {
        resolved.add(entry.key);
      }
    }

    return resolved;
  }

  int _countSkipped(
    Map<wizard.ImportEntityType, Set<int>> selections,
    Map<wizard.ImportEntityType, Map<int, DuplicateAction>> duplicateActions,
  ) {
    final diveActions = duplicateActions[wizard.ImportEntityType.dives] ?? {};
    return diveActions.values.where((a) => a == DuplicateAction.skip).length;
  }

  Map<wizard.ImportEntityType, int> _convertImportCounts(
    UddfEntityImportResult result,
  ) {
    final counts = <wizard.ImportEntityType, int>{};
    if (result.dives > 0) counts[wizard.ImportEntityType.dives] = result.dives;
    if (result.sites > 0) counts[wizard.ImportEntityType.sites] = result.sites;
    if (result.buddies > 0) {
      counts[wizard.ImportEntityType.buddies] = result.buddies;
    }
    if (result.equipment > 0) {
      counts[wizard.ImportEntityType.equipment] = result.equipment;
    }
    if (result.trips > 0) counts[wizard.ImportEntityType.trips] = result.trips;
    if (result.certifications > 0) {
      counts[wizard.ImportEntityType.certifications] = result.certifications;
    }
    if (result.diveCenters > 0) {
      counts[wizard.ImportEntityType.diveCenters] = result.diveCenters;
    }
    if (result.tags > 0) counts[wizard.ImportEntityType.tags] = result.tags;
    if (result.diveTypes > 0) {
      counts[wizard.ImportEntityType.diveTypes] = result.diveTypes;
    }
    if (result.equipmentSets > 0) {
      counts[wizard.ImportEntityType.equipmentSets] = result.equipmentSets;
    }
    if (result.courses > 0) {
      counts[wizard.ImportEntityType.courses] = result.courses;
    }
    return counts;
  }

  static UddfImportResult _payloadToUddfResult(ImportPayload payload) {
    return UddfImportResult(
      dives: payload.entitiesOf(ui.ImportEntityType.dives),
      sites: payload.entitiesOf(ui.ImportEntityType.sites),
      trips: payload.entitiesOf(ui.ImportEntityType.trips),
      equipment: payload.entitiesOf(ui.ImportEntityType.equipment),
      buddies: payload.entitiesOf(ui.ImportEntityType.buddies),
      diveCenters: payload.entitiesOf(ui.ImportEntityType.diveCenters),
      certifications: payload.entitiesOf(ui.ImportEntityType.certifications),
      tags: payload.entitiesOf(ui.ImportEntityType.tags),
      customDiveTypes: payload.entitiesOf(ui.ImportEntityType.diveTypes),
      equipmentSets: payload.entitiesOf(ui.ImportEntityType.equipmentSets),
      courses: payload.entitiesOf(ui.ImportEntityType.courses),
      serviceRecords: payload.entitiesOf(ui.ImportEntityType.serviceRecords),
    );
  }
}
