import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_import/data/services/uddf_duplicate_checker.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_import/data/services/uddf_parser_service.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/uddf_file_picker_step.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/entity_match_result.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

/// Riverpod [StateProvider] signalling whether the UDDF file acquisition step
/// has loaded data and may advance to the review step.
///
/// Set to `true` after a file has been successfully parsed.
final uddfAdapterCanAdvanceProvider = StateProvider<bool>((ref) => false);

/// Import source adapter for UDDF/XML files.
///
/// Implements [ImportSourceAdapter] for the unified import wizard. Unlike the
/// FIT and HealthKit adapters which only handle dives, this adapter supports
/// up to 11 entity types (dives, sites, buddies, equipment, trips,
/// certifications, dive centers, tags, dive types, equipment sets, courses).
///
/// Entity data arrives as `Map<String, dynamic>` from [UddfImportResult],
/// with each entity type using different map keys for display fields.
class UddfAdapter implements ImportSourceAdapter {
  UddfAdapter({
    required UddfParserService parser,
    required UddfDuplicateChecker duplicateChecker,
    required UddfEntityImporter entityImporter,
    required ImportRepositories repositories,
    required DiveRepository diveRepository,
    required List<Trip> existingTrips,
    required List<DiveSite> existingSites,
    required List<EquipmentItem> existingEquipment,
    required List<Buddy> existingBuddies,
    required List<DiveCenter> existingDiveCenters,
    required List<Certification> existingCertifications,
    required List<Tag> existingTags,
    required List<DiveTypeEntity> existingDiveTypes,
    required String diverId,
    AppSettings settings = const AppSettings(),
    String displayName = 'UDDF Import',
  }) : _parser = parser,
       _duplicateChecker = duplicateChecker,
       _entityImporter = entityImporter,
       _repositories = repositories,
       _diveRepository = diveRepository,
       _existingTrips = existingTrips,
       _existingSites = existingSites,
       _existingEquipment = existingEquipment,
       _existingBuddies = existingBuddies,
       _existingDiveCenters = existingDiveCenters,
       _existingCertifications = existingCertifications,
       _existingTags = existingTags,
       _existingDiveTypes = existingDiveTypes,
       _diverId = diverId,
       _settings = settings,
       _displayName = displayName;

  final UddfParserService _parser;
  final UddfDuplicateChecker _duplicateChecker;
  final UddfEntityImporter _entityImporter;
  final ImportRepositories _repositories;
  final DiveRepository _diveRepository;
  final List<Trip> _existingTrips;
  final List<DiveSite> _existingSites;
  final List<EquipmentItem> _existingEquipment;
  final List<Buddy> _existingBuddies;
  final List<DiveCenter> _existingDiveCenters;
  final List<Certification> _existingCertifications;
  final List<Tag> _existingTags;
  final List<DiveTypeEntity> _existingDiveTypes;
  final String _diverId;
  final AppSettings _settings;
  final String _displayName;

  UddfImportResult? _parsedData;

  /// Load a pre-parsed [UddfImportResult] into this adapter.
  ///
  /// Must be called before [buildBundle]. The actual file-picking UI is
  /// provided by the [acquisitionSteps] widget; parsed data is set here
  /// to decouple file I/O from adapter logic.
  void setParsedData(UddfImportResult data) {
    _parsedData = data;
  }

  // ---------------------------------------------------------------------------
  // ImportSourceAdapter interface
  // ---------------------------------------------------------------------------

  @override
  void resetState() {}

  @override
  ImportSourceType get sourceType => ImportSourceType.uddf;

  @override
  String get displayName => _displayName;

  @override
  String get defaultTagName {
    final now = DateTime.now();
    final date =
        '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return '$_displayName Import $date';
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
      builder: (context) => UddfFilePickerStep(
        parser: _parser,
        onDataParsed: (data) {
          setParsedData(data);
        },
      ),
      canAdvance: uddfAdapterCanAdvanceProvider,
      autoAdvance: false,
    ),
  ];

  @override
  Future<ImportBundle> buildBundle() async {
    final data = _parsedData;
    if (data == null) {
      return ImportBundle(
        source: ImportSourceInfo(
          type: ImportSourceType.uddf,
          displayName: _displayName,
        ),
        groups: const {},
      );
    }

    final groups = <ImportEntityType, EntityGroup>{};

    _addGroupIfNotEmpty(
      groups,
      ImportEntityType.dives,
      data.dives,
      _diveToEntityItem,
    );
    _addGroupIfNotEmpty(
      groups,
      ImportEntityType.sites,
      data.sites,
      _siteToEntityItem,
    );
    _addGroupIfNotEmpty(
      groups,
      ImportEntityType.buddies,
      data.buddies,
      _buddyToEntityItem,
    );
    _addGroupIfNotEmpty(
      groups,
      ImportEntityType.equipment,
      data.equipment,
      _equipmentToEntityItem,
    );
    _addGroupIfNotEmpty(
      groups,
      ImportEntityType.trips,
      data.trips,
      _tripToEntityItem,
    );
    _addGroupIfNotEmpty(
      groups,
      ImportEntityType.certifications,
      data.certifications,
      _certificationToEntityItem,
    );
    _addGroupIfNotEmpty(
      groups,
      ImportEntityType.diveCenters,
      data.diveCenters,
      _diveCenterToEntityItem,
    );
    _addGroupIfNotEmpty(
      groups,
      ImportEntityType.tags,
      data.tags,
      _tagToEntityItem,
    );
    _addGroupIfNotEmpty(
      groups,
      ImportEntityType.diveTypes,
      data.customDiveTypes,
      _diveTypeToEntityItem,
    );
    _addGroupIfNotEmpty(
      groups,
      ImportEntityType.equipmentSets,
      data.equipmentSets,
      _equipmentSetToEntityItem,
    );
    _addGroupIfNotEmpty(
      groups,
      ImportEntityType.courses,
      data.courses,
      _courseToEntityItem,
    );

    return ImportBundle(
      source: ImportSourceInfo(
        type: ImportSourceType.uddf,
        displayName: _displayName,
      ),
      groups: groups,
    );
  }

  @override
  Future<ImportBundle> checkDuplicates(ImportBundle bundle) async {
    final data = _parsedData;
    if (data == null) return bundle;

    final existingDives = await _diveRepository.getAllDives(diverId: _diverId);

    final dupResult = _duplicateChecker.check(
      importData: data,
      existingTrips: _existingTrips,
      existingSites: _existingSites,
      existingEquipment: _existingEquipment,
      existingBuddies: _existingBuddies,
      existingDiveCenters: _existingDiveCenters,
      existingCertifications: _existingCertifications,
      existingTags: _existingTags,
      existingDiveTypes: _existingDiveTypes,
      existingDives: existingDives,
    );

    final updatedGroups = Map<ImportEntityType, EntityGroup>.from(
      bundle.groups,
    );

    _applyDuplicateIndices(
      updatedGroups,
      ImportEntityType.dives,
      Set<int>.from(dupResult.diveMatches.keys),
      matchResults: dupResult.diveMatches,
    );
    _applyDuplicateIndices(
      updatedGroups,
      ImportEntityType.trips,
      dupResult.duplicateTrips,
      entityMatches: dupResult.entityMatchesFor('trips'),
    );
    _applyDuplicateIndices(
      updatedGroups,
      ImportEntityType.sites,
      dupResult.duplicateSites,
      entityMatches: dupResult.entityMatchesFor('sites'),
    );
    _applyDuplicateIndices(
      updatedGroups,
      ImportEntityType.equipment,
      dupResult.duplicateEquipment,
      entityMatches: dupResult.entityMatchesFor('equipment'),
    );
    _applyDuplicateIndices(
      updatedGroups,
      ImportEntityType.buddies,
      dupResult.duplicateBuddies,
      entityMatches: dupResult.entityMatchesFor('buddies'),
    );
    _applyDuplicateIndices(
      updatedGroups,
      ImportEntityType.diveCenters,
      dupResult.duplicateDiveCenters,
      entityMatches: dupResult.entityMatchesFor('diveCenters'),
    );
    _applyDuplicateIndices(
      updatedGroups,
      ImportEntityType.certifications,
      dupResult.duplicateCertifications,
      entityMatches: dupResult.entityMatchesFor('certifications'),
    );
    _applyDuplicateIndices(
      updatedGroups,
      ImportEntityType.tags,
      dupResult.duplicateTags,
      entityMatches: dupResult.entityMatchesFor('tags'),
    );
    _applyDuplicateIndices(
      updatedGroups,
      ImportEntityType.diveTypes,
      dupResult.duplicateDiveTypes,
      entityMatches: dupResult.entityMatchesFor('diveTypes'),
    );

    return ImportBundle(source: bundle.source, groups: updatedGroups);
  }

  @override
  Future<UnifiedImportResult> performImport(
    ImportBundle bundle,
    Map<ImportEntityType, Set<int>> selections,
    Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions, {
    bool retainSourceDiveNumbers = false,
    void Function(String phase, int current, int total)? onProgress,
  }) async {
    final data = _parsedData;
    if (data == null) {
      return const UnifiedImportResult(
        importedCounts: {},
        consolidatedCount: 0,
        skippedCount: 0,
        errorMessage: 'No parsed data available',
      );
    }

    // Build UddfImportSelections from the wizard's selections map,
    // applying duplicate actions for dives.
    final diveSelections = _resolveDiveSelections(selections, duplicateActions);
    final skipped = _countSkipped(selections, duplicateActions);

    final uddfSelections = UddfImportSelections(
      dives: diveSelections,
      sites: selections[ImportEntityType.sites] ?? const {},
      buddies: selections[ImportEntityType.buddies] ?? const {},
      equipment: selections[ImportEntityType.equipment] ?? const {},
      trips: selections[ImportEntityType.trips] ?? const {},
      certifications: selections[ImportEntityType.certifications] ?? const {},
      diveCenters: selections[ImportEntityType.diveCenters] ?? const {},
      tags: selections[ImportEntityType.tags] ?? const {},
      diveTypes: selections[ImportEntityType.diveTypes] ?? const {},
      equipmentSets: selections[ImportEntityType.equipmentSets] ?? const {},
      courses: selections[ImportEntityType.courses] ?? const {},
    );

    final result = await _entityImporter.import(
      data: data,
      selections: uddfSelections,
      repositories: _repositories,
      diverId: _diverId,
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
    Map<ImportEntityType, EntityGroup> groups,
    ImportEntityType type,
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
      final units = UnitFormatter(_settings);
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
    String subtitle;
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

    String subtitle;
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
  // Helpers — duplicate checking
  // ---------------------------------------------------------------------------

  void _applyDuplicateIndices(
    Map<ImportEntityType, EntityGroup> groups,
    ImportEntityType type,
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

  /// Resolve dive selections by applying duplicate actions.
  ///
  /// - Selected dives with [DuplicateAction.skip] are excluded.
  /// - Dives with [DuplicateAction.importAsNew] are included even if not
  ///   in the base selection.
  Set<int> _resolveDiveSelections(
    Map<ImportEntityType, Set<int>> selections,
    Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions,
  ) {
    final baseSelections = Set<int>.from(
      selections[ImportEntityType.dives] ?? <int>{},
    );
    final diveActions = duplicateActions[ImportEntityType.dives] ?? {};

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

  /// Count items that were skipped via [DuplicateAction.skip].
  int _countSkipped(
    Map<ImportEntityType, Set<int>> selections,
    Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions,
  ) {
    final diveActions = duplicateActions[ImportEntityType.dives] ?? {};
    var skipped = 0;

    for (final entry in diveActions.entries) {
      if (entry.value == DuplicateAction.skip) {
        skipped++;
      }
    }

    return skipped;
  }

  /// Convert [UddfEntityImportResult] to [ImportEntityType]-keyed counts.
  Map<ImportEntityType, int> _convertImportCounts(
    UddfEntityImportResult result,
  ) {
    final counts = <ImportEntityType, int>{};

    if (result.dives > 0) counts[ImportEntityType.dives] = result.dives;
    if (result.sites > 0) counts[ImportEntityType.sites] = result.sites;
    if (result.buddies > 0) counts[ImportEntityType.buddies] = result.buddies;
    if (result.equipment > 0) {
      counts[ImportEntityType.equipment] = result.equipment;
    }
    if (result.trips > 0) counts[ImportEntityType.trips] = result.trips;
    if (result.certifications > 0) {
      counts[ImportEntityType.certifications] = result.certifications;
    }
    if (result.diveCenters > 0) {
      counts[ImportEntityType.diveCenters] = result.diveCenters;
    }
    if (result.tags > 0) counts[ImportEntityType.tags] = result.tags;
    if (result.diveTypes > 0) {
      counts[ImportEntityType.diveTypes] = result.diveTypes;
    }
    if (result.equipmentSets > 0) {
      counts[ImportEntityType.equipmentSets] = result.equipmentSets;
    }
    if (result.courses > 0) counts[ImportEntityType.courses] = result.courses;

    return counts;
  }
}
