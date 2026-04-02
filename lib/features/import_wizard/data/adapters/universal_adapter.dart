import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
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
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/entity_match_result.dart';
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

/// Import source adapter for universal file imports (CSV, Subsurface XML,
/// UDDF, auto-detected formats). Wraps [UniversalImportNotifier] into the
/// unified import wizard framework.
class UniversalAdapter implements ImportSourceAdapter {
  UniversalAdapter({
    required WidgetRef ref,
    String displayName = 'Universal Import',
  }) : _ref = ref,
       _displayName = displayName;

  final WidgetRef _ref;
  final String _displayName;

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
    final uddfSelections = UddfImportSelections(
      dives: resolve(wizard.ImportEntityType.dives),
      sites: resolve(wizard.ImportEntityType.sites),
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
      if (action != DuplicateAction.skip) {
        resolved.add(index);
      }
    }

    for (final entry in actions.entries) {
      if (entry.value == DuplicateAction.importAsNew) {
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
    );
  }
}
