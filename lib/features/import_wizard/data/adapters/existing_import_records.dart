import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
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

  final List<Dive> dives;
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

/// The active profile's records, read the way the review always has:
/// through the diver-scoped list providers, refreshed. `refresh()` rather
/// than `read()`, which may return a value invalidated but not re-fetched.
Future<ExistingImportRecords> loadActiveDiverRecords(
  ProviderContainer container,
  String? diverId,
) async {
  final trips = await container.refresh(allTripsProvider.future);
  final sites = await container.refresh(sitesProvider.future);
  final equipment = await container.refresh(allEquipmentProvider.future);
  final buddies = await container.refresh(allBuddiesProvider.future);
  final diveCenters = await container.refresh(allDiveCentersProvider.future);
  final certifications = await container.refresh(
    allCertificationsProvider.future,
  );
  final tags = await container.refresh(tagsProvider.future);
  final diveTypes = await container.refresh(diveTypesProvider.future);
  final diveRepo = container.read(diveRepositoryProvider);
  return ExistingImportRecords(
    trips: trips,
    sites: sites,
    equipment: equipment,
    buddies: buddies,
    diveCenters: diveCenters,
    certifications: certifications,
    tags: tags,
    diveTypes: diveTypes,
    dives: await diveRepo.getAllDives(diverId: diverId),
    sourceUuidByDiveId: await diveRepo.getSourceUuidByDiveId(diverId: diverId),
    certificationCatalog: await container.read(
      allCustomCertificationsCatalogProvider.future,
    ),
  );
}

/// Another existing profile's records, straight from the repositories,
/// which take the diver id as an argument. [diverId] is never null here: a
/// null id would make every filter return all divers' rows.
Future<ExistingImportRecords> loadProfileRecords(
  ProviderContainer container,
  String diverId,
) async {
  final diveRepo = container.read(diveRepositoryProvider);
  return ExistingImportRecords(
    trips: await container
        .read(tripRepositoryProvider)
        .getAllTrips(diverId: diverId),
    sites: await container
        .read(siteRepositoryProvider)
        .getAllSites(diverId: diverId),
    equipment: await container
        .read(equipmentRepositoryProvider)
        .getAllEquipment(diverId: diverId),
    buddies: await container
        .read(buddyRepositoryProvider)
        .getAllBuddies(diverId: diverId),
    diveCenters: await container
        .read(diveCenterRepositoryProvider)
        .getAllDiveCenters(diverId: diverId),
    certifications: await container
        .read(certificationRepositoryProvider)
        .getAllCertifications(diverId: diverId),
    tags: await container
        .read(tagRepositoryProvider)
        .getAllTags(diverId: diverId),
    diveTypes: await container
        .read(diveTypeRepositoryProvider)
        .getAllDiveTypes(diverId: diverId),
    dives: await diveRepo.getAllDives(diverId: diverId),
    sourceUuidByDiveId: await diveRepo.getSourceUuidByDiveId(diverId: diverId),
    certificationCatalog: await container.read(
      allCustomCertificationsCatalogProvider.future,
    ),
  );
}

/// A profile the import will create has no records yet. Built-in dive types
/// exist for every diver, so they still count (a null id asks for those
/// alone).
Future<ExistingImportRecords> loadNewProfileRecords(
  ProviderContainer container,
) async {
  return ExistingImportRecords(
    diveTypes: await container
        .read(diveTypeRepositoryProvider)
        .getAllDiveTypes(),
  );
}
