import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/conflict_field_catalogue.dart';

import '../../../../helpers/test_database.dart';

/// Entities whose catalogue lands in a later task of the #694 plan. Emptied
/// task by task, then deleted.
const _pending = <String>{
  'divers',
  'diverSettings',
  'buddies',
  'diveCenters',
  'diveCenterGearNotes',
  'trips',
  'liveaboardDetails',
  'itineraryDays',
  'tripDayWeather',
  'tripCylinders',
  'tripCylinderEvents',
  'checklistTemplates',
  'checklistTemplateItems',
  'tripChecklistItems',
  'preDiveChecklistTemplates',
  'preDiveChecklistTemplateItems',
  'preDiveSessions',
  'preDiveSessionItems',
  'gpsTracks',
  'navTracks',
  'divePlans',
  'divePlanTanks',
  'divePlanSegments',
  'divePlanMissions',
  'divePlanMissionLegs',
  'divePlanMissionMembers',
  'equipment',
  'equipmentSets',
  'equipmentSetItems',
  'equipmentSetGeofences',
  'cylinderConfigs',
  'cylinderConfigItems',
  'qualityFindings',
  'equipmentAttributes',
  'equipmentComponents',
  'mediaSmartAlbums',
  'divePlanEquipment',
  'diverWeightEntries',
  'diveTypes',
  'siteTypes',
  'diveRoles',
  'tankPresets',
  'weightPresets',
  'weightPresetEntries',
  'diveComputers',
  'transmitters',
  'cylinderFills',
  'connectionMaps',
  'savedQueries',
  'species',
  'tags',
  'courses',
  'courseRequirements',
  'courseRequirementDives',
  'dives',
  'diveSites',
  'diveTanks',
  'diveWeights',
  'diveEquipment',
  'diveTags',
  'diveDiveTypes',
  'diveBuddies',
  'diveProfileEvents',
  'diveSafetyReviews',
  'diveSafetyFindings',
  'emergencyChambers',
  'incidents',
  'equipmentObservations',
  'equipmentFindings',
  'gasSwitches',
  'diveCustomFields',
  'importedFiles',
  'diveDataSources',
  'siteSpecies',
  'siteSiteTypes',
  'siteTags',
  'equipmentTags',
  'equipmentShares',
  'tripEquipment',
  'tripHides',
  'siteHides',
  'equipmentOwnershipEvents',
  'mediaSpecies',
  'siteFeatures',
  'csvPresets',
  'viewConfigs',
  'fieldPresets',
  'tideRecords',
  'sightings',
  'certifications',
  'serviceRecords',
  'serviceKinds',
  'serviceSchedules',
  'settings',
  'media',
  'mediaEnrichment',
  'mediaStores',
  'connectedAccounts',
  'mediaSubscriptions',
  'diveProfileSeries',
  'tankPressureSeries',
};

/// Every column of every synced table must have a label and a value kind in
/// the conflict catalogue, or the Resolve Conflicts dialog shows a raw column
/// name to the diver (#694). Driven off the live Drift schema, so a new synced
/// column fails here until it is catalogued.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async => setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  for (final entity in SyncService.entityHasUpdatedAt.keys) {
    test(
      'every $entity column has a conflict label',
      () {
        final table = SyncDataSerializer().syncTableFor(entity);
        final missing = [
          for (final column in table.$columns)
            if (!isConflictFieldCovered(entity, _camelCase(column.name)))
              '${_camelCase(column.name)} (${column.type})',
        ];
        expect(
          missing,
          isEmpty,
          reason:
              '$entity has columns with no conflict catalogue entry. Add '
              'each to lib/features/settings/presentation/conflicts/'
              'catalogue/ with a label and a FieldKind.',
        );
      },
      skip: _pending.contains(entity)
          ? 'catalogued in a later task of the #694 plan'
          : false,
    );
  }
}

/// Drift's SQL name back to the JSON key `toJson` uses. No synced column
/// uses `.named(...)`, so the getter is always the camelCase of the SQL name.
String _camelCase(String columnName) {
  final parts = columnName.split('_');
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}
