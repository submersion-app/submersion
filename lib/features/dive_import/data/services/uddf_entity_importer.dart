import 'package:drift/drift.dart' show Value;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show DiveDataSourcesCompanion;
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
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
  final SiteRepository siteRepository;
  final DiveRepository diveRepository;
  final TankPressureRepository tankPressureRepository;
  final CourseRepository courseRepository;

  const ImportRepositories({
    required this.tripRepository,
    required this.equipmentRepository,
    required this.equipmentSetRepository,
    required this.buddyRepository,
    required this.diveCenterRepository,
    required this.certificationRepository,
    required this.tagRepository,
    required this.diveTypeRepository,
    required this.siteRepository,
    required this.diveRepository,
    required this.tankPressureRepository,
    required this.courseRepository,
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

  final TankPresetEntity? _defaultTankPreset;
  final int _defaultStartPressure;
  final bool _applyDefaultTankToImports;

  UddfEntityImporter({
    TankPresetEntity? defaultTankPreset,
    int defaultStartPressure = 200,
    bool applyDefaultTankToImports = false,
  }) : _defaultTankPreset = defaultTankPreset,
       _defaultStartPressure = defaultStartPressure,
       _applyDefaultTankToImports = applyDefaultTankToImports;

  /// Import selected entities from [data] using [repositories].
  ///
  /// Only entities at indices present in [selections] are imported.
  /// Reports progress via [onProgress] callback.
  Future<UddfEntityImportResult> import({
    required UddfImportResult data,
    required UddfImportSelections selections,
    required ImportRepositories repositories,
    required String diverId,
    bool retainSourceDiveNumbers = false,
    ImportProgressCallback? onProgress,
  }) async {
    final now = DateTime.now();

    // ID mappings for cross-references
    final tripIdMapping = <String, String>{};
    final equipmentIdMapping = <String, String>{};
    final buddyIdMapping = <String, String>{};
    final diveCenterIdMapping = <String, String>{};
    final tagIdMapping = <String, String>{};
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

    final buddiesCount = await _importBuddies(
      data.buddies,
      selections.buddies,
      repositories.buddyRepository,
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

    final sitesCount = await _importSites(
      data.sites,
      selections.sites,
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
      onProgress: onProgress,
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
        size: equipData['size'] as String?,
        status: equipStatus,
        purchaseDate: equipData['purchaseDate'] as DateTime?,
        purchasePrice: equipData['purchasePrice'] as double?,
        purchaseCurrency: equipData['purchaseCurrency'] as String? ?? 'USD',
        lastServiceDate: equipData['lastServiceDate'] as DateTime?,
        serviceIntervalDays: equipData['serviceIntervalDays'] as int?,
        notes: equipData['notes'] as String? ?? '',
        isActive: equipData['isActive'] as bool? ?? true,
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
        certificationLevel:
            buddyData['certificationLevel'] as CertificationLevel?,
        certificationAgency:
            buddyData['certificationAgency'] as CertificationAgency?,
        notes: buddyData['notes'] as String? ?? '',
        createdAt: now,
        updatedAt: now,
      );

      await repository.createBuddy(buddy);
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

  // -- Site import --

  Future<int> _importSites(
    List<Map<String, dynamic>> items,
    Set<int> selected,
    SiteRepository repository,
    String diverId,
    Map<String, DiveSite> idMapping,
    ImportProgressCallback? onProgress,
  ) async {
    // For deselected sites (duplicates the user chose not to re-import),
    // resolve their UDDF IDs to existing database sites by name so that
    // dives referencing them still get linked correctly.
    final existingSites = await repository.getAllSites(diverId: diverId);
    final existingByName = <String, DiveSite>{};
    for (final site in existingSites) {
      existingByName[site.name.toLowerCase()] = site;
    }
    for (var i = 0; i < items.length; i++) {
      if (selected.contains(i)) continue; // will be imported below
      final uddfId = items[i]['uddfId'] as String?;
      final name = items[i]['name'] as String?;
      if (uddfId != null && name != null) {
        final existing = existingByName[name.toLowerCase()];
        if (existing != null) {
          idMapping[uddfId] = existing;
        }
      }
    }

    if (selected.isEmpty) return 0;
    onProgress?.call(ImportPhase.sites, 0, selected.length);
    var count = 0;

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
      if (uddfId != null) idMapping[uddfId] = createdSite;
      count++;
      onProgress?.call(ImportPhase.sites, count, selected.length);
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
    ImportProgressCallback? onProgress,
  }) async {
    if (selected.isEmpty) return const _DiveImportResult(0, 0);
    onProgress?.call(ImportPhase.dives, 0, selected.length);
    var count = 0;
    final importedDiveIds = <String>[];
    final inlineBuddyIds = <String>{};

    // Sort selected indices by dateTime (oldest first) for sequential numbering.
    final sortedSelected = selected.toList()
      ..sort((a, b) {
        final aTime = items[a]['dateTime'] as DateTime? ?? DateTime(0);
        final bTime = items[b]['dateTime'] as DateTime? ?? DateTime(0);
        return aTime.compareTo(bTime);
      });

    // Auto-assign dive numbers starting from the next available number,
    // unless the user opted to retain source file numbering.
    var nextDiveNumber = retainSourceDiveNumbers
        ? null
        : await repos.diveRepository.getNextDiveNumber(diverId: diverId);

    for (final i in sortedSelected) {
      final diveData = items[i];

      // Build profile (include setpoint/ppO2 sensor readings)
      final profileData = diveData['profile'] as List<Map<String, dynamic>>?;
      final profile =
          profileData
              ?.map(
                (p) => DiveProfilePoint(
                  timestamp: p['timestamp'] as int? ?? 0,
                  depth: p['depth'] as double? ?? 0.0,
                  temperature: p['temperature'] as double?,
                  pressure: p['pressure'] as double?,
                  setpoint: p['setpoint'] as double?,
                  ppO2: p['ppO2'] as double?,
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

      // Parse notes with weight
      var notes = diveData['notes'] as String? ?? '';
      final weightUsed = diveData['weightUsed'] as double?;
      if (weightUsed != null && weightUsed > 0) {
        if (notes.isNotEmpty) notes += '\n';
        notes += 'Weight used: ${weightUsed.toStringAsFixed(1)} kg';
      }

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

      final dateTime = diveData['dateTime'] as DateTime? ?? now;
      final runtime = diveData['runtime'] as Duration?;
      final parsedEntryTime = diveData['entryTime'] as DateTime?;
      final entryTime = parsedEntryTime ?? dateTime;
      final exitTime = runtime != null ? dateTime.add(runtime) : null;
      final diveTypeId = diveData['diveType'] as String? ?? 'recreational';

      // Parse dive mode, planner flag, and favorite
      final diveMode = diveData['diveMode'] as DiveMode? ?? DiveMode.oc;
      final isPlanned = diveData['isPlanned'] as bool? ?? false;
      final isFavorite = diveData['isFavorite'] as bool? ?? false;

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

      var dive = Dive(
        id: diveId,
        diverId: diverId,
        diveNumber: nextDiveNumber != null
            ? nextDiveNumber++
            : diveData['diveNumber'] as int?,
        dateTime: dateTime,
        entryTime: entryTime,
        exitTime: exitTime,
        bottomTime: diveData['duration'] as Duration?,
        runtime: runtime,
        maxDepth: diveData['maxDepth'] as double?,
        avgDepth: diveData['avgDepth'] as double?,
        waterTemp: diveData['waterTemp'] as double?,
        airTemp: diveData['airTemp'] as double?,
        surfacePressure: diveData['surfacePressure'] as double?,
        surfaceInterval: diveData['surfaceInterval'] as Duration?,
        gradientFactorLow: diveData['gradientFactorLow'] as int?,
        gradientFactorHigh: diveData['gradientFactorHigh'] as int?,
        diveComputerModel: diveData['diveComputerModel'] as String?,
        diveComputerSerial: diveData['diveComputerSerial'] as String?,
        diveComputerFirmware: diveData['diveComputerFirmware'] as String?,
        buddy: diveData['buddy'] as String?,
        diveMaster: diveData['diveMaster'] as String?,
        rating: diveData['rating'] as int?,
        notes: notes,
        visibility: diveData['visibility'] as Visibility?,
        diveTypeId: diveTypeId,
        profile: profile,
        tanks: tanks,
        weights: weights,
        site: linkedSite,
        tripId: linkedTripId,
        diveCenter: linkedDiveCenter,
        equipment: linkedEquipment,
        sightings: sightings,
        currentDirection: diveData['currentDirection'] as CurrentDirection?,
        currentStrength: diveData['currentStrength'] as CurrentStrength?,
        swellHeight: diveData['swellHeight'] as double?,
        entryMethod: diveData['entryMethod'] as EntryMethod?,
        exitMethod: diveData['exitMethod'] as EntryMethod?,
        waterType: diveData['waterType'] as WaterType?,
        altitude: diveData['altitude'] as double?,
        // Dive mode and rebreather fields
        diveMode: diveMode,
        isPlanned: isPlanned,
        isFavorite: isFavorite,
        courseId: linkedCourseId,
        setpointLow: diveData['setpointLow'] as double?,
        setpointHigh: diveData['setpointHigh'] as double?,
        setpointDeco: diveData['setpointDeco'] as double?,
        scrType: diveData['scrType'] as ScrType?,
        scrInjectionRate: diveData['scrInjectionRate'] as double?,
        scrAdditionRatio: diveData['scrAdditionRatio'] as double?,
        scrOrificeSize: diveData['scrOrificeSize'] as String?,
        assumedVo2: diveData['assumedVo2'] as double?,
        diluentGas: diluentGas,
        loopO2Min: diveData['loopO2Min'] as double?,
        loopO2Max: diveData['loopO2Max'] as double?,
        loopO2Avg: diveData['loopO2Avg'] as double?,
        loopVolume: diveData['loopVolume'] as double?,
        scrubber: scrubber,
      );

      // Auto-calculate bottom time from profile if not set
      if (dive.bottomTime == null && dive.profile.isNotEmpty) {
        final calculatedBottomTime = dive.calculateBottomTimeFromProfile();
        if (calculatedBottomTime != null) {
          dive = dive.copyWith(bottomTime: calculatedBottomTime);
        }
      }

      await repos.diveRepository.createDive(dive);
      importedDiveIds.add(diveId);

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
        final switches = gasSwitchesData
            .where((gs) => gs['timestamp'] != null)
            .map(
              (gs) => GasSwitch(
                id: _uuid.v4(),
                diveId: diveId,
                timestamp: gs['timestamp'] as int,
                tankId: gs['tankRef'] as String? ?? '',
                depth: gs['depth'] as double?,
                createdAt: now,
              ),
            )
            .toList();
        if (switches.isNotEmpty) {
          await repos.diveRepository.insertGasSwitches(switches);
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

      // Create a DiveDataSource record to track provenance.
      await repos.diveRepository.saveComputerReading(
        DiveDataSourcesCompanion(
          id: Value(_uuid.v4()),
          diveId: Value(diveId),
          isPrimary: const Value(true),
          computerModel: Value(diveData['diveComputerModel'] as String?),
          computerSerial: Value(diveData['diveComputerSerial'] as String?),
          sourceFileName: Value(sourceFileName),
          sourceFileFormat: const Value('uddf'),
          maxDepth: Value(diveData['maxDepth'] as double?),
          avgDepth: Value(diveData['avgDepth'] as double?),
          duration: Value(dive.bottomTime?.inSeconds),
          waterTemp: Value(diveData['waterTemp'] as double?),
          entryTime: Value(dive.entryTime),
          exitTime: Value(dive.exitTime),
          importedAt: Value(now),
          createdAt: Value(now),
        ),
      );

      count++;
      onProgress?.call(ImportPhase.dives, count, selected.length);
    }

    return _DiveImportResult(count, inlineBuddyIds.length, importedDiveIds);
  }

  // -- Dive helper methods --

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
          volume: t['volume'] as double?,
          startPressure: t['startPressure'] as int?,
          endPressure: t['endPressure'] as int?,
          workingPressure: t['workingPressure'] as int?,
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

      // Check for multi-tank pressure data first
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
      } else {
        // Legacy single pressure field
        final pressure = p['pressure'] as double?;
        final tankIdx = (p['tankIndex'] as int?) ?? 0;
        if (pressure != null && tankIdx >= 0 && tankIdx < tanks.length) {
          final tankId = tanks[tankIdx].id;
          pressuresByTank.putIfAbsent(tankId, () => []).add((
            timestamp: timestamp,
            pressure: pressure,
          ));
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
        await repository.addBuddyToDive(diveId, newBuddyId, BuddyRole.buddy);
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
          BuddyRole.diveGuide,
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
      await repository.addBuddyToDive(diveId, buddy.id, BuddyRole.buddy);
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
      await repository.addBuddyToDive(diveId, guide.id, BuddyRole.diveGuide);
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
      return _parseEnumValue(value, CertificationAgency.values) ??
          CertificationAgency.padi;
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

  const _DiveImportResult(
    this.count,
    this.inlineBuddies, [
    this.diveIds = const [],
  ]);
}
