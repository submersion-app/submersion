import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_import/domain/models/dive_match_record.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';

/// The records one import target's items are checked against for
/// duplicates (issue #1893).
class ExistingImportRecords {
  const ExistingImportRecords({
    this.dives = const [],
    this.sites = const [],
    this.trips = const [],
    this.equipment = const [],
    this.buddies = const [],
    this.diveCenters = const [],
    this.certifications = const [],
    this.tags = const [],
    this.diveTypes = const [],
    this.sourceUuidByDiveId = const {},
    this.certificationCatalog,
  });

  final List<DiveMatchRecord> dives;
  final List<DiveSite> sites;
  final List<Trip> trips;
  final List<EquipmentItem> equipment;
  final List<Buddy> buddies;
  final List<DiveCenter> diveCenters;
  final List<Certification> certifications;
  final List<Tag> tags;
  final List<DiveTypeEntity> diveTypes;
  final Map<String, String> sourceUuidByDiveId;

  /// Names custom agencies, so a re-imported card with a custom agency is
  /// recognised as a duplicate (issue #690).
  final CertificationCatalog? certificationCatalog;

  ImportDuplicateResult check(
    ImportPayload payload, {
    required bool checkIntraBatch,
    required UnitFormatter units,
  }) {
    return const ImportDuplicateChecker().check(
      payload: payload,
      existingDives: dives,
      existingSites: sites,
      existingTrips: trips,
      existingEquipment: equipment,
      existingBuddies: buddies,
      existingDiveCenters: diveCenters,
      existingCertifications: certifications,
      existingTags: tags,
      existingDiveTypes: diveTypes,
      existingSourceUuidByDiveId: sourceUuidByDiveId,
      checkIntraBatch: checkIntraBatch,
      // A single file is checked against itself too: a logbook can hold the
      // same dive twice (#3110).
      checkWithinFile: !checkIntraBatch,
      units: units,
      certificationCatalog: certificationCatalog,
    );
  }
}

/// The records [payload] is checked against, and only those (issue #3855).
///
/// Each entity type is compared with its own records alone, so a type the
/// payload does not carry has nothing to read: a file of sites must not pay
/// to read the logbook or every certification's card image. Source UUIDs are
/// read only for dives that carry one.
Future<ExistingImportRecords> readRecordsNeededBy(
  ImportPayload payload, {
  required Future<List<DiveMatchRecord>> Function() dives,
  required Future<Map<String, String>> Function() sourceUuidByDiveId,
  required Future<List<Trip>> Function() trips,
  required Future<List<DiveSite>> Function() sites,
  required Future<List<EquipmentItem>> Function() equipment,
  required Future<List<Buddy>> Function() buddies,
  required Future<List<DiveCenter>> Function() diveCenters,
  required Future<List<Certification>> Function() certifications,
  required Future<List<Tag>> Function() tags,
  required Future<List<DiveTypeEntity>> Function() diveTypes,
  required Future<CertificationCatalog> Function() certificationCatalog,
}) async {
  bool carries(ImportEntityType type) => payload.entitiesOf(type).isNotEmpty;
  Future<List<T>> readIfCarried<T>(
    ImportEntityType type,
    Future<List<T>> Function() read,
  ) async => carries(type) ? await read() : <T>[];

  return ExistingImportRecords(
    trips: await readIfCarried(ImportEntityType.trips, trips),
    sites: await readIfCarried(ImportEntityType.sites, sites),
    equipment: await readIfCarried(ImportEntityType.equipment, equipment),
    buddies: await readIfCarried(ImportEntityType.buddies, buddies),
    diveCenters: await readIfCarried(ImportEntityType.diveCenters, diveCenters),
    certifications: await readIfCarried(
      ImportEntityType.certifications,
      certifications,
    ),
    tags: await readIfCarried(ImportEntityType.tags, tags),
    diveTypes: await readIfCarried(ImportEntityType.diveTypes, diveTypes),
    dives: await readIfCarried(ImportEntityType.dives, dives),
    sourceUuidByDiveId: _carriesSourceUuid(payload)
        ? await sourceUuidByDiveId()
        : const {},
    certificationCatalog: carries(ImportEntityType.certifications)
        ? await certificationCatalog()
        : null,
  );
}

bool _carriesSourceUuid(ImportPayload payload) => payload
    .entitiesOf(ImportEntityType.dives)
    .any((dive) => (dive['sourceUuid'] as String?)?.isNotEmpty ?? false);

/// The active profile's records, read the way the review always has:
/// through the diver-scoped list providers, refreshed. `refresh()` rather
/// than `read()`, which may return a value invalidated but not re-fetched.
Future<ExistingImportRecords> loadActiveDiverRecords(
  ProviderContainer container,
  ImportPayload payload,
  String? diverId,
) {
  final diveRepo = container.read(diveRepositoryProvider);
  return readRecordsNeededBy(
    payload,
    dives: () => diveRepo.getDiveMatchRecords(diverId: diverId),
    sourceUuidByDiveId: () => diveRepo.getSourceUuidByDiveId(diverId: diverId),
    trips: () => container.refresh(allTripsProvider.future),
    sites: () => container.refresh(sitesProvider.future),
    equipment: () => container.refresh(allEquipmentProvider.future),
    buddies: () => container.refresh(allBuddiesProvider.future),
    diveCenters: () => container.refresh(allDiveCentersProvider.future),
    certifications: () =>
        container.refresh(certificationMetadataProvider.future),
    tags: () => container.refresh(tagsProvider.future),
    diveTypes: () => container.refresh(diveTypesProvider.future),
    certificationCatalog: () =>
        container.read(allCustomCertificationsCatalogProvider.future),
  );
}

/// Another existing profile's records, straight from the repositories,
/// which take the diver id as an argument. [diverId] is never null here: a
/// null id would make every filter return all divers' rows.
Future<ExistingImportRecords> loadProfileRecords(
  ProviderContainer container,
  ImportPayload payload,
  String diverId,
) {
  final diveRepo = container.read(diveRepositoryProvider);
  return readRecordsNeededBy(
    payload,
    dives: () => diveRepo.getDiveMatchRecords(diverId: diverId),
    sourceUuidByDiveId: () => diveRepo.getSourceUuidByDiveId(diverId: diverId),
    trips: () =>
        container.read(tripRepositoryProvider).getAllTrips(diverId: diverId),
    sites: () =>
        container.read(siteRepositoryProvider).getAllSites(diverId: diverId),
    equipment: () => container
        .read(equipmentRepositoryProvider)
        .getAllEquipment(diverId: diverId),
    buddies: () =>
        container.read(buddyRepositoryProvider).getAllBuddies(diverId: diverId),
    diveCenters: () => container
        .read(diveCenterRepositoryProvider)
        .getAllDiveCenters(diverId: diverId),
    certifications: () => container
        .read(certificationRepositoryProvider)
        .getCertificationMetadata(diverId: diverId),
    tags: () =>
        container.read(tagRepositoryProvider).getAllTags(diverId: diverId),
    diveTypes: () => container
        .read(diveTypeRepositoryProvider)
        .getAllDiveTypes(diverId: diverId),
    certificationCatalog: () =>
        container.read(allCustomCertificationsCatalogProvider.future),
  );
}

/// A profile the import will create has no records yet. Built-in dive types
/// exist for every diver, so they still count (a null id asks for those
/// alone).
Future<ExistingImportRecords> loadNewProfileRecords(
  ProviderContainer container,
  ImportPayload payload,
) async {
  return ExistingImportRecords(
    diveTypes: payload.entitiesOf(ImportEntityType.diveTypes).isEmpty
        ? const []
        : await container.read(diveTypeRepositoryProvider).getAllDiveTypes(),
  );
}
