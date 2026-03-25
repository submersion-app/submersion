import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
// Import wizard bundle types: hide ImportEntityType to avoid name clash with
// universal_import's same-named enum. Access it via the ImportSourceAdapter
// interface which already uses the wizard's ImportEntityType.
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart'
    hide ImportEntityType;
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart'
    as wizard
    show ImportEntityType;
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tank_presets/domain/services/default_tank_preset_resolver.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart'
    as ui;
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/features/universal_import/presentation/widgets/field_mapping_step.dart';
import 'package:submersion/features/universal_import/presentation/widgets/file_selection_step.dart';
import 'package:submersion/features/universal_import/presentation/widgets/source_confirmation_step.dart';

// =============================================================================
// canAdvance providers
// =============================================================================

/// Signals whether the "Select File" acquisition step may advance.
///
/// True once the notifier has a successful detection result and has moved
/// past [ImportWizardStep.fileSelection].
final universalAdapterFileSelectedProvider = Provider<bool>((ref) {
  final state = ref.watch(universalImportNotifierProvider);
  return state.detectionResult != null &&
      state.currentStep != ImportWizardStep.fileSelection;
});

/// Signals whether the "Confirm Source" step is ready to advance.
///
/// True once detection has completed and the format is supported. The user
/// does not need to have pressed "Confirm" yet — the wizard's Next button
/// and [onBeforeAdvance] handle committing the choice.
final universalAdapterSourceReadyProvider = Provider<bool>((ref) {
  final state = ref.watch(universalImportNotifierProvider);
  final detection = state.detectionResult;
  return detection != null && detection.isFormatSupported;
});

/// Signals whether the "Map Fields" step is ready to advance.
///
/// For non-CSV formats the payload is produced immediately after source
/// confirmation, so the step auto-advances. For CSV, it is ready once the
/// user has mapped at least one column (the mapping is saved to the notifier
/// on every change).
final universalAdapterMappingReadyProvider = Provider<bool>((ref) {
  final state = ref.watch(universalImportNotifierProvider);
  // Non-CSV: payload was already produced — ready immediately.
  if (state.payload != null) return true;
  // CSV: ready when the user has configured at least one column mapping.
  final mapping = state.fieldMapping;
  return mapping != null && mapping.columns.isNotEmpty;
});

// =============================================================================
// UniversalAdapter
// =============================================================================

/// Import source adapter for universal file imports (CSV, Subsurface XML,
/// UDDF, auto-detected formats).
///
/// Wraps the existing [UniversalImportNotifier] state management into the
/// unified import wizard framework. The three acquisition steps embed the
/// existing [FileSelectionStep], [SourceConfirmationStep], and
/// [FieldMappingStep] widgets directly so their mature UI is fully reused.
///
/// For the "Map Fields" step the wizard auto-advances for non-CSV formats
/// because the notifier skips that step automatically after source
/// confirmation.
class UniversalAdapter implements ImportSourceAdapter {
  UniversalAdapter({
    required WidgetRef ref,
    String displayName = 'Universal Import',
  }) : _ref = ref,
       _displayName = displayName {
    // Reset state from any previous import session.
    // Deferred to avoid modifying provider state during widget build.
    Future.microtask(
      () => ref.read(universalImportNotifierProvider.notifier).reset(),
    );
  }

  final WidgetRef _ref;
  final String _displayName;

  // ---------------------------------------------------------------------------
  // ImportSourceAdapter interface
  // ---------------------------------------------------------------------------

  @override
  ImportSourceType get sourceType => ImportSourceType.universal;

  @override
  String get displayName => _displayName;

  @override
  Set<DuplicateAction> get supportedDuplicateActions => const {
    DuplicateAction.skip,
    DuplicateAction.importAsNew,
  };

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
      builder: (context) => const SourceConfirmationStep(),
      canAdvance: universalAdapterSourceReadyProvider,
      onBeforeAdvance: () {
        _ref.read(universalImportNotifierProvider.notifier).confirmSource();
      },
    ),
    WizardStepDef(
      label: 'Map Fields',
      icon: Icons.table_chart_outlined,
      builder: (context) => const FieldMappingStep(),
      canAdvance: universalAdapterMappingReadyProvider,
      // Non-CSV formats auto-advance because the payload is produced
      // immediately after source confirmation (the notifier skips field
      // mapping). CSV formats wait for the user to tap "Next".
      autoAdvance: true,
      onBeforeAdvance: () {
        final notifier = _ref.read(universalImportNotifierProvider.notifier);
        notifier.confirmFieldMapping();
      },
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
          displayName: 'Universal Import',
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
    );
    _applyDuplicateIndices(
      updatedGroups,
      wizard.ImportEntityType.sites,
      dupResult.duplicates[ui.ImportEntityType.sites] ?? const {},
    );
    _applyDuplicateIndices(
      updatedGroups,
      wizard.ImportEntityType.equipment,
      dupResult.duplicates[ui.ImportEntityType.equipment] ?? const {},
    );
    _applyDuplicateIndices(
      updatedGroups,
      wizard.ImportEntityType.buddies,
      dupResult.duplicates[ui.ImportEntityType.buddies] ?? const {},
    );
    _applyDuplicateIndices(
      updatedGroups,
      wizard.ImportEntityType.diveCenters,
      dupResult.duplicates[ui.ImportEntityType.diveCenters] ?? const {},
    );
    _applyDuplicateIndices(
      updatedGroups,
      wizard.ImportEntityType.certifications,
      dupResult.duplicates[ui.ImportEntityType.certifications] ?? const {},
    );
    _applyDuplicateIndices(
      updatedGroups,
      wizard.ImportEntityType.tags,
      dupResult.duplicates[ui.ImportEntityType.tags] ?? const {},
    );
    _applyDuplicateIndices(
      updatedGroups,
      wizard.ImportEntityType.diveTypes,
      dupResult.duplicates[ui.ImportEntityType.diveTypes] ?? const {},
    );

    return ImportBundle(source: bundle.source, groups: updatedGroups);
  }

  @override
  Future<UnifiedImportResult> performImport(
    ImportBundle bundle,
    Map<wizard.ImportEntityType, Set<int>> selections,
    Map<wizard.ImportEntityType, Map<int, DuplicateAction>> duplicateActions, {
    bool retainSourceDiveNumbers = false,
    void Function(String phase, int current, int total)? onProgress,
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

    final diveSelections = _resolveDiveSelections(selections, duplicateActions);
    final skipped = _countSkipped(selections, duplicateActions);

    var uddfData = _payloadToUddfResult(payload);
    var uddfSelections = UddfImportSelections(
      dives: diveSelections,
      sites: selections[wizard.ImportEntityType.sites] ?? const {},
      buddies: selections[wizard.ImportEntityType.buddies] ?? const {},
      equipment: selections[wizard.ImportEntityType.equipment] ?? const {},
      trips: selections[wizard.ImportEntityType.trips] ?? const {},
      certifications:
          selections[wizard.ImportEntityType.certifications] ?? const {},
      diveCenters: selections[wizard.ImportEntityType.diveCenters] ?? const {},
      tags: selections[wizard.ImportEntityType.tags] ?? const {},
      diveTypes: selections[wizard.ImportEntityType.diveTypes] ?? const {},
      equipmentSets:
          selections[wizard.ImportEntityType.equipmentSets] ?? const {},
      courses: selections[wizard.ImportEntityType.courses] ?? const {},
    );

    // Inject batch tag if present so it flows through the import pipeline.
    final batchTag = notifierState.options?.batchTag;
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
      retainSourceDiveNumbers: retainSourceDiveNumbers,
      onProgress: onProgress,
    );

    return UnifiedImportResult(
      importedCounts: _convertImportCounts(result),
      consolidatedCount: 0,
      skippedCount: skipped,
      importedDiveIds: result.diveIds,
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
    final maxDepth = data['maxDepth'] as double?;
    final runtime = data['runtime'] as Duration?;
    final duration = data['duration'] as Duration?;
    final effectiveDuration = runtime ?? duration;

    String title;
    if (dateTime != null) {
      final dateStr = _dateFormatter.format(dateTime);
      final timeStr = _timeFormatter.format(dateTime);
      title = '$dateStr \u2014 $timeStr';
    } else {
      title = 'Unknown date';
    }

    final parts = <String>[];
    if (maxDepth != null) {
      parts.add('${maxDepth.toStringAsFixed(1)}m max');
    }
    if (effectiveDuration != null) {
      parts.add('${effectiveDuration.inMinutes} min');
    }
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
      subtitle = '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
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
    final level = data['level'] as String?;
    final name = data['name'] as String?;
    final agencyValue = data['agency'];

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

  EntityItem _courseToEntityItem(Map<String, dynamic> data) {
    final name = (data['name'] as String?) ?? 'Unnamed';
    final agency = data['agency'] as String?;
    return EntityItem(title: name, subtitle: agency ?? '');
  }

  // ---------------------------------------------------------------------------
  // Helpers — duplicate application
  // ---------------------------------------------------------------------------

  void _applyDuplicateIndices(
    Map<wizard.ImportEntityType, EntityGroup> groups,
    wizard.ImportEntityType type,
    Set<int> duplicateIndices, {
    Map<int, DiveMatchResult>? matchResults,
  }) {
    final group = groups[type];
    if (group == null || duplicateIndices.isEmpty) return;

    groups[type] = EntityGroup(
      items: group.items,
      duplicateIndices: duplicateIndices,
      matchResults: matchResults,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers — import
  // ---------------------------------------------------------------------------

  Set<int> _resolveDiveSelections(
    Map<wizard.ImportEntityType, Set<int>> selections,
    Map<wizard.ImportEntityType, Map<int, DuplicateAction>> duplicateActions,
  ) {
    final baseSelections = Set<int>.from(
      selections[wizard.ImportEntityType.dives] ?? <int>{},
    );
    final diveActions = duplicateActions[wizard.ImportEntityType.dives] ?? {};
    final indicesToImport = <int>{};

    for (final index in baseSelections) {
      final action = diveActions[index];
      if (action != DuplicateAction.skip) {
        indicesToImport.add(index);
      }
    }

    for (final entry in diveActions.entries) {
      if (entry.value == DuplicateAction.importAsNew) {
        indicesToImport.add(entry.key);
      }
    }

    return indicesToImport;
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
    );
  }

  /// Inject a batch tag into the UDDF data so it flows through the existing
  /// tag import and dive-tag linking pipeline.
  ///
  /// Returns a new (UddfImportResult, UddfImportSelections) pair with:
  /// - The batch tag appended to the tags list
  /// - The tag index added to the tags selection
  /// - Each selected dive's `tagRefs` updated to include the batch tag ID
  static (UddfImportResult, UddfImportSelections) _injectBatchTag(
    UddfImportResult data,
    UddfImportSelections selections,
    String tagName,
  ) {
    final batchTagId = 'batch_tag_${DateTime.now().millisecondsSinceEpoch}';

    final updatedTags = [
      ...data.tags,
      <String, dynamic>{'name': tagName, 'uddfId': batchTagId},
    ];
    final batchTagIndex = updatedTags.length - 1;

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
}
