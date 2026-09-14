import 'dart:io';

import 'package:flutter/material.dart';
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
import 'package:submersion/features/site_types/presentation/providers/site_type_providers.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
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
import 'package:submersion/features/import_wizard/data/adapters/batch_source_files.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_number_conflict_notice.dart';
import 'package:submersion/features/import_wizard/data/adapters/diver_slice_review.dart';
import 'package:submersion/features/import_wizard/data/adapters/existing_import_records.dart';
import 'package:submersion/features/import_wizard/domain/models/diver_import_outcome.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/universal_import/data/services/diver_slice_duplicates.dart';
import 'package:submersion/features/universal_import/data/services/payload_slicer.dart';
import 'package:submersion/features/import_wizard/data/adapters/import_notice_grouper.dart';
import 'package:submersion/features/import_wizard/data/adapters/import_photo_linker.dart';
import 'package:submersion/features/import_wizard/data/adapters/resolved_photo_attachment.dart';
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
import 'package:submersion/features/import_wizard/presentation/widgets/diver_mapping_step.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/photo_folder_step.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
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

/// Whether an archive actually bundled photos.
///
/// Keyed by source file basename, so a key alone does not mean a photo:
/// asking the map for keys rather than contents would put the Photos step
/// in front of the user, and demand a destination folder, for nothing.
bool _hasBundledPhotos(Map<String, List<String>> byBaseName) =>
    byBaseName.values.any((paths) => paths.isNotEmpty);

/// True when the import carries no photos at all: the parsed payload
/// references none and no imported archive bundled any.
///
/// Used as the Photos step's auto-advance condition, so the step is invisible
/// for every import that has nothing to ask about.
final universalAdapterNoPhotosProvider = Provider<bool>((ref) {
  final payload = ref.watch(
    universalImportNotifierProvider.select((s) => s.payload),
  );
  final bundled = ref.watch(
    universalImportNotifierProvider.select((s) => s.photoPathsByBaseName),
  );
  final referenced = payload?.entitiesOf(ui.ImportEntityType.media) ?? const [];
  return referenced.isEmpty && !_hasBundledPhotos(bundled);
});

/// True when the Photos step has nothing left to ask.
///
/// Deliberately looser than [universalAdapterNoPhotosProvider]: a user who
/// answered each question the import poses (a folder to resolve referenced
/// photos against, a folder to save bundled photos into) or chose to skip
/// may advance, but the step is never auto-advanced past a decision they
/// have not made.
final universalAdapterPhotosReadyProvider = Provider<bool>((ref) {
  if (ref.watch(universalAdapterNoPhotosProvider)) return true;
  final state = ref.watch(universalImportNotifierProvider);
  if (state.photosSkipped) return true;
  final referenced =
      state.payload?.entitiesOf(ui.ImportEntityType.media) ?? const [];
  final referencedReady = referenced.isEmpty || state.photoResolution != null;
  final bundledReady =
      !_hasBundledPhotos(state.photoPathsByBaseName) ||
      state.bundledPhotoFolderPath != null;
  return referencedReady && bundledReady;
});

/// True once a payload exists that needed no column mapping (every format
/// but CSV), so the Map Fields step played no part in this import and the
/// step indicator leaves it out (issue #1893).
final universalAdapterNoFieldMappingProvider = Provider<bool>((ref) {
  final state = ref.watch(universalImportNotifierProvider);
  return state.payload != null && !state.needsFieldMapping;
});

/// True when the parsed payload has at most one diver, so the Divers step
/// has nothing to ask and skips itself (issue #1893).
final universalAdapterSingleDiverProvider = Provider<bool>((ref) {
  final parsed = ref.watch(
    universalImportNotifierProvider.select((s) => s.parsedPayload),
  );
  return !(parsed?.needsDiverMapping ?? false);
});

/// True once every row of the Divers step has a choice and at least one of
/// them imports somewhere.
final universalAdapterDiverMappingReadyProvider = Provider<bool>((ref) {
  final state = ref.watch(universalImportNotifierProvider);
  final parsed = state.parsedPayload;
  if (parsed == null || !parsed.needsDiverMapping) return true;
  final rows = orderedDiverRows(parsed.sourceDivers);
  final mapping = state.diverMapping;
  return rows.every((row) => mapping.containsKey(row.key)) &&
      rows.any((row) => mapping[row.key] is! SkipDiverTarget);
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
      hiddenWhen: universalAdapterNoFieldMappingProvider,
      onBeforeAdvance: () async {
        final notifier = _ref.read(universalImportNotifierProvider.notifier);
        await notifier.confirmFieldMapping();
        await _seedDiverMapping();
      },
    ),
    WizardStepDef(
      label: 'Divers',
      icon: Icons.people_outline,
      builder: (context) => const DiverMappingStep(),
      canAdvance: universalAdapterDiverMappingReadyProvider,
      // Only a logbook with two or more divers has anything to ask.
      canAutoAdvance: universalAdapterSingleDiverProvider,
      autoAdvance: true,
      hiddenWhen: universalAdapterSingleDiverProvider,
      onBeforeAdvance: () async {
        final activeDiverId = await _ref.read(
          validatedCurrentDiverIdProvider.future,
        );
        if (activeDiverId == null) return;
        _ref
            .read(universalImportNotifierProvider.notifier)
            .applyDiverMapping(activeDiverId: activeDiverId);
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
      hiddenWhen: universalAdapterNoPhotosProvider,
    ),
  ];

  /// Seeds the Divers step's defaults (issue #1893). Runs as Map Fields is
  /// left, which the wizard does even when it auto-skips that step, after
  /// choosing the next page and before rendering it.
  Future<void> _seedDiverMapping() async {
    final parsed = _ref.read(universalImportNotifierProvider).parsedPayload;
    if (parsed == null || !parsed.needsDiverMapping) return;
    final activeDiverId = await _ref.read(
      validatedCurrentDiverIdProvider.future,
    );
    if (activeDiverId == null) return;
    final profiles = await _ref.read(allDiversProvider.future);
    _ref
        .read(universalImportNotifierProvider.notifier)
        .initDiverMapping(profiles: profiles, activeDiverId: activeDiverId);
  }

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

    final targets = await _importTargets(payload);
    return ImportBundle(
      source: ImportSourceInfo(
        type: ImportSourceType.universal,
        displayName: _displayName,
      ),
      // One profile needs no labels; the counts already say where it goes.
      groups: targets.length > 1
          ? _labelTargets(groups, payload, targets)
          : groups,
      nextDiveNumberByTarget: await _nextDiveNumbers(targets.keys),
    );
  }

  /// The profile behind each target key of an expanded payload (#1893).
  /// Empty for a payload that was never split across profiles.
  Future<Map<String, ImportTarget>> _importTargets(
    ImportPayload payload,
  ) async {
    final keys = <String>{
      for (final items in payload.entities.values)
        for (final item in items)
          if (item[DiverTarget.itemKey] case final String key) key,
    };
    if (keys.isEmpty) return const {};
    final profiles = await _ref.read(allDiversProvider.future);
    final nameById = {for (final p in profiles) p.id: p.name};
    final nameBySource = {for (final d in payload.sourceDivers) d.key: d.name};
    return {
      for (final key in keys)
        key: switch (DiverTarget.diverIdOf(key)) {
          final String id => ImportTarget(
            key: key,
            name: nameById[id] ?? id,
            isNew: false,
          ),
          null => ImportTarget(
            key: key,
            name: nameBySource[DiverTarget.newSourceKeyOf(key)] ?? '',
            isNew: true,
          ),
        },
    };
  }

  /// [groups] with each item labelled with its target. Groups are built one
  /// to one from the payload's lists, so index i is payload item i.
  Map<wizard.ImportEntityType, EntityGroup> _labelTargets(
    Map<wizard.ImportEntityType, EntityGroup> groups,
    ImportPayload payload,
    Map<String, ImportTarget> targets,
  ) {
    return {
      for (final MapEntry(key: type, value: group) in groups.entries)
        type: EntityGroup(
          items: [
            for (final (i, item) in group.items.indexed)
              switch (payload.entitiesOf(
                ui.ImportEntityType.values.byName(type.name),
              )[i][DiverTarget.itemKey]) {
                final String key when targets.containsKey(key) => item.copyWith(
                  target: targets[key],
                ),
                _ => item,
              },
          ],
          duplicateIndices: group.duplicateIndices,
          matchResults: group.matchResults,
          entityMatches: group.entityMatches,
          autoSkipIndices: group.autoSkipIndices,
        ),
    };
  }

  /// Each target's next dive number: a new profile starts at 1.
  Future<Map<String, int>> _nextDiveNumbers(Iterable<String> targetKeys) async {
    final dives = _ref.read(diveRepositoryProvider);
    return {
      for (final key in targetKeys)
        key: switch (DiverTarget.diverIdOf(key)) {
          final String id => await dives.getNextDiveNumber(diverId: id),
          null => 1,
        },
    };
  }

  /// The records a slice's items are checked against: the active profile
  /// through its providers as always, another profile through the
  /// repositories, a profile the import creates against nothing (#1893).
  Future<ExistingImportRecords> _existingRecordsFor(
    String? targetKey,
    String? activeDiverId,
  ) {
    if (targetKey == null) return loadActiveDiverRecords(_ref, activeDiverId);
    final diverId = DiverTarget.diverIdOf(targetKey);
    if (diverId == null) return loadNewProfileRecords(_ref);
    if (diverId == activeDiverId) {
      return loadActiveDiverRecords(_ref, activeDiverId);
    }
    return loadProfileRecords(_ref, diverId);
  }

  @override
  Future<ImportBundle> checkDuplicates(ImportBundle bundle) async {
    final notifierState = _ref.read(universalImportNotifierProvider);
    final payload = notifierState.payload;
    if (payload == null) return bundle;

    // Scope duplicate detection to each target profile's own data (#1893).
    // An unexpanded payload is one slice checked against the active diver,
    // exactly as before.
    final currentDiver = await _ref.read(currentDiverProvider.future);
    final activeDiverId = currentDiver?.id;
    final checkIntraBatch =
        (payload.metadata['batchFileCount'] as int? ?? 1) > 1;
    final units = UnitFormatter(_ref.read(settingsProvider));
    final slices = PayloadSlicer.slice(
      payload,
      firstTargetKey: activeDiverId == null
          ? null
          : ExistingDiverTarget(activeDiverId).targetKey,
    );
    final dupResult = mergeDuplicateResults([
      for (final slice in slices)
        duplicatesToGlobal(
          slice,
          (await _existingRecordsFor(slice.targetKey, activeDiverId)).check(
            slice.payload,
            checkIntraBatch: checkIntraBatch,
            units: units,
          ),
        ),
    ]);

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

    return ImportBundle(
      source: bundle.source,
      groups: updatedGroups,
      nextDiveNumberByTarget: bundle.nextDiveNumberByTarget,
    );
  }

  /// One importer run: [payload] with the review state that indexes it,
  /// written to [diverId]. A single-diver import runs this once for the
  /// whole payload; a multi-diver import once per profile (issue #1893).
  Future<UddfEntityImportResult> _runImporter({
    required UddfEntityImporter importer,
    required ImportRepositories repos,
    required ImportPayload payload,
    required ImportBundle bundle,
    required Map<wizard.ImportEntityType, Set<int>> selections,
    required Map<wizard.ImportEntityType, Map<int, DuplicateAction>>
    duplicateActions,
    required String diverId,
    required bool retainSourceDiveNumbers,
    ImportProgressCallback? onProgress,
    ImportCancellationToken? cancelToken,
  }) {
    final notifierState = _ref.read(universalImportNotifierProvider);

    // Resolve selections for all entity types: include duplicate items
    // whose action is importAsNew (not just the base selection set).
    Set<int> resolve(wizard.ImportEntityType type) =>
        _resolveSelections(type, selections, duplicateActions);

    final uddfData = payloadToUddfResult(payload);

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
        // the entity IS imported: _importBuddies/_importTags/_importEquipment
        // overwrite the mapping with the newly created id.
        final links =
            action == null ||
            action == DuplicateAction.skip ||
            action == DuplicateAction.consolidate;
        if (!links) continue;
        if (entry.key < 0 || entry.key >= items.length) continue;
        final item = items[entry.key];
        // A dive references its types by id (the slug), not by uddfId or
        // name, and a UDDF type record carries no uddfId at all (#1834).
        final ref = type == wizard.ImportEntityType.diveTypes
            ? (item['id'] as String?) ?? (item['uddfId'] as String?)
            : (item['uddfId'] as String?) ?? (item['name'] as String?);
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

    return importer.import(
      data: uddfData,
      selections: uddfSelections,
      repositories: repos,
      diverId: diverId,
      retainSourceDiveNumbers: retainSourceDiveNumbers,
      // The confirmed options, not the raw auto-detection: Source
      // Confirmation lets the diver override a wrong guess, the parse
      // already ran on the override, and a resync later picks its parser
      // from whatever is persisted here.
      sourceFormat:
          notifierState.options?.format ??
          notifierState.detectionResult?.format,
      sourceFileBytes: notifierState.fileBytes,
      sourceFileName: notifierState.fileName,
      sourceFilesById: batchSourceFiles(notifierState.files),
      preResolvedBuddyIds: preResolvedIdsFor(
        wizard.ImportEntityType.buddies,
        uddfData.buddies,
      ),
      preResolvedTagIds: preResolvedIdsFor(
        wizard.ImportEntityType.tags,
        uddfData.tags,
      ),
      preResolvedEquipmentIds: preResolvedIdsFor(
        wizard.ImportEntityType.equipment,
        uddfData.equipment,
      ),
      preResolvedDiveTypeIds: preResolvedIdsFor(
        wizard.ImportEntityType.diveTypes,
        uddfData.customDiveTypes,
      ),
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  Future<UddfEntityImporter> _buildImporter() async {
    final settings = _ref.read(settingsProvider);
    final resolver = DefaultTankPresetResolver(
      repository: _ref.read(tankPresetRepositoryProvider),
    );
    final defaultTankPreset = await resolver.resolve(
      settings.defaultTankPreset,
    );
    return UddfEntityImporter(
      defaultTankPreset: defaultTankPreset,
      defaultStartPressure: settings.defaultStartPressure,
      applyDefaultTankToImports: settings.applyDefaultTankToImports,
      placeNameLanguage: settings.placeNameLanguage,
    );
  }

  /// Imports each slice into its profile, creating new profiles just before
  /// their own slice, so a failure never leaves an empty profile behind. A
  /// slice with nothing selected is skipped and creates nothing. A failure
  /// in the first imported slice fails the import as before; a later one
  /// stops the loop and is reported next to what already landed.
  Future<
    ({
      UddfEntityImportResult result,
      List<DiverImportOutcome> outcomes,
      String? error,
      Set<int> unreachedDives,
    })
  >
  _importSlices({
    required List<DiverSlice> slices,
    required UddfEntityImporter importer,
    required ImportRepositories repos,
    required ImportPayload payload,
    required ImportBundle bundle,
    required Map<wizard.ImportEntityType, Set<int>> selections,
    required Map<wizard.ImportEntityType, Map<int, DuplicateAction>>
    duplicateActions,
    required String activeDiverId,
    required bool retainSourceDiveNumbers,
    ImportProgressCallback? onProgress,
    ImportCancellationToken? cancelToken,
  }) async {
    final profiles = await _ref.read(allDiversProvider.future);
    final nameById = {for (final p in profiles) p.id: p.name};
    var total = const UddfEntityImportResult();
    final outcomes = <DiverImportOutcome>[];
    // The dives of slice [from] and every slice after it: what a stop at
    // that slice leaves unimported.
    Set<int> diveIndicesFrom(int from) => {
      for (final s in slices.skip(from))
        ...?s.globalIndices[ui.ImportEntityType.dives],
    };

    for (final (index, slice) in slices.indexed) {
      if (cancelToken?.isCancelled ?? false) {
        return (
          result: total,
          outcomes: outcomes,
          error: null,
          unreachedDives: diveIndicesFrom(index),
        );
      }
      final review = DiverSliceReview.of(
        slice,
        bundle,
        selections,
        duplicateActions,
      );
      if (!_importsAnything(review)) continue;

      final targetKey = slice.targetKey!;
      final newSourceKey = DiverTarget.newSourceKeyOf(targetKey);
      var name = newSourceKey ?? '';
      try {
        final String diverId;
        if (newSourceKey != null) {
          final source = payload.sourceDivers
              .where((d) => d.key == newSourceKey)
              .firstOrNull;
          if (source == null) {
            throw StateError('No source diver $newSourceKey');
          }
          name = source.name;
          diverId = await _createProfile(source);
        } else {
          diverId = DiverTarget.diverIdOf(targetKey)!;
          name = nameById[diverId] ?? diverId;
        }

        final sliceResult = await _runImporter(
          importer: importer,
          repos: repos,
          payload: slice.payload,
          bundle: review.bundle,
          selections: review.selections,
          duplicateActions: review.duplicateActions,
          diverId: diverId,
          retainSourceDiveNumbers: retainSourceDiveNumbers,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
        total = addSliceResult(total, slice, sliceResult);
        outcomes.add(
          DiverImportOutcome(
            diverId: diverId,
            name: name,
            isNew: newSourceKey != null,
            isActive: diverId == activeDiverId,
            diveIds: sliceResult.diveIds,
          ),
        );
      } catch (e, stackTrace) {
        if (outcomes.isEmpty) rethrow;
        _log.error(
          'Import stopped before profile $name',
          error: e,
          stackTrace: stackTrace,
        );
        return (
          result: total,
          outcomes: outcomes,
          error:
              'Imported ${outcomes.map((o) => o.name).join(', ')}, '
              'then stopped before $name: $e',
          unreachedDives: diveIndicesFrom(index),
        );
      }
    }
    return (
      result: total,
      outcomes: outcomes,
      error: null,
      unreachedDives: const <int>{},
    );
  }

  /// Whether a slice's review imports anything at all.
  bool _importsAnything(DiverSliceReview review) =>
      wizard.ImportEntityType.values.any(
        (type) => _resolveSelections(
          type,
          review.selections,
          review.duplicateActions,
        ).isNotEmpty,
      ) ||
      _resolveSiteOverrides(review.duplicateActions, review.bundle).isNotEmpty;

  /// Creates the profile a new-profile target asked for, seeded from what
  /// the source logbook knows about the diver.
  Future<String> _createProfile(SourceDiver source) async {
    final now = DateTime.now();
    final created = await _ref
        .read(diverRepositoryProvider)
        .createDiver(
          Diver(
            id: '',
            name: source.name,
            email: source.email,
            phone: source.phone,
            emergencyContact: EmergencyContact(name: source.emergencyContact),
            bloodType: source.bloodType,
            insurance: source.danNumber == null
                ? const DiverInsurance()
                : DiverInsurance(
                    provider: 'DAN',
                    policyNumber: source.danNumber,
                  ),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return created.id;
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
    final repos = universalImportRepositories(_ref);
    final importer = await _buildImporter();

    // Every profile this import writes to, the active one first (#1893). A
    // payload the Divers step never split is one untargeted slice, imported
    // into the active diver exactly as before.
    final slices = PayloadSlicer.slice(
      payload,
      firstTargetKey: ExistingDiverTarget(currentDiver.id).targetKey,
    );
    final UddfEntityImportResult result;
    var outcomes = const <DiverImportOutcome>[];
    String? stoppedEarly;
    var unreachedDives = const <int>{};
    if (slices.length == 1 && slices.single.targetKey == null) {
      result = await _runImporter(
        importer: importer,
        repos: repos,
        payload: payload,
        bundle: bundle,
        selections: selections,
        duplicateActions: duplicateActions,
        diverId: currentDiver.id,
        retainSourceDiveNumbers: retainSourceDiveNumbers,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } else {
      final run = await _importSlices(
        slices: slices,
        importer: importer,
        repos: repos,
        payload: payload,
        bundle: bundle,
        selections: selections,
        duplicateActions: duplicateActions,
        activeDiverId: currentDiver.id,
        retainSourceDiveNumbers: retainSourceDiveNumbers,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      result = run.result;
      outcomes = run.outcomes;
      stoppedEarly = run.error;
      unreachedDives = run.unreachedDives;
    }

    // Fold consolidate-flagged dives (imported as standalone above) into their
    // matched existing dive. These indices come only from an explicit user
    // choice in the review step, and each has a match result (the UI offers
    // Consolidate only on matches).
    final reached = reachedDiveReview(
      actions: duplicateActions[wizard.ImportEntityType.dives] ?? const {},
      matches:
          bundle.groups[wizard.ImportEntityType.dives]?.matchResults ??
          const {},
      unreached: unreachedDives,
    );
    final diveActions = reached.actions;
    final consolidateIndices = <int>{
      for (final entry in diveActions.entries)
        if (entry.value == DuplicateAction.consolidate) entry.key,
    };

    var consolidated = 0;
    var removedDiveIds = const <String>{};
    if (consolidateIndices.isNotEmpty) {
      final summary = await performConsolidations(
        indices: consolidateIndices,
        diveIdByIndex: result.diveIdByIndex,
        duplicateResult: ImportDuplicateResult(diveMatches: reached.matches),
        consolidationService: _ref.read(diveConsolidationServiceProvider),
        diveRepository: repos.diveRepository,
      );
      consolidated = summary.consolidated;
      removedDiveIds = summary.removedDiveIds;
    }

    // Attach ZIP-bundled photos to the dives that survived import (skipping
    // any that were folded away by consolidation). The extracted copies live
    // in a temp folder the wizard deletes, so each is first written into the
    // folder the user chose in the Photos step and then linked from there;
    // no destination means the user skipped them. Nothing is ever filed
    // inside the app's own storage.
    // Both attach paths aim at the same dives: whichever dive each source
    // index actually ended up on, including the existing dive behind a
    // skipped or consolidated duplicate.
    final photoDiveIds = photoTargetDiveIds(
      diveIdByIndex: result.diveIdByIndex,
      matchResults: reached.matches,
      duplicateActions: diveActions,
    );

    // A target that is not the dive this import created is an existing
    // dive behind a skipped or consolidated duplicate. Its own start is
    // what a photo with no capture time of its own should fall back to,
    // and it can sit up to the duplicate matcher's window away from the
    // start the discarded duplicate recorded.
    final diveStartById = <String, DateTime>{};
    for (final entry in photoDiveIds.entries) {
      final targetId = entry.value;
      if (result.diveIdByIndex[entry.key] == targetId) continue;
      try {
        final existing = await repos.diveRepository.getDiveById(targetId);
        if (existing != null) diveStartById[targetId] = existing.dateTime;
      } catch (e) {
        // A lookup failure only costs the photo a better fallback.
        _log.warning('Could not read dive $targetId for a photo time: $e');
      }
    }

    final bundledFolder = notifierState.bundledPhotoFolderPath;
    var attachedPhotos = 0;
    if (bundledFolder != null &&
        _hasBundledPhotos(notifierState.photoPathsByBaseName)) {
      final linker = ImportPhotoLinker(_ref.read(localFileLinkServiceProvider));
      final attached = await attachImportedPhotos(
        photoPathsByBaseName: notifierState.photoPathsByBaseName,
        diveIdByIndex: photoDiveIds,
        removedDiveIds: removedDiveIds,
        dives: payload.entitiesOf(ui.ImportEntityType.dives),
        diveStartById: diveStartById,
        files: notifierState.files,
        singleFileName: notifierState.fileName,
        attach: (file, diveId, diveStart) => linker.linkBundled(
          file: file,
          diveId: diveId,
          diveStart: diveStart,
          destinationDir: bundledFolder,
        ),
      );
      attachedPhotos = attached - linker.alreadyLinked;
    }

    // Attach photos the logbook referenced by absolute path, resolved against
    // the folder picked in the Photos step. This and the ZIP path above cover
    // different sources and cannot double-count: a ZIP sidecar and a
    // <picture> reference never describe the same file.
    //
    // These are linked in place, never copied: the user keeps the photos
    // wherever they already are, and the row stores the same handle the
    // Files tab would. A dive the user skipped as a duplicate still gets
    // its photos, on the existing dive it matched, so re-importing a
    // logbook is the way to add its photos to dives imported earlier.
    final resolution = notifierState.photoResolution;
    var resolvedPhotos = 0;
    if (resolution != null) {
      final linker = ImportPhotoLinker(_ref.read(localFileLinkServiceProvider));
      final attached = await attachResolvedPhotos(
        media: payload.entitiesOf(ui.ImportEntityType.media),
        resolvedPathByIndex: resolution.resolvedPathByIndex,
        diveIdByIndex: photoDiveIds,
        removedDiveIds: removedDiveIds,
        dives: payload.entitiesOf(ui.ImportEntityType.dives),
        diveStartById: diveStartById,
        selectedIndices: selections[wizard.ImportEntityType.media],
        attach: linker.linkResolved,
      );
      // Already-linked photos are successful no-ops to the attach loop;
      // keep them out of the summary's attached count.
      resolvedPhotos = attached - linker.alreadyLinked;
    }

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
    scheduleSensorSummaryRefresh(netImportedDiveIds);
    // Check-ins ride inside imported equipment, with or without new dives;
    // merged into the batch above when there is one, so no extra pass.
    scheduleAllConditionFindingsRefresh();

    final numberConflict = await diveNumberConflictNotice(
      retainSourceDiveNumbers: retainSourceDiveNumbers,
      diveRepository: repos.diveRepository,
      importedDiveIds: netImportedDiveIds,
    );
    final notices = [
      ...groupImportNotices(payload.warnings, netDives),
      ?numberConflict,
    ];

    final diverOutcomes = [
      for (final outcome in outcomes) outcome.withoutDives(removedDiveIds),
    ];
    return UnifiedImportResult(
      notices: notices,
      importedCounts: counts,
      consolidatedCount: consolidated,
      skippedCount: skipped + cleanedUpFailures,
      // "View Dives", the quality count and site matching all work in the
      // active profile, so they get only its dives; every profile's dives
      // are in diverOutcomes.
      importedDiveIds: diverOutcomes.isEmpty
          ? netImportedDiveIds
          : [
              for (final outcome in diverOutcomes)
                if (outcome.isActive) ...outcome.diveIds,
            ],
      fileOutcomes: fileOutcomes,
      attachedPhotoCount: attachedPhotos + resolvedPhotos,
      unmatchedPhotoCount:
          notifierState.unmatchedPhotoCount + (resolution?.notFoundCount ?? 0),
      diverOutcomes: diverOutcomes,
      errorMessage: stoppedEarly,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers — entity item conversion
  // ---------------------------------------------------------------------------

  /// Formatter for the review list's dates and times, built from the active
  /// diver's unit settings so the wizard matches the rest of the app.
  UnitFormatter get _units => UnitFormatter(_ref.read(settingsProvider));

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

    final units = _units;

    String title;
    if (dateTime != null) {
      final dateStr = units.formatDate(dateTime);
      final timeStr = units.formatTime(dateTime);
      title = '$dateStr \u2014 $timeStr';
    } else {
      title = 'Unknown date';
    }

    final parts = <String>[];
    if (siteName != null && siteName.isNotEmpty) parts.add(siteName);
    if (maxDepth != null) {
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

    final units = _units;
    String subtitle;
    if (startDate != null && endDate != null) {
      subtitle =
          '${units.formatDate(startDate)} - '
          '${units.formatDate(endDate)}';
    } else if (startDate != null) {
      subtitle = units.formatDate(startDate);
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

  /// Attaches ZIP-bundled photos to the dives their source file produced.
  ///
  /// [diveIdByIndex] is a target map, not strictly a map of newly created
  /// dives: a duplicate the user skipped or consolidated resolves to the
  /// existing dive it matched (see [photoTargetDiveIds]), so a bundled
  /// photo can land on a dive that was already in the log.
  ///
  /// Photos are keyed by their source file's basename; a file's photos are
  /// attached only when that file produced exactly one dive (the DiveCloud
  /// shape) so a multi-dive file never duplicates photos across its dives.
  /// Attach failures are logged and skipped, never thrown: the dive import
  /// already succeeded and a failed photo must not fail the wizard.
  ///
  /// Returns the number of photos attached.
  static Future<int> attachImportedPhotos({
    required Map<String, List<String>> photoPathsByBaseName,
    required Map<int, String> diveIdByIndex,
    required Set<String> removedDiveIds,
    required List<Map<String, dynamic>> dives,
    Map<String, DateTime> diveStartById = const {},
    required List<PickedImportFile> files,
    required String? singleFileName,
    required Future<void> Function(
      File file,
      String diveId,
      DateTime? diveStart,
    )
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
      // The dive's own start, which is a fallback for the photo's capture
      // time and not a capture time itself: an archive carries no offset.
      // A photo routed to an existing dive takes that dive's start, not the
      // start recorded by the duplicate the user chose not to keep.
      final diveStart =
          diveStartById[diveId] ?? dives[diveIndex]['dateTime'] as DateTime?;
      for (final photoPath in photos) {
        try {
          await attach(File(photoPath), diveId, diveStart);
          attachedCount++;
        } catch (e) {
          // Best-effort: see doc comment. Logged, because this path now
          // writes into a folder the user chose, and a photo that never
          // arrived there should be diagnosable.
          _log.warning('Failed to attach bundled photo $photoPath: $e');
        }
      }
    }
    return attachedCount;
  }

  /// Attaches resolved photos to the dives that survived import.
  ///
  static String? _captionOf(Map<String, dynamic> picture) {
    final caption = (picture['caption'] as String?)?.trim();
    return caption == null || caption.isEmpty ? null : caption;
  }

  /// The dive each payload index's photos should land on.
  ///
  /// Imported dives map to the id the importer created. Both duplicate
  /// outcomes that do not leave a standalone dive behind map to the
  /// existing dive instead, so their photos are never silently lost: a
  /// skipped duplicate imports nothing at all, and a consolidated one is
  /// folded into the match and then removed. The linker's path dedupe
  /// keeps a repeat import from doubling any of them up.
  @visibleForTesting
  /// The dive review decisions and duplicate matches of the profiles an
  /// import actually reached (issue #1893). When a later profile's slice
  /// fails or the user cancels, its dives were never imported; left in, a
  /// skipped or consolidated duplicate there would still send its photos to
  /// the existing dive it matched.
  @visibleForTesting
  static ({
    Map<int, DuplicateAction> actions,
    Map<int, DiveMatchResult> matches,
  })
  reachedDiveReview({
    required Map<int, DuplicateAction> actions,
    required Map<int, DiveMatchResult> matches,
    required Set<int> unreached,
  }) {
    return (
      actions: {
        for (final entry in actions.entries)
          if (!unreached.contains(entry.key)) entry.key: entry.value,
      },
      matches: {
        for (final entry in matches.entries)
          if (!unreached.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  static Map<int, String> photoTargetDiveIds({
    required Map<int, String> diveIdByIndex,
    required Map<int, DiveMatchResult> matchResults,
    required Map<int, DuplicateAction> duplicateActions,
  }) {
    final targets = Map<int, String>.of(diveIdByIndex);
    for (final entry in matchResults.entries) {
      final action = duplicateActions[entry.key];
      if (action == DuplicateAction.consolidate) {
        // The imported dive is about to be folded into the match and put
        // in removedDiveIds, so its photos have to follow the fold.
        targets[entry.key] = entry.value.diveId;
      } else if (action == null || action == DuplicateAction.skip) {
        // Skip imports no dive, so without this the photos have nowhere to
        // land. An undecided duplicate is not reachable today (the wizard
        // gates advancement on pending decisions), but dropping photos
        // silently is the exact defect this exists to prevent.
        targets.putIfAbsent(entry.key, () => entry.value.diveId);
      }
    }
    return targets;
  }

  /// Each payload media entry names its dive by `_diveIndex`, so unlike
  /// [attachImportedPhotos] this needs no one-dive-per-file rule: a
  /// multi-dive logbook attaches each photo to exactly the dive that
  /// referenced it.
  ///
  /// [selectedIndices] is the review step's selection for the media group;
  /// null means every resolved photo is attached.
  ///
  /// A link failure is counted and skipped rather than thrown: the dive
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
    Map<String, DateTime> diveStartById = const {},
    Set<int>? selectedIndices,
    required Future<void> Function(ResolvedPhotoAttachment photo) attach,
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

      // Only a source-recorded offset makes an asserted capture time; a
      // source with none leaves takenAt null so the linker may prefer the
      // file's own EXIF time over the dive start.
      DateTime? diveStart;
      DateTime? takenAt;
      if (diveIndex >= 0 && diveIndex < dives.length) {
        // The source's own recorded start drives the offset, because the
        // offset was recorded against it. The fallback capture time, on the
        // other hand, describes the dive the photo actually lands on.
        final sourceStart = dives[diveIndex]['dateTime'] as DateTime?;
        diveStart = diveStartById[diveId] ?? sourceStart;
        final offsetSeconds = picture['offsetSeconds'];
        if (sourceStart != null && offsetSeconds is int) {
          takenAt = sourceStart.add(Duration(seconds: offsetSeconds));
        }
      }

      try {
        await attach(
          ResolvedPhotoAttachment(
            file: File(entry.value),
            diveId: diveId,
            takenAt: takenAt,
            diveStart: diveStart,
            latitude: asDoubleOrNull(picture['latitude']),
            longitude: asDoubleOrNull(picture['longitude']),
            caption: _captionOf(picture),
          ),
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

  /// The entity importer's input for [payload]. Exposed so round-trip
  /// tests import exactly what the wizard would.
  @visibleForTesting
  static UddfImportResult payloadToUddfResult(ImportPayload payload) {
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
      customDiveRoles: [
        for (final role
            in (payload.metadata[ImportPayload.customDiveRolesKey] as List?) ??
                const [])
          if (role is Map<String, dynamic>) role,
      ],
      // Issue #1765: carried as metadata for the same reason as the roles.
      customSiteTypes: [
        for (final type
            in (payload.metadata[ImportPayload.customSiteTypesKey] as List?) ??
                const [])
          if (type is Map<String, dynamic>) type,
      ],
    );
  }
}

/// The repositories a UDDF import writes through. Every optional one is
/// supplied here: the importer skips the entities a missing one owns, so
/// leaving one out drops that data from real imports without a word.
ImportRepositories universalImportRepositories(WidgetRef ref) {
  return ImportRepositories(
    tripRepository: ref.read(tripRepositoryProvider),
    equipmentRepository: ref.read(equipmentRepositoryProvider),
    equipmentSetRepository: ref.read(equipmentSetRepositoryProvider),
    buddyRepository: ref.read(buddyRepositoryProvider),
    diveCenterRepository: ref.read(diveCenterRepositoryProvider),
    certificationRepository: ref.read(certificationRepositoryProvider),
    tagRepository: ref.read(tagRepositoryProvider),
    diveTypeRepository: ref.read(diveTypeRepositoryProvider),
    diveRoleRepository: ref.read(diveRoleRepositoryProvider),
    siteRepository: ref.read(siteRepositoryProvider),
    diveRepository: ref.read(diveRepositoryProvider),
    tankPressureRepository: ref.read(tankPressureRepositoryProvider),
    courseRepository: ref.read(courseRepositoryProvider),
    serviceRecordRepository: ref.read(serviceRecordRepositoryProvider),
    diveComputerRepository: ref.read(diveComputerRepositoryProvider),
    // Without it every check-in in the file is skipped (condition phase
    // 3a); the field is optional only for legacy callers.
    equipmentObservationRepository: ref.read(
      equipmentObservationRepositoryProvider,
    ),
    // Site types and site tags (issue #1765); without them an import
    // restores sites but not their classification.
    siteTypeRepository: ref.read(siteTypeRepositoryProvider),
    siteClassificationRepository: ref.read(
      siteClassificationRepositoryProvider,
    ),
  );
}
