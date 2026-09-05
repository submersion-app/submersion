import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/imported_computer_identity.dart';
import 'package:submersion/core/database/database.dart'
    show DiveDataSourcesCompanion, DiveSitesCompanion, DivesCompanion;
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/utils/deco_dive_detector.dart';
import 'package:submersion/features/dive_log/domain/services/dive_altitude_enricher.dart';
import 'package:submersion/features/equipment/data/services/dive_computer_gear_linker.dart';
import 'package:submersion/features/equipment/data/services/dive_equipment_defaulter.dart';
import 'package:submersion/features/pre_dive/data/services/checklist_dive_linker.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/core/utils/number_utils.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart'
    as equipment_domain;
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/universal_import/data/services/import_tank_defaults.dart';
import 'package:uuid/uuid.dart';

/// Bundles all repositories needed for UDDF import.
class ImportRepositories {
  final TripRepository tripRepository;
  final EquipmentRepository equipmentRepository;
  final EquipmentSetRepository equipmentSetRepository;
  final BuddyRepository buddyRepository;
  final DiveCenterRepository diveCenterRepository;
  final CertificationRepository certificationRepository;
  final TagRepository tagRepository;
  final DiveTypeRepository diveTypeRepository;

  /// Optional so existing constructors and mock bundles keep working;
  /// when null, custom dive role restore is skipped.
  final DiveRoleRepository? diveRoleRepository;

  /// Optional for the same reason; when null, equipment service history in
  /// the source is skipped rather than failing the import.
  final ServiceRecordRepository? serviceRecordRepository;
  final SiteRepository siteRepository;
  final DiveRepository diveRepository;
  final TankPressureRepository tankPressureRepository;
  final CourseRepository courseRepository;

  /// Optional for the same reason; when null, the dives keep their
  /// `dive_computer_model`/`_serial` display snapshots but no
  /// `dive_computers` row is registered and no attribution is stamped
  /// (#1288).
  final DiveComputerRepository? diveComputerRepository;

  const ImportRepositories({
    required this.tripRepository,
    required this.equipmentRepository,
    required this.equipmentSetRepository,
    required this.buddyRepository,
    required this.diveCenterRepository,
    required this.certificationRepository,
    required this.tagRepository,
    required this.diveTypeRepository,
    this.diveRoleRepository,
    this.serviceRecordRepository,
    required this.siteRepository,
    required this.diveRepository,
    required this.tankPressureRepository,
    required this.courseRepository,
    this.diveComputerRepository,
  });
}

/// Which entity types are selected for import (by index into parsed lists).
class UddfImportSelections {
  final Set<int> trips;
  final Set<int> equipment;
  final Set<int> buddies;
  final Set<int> diveCenters;
  final Set<int> certifications;
  final Set<int> tags;
  final Set<int> diveTypes;
  final Set<int> sites;

  /// Maps import-list index → existing site ID for sites the user chose to
  /// overwrite. These indices are NOT included in [sites] (which creates new
  /// entries); instead, the matching existing site is updated in place.
  final Map<int, String> siteOverrides;
  final Set<int> equipmentSets;
  final Set<int> dives;
  final Set<int> courses;

  const UddfImportSelections({
    this.trips = const {},
    this.equipment = const {},
    this.buddies = const {},
    this.diveCenters = const {},
    this.certifications = const {},
    this.tags = const {},
    this.diveTypes = const {},
    this.sites = const {},
    this.siteOverrides = const {},
    this.equipmentSets = const {},
    this.dives = const {},
    this.courses = const {},
  });

  /// Create selections with all items selected.
  factory UddfImportSelections.selectAll(UddfImportResult data) {
    return UddfImportSelections(
      trips: _allIndices(data.trips.length),
      equipment: _allIndices(data.equipment.length),
      buddies: _allIndices(data.buddies.length),
      diveCenters: _allIndices(data.diveCenters.length),
      certifications: _allIndices(data.certifications.length),
      tags: _allIndices(data.tags.length),
      diveTypes: _allIndices(data.customDiveTypes.length),
      sites: _allIndices(data.sites.length),
      equipmentSets: _allIndices(data.equipmentSets.length),
      dives: _allIndices(data.dives.length),
      courses: _allIndices(data.courses.length),
    );
  }

  static Set<int> _allIndices(int count) =>
      Set<int>.from(List.generate(count, (i) => i));
}

/// Counts of imported entities per type.
class UddfEntityImportResult {
  final int trips;
  final int equipment;
  final int equipmentSets;
  final int buddies;
  final int diveCenters;
  final int certifications;
  final int tags;
  final int diveTypes;
  final int sites;
  final int dives;
  final int courses;
  final List<String> diveIds;

  /// The persisted dive id created for each imported source-dive index.
  ///
  /// Keyed by the index into the `dives` list passed to [import] (the same
  /// indices used by [UddfImportSelections.dives]), not by import order —
  /// dives are persisted oldest-first for sequential numbering, so this map
  /// is how callers recover which dive id corresponds to which input index.
  final Map<int, String> diveIdByIndex;

  /// How many `dive_data_sources` rows were restored from a Submersion
  /// export's `<source>` entries, rather than synthesised from the dive.
  final int restoredDataSources;

  const UddfEntityImportResult({
    this.trips = 0,
    this.equipment = 0,
    this.equipmentSets = 0,
    this.buddies = 0,
    this.diveCenters = 0,
    this.certifications = 0,
    this.tags = 0,
    this.diveTypes = 0,
    this.sites = 0,
    this.dives = 0,
    this.courses = 0,
    this.diveIds = const [],
    this.diveIdByIndex = const {},
    this.restoredDataSources = 0,
  });

  int get total =>
      trips +
      equipment +
      equipmentSets +
      buddies +
      diveCenters +
      certifications +
      tags +
      diveTypes +
      sites +
      dives +
      courses;

  String get summary {
    final parts = <String>[];
    if (dives > 0) parts.add('$dives dives');
    if (sites > 0) parts.add('$sites sites');
    if (trips > 0) parts.add('$trips trips');
    if (equipment > 0) parts.add('$equipment equipment');
    if (equipmentSets > 0) parts.add('$equipmentSets equipment sets');
    if (buddies > 0) parts.add('$buddies buddies');
    if (diveCenters > 0) parts.add('$diveCenters dive centers');
    if (certifications > 0) parts.add('$certifications certifications');
    if (courses > 0) parts.add('$courses courses');
    if (diveTypes > 0) parts.add('$diveTypes custom dive types');
    if (tags > 0) parts.add('$tags tags');
    return parts.isEmpty ? 'No data imported' : 'Imported ${parts.join(', ')}';
  }
}

/// Stateless service that creates entities from parsed UDDF data.
///
/// Takes repository instances directly (not Riverpod Ref) for testability.
/// Creates entities in dependency order, maintaining ID mappings for
/// cross-references between entity types.
class UddfEntityImporter {
  static const _uuid = Uuid();
  final _log = LoggerService.forClass(UddfEntityImporter);

  final TankPresetEntity? _defaultTankPreset;
  final int _defaultStartPressure;
  final bool _applyDefaultTankToImports;

  /// ISO 639-1 code for reverse-geocoded country/region (issue #1187).
  final String _placeNameLanguage;

  UddfEntityImporter({
    TankPresetEntity? defaultTankPreset,
    int defaultStartPressure = 200,
    bool applyDefaultTankToImports = false,
    String placeNameLanguage = LocationService.defaultLanguageCode,
  }) : _defaultTankPreset = defaultTankPreset,
       _defaultStartPressure = defaultStartPressure,
       _applyDefaultTankToImports = applyDefaultTankToImports,
       _placeNameLanguage = placeNameLanguage;

  /// Parse a value that may be either an enum instance or a string matching
  /// an enum name. Returns null if the value is null or unrecognised.
  static T? _parseEnum<T extends Enum>(Object? value, List<T> values) {
    if (value == null) return null;
    if (value is T) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      for (final v in values) {
        if (v.name.toLowerCase() == lower) return v;
      }
    }
    return null;
  }

  /// Import selected entities from [data] using [repositories].
  ///
  /// Only entities at indices present in [selections] are imported.
  /// Reports progress via [onProgress] callback.
  ///
  /// If [cancelToken] is non-null, the dive-import loop polls
  /// [ImportCancellationToken.isCancelled] between each dive and returns the
  /// partial result already persisted when cancellation is observed.
  ///
  /// [preResolvedBuddyIds] and [preResolvedTagIds] map source refs
  /// (uddfId/name) to EXISTING database ids for flagged duplicates the
  /// reviewer chose not to import as new rows. Seeding the id mappings with
  /// them makes dive linking resolve to the existing record instead of
  /// silently dropping the association (#756).
  Future<UddfEntityImportResult> import({
    required UddfImportResult data,
    required UddfImportSelections selections,
    required ImportRepositories repositories,
    required String diverId,
    bool retainSourceDiveNumbers = false,
    Map<String, String> preResolvedBuddyIds = const {},
    Map<String, String> preResolvedTagIds = const {},
    ImportProgressCallback? onProgress,
    ImportCancellationToken? cancelToken,
  }) async {
    final now = DateTime.now();

    // ID mappings for cross-references
    final tripIdMapping = <String, String>{};
    final equipmentIdMapping = <String, String>{};
    final buddyIdMapping = <String, String>{...preResolvedBuddyIds};
    final diveCenterIdMapping = <String, String>{};
    final tagIdMapping = <String, String>{...preResolvedTagIds};
    final siteIdMapping = <String, DiveSite>{};
    final courseIdMapping = <String, String>{};

    // Import in dependency order
    final tripsCount = await _importTrips(
      data.trips,
      selections.trips,
      repositories.tripRepository,
      diverId,
      tripIdMapping,
      now,
      onProgress,
    );

    final equipmentCount = await _importEquipment(
      data.equipment,
      selections.equipment,
      repositories.equipmentRepository,
      diverId,
      equipmentIdMapping,
      now,
      onProgress,
    );

    // Service history belongs to the equipment it describes, so it rides
    // along with whatever equipment was selected rather than being its own
    // choice in the wizard.
    await _importServiceRecords(
      data.serviceRecords,
      repositories.serviceRecordRepository,
      equipmentIdMapping,
      now,
    );

    final buddiesCount = await _importBuddies(
      data.buddies,
      selections.buddies,
      repositories.buddyRepository,
      repositories.certificationRepository,
      diverId,
      buddyIdMapping,
      now,
      onProgress,
    );

    final diveCentersCount = await _importDiveCenters(
      data.diveCenters,
      selections.diveCenters,
      repositories.diveCenterRepository,
      diverId,
      diveCenterIdMapping,
      now,
      onProgress,
    );

    final certificationsCount = await _importCertifications(
      data.certifications,
      selections.certifications,
      repositories.certificationRepository,
      diverId,
      now,
      onProgress,
    );

    final tagsCount = await _importTags(
      data.tags,
      selections.tags,
      repositories.tagRepository,
      diverId,
      tagIdMapping,
      now,
      onProgress,
    );

    final diveTypesCount = await _importDiveTypes(
      data.customDiveTypes,
      selections.diveTypes,
      repositories.diveTypeRepository,
      diverId,
      now,
      onProgress,
    );

    // Custom dive roles restore unconditionally (no selection UI): they are
    // tiny reference rows whose ids are referenced by imported dive_buddies
    // and dives rows, and the id-preserving insert is idempotent.
    final diveRoleRepository = repositories.diveRoleRepository;
    if (diveRoleRepository != null) {
      await _importDiveRoles(data.customDiveRoles, diveRoleRepository, diverId);
    }

    final sitesCount = await _importSites(
      data.sites,
      selections.sites,
      selections.siteOverrides,
      repositories.siteRepository,
      diverId,
      siteIdMapping,
      onProgress,
    );

    final equipmentSetsCount = await _importEquipmentSets(
      data.equipmentSets,
      selections.equipmentSets,
      repositories.equipmentSetRepository,
      diverId,
      equipmentIdMapping,
      now,
      onProgress,
    );

    final coursesCount = await _importCourses(
      data.courses,
      selections.courses,
      repositories.courseRepository,
      diverId,
      courseIdMapping,
      buddyIdMapping,
      now,
      onProgress,
    );

    final divesResult = await _importDives(
      data.dives,
      selections.dives,
      repositories,
      diverId,
      tripIdMapping: tripIdMapping,
      equipmentIdMapping: equipmentIdMapping,
      buddyIdMapping: buddyIdMapping,
      diveCenterIdMapping: diveCenterIdMapping,
      tagIdMapping: tagIdMapping,
      siteIdMapping: siteIdMapping,
      courseIdMapping: courseIdMapping,
      sourceFileName: data.sourceFileName,
      retainSourceDiveNumbers: retainSourceDiveNumbers,
      now: now,
      dataSourcesByDiveRef: data.dataSourcesByDiveRef,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );

    return UddfEntityImportResult(
      trips: tripsCount,
      equipment: equipmentCount,
      equipmentSets: equipmentSetsCount,
      buddies: buddiesCount + divesResult.inlineBuddies,
      diveCenters: diveCentersCount,
      certifications: certificationsCount,
      tags: tagsCount,
      diveTypes: diveTypesCount,
      sites: sitesCount,
      dives: divesResult.count,
      courses: coursesCount,
      diveIds: divesResult.diveIds,
      diveIdByIndex: divesResult.diveIdByIndex,
      restoredDataSources: divesResult.restoredDataSources,
    );
  }

  // -- Trip import --

  Future<int> _importTrips(
    List<Map<String, dynamic>> items,
    Set<int> selected,
    TripRepository repository,
    String diverId,
    Map<String, String> idMapping,
    DateTime now,
    ImportProgressCallback? onProgress,
  ) async {
    if (selected.isEmpty) return 0;
    onProgress?.call(ImportPhase.trips, 0, selected.length);
    var count = 0;

    for (var i = 0; i < items.length; i++) {
      if (!selected.contains(i)) continue;
      final tripData = items[i];
      final name = tripData['name'] as String?;
      if (name == null || name.isEmpty) continue;

      final uddfId = tripData['uddfId'] as String?;
      final newId = _uuid.v4();

      final tripTypeStr = tripData['tripType'] as String?;
      final trip = Trip(
        id: newId,
        diverId: diverId,
        name: name,
        startDate: tripData['startDate'] as DateTime? ?? now,
        endDate: tripData['endDate'] as DateTime? ?? now,
        location: tripData['location'] as String?,
        resortName: tripData['resortName'] as String?,
        liveaboardName: tripData['liveaboardName'] as String?,
        tripType: tripTypeStr != null
            ? TripType.fromName(tripTypeStr)
            : TripType.shore,
        notes: tripData['notes'] as String? ?? '',
        createdAt: now,
        updatedAt: now,
      );

      await repository.createTrip(trip);
      if (uddfId != null) idMapping[uddfId] = newId;
      count++;
      onProgress?.call(ImportPhase.trips, count, selected.length);
    }

    return count;
  }

  // -- Equipment service history --

  /// Persists service records for equipment that was actually imported.
  ///
  /// Each record names its owner through `equipmentRef`, the same key
  /// `_importEquipment` registered in [equipmentIdMapping]. Records whose
  /// equipment was not imported (deselected, or a dangling reference) are
  /// skipped - a service record with no item to attach to is unreachable.
  Future<int> _importServiceRecords(
    List<Map<String, dynamic>> items,
    ServiceRecordRepository? repository,
    Map<String, String> equipmentIdMapping,
    DateTime now,
  ) async {
    if (repository == null || items.isEmpty) return 0;
    var count = 0;

    for (final recordData in items) {
      final ref = recordData['equipmentRef'] as String?;
      if (ref == null) continue;
      final equipmentId = equipmentIdMapping[ref];
      if (equipmentId == null) continue;

      final serviceDate = recordData['serviceDate'] as DateTime?;
      if (serviceDate == null) continue;

      final record = equipment_domain.ServiceRecord(
        id: _uuid.v4(),
        equipmentId: equipmentId,
        serviceCategory:
            _parseEnum(recordData['serviceCategory'], ServiceCategory.values) ??
            ServiceCategory.other,
        serviceDate: serviceDate,
        provider: recordData['provider'] as String?,
        cost: asDoubleOrNull(recordData['cost']),
        currency: recordData['currency'] as String? ?? 'USD',
        nextServiceDue: recordData['nextServiceDue'] as DateTime?,
        notes: recordData['notes'] as String? ?? '',
        createdAt: now,
        updatedAt: now,
      );

      try {
        await repository.createRecord(record);
        count++;
      } catch (_) {
        // One bad record must not abort the import.
      }
    }

    return count;
  }

  // -- Equipment import --

  Future<int> _importEquipment(
    List<Map<String, dynamic>> items,
    Set<int> selected,
    EquipmentRepository repository,
    String diverId,
    Map<String, String> idMapping,
    DateTime now,
    ImportProgressCallback? onProgress,
  ) async {
    if (selected.isEmpty) return 0;
    onProgress?.call(ImportPhase.equipment, 0, selected.length);
    var count = 0;

    for (var i = 0; i < items.length; i++) {
      if (!selected.contains(i)) continue;
      final equipData = items[i];
      final name = equipData['name'] as String?;
      if (name == null || name.isEmpty) continue;

      final uddfId = equipData['uddfId'] as String?;
      final newId = _uuid.v4();

      final equipType = _parseEquipmentType(equipData['type']);
      final equipStatus = _parseEquipmentStatus(equipData['status']);

      final item = EquipmentItem(
        id: newId,
        diverId: diverId,
        name: name,
        type: equipType,
        brand: equipData['brand'] as String?,
        model: equipData['model'] as String?,
        serialNumber: equipData['serialNumber'] as String?,
        status: equipStatus,
        purchaseDate: equipData['purchaseDate'] as DateTime?,
        purchasePrice: equipData['purchasePrice'] as double?,
        purchaseCurrency: equipData['purchaseCurrency'] as String? ?? 'USD',
        lastServiceDate: equipData['lastServiceDate'] as DateTime?,
        serviceIntervalDays: equipData['serviceIntervalDays'] as int?,
        notes: equipData['notes'] as String? ?? '',
        isActive: equipData['isActive'] as bool? ?? true,
        attributes: [
          if ((equipData['size'] as String?)?.trim().isNotEmpty ?? false)
            EquipmentAttribute.curated(
              equipmentId: newId,
              key: EquipmentAttrKeys.size,
              valueText: (equipData['size'] as String).trim(),
            ),
        ],
      );

      await repository.createEquipment(item);
      if (uddfId != null) idMapping[uddfId] = newId;
      count++;
      onProgress?.call(ImportPhase.equipment, count, selected.length);
    }

    return count;
  }

  // -- Buddy import --

  Future<int> _importBuddies(
    List<Map<String, dynamic>> items,
    Set<int> selected,
    BuddyRepository repository,
    CertificationRepository certRepository,
    String diverId,
    Map<String, String> idMapping,
    DateTime now,
    ImportProgressCallback? onProgress,
  ) async {
    if (selected.isEmpty) return 0;
    onProgress?.call(ImportPhase.buddies, 0, selected.length);
    var count = 0;

    for (var i = 0; i < items.length; i++) {
      if (!selected.contains(i)) continue;
      final buddyData = items[i];
      final name = buddyData['name'] as String?;
      if (name == null || name.isEmpty) continue;

      final uddfId = buddyData['uddfId'] as String?;
      final newId = _uuid.v4();

      final buddy = Buddy(
        id: newId,
        diverId: diverId,
        name: name,
        email: buddyData['email'] as String?,
        phone: buddyData['phone'] as String?,
        notes: buddyData['notes'] as String? ?? '',
        createdAt: now,
        updatedAt: now,
      );

      await repository.createBuddy(buddy);

      // issue #553: buddy certs live in the certifications table now (setting
      // them on the Buddy entity would be ignored). Create a buddy-owned cert
      // row from the parsed certification, if any.
      final certLevel = _parseEnum(
        buddyData['certificationLevel'],
        CertificationLevel.values,
      );
      final certAgency = _parseEnum(
        buddyData['certificationAgency'],
        CertificationAgency.values,
      );
      if (certLevel != null || certAgency != null) {
        await certRepository.createCertification(
          Certification(
            id: '',
            buddyId: newId,
            name: certLevel?.displayName ?? certAgency?.displayName ?? name,
            agency: certAgency ?? CertificationAgency.other,
            level: certLevel,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      if (uddfId != null) idMapping[uddfId] = newId;
      count++;
      onProgress?.call(ImportPhase.buddies, count, selected.length);
    }

    return count;
  }

  // -- Dive Center import --

  Future<int> _importDiveCenters(
    List<Map<String, dynamic>> items,
    Set<int> selected,
    DiveCenterRepository repository,
    String diverId,
    Map<String, String> idMapping,
    DateTime now,
    ImportProgressCallback? onProgress,
  ) async {
    if (selected.isEmpty) return 0;
    onProgress?.call(ImportPhase.diveCenters, 0, selected.length);
    var count = 0;

    for (var i = 0; i < items.length; i++) {
      if (!selected.contains(i)) continue;
      final centerData = items[i];
      final name = centerData['name'] as String?;
      if (name == null || name.isEmpty) continue;

      final uddfId = centerData['uddfId'] as String?;
      final newId = _uuid.v4();

      final affiliations = _parseStringList(centerData['affiliations']);

      final center = DiveCenter(
        id: newId,
        diverId: diverId,
        name: name,
        street: centerData['street'] as String?,
        city: centerData['city'] as String?,
        stateProvince: centerData['stateProvince'] as String?,
        postalCode: centerData['postalCode'] as String?,
        latitude: centerData['latitude'] as double?,
        longitude: centerData['longitude'] as double?,
        country: centerData['country'] as String?,
        phone: centerData['phone'] as String?,
        email: centerData['email'] as String?,
        website: centerData['website'] as String?,
        affiliations: affiliations,
        rating: centerData['rating'] as double?,
        notes: centerData['notes'] as String? ?? '',
        createdAt: now,
        updatedAt: now,
      );

      await repository.createDiveCenter(center);
      if (uddfId != null) idMapping[uddfId] = newId;
      count++;
      onProgress?.call(ImportPhase.diveCenters, count, selected.length);
    }

    return count;
  }

  // -- Certification import --

  Future<int> _importCertifications(
    List<Map<String, dynamic>> items,
    Set<int> selected,
    CertificationRepository repository,
    String diverId,
    DateTime now,
    ImportProgressCallback? onProgress,
  ) async {
    if (selected.isEmpty) return 0;
    onProgress?.call(ImportPhase.certifications, 0, selected.length);
    var count = 0;

    for (var i = 0; i < items.length; i++) {
      if (!selected.contains(i)) continue;
      final certData = items[i];
      final name = certData['name'] as String?;
      if (name == null || name.isEmpty) continue;

      final newId = _uuid.v4();
      final agency = _parseCertificationAgency(certData['agency']);
      final level = _parseCertificationLevel(certData['level']);

      final certification = Certification(
        id: newId,
        diverId: diverId,
        name: name,
        agency: agency,
        level: level,
        cardNumber: certData['cardNumber'] as String?,
        issueDate: certData['issueDate'] as DateTime?,
        expiryDate: certData['expiryDate'] as DateTime?,
        instructorName: certData['instructorName'] as String?,
        instructorNumber: certData['instructorNumber'] as String?,
        notes: certData['notes'] as String? ?? '',
        createdAt: now,
        updatedAt: now,
      );

      await repository.createCertification(certification);
      count++;
      onProgress?.call(ImportPhase.certifications, count, selected.length);
    }

    return count;
  }

  // -- Tag import --

  Future<int> _importTags(
    List<Map<String, dynamic>> items,
    Set<int> selected,
    TagRepository repository,
    String diverId,
    Map<String, String> idMapping,
    DateTime now,
    ImportProgressCallback? onProgress,
  ) async {
    if (selected.isEmpty) return 0;
    onProgress?.call(ImportPhase.tags, 0, selected.length);
    var count = 0;

    for (var i = 0; i < items.length; i++) {
      if (!selected.contains(i)) continue;
      final tagData = items[i];
      final name = tagData['name'] as String?;
      if (name == null || name.isEmpty) continue;

      final uddfId = tagData['uddfId'] as String?;

      // Reuse the tag this diver already has by that name rather than minting
      // a second uuid for it -- the same guard _importDiveTypes applies to
      // colliding slugs. `tags` is uniquely indexed on (diver scope,
      // case-folded name) since v149, so a blind mint would collide (#1032).
      final existing = await repository.getTagByName(name, diverId: diverId);
      if (existing != null) {
        if (uddfId != null) idMapping[uddfId] = existing.id;
        continue;
      }

      final newId = _uuid.v4();
      final tag = Tag(
        id: newId,
        diverId: diverId,
        name: name,
        colorHex: tagData['color'] as String?,
        createdAt: now,
        updatedAt: now,
      );

      await repository.createTag(tag);
      if (uddfId != null) idMapping[uddfId] = newId;
      count++;
      onProgress?.call(ImportPhase.tags, count, selected.length);
    }

    return count;
  }

  // -- Dive Type import --

  Future<int> _importDiveTypes(
    List<Map<String, dynamic>> items,
    Set<int> selected,
    DiveTypeRepository repository,
    String diverId,
    DateTime now,
    ImportProgressCallback? onProgress,
  ) async {
    if (selected.isEmpty) return 0;
    onProgress?.call(ImportPhase.diveTypes, 0, selected.length);
    var count = 0;

    for (var i = 0; i < items.length; i++) {
      if (!selected.contains(i)) continue;
      final typeData = items[i];
      final name = typeData['name'] as String?;
      final isBuiltIn = typeData['isBuiltIn'] as bool? ?? false;
      if (isBuiltIn || name == null || name.isEmpty) continue;

      final typeId =
          typeData['id'] as String? ?? DiveTypeEntity.generateSlug(name);

      // createDiveType does not reject a colliding id - it suffixes it and
      // inserts anyway. Without this check a source whose vocabulary overlaps
      // the built-ins ("Shore", "Boat", "Night") would add a near-duplicate
      // custom type beside every one of them.
      if (await repository.getDiveTypeById(typeId) != null) continue;

      final diveType = DiveTypeEntity(
        id: typeId,
        diverId: diverId,
        name: name,
        isBuiltIn: false,
        sortOrder: typeData['sortOrder'] as int? ?? 100,
        createdAt: now,
        updatedAt: now,
      );

      try {
        await repository.createDiveType(diveType);
        count++;
      } catch (_) {
        // Ignore duplicates — dive type may already exist with same slug
      }
      onProgress?.call(ImportPhase.diveTypes, count, selected.length);
    }

    return count;
  }

  Future<int> _importDiveRoles(
    List<Map<String, dynamic>> items,
    DiveRoleRepository repository,
    String diverId,
  ) async {
    var count = 0;
    for (final roleData in items) {
      final name = roleData['name'] as String?;
      final id = roleData['id'] as String?;
      final isBuiltIn = roleData['isBuiltIn'] as bool? ?? false;
      if (isBuiltIn || id == null || name == null || name.isEmpty) continue;

      try {
        final imported = await repository.importDiveRole(
          id: id,
          name: name,
          diverId: diverId,
          sortOrder: roleData['sortOrder'] as int? ?? 100,
        );
        if (imported) count++;
      } catch (_) {
        // Ignore duplicates -- the role may already exist with the same id.
      }
    }
    return count;
  }

  // -- Site import --

  /// How close a deselected site must be to an existing row to bind to it
  /// when their names differ. Matches the radius `ImportDuplicateChecker`
  /// uses to flag the site as a duplicate in the first place.
  static const double _siteProximityMeters = 100;

  /// Nearest existing site within [_siteProximityMeters] of [item]'s
  /// coordinates, or null when the item has no coordinates or nothing sits
  /// close enough.
  DiveSite? _nearestExistingSite(
    List<DiveSite> existingSites,
    Map<String, dynamic> item,
  ) {
    final lat = (item['latitude'] as num?)?.toDouble();
    final lon = (item['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    final point = GeoPoint(lat, lon);

    DiveSite? nearest;
    var nearestMeters = double.infinity;
    for (final site in existingSites) {
      final location = site.location;
      if (location == null) continue;
      final meters = distanceMeters(location, point);
      if (meters <= _siteProximityMeters && meters < nearestMeters) {
        nearest = site;
        nearestMeters = meters;
      }
    }
    return nearest;
  }

  Future<int> _importSites(
    List<Map<String, dynamic>> items,
    Set<int> selected,
    Map<int, String> overrides,
    SiteRepository repository,
    String diverId,
    Map<String, DiveSite> idMapping,
    ImportProgressCallback? onProgress,
  ) async {
    // For deselected sites (duplicates the user chose not to re-import),
    // resolve their UDDF IDs to existing database sites so that dives
    // referencing them still get linked correctly.
    //
    // The name lookup alone is not enough: ImportDuplicateChecker flags a site
    // as a duplicate on name OR on proximity, so a site suppressed by the
    // proximity arm carries a name that matches nothing here. Without the
    // coordinate fallback its dives import with no site and no location at
    // all, silently.
    final existingSites = await repository.getAllSites(diverId: diverId);
    final existingByName = <String, DiveSite>{};
    final existingById = <String, DiveSite>{};
    for (final site in existingSites) {
      existingByName[site.name.toLowerCase()] = site;
      existingById[site.id] = site;
    }
    for (var i = 0; i < items.length; i++) {
      if (selected.contains(i)) continue; // will be imported below
      if (overrides.containsKey(i)) continue; // will be overwritten below
      final uddfId = items[i]['uddfId'] as String?;
      if (uddfId == null) continue;
      final name = items[i]['name'] as String?;
      final existing =
          (name == null ? null : existingByName[name.toLowerCase()]) ??
          _nearestExistingSite(existingSites, items[i]);
      if (existing != null) {
        idMapping[uddfId] = existing;
      }
    }

    final totalWork = selected.length + overrides.length;
    if (totalWork == 0) return 0;
    onProgress?.call(ImportPhase.sites, 0, totalWork);
    var count = 0;

    // Handle overwrite (replaceSource): update existing sites in place.
    //
    // Unlike the create path below, this builds the row from the EXISTING
    // entity via copyWith so fields absent from the import payload keep their
    // current values. Constructing a fresh DiveSite here would reset every
    // unmapped field to its constructor default -- notably isShared, city,
    // island, photoIds and conditions -- because updateSite writes the whole
    // column set, not just the fields the import happened to supply.
    for (final entry in overrides.entries) {
      final i = entry.key;
      final existingId = entry.value;
      if (i < 0 || i >= items.length) {
        _log.warning(
          'Site override index $i is out of range (${items.length} items); '
          'skipping',
        );
        continue;
      }
      final siteData = items[i];
      final name = siteData['name'] as String?;
      if (name == null || name.isEmpty) {
        _log.warning('Site override at index $i has no name; skipping');
        continue;
      }

      final existing = existingById[existingId];
      if (existing == null) {
        _log.warning(
          'Site override at index $i targets unknown site $existingId; '
          'skipping',
        );
        continue;
      }

      final uddfId = siteData['uddfId'] as String?;
      final lat = siteData['latitude'] as double?;
      final lon = siteData['longitude'] as double?;

      String? country = siteData['country'] as String?;
      String? region = siteData['region'] as String?;

      // Auto-lookup country/region if coordinates exist but fields are empty.
      if (lat != null && lon != null && (country == null || region == null)) {
        try {
          final geocodeResult = await LocationService.instance.reverseGeocode(
            lat,
            lon,
            languageCode: _placeNameLanguage,
          );
          country ??= geocodeResult.country;
          region ??= geocodeResult.region;
        } catch (_) {
          // Geocoding is best-effort
        }
      }

      final difficultyStr = siteData['difficulty'] as String?;
      final difficulty = difficultyStr != null
          ? SiteDifficulty.fromString(difficultyStr)
          : null;

      // Every argument is nullable and copyWith treats null as "keep the
      // existing value", so absent payload fields are preserved.
      final overwrittenSite = existing.copyWith(
        name: name,
        description: siteData['description'] as String?,
        location: (lat != null && lon != null) ? GeoPoint(lat, lon) : null,
        minDepth: siteData['minDepth'] as double?,
        maxDepth: siteData['maxDepth'] as double?,
        difficulty: difficulty,
        country: country,
        region: region,
        rating: siteData['rating'] as double?,
        notes: siteData['notes'] as String?,
        hazards: siteData['hazards'] as String?,
        accessNotes: siteData['accessNotes'] as String?,
        mooringNumber: siteData['mooringNumber'] as String?,
        parkingInfo: siteData['parkingInfo'] as String?,
        altitude: siteData['altitude'] as double?,
      );

      // Core fields and the importer-only metadata columns go out as one
      // UPDATE so a failure can't leave the row half-overwritten.
      final waterType = siteData['waterType'] as String?;
      final bodyOfWater = siteData['bodyOfWater'] as String?;
      await repository.updateSiteWithImportedMetadata(
        overwrittenSite,
        DiveSitesCompanion(
          waterType: waterType != null
              ? Value(waterType)
              : const Value.absent(),
          bodyOfWater: bodyOfWater != null
              ? Value(bodyOfWater)
              : const Value.absent(),
        ),
      );

      if (uddfId != null) idMapping[uddfId] = overwrittenSite;
      count++;
      onProgress?.call(ImportPhase.sites, count, totalWork);
    }

    for (var i = 0; i < items.length; i++) {
      if (!selected.contains(i)) continue;
      final siteData = items[i];
      final name = siteData['name'] as String?;
      if (name == null || name.isEmpty) continue;

      final uddfId = siteData['uddfId'] as String?;
      final lat = siteData['latitude'] as double?;
      final lon = siteData['longitude'] as double?;

      String? country = siteData['country'] as String?;
      String? region = siteData['region'] as String?;

      // Auto-lookup country/region if coordinates exist but fields are empty
      if (lat != null && lon != null && (country == null || region == null)) {
        try {
          final geocodeResult = await LocationService.instance.reverseGeocode(
            lat,
            lon,
            languageCode: _placeNameLanguage,
          );
          country ??= geocodeResult.country;
          region ??= geocodeResult.region;
        } catch (_) {
          // Geocoding is best-effort
        }
      }

      // Parse difficulty enum
      final difficultyStr = siteData['difficulty'] as String?;
      final difficulty = difficultyStr != null
          ? SiteDifficulty.fromString(difficultyStr)
          : null;

      final newSite = DiveSite(
        id: _uuid.v4(),
        diverId: diverId,
        name: name,
        description: siteData['description'] as String? ?? '',
        location: (lat != null && lon != null) ? GeoPoint(lat, lon) : null,
        minDepth: siteData['minDepth'] as double?,
        maxDepth: siteData['maxDepth'] as double?,
        difficulty: difficulty,
        country: country,
        region: region,
        rating: siteData['rating'] as double?,
        notes: siteData['notes'] as String? ?? '',
        hazards: siteData['hazards'] as String?,
        accessNotes: siteData['accessNotes'] as String?,
        mooringNumber: siteData['mooringNumber'] as String?,
        parkingInfo: siteData['parkingInfo'] as String?,
        altitude: siteData['altitude'] as double?,
      );

      final createdSite = await repository.createSite(newSite);

      // Write MacDive site metadata columns that don't flow through the
      // DiveSite domain entity. Only set columns when source provides a value.
      final waterType = siteData['waterType'] as String?;
      final bodyOfWater = siteData['bodyOfWater'] as String?;
      if (waterType != null || bodyOfWater != null) {
        await repository.applyImportedMetadata(
          createdSite.id,
          DiveSitesCompanion(
            waterType: waterType != null
                ? Value(waterType)
                : const Value.absent(),
            bodyOfWater: bodyOfWater != null
                ? Value(bodyOfWater)
                : const Value.absent(),
          ),
        );
      }

      if (uddfId != null) idMapping[uddfId] = createdSite;
      count++;
      onProgress?.call(ImportPhase.sites, count, totalWork);
    }

    return count;
  }

  // -- Equipment Set import --

  Future<int> _importEquipmentSets(
    List<Map<String, dynamic>> items,
    Set<int> selected,
    EquipmentSetRepository repository,
    String diverId,
    Map<String, String> equipmentIdMapping,
    DateTime now,
    ImportProgressCallback? onProgress,
  ) async {
    if (selected.isEmpty) return 0;
    onProgress?.call(ImportPhase.equipmentSets, 0, selected.length);
    var count = 0;

    for (var i = 0; i < items.length; i++) {
      if (!selected.contains(i)) continue;
      final setData = items[i];
      final name = setData['name'] as String?;
      if (name == null || name.isEmpty) continue;

      final newId = _uuid.v4();

      // Map equipment item references to new IDs
      final itemRefsValue = setData['equipmentRefs'];
      final itemRefs = itemRefsValue is List
          ? itemRefsValue.whereType<String>().toList()
          : <String>[];
      final mappedItemIds = <String>[
        for (final oldRef in itemRefs)
          if (equipmentIdMapping.containsKey(oldRef))
            equipmentIdMapping[oldRef]!,
      ];

      final equipmentSet = EquipmentSet(
        id: newId,
        diverId: diverId,
        name: name,
        description: setData['description'] as String? ?? '',
        equipmentIds: mappedItemIds,
        createdAt: now,
        updatedAt: now,
      );

      await repository.createSet(equipmentSet);
      count++;
      onProgress?.call(ImportPhase.equipmentSets, count, selected.length);
    }

    return count;
  }

  // -- Course import --

  Future<int> _importCourses(
    List<Map<String, dynamic>> items,
    Set<int> selected,
    CourseRepository repository,
    String diverId,
    Map<String, String> idMapping,
    Map<String, String> buddyIdMapping,
    DateTime now,
    ImportProgressCallback? onProgress,
  ) async {
    if (selected.isEmpty) return 0;
    onProgress?.call(ImportPhase.courses, 0, selected.length);
    var count = 0;

    for (var i = 0; i < items.length; i++) {
      if (!selected.contains(i)) continue;
      final courseData = items[i];
      final name = courseData['name'] as String?;
      if (name == null || name.isEmpty) continue;

      final uddfId = courseData['uddfId'] as String?;
      final newId = _uuid.v4();

      final agency = _parseCertificationAgency(courseData['agency']);

      // Map instructor buddy reference to new ID
      String? instructorId;
      final instructorRef = courseData['instructorRef'] as String?;
      if (instructorRef != null) {
        instructorId = buddyIdMapping[instructorRef];
      }

      final course = Course(
        id: newId,
        diverId: diverId,
        name: name,
        agency: agency,
        startDate: courseData['startDate'] as DateTime? ?? now,
        completionDate: courseData['completionDate'] as DateTime?,
        instructorId: instructorId,
        instructorName: courseData['instructorName'] as String?,
        instructorNumber: courseData['instructorNumber'] as String?,
        location: courseData['location'] as String?,
        notes: courseData['notes'] as String? ?? '',
        createdAt: now,
        updatedAt: now,
      );

      await repository.createCourse(course);
      if (uddfId != null) idMapping[uddfId] = newId;
      count++;
      onProgress?.call(ImportPhase.courses, count, selected.length);
    }

    return count;
  }

  // -- Dive import --

  /// Group key for the computer a parsed dive names, matching the identity
  /// [DiveComputerRepository.findOrRegisterImportedComputer] dedupes on, so
  /// two spellings of one device share a single registration.
  ///
  /// Null when the source names no model, which is the signal to leave the
  /// dive unattributed rather than register a placeholder device.
  String? _importedComputerKey(Map<String, dynamic> diveData) => computerKeyFor(
    diveData['diveComputerModel'] as String?,
    diveData['diveComputerSerial'] as String?,
  );

  /// The `<source>` entries belonging to one parsed dive.
  ///
  /// Submersion's own export writes `<dive id="dive_<uuid>">`, and the parser
  /// keeps that attribute verbatim as `sourceUuid`, so the ref is already
  /// prefixed. A file whose dive ids are bare needs the prefix added. Both
  /// shapes are tried rather than assuming either, and this lives in one
  /// place so the restore and the computer registration cannot resolve a dive
  /// differently.
  static List<Map<String, dynamic>> _entriesForDive(
    Map<String, dynamic> diveData,
    Map<String, List<Map<String, dynamic>>> dataSourcesByDiveRef,
  ) {
    final sourceUuid = diveData['sourceUuid'] as String?;
    if (sourceUuid == null) return const [];
    return dataSourcesByDiveRef[sourceUuid] ??
        dataSourcesByDiveRef['dive_$sourceUuid'] ??
        const [];
  }

  /// The registration key for a model and serial pair.
  ///
  /// Shared so a restored `<source>` entry resolves its computer exactly the
  /// way a dive does. Serial wins when present, which is why this cannot be
  /// approximated as "model plus serial" at a second call site.
  static String? computerKeyFor(String? model, String? serial) {
    final normalizedModel = normalizeComputerIdentityPart(model);
    if (normalizedModel.isEmpty) return null;
    final normalizedSerial = normalizeComputerIdentityPart(serial);
    return normalizedSerial.isNotEmpty
        ? 'serial:$normalizedSerial'
        : 'model:$normalizedModel';
  }

  /// Register every distinct computer the selected dives name, returning the
  /// registry id for each [_importedComputerKey].
  ///
  /// Runs once per import rather than per dive so a hundred dives off one
  /// computer cost one registration lookup, not a hundred.
  ///
  /// Best-effort per device, mirroring `_relinkOrphanedRows`: attribution is
  /// cosmetic next to the dives themselves, so a registry failure degrades
  /// that one device to unattributed instead of costing the user the whole
  /// import. The dive still keeps its `dive_computer_model` snapshot, which
  /// is what the Details card renders.
  Future<Map<String, String>> _registerImportedComputers(
    List<Map<String, dynamic>> items,
    List<int> selected,
    String diverId,
    DiveComputerRepository? repository, {
    Map<String, List<Map<String, dynamic>>> dataSourcesByDiveRef = const {},
  }) async {
    if (repository == null) return const {};

    final idByKey = <String, String>{};

    Future<void> register({
      required String? model,
      String? manufacturer,
      String? serial,
      String? firmware,
    }) async {
      final key = computerKeyFor(model, serial);
      if (key == null || idByKey.containsKey(key)) return;
      try {
        final computer = await repository.findOrRegisterImportedComputer(
          model: model!,
          manufacturer: manufacturer,
          serialNumber: serial,
          firmwareVersion: firmware,
          diverId: diverId,
        );
        if (computer != null) idByKey[key] = computer.id;
      } catch (e, stackTrace) {
        _log.error(
          'Failed to register imported dive computer for "$key"; '
          'its dives stay unattributed',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    for (final i in selected) {
      final diveData = items[i];
      await register(
        model: diveData['diveComputerModel'] as String?,
        manufacturer: diveData['diveComputerManufacturer'] as String?,
        serial: diveData['diveComputerSerial'] as String?,
        firmware: diveData['diveComputerFirmware'] as String?,
      );
    }

    // A restored multi-source dive names computers its own snapshot cannot:
    // the dive carries only its primary computer's model and serial, so a
    // second computer would go unregistered and its restored source row would
    // lose the registry link. Registering from the entries too is what keeps
    // the restore lossless.
    //
    // Only the SELECTED dives' entries, matching the loop above. Ranging over
    // every ref in the file would register devices belonging to dives the
    // user chose not to import, leaving the registry listing computers that
    // own nothing.
    for (final i in selected) {
      for (final entry in _entriesForDive(items[i], dataSourcesByDiveRef)) {
        await register(
          model: entry['computerModel'] as String?,
          serial: entry['computerSerial'] as String?,
        );
      }
    }

    return idByKey;
  }

  /// One companion per restored `<source>` entry.
  ///
  /// Exactly one row must end up primary. A hand-edited or malformed file
  /// could claim zero or several, and a dive with no primary source would
  /// break primary-source resolution for that dive permanently. The first
  /// entry claiming it wins; if none claims it, the first entry is promoted.
  ///
  /// Computers resolve through model and serial, NOT through the dump's
  /// `<link ref="computer_...">`: [computerIdByKey] is keyed by
  /// [computerKeyFor], and the exported computer id belongs to an id space
  /// this importer never uses.
  List<DiveDataSourcesCompanion> _restoredSourceCompanions({
    required List<Map<String, dynamic>> entries,
    required String diveId,
    required Map<String, String> computerIdByKey,
    required String? fallbackComputerId,
    required String? sourceFileName,
    required DateTime now,
  }) {
    var primaryIndex = entries.indexWhere((e) => e['isPrimary'] == true);
    if (primaryIndex < 0) primaryIndex = 0;

    return [
      for (var i = 0; i < entries.length; i++)
        _companionForEntry(
          entries[i],
          diveId: diveId,
          isPrimary: i == primaryIndex,
          computerId:
              computerIdByKey[computerKeyFor(
                entries[i]['computerModel'] as String?,
                entries[i]['computerSerial'] as String?,
              )] ??
              (i == primaryIndex ? fallbackComputerId : null),
          sourceFileName: sourceFileName,
          now: now,
        ),
    ];
  }

  DiveDataSourcesCompanion _companionForEntry(
    Map<String, dynamic> entry, {
    required String diveId,
    required bool isPrimary,
    required String? computerId,
    required String? sourceFileName,
    required DateTime now,
  }) {
    Value<T?> maybe<T>(String key) {
      final value = entry[key];
      return value == null ? const Value.absent() : Value(value as T);
    }

    return DiveDataSourcesCompanion(
      id: Value(_uuid.v4()),
      diveId: Value(diveId),
      isPrimary: Value(isPrimary),
      computerId: Value(computerId),
      computerModel: maybe<String>('computerModel'),
      computerSerial: maybe<String>('computerSerial'),
      sourceFormat: maybe<String>('sourceFormat'),
      sourceFileName: Value(
        entry['sourceFileName'] as String? ?? sourceFileName,
      ),
      sourceFileFormat: Value(entry['sourceFileFormat'] as String? ?? 'uddf'),
      sourceUuid: maybe<String>('sourceUuid'),
      rawData: maybe<Uint8List>('rawData'),
      rawFingerprint: maybe<Uint8List>('rawFingerprint'),
      descriptorVendor: maybe<String>('descriptorVendor'),
      descriptorProduct: maybe<String>('descriptorProduct'),
      descriptorModel: maybe<int>('descriptorModel'),
      libdivecomputerVersion: maybe<String>('libdivecomputerVersion'),
      mergeSourceSlot: maybe<int>('mergeSourceSlot'),
      timeOffsetSeconds: maybe<int>('timeOffsetSeconds'),
      maxDepth: maybe<double>('maxDepth'),
      avgDepth: maybe<double>('avgDepth'),
      duration: maybe<int>('duration'),
      waterTemp: maybe<double>('waterTemp'),
      entryLatitude: maybe<double>('entryLatitude'),
      entryLongitude: maybe<double>('entryLongitude'),
      exitLatitude: maybe<double>('exitLatitude'),
      exitLongitude: maybe<double>('exitLongitude'),
      entryTime: maybe<DateTime>('entryTime'),
      exitTime: maybe<DateTime>('exitTime'),
      maxAscentRate: maybe<double>('maxAscentRate'),
      maxDescentRate: maybe<double>('maxDescentRate'),
      surfaceInterval: maybe<int>('surfaceInterval'),
      cns: maybe<double>('cns'),
      otu: maybe<double>('otu'),
      decoAlgorithm: maybe<String>('decoAlgorithm'),
      gradientFactorLow: maybe<int>('gradientFactorLow'),
      gradientFactorHigh: maybe<int>('gradientFactorHigh'),
      lastParsedAt: maybe<DateTime>('lastParsedAt'),
      // The entry's own stamps, not the import clock. importedAt is shown as
      // "Imported" in the data sources panel, so taking `now` would relabel a
      // 2019 dive with the day of the restore.
      importedAt: Value(entry['importedAt'] as DateTime? ?? now),
      createdAt: Value(entry['createdAt'] as DateTime? ?? now),
    );
  }

  Future<_DiveImportResult> _importDives(
    List<Map<String, dynamic>> items,
    Set<int> selected,
    ImportRepositories repos,
    String diverId, {
    required Map<String, String> tripIdMapping,
    required Map<String, String> equipmentIdMapping,
    required Map<String, String> buddyIdMapping,
    required Map<String, String> diveCenterIdMapping,
    required Map<String, String> tagIdMapping,
    required Map<String, DiveSite> siteIdMapping,
    required Map<String, String> courseIdMapping,
    String? sourceFileName,
    bool retainSourceDiveNumbers = false,
    required DateTime now,
    Map<String, List<Map<String, dynamic>>> dataSourcesByDiveRef = const {},
    ImportProgressCallback? onProgress,
    ImportCancellationToken? cancelToken,
  }) async {
    if (selected.isEmpty) return const _DiveImportResult(0, 0);
    onProgress?.call(ImportPhase.dives, 0, selected.length);
    var count = 0;
    var restoredDataSources = 0;
    final importedDiveIds = <String>[];
    final diveIdByIndex = <int, String>{};
    final inlineBuddyIds = <String>{};

    // Sort selected indices by dateTime (oldest first) for sequential
    // numbering. An undated dive is stored at [now] further down, so it has
    // to sort as [now] here too: keying it as year zero handed the newest
    // row in the batch the lowest dive number (#239).
    final sortedSelected = selected.toList()
      ..sort((a, b) {
        final aTime = items[a]['dateTime'] as DateTime? ?? now;
        final bTime = items[b]['dateTime'] as DateTime? ?? now;
        final byTime = aTime.compareTo(bTime);
        // Dives sharing a timestamp keep the order the file lists them in.
        // List.sort makes no stability guarantee, so a tie left to it can
        // come out in any order, and a logbook of dives entered by hand
        // arrives with a whole day of them tied at midnight.
        return byTime != 0 ? byTime : a.compareTo(b);
      });

    // Auto-assign dive numbers starting from the next available number,
    // unless the user opted to retain source file numbering.
    var nextDiveNumber = retainSourceDiveNumbers
        ? null
        : await repos.diveRepository.getNextDiveNumber(diverId: diverId);

    // One instance for the run: its lookup cache collapses a batch of dives
    // at the same location into a single elevation request.
    final altitudeEnricher = DiveAltitudeEnricher();

    // Register the computers this batch names, once per distinct device,
    // before any dive is written. The filter, the statistics SQL, and "View
    // dives from this computer" all read the `dive_computers` registry
    // rather than the per-dive display snapshots, so without this a
    // file-only logbook shows a computer on every dive and still reports
    // "No dive computers registered" (#1288).
    final computerIdByKey = await _registerImportedComputers(
      items,
      sortedSelected,
      diverId,
      repos.diveComputerRepository,
      dataSourcesByDiveRef: dataSourcesByDiveRef,
    );

    for (final i in sortedSelected) {
      if (cancelToken?.isCancelled ?? false) break;

      final diveData = items[i];

      // Build profile (include setpoint/ppO2 sensor readings)
      final profileData = diveData['profile'] as List<Map<String, dynamic>>?;
      final profile =
          profileData
              ?.map(
                (p) => DiveProfilePoint(
                  timestamp: p['timestamp'] as int? ?? 0,
                  depth: asDoubleOrNull(p['depth']) ?? 0.0,
                  temperature: asDoubleOrNull(p['temperature']),
                  heartRate: p['heartRate'] as int?,
                  cns: asDoubleOrNull(p['cns']),
                  ndl: p['ndl'] as int?,
                  tts: p['tts'] as int?,
                  ceiling: asDoubleOrNull(p['ceiling']),
                  rbt: p['rbt'] as int?,
                  decoType: p['decoType'] as int?,
                  setpoint: asDoubleOrNull(p['setpoint']),
                  ppO2: asDoubleOrNull(p['ppO2']),
                  o2Sensor1: asDoubleOrNull(p['o2Sensor1']),
                  o2Sensor2: asDoubleOrNull(p['o2Sensor2']),
                  o2Sensor3: asDoubleOrNull(p['o2Sensor3']),
                  o2Sensor4: asDoubleOrNull(p['o2Sensor4']),
                  o2Sensor5: asDoubleOrNull(p['o2Sensor5']),
                  o2Sensor6: asDoubleOrNull(p['o2Sensor6']),
                  // UDDF carries no millivolt field; these arrive only via the
                  // libdivecomputer path that shares this map (issue #810).
                  o2SensorMv1: p['o2SensorMv1'] as int?,
                  o2SensorMv2: p['o2SensorMv2'] as int?,
                  o2SensorMv3: p['o2SensorMv3'] as int?,
                  o2SensorMv4: p['o2SensorMv4'] as int?,
                  o2SensorMv5: p['o2SensorMv5'] as int?,
                  o2SensorMv6: p['o2SensorMv6'] as int?,
                ),
              )
              .toList() ??
          [];

      // Build tanks
      final tanks = _buildTanks(diveData);

      // Link to imported site
      DiveSite? linkedSite;
      final siteDataMap = diveData['site'] as Map<String, dynamic>?;
      if (siteDataMap != null) {
        final uddfSiteId = siteDataMap['uddfId'] as String?;
        if (uddfSiteId != null) linkedSite = siteIdMapping[uddfSiteId];
      }
      // Fallback: CSV imports store siteId directly on the dive map.
      if (linkedSite == null) {
        final directSiteId = diveData['siteId'] as String?;
        if (directSiteId != null) linkedSite = siteIdMapping[directSiteId];
      }

      // Link to imported trip
      String? linkedTripId;
      final tripRef = diveData['tripRef'] as String?;
      if (tripRef != null) linkedTripId = tripIdMapping[tripRef];

      // Link to imported dive center
      DiveCenter? linkedDiveCenter;
      final diveCenterRef = diveData['diveCenterRef'] as String?;
      if (diveCenterRef != null) {
        final newCenterId = diveCenterIdMapping[diveCenterRef];
        if (newCenterId != null) {
          linkedDiveCenter = await repos.diveCenterRepository.getDiveCenterById(
            newCenterId,
          );
        }
      }

      // Link to imported course
      String? linkedCourseId;
      final courseRef = diveData['courseRef'] as String?;
      if (courseRef != null) linkedCourseId = courseIdMapping[courseRef];

      // Link to imported equipment
      final linkedEquipment = await _resolveEquipmentRefs(
        diveData['equipmentRefs'],
        equipmentIdMapping,
        repos.equipmentRepository,
      );

      final notes = diveData['notes'] as String? ?? '';

      // Parse sightings
      final sightings = _buildSightings(diveData);

      // Build DiveWeight objects from parsed weight data
      final diveId = _uuid.v4();
      final weightsData = diveData['weights'] as List<Map<String, dynamic>>?;
      final weights =
          weightsData
              ?.map(
                (w) => DiveWeight(
                  id: _uuid.v4(),
                  diveId: diveId,
                  weightType: w['type'] as WeightType? ?? WeightType.integrated,
                  amountKg: w['amount'] as double? ?? 0.0,
                  notes: w['notes'] as String? ?? '',
                ),
              )
              .toList() ??
          [];

      // Formats that report a single ballast total rather than a breakdown
      // (MacDive's ZWEIGHT, UDDF <leadquantity>, Shearwater Cloud) land here.
      // These used to be appended to the dive notes as "Weight used: N kg",
      // which left the Weights section empty and the value unusable for
      // weighting statistics (#912).
      if (weights.isEmpty) {
        final totalKg =
            asDoubleOrNull(diveData['weightUsed']) ??
            asDoubleOrNull(diveData['weightAmount']);
        if (totalKg != null && totalKg > 0) {
          weights.add(
            DiveWeight(
              id: _uuid.v4(),
              diveId: diveId,
              weightType:
                  _parseEnum(diveData['weightType'], WeightType.values) ??
                  WeightType.integrated,
              amountKg: totalKg,
            ),
          );
        }
      }

      final dateTime = diveData['dateTime'] as DateTime? ?? now;
      // CSV imports provide only 'duration' (used as bottomTime); fall back
      // to it for runtime so the total dive time is populated.
      final durationValue = diveData['duration'] as Duration?;
      final runtime = diveData['runtime'] as Duration? ?? durationValue;
      // `duration` is ambiguous across import formats: some parsers (FIT) put a
      // genuine bottom time here, while others (Subsurface) put total runtime,
      // which would make bottom time equal runtime. Only trust `duration` as a
      // real bottom time when it differs from runtime; otherwise leave it null
      // so the profile-based auto-calculation below can derive it.
      final bottomTimeSeed = durationValue != null && durationValue != runtime
          ? durationValue
          : null;
      final parsedEntryTime = diveData['entryTime'] as DateTime?;
      final entryTime = parsedEntryTime ?? dateTime;
      final exitTime = runtime != null ? dateTime.add(runtime) : null;
      // Parser-emitted profile events; consumed below for the deco default
      // and persisted as ProfileEvents after the dive row is created.
      final eventMaps = (diveData['events'] as List?)
          ?.cast<Map<String, dynamic>>();
      // UDDF sources emit events under 'profileEvents' instead of 'events'
      // (see the NOTE ON UDDF DIVERGENCE below). Only 'events' is persisted
      // as ProfileEvents, but both shapes should count toward deco detection.
      final decoDetectionEventMaps =
          eventMaps ??
          (diveData['profileEvents'] as List?)?.cast<Map<String, dynamic>>();
      // Sources without an explicit dive type used to land every dive on
      // 'recreational', including dives whose samples show mandatory deco
      // (ceiling, deco stops, exhausted NDL). Default those to the built-in
      // 'technical' type instead.
      final defaultDiveType =
          DecoDiveDetector.isDecoDive(
            samples: profile.map(
              (p) => DecoDiveSample(
                depth: p.depth,
                ndl: p.ndl,
                ceiling: p.ceiling,
                decoType: p.decoType,
                tts: p.tts,
              ),
            ),
            eventMaps: decoDetectionEventMaps,
          )
          ? 'technical'
          : 'recreational';
      final diveTypeIds =
          (diveData['diveTypeIds'] as List?)?.cast<String>() ??
          [diveData['diveType'] as String? ?? defaultDiveType];

      // Parse dive mode, planner flag, and favorite
      final diveMode =
          _parseEnum(diveData['diveMode'], DiveMode.values) ?? DiveMode.oc;
      final isPlanned = diveData['isPlanned'] as bool? ?? false;
      final isFavorite = diveData['isFavorite'] as bool? ?? false;
      final excludedFromStats = diveData['excludedFromStats'] as bool? ?? false;
      final excludedFromGasStats =
          diveData['excludedFromGasStats'] as bool? ?? false;

      // Build diluent gas mix (if present)
      final diluentO2 = diveData['diluentO2'] as double?;
      final diluentHe = diveData['diluentHe'] as double?;
      final diluentGas = (diluentO2 != null || diluentHe != null)
          ? GasMix(o2: diluentO2 ?? 21.0, he: diluentHe ?? 0.0)
          : null;

      // Build scrubber info (if present)
      final scrubberType = diveData['scrubberType'] as String?;
      final scrubberDur = diveData['scrubberDurationMinutes'] as int?;
      final scrubberRem = diveData['scrubberRemainingMinutes'] as int?;
      final scrubber = scrubberType != null
          ? ScrubberInfo(
              type: scrubberType,
              ratedMinutes: scrubberDur,
              remainingMinutes: scrubberRem,
            )
          : null;

      final diveName = (diveData['name'] as String?)?.trim();
      var dive = Dive(
        id: diveId,
        diverId: diverId,
        name: diveName != null && diveName.isNotEmpty ? diveName : null,
        diveNumber: nextDiveNumber != null
            ? nextDiveNumber++
            : diveData['diveNumber'] as int?,
        dateTime: dateTime,
        entryTime: entryTime,
        exitTime: exitTime,
        bottomTime: bottomTimeSeed,
        runtime: runtime,
        maxDepth: asDoubleOrNull(diveData['maxDepth']),
        avgDepth: asDoubleOrNull(diveData['avgDepth']),
        waterTemp: asDoubleOrNull(diveData['waterTemp']),
        airTemp: asDoubleOrNull(diveData['airTemp']),
        surfacePressure: asDoubleOrNull(diveData['surfacePressure']),
        surfaceInterval: diveData['surfaceInterval'] as Duration?,
        decoAlgorithm: diveData['decoAlgorithm'] as String?,
        gradientFactorLow: diveData['gradientFactorLow'] as int?,
        gradientFactorHigh: diveData['gradientFactorHigh'] as int?,
        diveComputerModel: diveData['diveComputerModel'] as String?,
        diveComputerSerial: diveData['diveComputerSerial'] as String?,
        diveComputerFirmware: diveData['diveComputerFirmware'] as String?,
        buddy: diveData['buddy'] as String?,
        diveMaster: diveData['diveMaster'] as String?,
        rating: diveData['rating'] as int?,
        notes: notes,
        visibility: _parseEnum(diveData['visibility'], Visibility.values),
        visibilityMeters: diveData['visibilityMeters'] as double?,
        diveTypeIds: diveTypeIds,
        profile: profile,
        tanks: tanks,
        weights: weights,
        site: linkedSite,
        tripId: linkedTripId,
        diveCenter: linkedDiveCenter,
        equipment: linkedEquipment,
        sightings: sightings,
        currentDirection: _parseEnum(
          diveData['currentDirection'],
          CurrentDirection.values,
        ),
        currentStrength: _parseEnum(
          diveData['currentStrength'],
          CurrentStrength.values,
        ),
        swellHeight: asDoubleOrNull(diveData['swellHeight']),
        entryMethod: _parseEnum(diveData['entryMethod'], EntryMethod.values),
        exitMethod: _parseEnum(diveData['exitMethod'], EntryMethod.values),
        waterType: _parseEnum(diveData['waterType'], WaterType.values),
        altitude: asDoubleOrNull(diveData['altitude']),
        // Entry/exit GPS, so file-imported dives become eligible for the
        // existing site matcher.
        entryLocation: _geoPoint(diveData['latitude'], diveData['longitude']),
        exitLocation: _geoPoint(
          diveData['exitLatitude'],
          diveData['exitLongitude'],
        ),
        // Dive mode and rebreather fields
        diveMode: diveMode,
        isPlanned: isPlanned,
        isFavorite: isFavorite,
        excludedFromStats: excludedFromStats,
        excludedFromGasStats: excludedFromGasStats,
        courseId: linkedCourseId,
        setpointLow: asDoubleOrNull(diveData['setpointLow']),
        setpointHigh: asDoubleOrNull(diveData['setpointHigh']),
        setpointDeco: asDoubleOrNull(diveData['setpointDeco']),
        scrType: diveData['scrType'] as ScrType?,
        scrInjectionRate: asDoubleOrNull(diveData['scrInjectionRate']),
        scrAdditionRatio: asDoubleOrNull(diveData['scrAdditionRatio']),
        scrOrificeSize: diveData['scrOrificeSize'] as String?,
        assumedVo2: asDoubleOrNull(diveData['assumedVo2']),
        diluentGas: diluentGas,
        loopO2Min: asDoubleOrNull(diveData['loopO2Min']),
        loopO2Max: asDoubleOrNull(diveData['loopO2Max']),
        loopO2Avg: asDoubleOrNull(diveData['loopO2Avg']),
        loopVolume: asDoubleOrNull(diveData['loopVolume']),
        scrubber: scrubber,
      );

      // Auto-calculate bottom time from profile if not set
      if (dive.bottomTime == null && dive.profile.isNotEmpty) {
        final calculatedBottomTime = dive.calculateBottomTimeFromProfile();
        if (calculatedBottomTime != null) {
          dive = dive.copyWith(bottomTime: calculatedBottomTime);
        }
      }
      // If bottom time still could not be derived (no profile, or a profile the
      // heuristic could not resolve), fall back to the source duration so the
      // field is not left empty for minimal imports such as CSV.
      if (dive.bottomTime == null && durationValue != null) {
        dive = dive.copyWith(bottomTime: durationValue);
      }

      await repos.diveRepository.createDive(dive);

      // createDive's companion deliberately omits computer_id, so attribution
      // has to be an explicit second write (#1288).
      final computerKey = _importedComputerKey(diveData);
      final computerId = computerKey == null
          ? null
          : computerIdByKey[computerKey];
      if (computerId != null) {
        // Best-effort for the same reason as the registration above, and more
        // pressingly: the dive is already committed, so throwing here would
        // abort the loop and leave a half-imported logbook behind.
        //
        // The provenance row below is still stamped on failure, deliberately.
        // The #1064 beforeOpen heal adopts dives.computer_id from exactly that
        // column, so leaving it is what recovers the attribution on the next
        // open; clearing it for symmetry would discard the recovery.
        try {
          await repos.diveComputerRepository?.attributeDiveToComputer(
            diveId: diveId,
            computerId: computerId,
          );
        } catch (e, stackTrace) {
          _log.error(
            'Failed to attribute imported dive $diveId to computer '
            '$computerId; the data source keeps the link, so the beforeOpen '
            'self-heal will adopt it on the next open',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      await DiveEquipmentDefaulter().applyForImportedDive(dive);
      await ChecklistDiveLinker().applyForImportedDive(dive);
      await altitudeEnricher.applyForImportedDive(dive);
      // After the defaulter, never before: the defaulter bails on a dive
      // that already has equipment, so linking first would suppress the
      // diver's default and geofenced sets.
      await DiveComputerGearLinker().linkComputerGearForDive(diveId: dive.id);
      importedDiveIds.add(diveId);
      diveIdByIndex[i] = diveId;

      // Write MacDive dive metadata columns that don't flow through the Dive
      // domain entity. Also plug `weather` into the existing weatherDescription
      // column (it wasn't being populated for UDDF imports). Only issue the
      // UPDATE when at least one value is present to avoid a no-op write.
      final boatName = diveData['boatName'] as String?;
      final boatCaptain = diveData['boatCaptain'] as String?;
      final diveOperator = diveData['diveOperator'] as String?;
      final surfaceConditions = diveData['surfaceConditions'] as String?;
      final weather = diveData['weather'] as String?;
      if (boatName != null ||
          boatCaptain != null ||
          diveOperator != null ||
          surfaceConditions != null ||
          weather != null) {
        await repos.diveRepository.applyImportedMetadata(
          diveId,
          DivesCompanion(
            boatName: boatName != null ? Value(boatName) : const Value.absent(),
            boatCaptain: boatCaptain != null
                ? Value(boatCaptain)
                : const Value.absent(),
            diveOperator: diveOperator != null
                ? Value(diveOperator)
                : const Value.absent(),
            surfaceConditions: surfaceConditions != null
                ? Value(surfaceConditions)
                : const Value.absent(),
            weatherDescription: weather != null
                ? Value(weather)
                : const Value.absent(),
          ),
        );
      }

      // Store per-tank pressure data
      if (profileData != null && tanks.isNotEmpty) {
        await _storeTankPressures(
          profileData,
          tanks,
          diveId,
          repos.tankPressureRepository,
        );
      }

      // Insert gas switches
      final gasSwitchesData =
          diveData['gasSwitches'] as List<Map<String, dynamic>>?;
      if (gasSwitchesData != null && gasSwitchesData.isNotEmpty) {
        // Build lookups from both UDDF tank ID and UDDF gas mix UUID to the
        // persisted tank row id. MacDive-style switches reference a gas mix
        // UUID (via <switchmix ref>), while top-level <gasswitches>
        // entries reference a tank UUID (via <tankref>); we accept either.
        // FIT imports carry no refs at all and address tanks positionally
        // via `tankIndex`.
        final tankIdByRef = <String, String>{};
        final tankIdByGasMixRef = <String, String>{};
        final tanksData = diveData['tanks'] as List<Map<String, dynamic>>?;
        if (tanksData != null) {
          for (var i = 0; i < tanks.length && i < tanksData.length; i++) {
            final tank = tanks[i];
            final tankData = tanksData[i];
            final ref = (tankData['uddfTankId'] as String?)?.trim();
            if (ref != null && ref.isNotEmpty) {
              tankIdByRef[ref] = tank.id;
            }
            final gasMixRef = (tankData['uddfGasMixRef'] as String?)?.trim();
            // First tank linked to a given gas wins; later tanks sharing the
            // same gas don't overwrite. This is a pragmatic resolution for
            // dives where multiple tanks carry the same mix.
            if (gasMixRef != null &&
                gasMixRef.isNotEmpty &&
                !tankIdByGasMixRef.containsKey(gasMixRef)) {
              tankIdByGasMixRef[gasMixRef] = tank.id;
            }
          }
        }

        final switches = gasSwitchesData
            .map((gs) {
              final timestamp = gs['timestamp'] as int?;
              if (timestamp == null) return null;
              final tankRef = (gs['tankRef'] as String?)?.trim();
              final gasMixRef = (gs['gasMixRef'] as String?)?.trim();
              String? tankId;
              if (tankRef != null && tankRef.isNotEmpty) {
                tankId = tankIdByRef[tankRef];
              }
              if ((tankId == null || tankId.isEmpty) &&
                  gasMixRef != null &&
                  gasMixRef.isNotEmpty) {
                tankId = tankIdByGasMixRef[gasMixRef];
              }
              if (tankId == null || tankId.isEmpty) {
                final tankIndex = gs['tankIndex'] as int?;
                if (tankIndex != null &&
                    tankIndex >= 0 &&
                    tankIndex < tanks.length) {
                  tankId = tanks[tankIndex].id;
                }
              }
              if (tankId == null || tankId.isEmpty) return null;
              return GasSwitch(
                id: _uuid.v4(),
                diveId: diveId,
                timestamp: timestamp,
                tankId: tankId,
                depth: gs['depth'] as double?,
                createdAt: now,
              );
            })
            .whereType<GasSwitch>()
            .toList();
        if (switches.isNotEmpty) {
          await repos.diveRepository.insertGasSwitches(switches);
        }
      }

      // Persist profile events emitted by the parser. Currently supported (Slice C + C.2):
      // setpointChange, bookmark, safetyStopStart, decoStopStart, decoViolation,
      // ascentRateWarning, ppO2High, ppO2Low. Future slices may add more types as
      // real SSRF exports surface additional event names.
      //
      // NOTE ON UDDF DIVERGENCE: SSRF's subsurface_xml_parser emits events under
      // `diveData['events']` (read here). The UDDF path in
      // `uddf_full_import_service.dart` emits events under
      // `diveData['profileEvents']` — a pre-existing key mismatch. UDDF-side
      // event persistence is intentionally out of scope for Slice C; when a
      // future slice adds UDDF event import, unify the keys or add a second
      // consumer block here.
      if (eventMaps != null && eventMaps.isNotEmpty) {
        final events = <ProfileEvent>[];
        for (final m in eventMaps) {
          // Defensive cast: malformed/partial events (missing/non-string
          // eventType) are forward-compat noise, not errors. Skip quietly.
          final eventTypeStr = m['eventType'] as String?;
          if (eventTypeStr == null || eventTypeStr.isEmpty) continue;
          final timestamp = m['timestamp'] as int?;
          if (timestamp == null) continue;
          final value = m['value'] as double?;
          final description = m['description'] as String?;
          switch (eventTypeStr) {
            case 'setpointChange':
              if (value == null) continue;
              events.add(
                ProfileEvent.setpointChange(
                  id: _uuid.v4(),
                  diveId: diveId,
                  timestamp: timestamp,
                  setpoint: value,
                  createdAt: now,
                ),
              );
              break;

            case 'bookmark':
              events.add(
                ProfileEvent.bookmark(
                  id: _uuid.v4(),
                  diveId: diveId,
                  timestamp: timestamp,
                  note: description,
                  createdAt: now,
                  source:
                      EventSource.imported, // override `user` factory default
                ),
              );
              break;

            case 'safetyStopStart':
              events.add(
                ProfileEvent.safetyStop(
                  id: _uuid.v4(),
                  diveId: diveId,
                  timestamp: timestamp,
                  depth:
                      0.0, // parser does not emit depth on event elements; placeholder used across safety/deco/ascent cases. Future enrichment slice may interpolate from samples.
                  createdAt: now,
                  isStart: true,
                  source: EventSource
                      .imported, // override `computed` factory default
                ),
              );
              break;

            case 'decoStopStart':
              events.add(
                ProfileEvent.decoStop(
                  id: _uuid.v4(),
                  diveId: diveId,
                  timestamp: timestamp,
                  depth: 0.0,
                  createdAt: now,
                  isStart: true,
                  // factory default is already `imported`; no override needed
                ),
              );
              break;

            case 'decoViolation':
              events.add(
                ProfileEvent.decoViolation(
                  id: _uuid.v4(),
                  diveId: diveId,
                  timestamp: timestamp,
                  value: value,
                  createdAt: now,
                  // factory default is already `imported`; no override needed
                ),
              );
              break;

            case 'ascentRateWarning':
              if (value == null) {
                _log.warning(
                  'Skipping ascentRateWarning event with missing value',
                );
                continue; // match setpointChange/ppO2 null-guard pattern
              }
              events.add(
                ProfileEvent.ascentRateWarning(
                  id: _uuid.v4(),
                  diveId: diveId,
                  timestamp: timestamp,
                  depth: 0.0,
                  rate: value,
                  createdAt: now,
                  source: EventSource
                      .imported, // override `computed` factory default
                ),
              );
              break;

            case 'ppO2High':
              if (value == null) {
                _log.warning('Skipping ppO2High event with missing value');
                continue; // match setpointChange null-guard pattern
              }
              events.add(
                ProfileEvent.ppO2High(
                  id: _uuid.v4(),
                  diveId: diveId,
                  timestamp: timestamp,
                  value: value,
                  createdAt: now,
                ),
              );
              break;

            case 'ppO2Low':
              if (value == null) {
                _log.warning('Skipping ppO2Low event with missing value');
                continue; // match setpointChange null-guard pattern
              }
              events.add(
                ProfileEvent.ppO2Low(
                  id: _uuid.v4(),
                  diveId: diveId,
                  timestamp: timestamp,
                  value: value,
                  createdAt: now,
                ),
              );
              break;

            default:
              // Unknown event type — skip with a log line so future types can
              // be tracked. Do not throw: unknown types are forward-compat
              // noise, not errors.
              _log.warning(
                'Skipping unknown profile event type from parser: $eventTypeStr',
              );
              break;
          }
        }
        if (events.isNotEmpty) {
          await repos.diveRepository.insertProfileEvents(events);
        }
      }

      // Link buddies to dive
      final linkedIds = await _linkBuddiesToDive(
        diveData,
        diveId,
        diverId,
        buddyIdMapping,
        repos.buddyRepository,
      );
      inlineBuddyIds.addAll(linkedIds);

      // Link tags to dive
      await _linkTagsToDive(
        diveData,
        diveId,
        tagIdMapping,
        repos.tagRepository,
      );

      // Provenance. A dive that arrived with <source> entries has its source
      // rows defined by them, so the synthesised row below is NOT written:
      // writing both would leave the dive with one more source than it was
      // exported with. A dive with no entries keeps today's behaviour
      // exactly, which is every foreign UDDF file and every older export.
      final sourceEntries = _entriesForDive(diveData, dataSourcesByDiveRef);

      if (sourceEntries.isEmpty) {
        await repos.diveRepository.saveComputerReading(
          DiveDataSourcesCompanion(
            id: Value(_uuid.v4()),
            diveId: Value(diveId),
            isPrimary: const Value(true),
            computerId: Value(computerId),
            computerModel: Value(diveData['diveComputerModel'] as String?),
            computerSerial: Value(diveData['diveComputerSerial'] as String?),
            sourceFileName: Value(sourceFileName),
            sourceFileFormat: const Value('uddf'),
            sourceUuid: Value(diveData['sourceUuid'] as String?),
            maxDepth: Value(asDoubleOrNull(diveData['maxDepth'])),
            avgDepth: Value(asDoubleOrNull(diveData['avgDepth'])),
            duration: Value(dive.bottomTime?.inSeconds),
            waterTemp: Value(asDoubleOrNull(diveData['waterTemp'])),
            entryTime: Value(dive.entryTime),
            exitTime: Value(dive.exitTime),
            cns: Value(asDoubleOrNull(diveData['cnsEnd'])),
            otu: Value(asDoubleOrNull(diveData['otu'])),
            decoAlgorithm: Value(diveData['decoAlgorithm'] as String?),
            gradientFactorLow: Value(diveData['gradientFactorLow'] as int?),
            gradientFactorHigh: Value(diveData['gradientFactorHigh'] as int?),
            importedAt: Value(now),
            createdAt: Value(now),
          ),
        );
      } else {
        // One insert for the whole batch, so the profile-adoption rule sees
        // the dive's real source count rather than a half-written dive.
        await repos.diveRepository.saveComputerReadings(
          _restoredSourceCompanions(
            entries: sourceEntries,
            diveId: diveId,
            computerIdByKey: computerIdByKey,
            fallbackComputerId: computerId,
            sourceFileName: sourceFileName,
            now: now,
          ),
        );
        restoredDataSources += sourceEntries.length;
      }

      count++;
      onProgress?.call(ImportPhase.dives, count, selected.length);
    }

    return _DiveImportResult(
      count,
      inlineBuddyIds.length,
      importedDiveIds,
      diveIdByIndex,
      restoredDataSources,
    );
  }

  // -- Dive helper methods --

  GeoPoint? _geoPoint(dynamic lat, dynamic lng) {
    final latVal = asDoubleOrNull(lat);
    final lngVal = asDoubleOrNull(lng);
    if (latVal == null || lngVal == null) return null;
    return GeoPoint(latVal, lngVal);
  }

  List<DiveTank> _buildTanks(Map<String, dynamic> diveData) {
    final tanksData = diveData['tanks'] as List<Map<String, dynamic>>?;
    if (tanksData != null && tanksData.isNotEmpty) {
      final processedTanks = _applyDefaultTankToImports
          ? applyTankDefaultsToList(
              tanksData,
              defaultPreset: _defaultTankPreset,
              defaultStartPressure: _defaultStartPressure,
            )
          : tanksData;
      return processedTanks.map((t) {
        TankMaterial? material;
        final materialValue = t['material'];
        if (materialValue is TankMaterial) {
          material = materialValue;
        } else if (materialValue is String) {
          material = _parseEnumValue(materialValue, TankMaterial.values);
        }

        TankRole role;
        final roleValue = t['role'];
        if (roleValue is TankRole) {
          role = roleValue;
        } else if (roleValue is String) {
          role =
              _parseEnumValue(roleValue, TankRole.values) ?? TankRole.backGas;
        } else {
          role = TankRole.backGas;
        }

        return DiveTank(
          id: _uuid.v4(),
          name: t['name'] as String?,
          presetName: t['presetName'] as String?,
          volume: t['volume'] as double?,
          startPressure: (t['startPressure'] as num?)?.toDouble(),
          endPressure: (t['endPressure'] as num?)?.toDouble(),
          workingPressure: (t['workingPressure'] as num?)?.toDouble(),
          gasMix: t['gasMix'] as GasMix? ?? const GasMix(),
          material: material,
          role: role,
          order: t['order'] as int? ?? 0,
        );
      }).toList();
    }

    // Fall back to gas mix from samples
    final gasMix = diveData['gasMix'] as GasMix?;
    if (gasMix != null) {
      return [DiveTank(id: _uuid.v4(), gasMix: gasMix)];
    }

    return [];
  }

  List<MarineSighting> _buildSightings(Map<String, dynamic> diveData) {
    final sightingsData = diveData['sightings'] as List<Map<String, dynamic>>?;
    if (sightingsData == null) return [];

    return [
      for (final sightingData in sightingsData)
        if (sightingData['speciesRef'] case final String speciesRef
            when speciesRef.isNotEmpty)
          MarineSighting(
            id: _uuid.v4(),
            speciesId: speciesRef,
            speciesName: _speciesNameFromRef(speciesRef),
            count: sightingData['count'] as int? ?? 1,
            notes: sightingData['notes'] as String? ?? '',
          ),
    ];
  }

  String _speciesNameFromRef(String ref) {
    if (!ref.startsWith('species_')) return ref;
    return ref
        .substring(8)
        .split('_')
        .map(
          (word) => word.isNotEmpty
              ? word[0].toUpperCase() + word.substring(1)
              : word,
        )
        .join(' ');
  }

  Future<List<EquipmentItem>> _resolveEquipmentRefs(
    dynamic equipmentRefsRaw,
    Map<String, String> equipmentIdMapping,
    EquipmentRepository repository,
  ) async {
    if (equipmentRefsRaw == null) return [];
    final equipmentRefs = equipmentRefsRaw is List
        ? equipmentRefsRaw.whereType<String>().toList()
        : <String>[];
    final result = <EquipmentItem>[];
    for (final oldRef in equipmentRefs) {
      final newId = equipmentIdMapping[oldRef];
      if (newId != null) {
        final equipment = await repository.getEquipmentById(newId);
        if (equipment != null) result.add(equipment);
      }
    }
    return result;
  }

  Future<void> _storeTankPressures(
    List<Map<String, dynamic>> profileData,
    List<DiveTank> tanks,
    String diveId,
    TankPressureRepository repository,
  ) async {
    final pressuresByTank =
        <String, List<({int timestamp, double pressure})>>{};

    for (final p in profileData) {
      final timestamp = p['timestamp'] as int? ?? 0;

      final allTankPressures =
          p['allTankPressures'] as List<Map<String, dynamic>>?;
      if (allTankPressures != null && allTankPressures.isNotEmpty) {
        for (final tp in allTankPressures) {
          final pressure = tp['pressure'] as double?;
          final tankIdx = tp['tankIndex'] as int? ?? 0;
          if (pressure != null && tankIdx >= 0 && tankIdx < tanks.length) {
            final tankId = tanks[tankIdx].id;
            pressuresByTank.putIfAbsent(tankId, () => []).add((
              timestamp: timestamp,
              pressure: pressure,
            ));
          }
        }
      }
    }

    if (pressuresByTank.isNotEmpty) {
      await repository.insertTankPressures(diveId, pressuresByTank);
    }
  }

  /// Returns the IDs of inline buddies created (not from the buddy section).
  Future<Set<String>> _linkBuddiesToDive(
    Map<String, dynamic> diveData,
    String diveId,
    String diverId,
    Map<String, String> buddyIdMapping,
    BuddyRepository repository,
  ) async {
    // Link referenced buddies (from pre-imported buddy entities)
    final buddyRefsValue = diveData['buddyRefs'];
    final buddyRefs = buddyRefsValue is List
        ? buddyRefsValue.whereType<String>().toList()
        : <String>[];
    for (final buddyRef in buddyRefs) {
      final newBuddyId = buddyIdMapping[buddyRef];
      if (newBuddyId != null) {
        await repository.addBuddyToDive(diveId, newBuddyId, DiveRole.buddyId);
      }
    }

    // Link referenced dive guides (same buddy entities, different role)
    final guideRefsValue = diveData['diveGuideRefs'];
    final guideRefs = guideRefsValue is List
        ? guideRefsValue.whereType<String>().toList()
        : <String>[];
    for (final guideRef in guideRefs) {
      final newGuideId = buddyIdMapping[guideRef];
      if (newGuideId != null) {
        await repository.addBuddyToDive(
          diveId,
          newGuideId,
          DiveRole.diveGuideId,
        );
      }
    }

    // Handle inline buddy names not in the diver section
    final inlineIds = <String>{};
    final unmatchedNamesValue = diveData['unmatchedBuddyNames'];
    final unmatchedNames = unmatchedNamesValue is List
        ? unmatchedNamesValue.whereType<String>().toList()
        : <String>[];
    for (final buddyName in unmatchedNames) {
      final buddy = await repository.findOrCreateByName(buddyName);
      if (buddy.diverId == null) {
        await repository.updateBuddy(buddy.copyWith(diverId: diverId));
      }
      await repository.addBuddyToDive(diveId, buddy.id, DiveRole.buddyId);
      inlineIds.add(buddy.id);
    }

    // Handle inline dive guide / divemaster names
    final unmatchedGuideValue = diveData['unmatchedDiveGuideNames'];
    final unmatchedGuides = unmatchedGuideValue is List
        ? unmatchedGuideValue.whereType<String>().toList()
        : <String>[];
    for (final guideName in unmatchedGuides) {
      final guide = await repository.findOrCreateByName(guideName);
      if (guide.diverId == null) {
        await repository.updateBuddy(guide.copyWith(diverId: diverId));
      }
      await repository.addBuddyToDive(diveId, guide.id, DiveRole.diveGuideId);
      inlineIds.add(guide.id);
    }

    return inlineIds;
  }

  Future<void> _linkTagsToDive(
    Map<String, dynamic> diveData,
    String diveId,
    Map<String, String> tagIdMapping,
    TagRepository repository,
  ) async {
    final tagRefsValue = diveData['tagRefs'];
    final tagRefs = tagRefsValue is List
        ? tagRefsValue.whereType<String>().toList()
        : <String>[];
    for (final tagRef in tagRefs) {
      final newTagId = tagIdMapping[tagRef];
      if (newTagId != null) {
        await repository.addTagToDive(diveId, newTagId);
      }
    }
  }

  // -- Enum parsing helpers --

  EquipmentType _parseEquipmentType(dynamic value) {
    if (value is EquipmentType) return value;
    if (value is String) {
      return _parseEnumValue(value, EquipmentType.values) ??
          EquipmentType.other;
    }
    return EquipmentType.other;
  }

  EquipmentStatus _parseEquipmentStatus(dynamic value) {
    if (value is EquipmentStatus) return value;
    if (value is String) {
      return _parseEnumValue(value, EquipmentStatus.values) ??
          EquipmentStatus.active;
    }
    return EquipmentStatus.active;
  }

  CertificationAgency _parseCertificationAgency(dynamic value) {
    if (value is CertificationAgency) return value;
    if (value is String) {
      // A named-but-unrecognised agency is "other", not PADI. Defaulting to
      // PADI relabels real cards from agencies outside the enum (#912).
      return _parseEnumValue(value, CertificationAgency.values) ??
          (value.trim().isEmpty
              ? CertificationAgency.padi
              : CertificationAgency.other);
    }
    return CertificationAgency.padi;
  }

  CertificationLevel? _parseCertificationLevel(dynamic value) {
    if (value is CertificationLevel) return value;
    if (value is String) {
      return _parseEnumValue(value, CertificationLevel.values);
    }
    return null;
  }

  T? _parseEnumValue<T extends Enum>(String value, List<T> values) {
    final lowerValue = value.toLowerCase();
    for (final enumValue in values) {
      if (enumValue.name.toLowerCase() == lowerValue) return enumValue;
    }
    return null;
  }

  List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.cast<String>().where((s) => s.isNotEmpty).toList();
    }
    if (value is String && value.isNotEmpty) {
      return value
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }
}

class _DiveImportResult {
  final int count;
  final int inlineBuddies;
  final List<String> diveIds;
  final Map<int, String> diveIdByIndex;

  /// How many `dive_data_sources` rows were restored from `<source>` entries.
  final int restoredDataSources;

  const _DiveImportResult(
    this.count,
    this.inlineBuddies, [
    this.diveIds = const [],
    this.diveIdByIndex = const {},
    this.restoredDataSources = 0,
  ]);
}
