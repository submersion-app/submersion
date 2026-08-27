/// Build smoke test for every provider that subscribes to a change tick
/// (issue #974).
///
/// Subscribing to a tick changes when a provider touches the database.
/// `ref.invalidateSelfWhen(repository.watchXChanges())` runs during BUILD,
/// synchronously, before any `await` -- not inside the awaited read that
/// follows it. A repository whose read path is defensive about an
/// uninitialised database can therefore still blow up on the watch path.
///
/// We shipped exactly that defect: `AppSettingsRepository.watchSettingsChanges()`
/// threw `StateError: Database not initialized` while the paired
/// `getSetting()` read swallowed the same condition, so adding the tick
/// subscription broke `shareByDefaultProvider` at build time even though the
/// read it guarded was fine.
///
/// This test reads each of the 158 tick-subscribing providers once against a
/// real in-memory database and asserts only that the build resolves without
/// throwing. An empty database returning `null` or an empty list is a PASS --
/// nothing here asserts on the returned data. Providers that genuinely cannot
/// build in a unit test (platform channels, network, media-store runtime)
/// belong in [_needsPlatform] with a reason rather than having the assertion
/// weakened for everyone else; that list is currently empty.
///
/// Add a case here whenever a provider gains an `invalidateSelfWhen`
/// subscription.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/maps/presentation/providers/offline_map_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/planner/presentation/pages/plan_compare_page.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/settings/presentation/pages/connected_accounts_page.dart';
import 'package:submersion/features/settings/presentation/pages/photos_media_setup_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/universal_import/presentation/providers/csv_preset_providers.dart';

import '../helpers/mock_providers.dart';
import '../helpers/test_database.dart';

/// Providers that cannot build in a plain unit test, keyed by name with the
/// reason as the skip message.
///
/// Currently empty: every tick-subscribing provider builds here, including the
/// ones that reach a media store, an offline map store, or the connected-account
/// registry -- on an empty database they all resolve before any platform
/// channel, network call, or media-store runtime is needed.
///
/// Add an entry (never a weaker assertion) if a future provider genuinely needs
/// a platform channel, the network, or a media-store runtime to build; that
/// provider then belongs in its own feature test with the appropriate fakes.
const Map<String, String> _needsPlatform = <String, String>{};

typedef _ProviderRead = Future<void> Function(ProviderContainer container);

typedef _TickCase = ({String name, _ProviderRead read});

const String _id = 'x';

/// Set in [main]'s `setUp`: several providers reach settings, which reads
/// [sharedPreferencesProvider]. That provider throws unless overridden, so we
/// hand it a mock-backed instance. Everything else stays real.
late SharedPreferences _prefs;

ProviderContainer _makeContainer() => ProviderContainer(
  // Riverpod 3 retries a failed provider with backoff, which leaves `.future`
  // pending forever instead of surfacing the error. Disable retry so a broken
  // build fails the test with its real exception rather than a 30s timeout.
  retry: (_, _) => null,
  overrides: [
    sharedPreferencesProvider.overrideWithValue(_prefs),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
  ],
);

/// Seeds the two rows keyed by [_id] that some families need in order to reach
/// their read at all: a diver (the table-preset seeder inserts presets with a
/// `diver_id` foreign key) and a trip ([tripWithStatsProvider] throws
/// "Trip not found" rather than returning null). Everything else is happy with
/// an empty database.
Future<void> _seedIdRows() async {
  final now = DateTime.now();
  await DiverRepository().createDiver(
    Diver(id: _id, name: 'Tick Smoke', createdAt: now, updatedAt: now),
  );
  await TripRepository().createTrip(
    Trip(
      id: _id,
      name: 'Tick Smoke',
      startDate: now,
      endDate: now,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

/// Drives `filteredTripsProvider` with an equipment filter so the private
/// `_equipmentFilteredTripsProvider` family builds, then polls until the
/// delegated AsyncValue settles and rethrows whatever it failed with.
Future<void> _readFilteredTrips(ProviderContainer container) async {
  container.read(tripFilterProvider.notifier).state = const TripFilterState(
    equipmentId: _id,
  );
  for (var attempt = 0; attempt < 200; attempt++) {
    final value = container.read(filteredTripsProvider);
    if (value.hasError) {
      Error.throwWithStackTrace(value.error!, value.stackTrace!);
    }
    if (!value.isLoading) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('filteredTripsProvider never left its loading state');
}

void _tickGroup(String feature, List<_TickCase> cases) {
  group(feature, () {
    for (final tickCase in cases) {
      test('${tickCase.name} builds against a real database', () async {
        final container = _makeContainer();
        addTearDown(container.dispose);
        await expectLater(
          tickCase.read(container),
          completes,
          reason:
              '${tickCase.name} subscribes to a change tick, so it touches the '
              'database during build. It must not throw.',
        );
      }, skip: _needsPlatform[tickCase.name]);
    }
  });
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    await _seedIdRows();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  _tickGroup('buddies', [
    (
      name: 'allBuddiesProvider',
      read: (c) => c.read(allBuddiesProvider.future),
    ),
    (
      name: 'allBuddiesWithDiveCountProvider',
      read: (c) => c.read(allBuddiesWithDiveCountProvider.future),
    ),
    (
      name: 'buddiesForDiveProvider',
      read: (c) => c.read(buddiesForDiveProvider(_id).future),
    ),
    (
      name: 'buddyByIdProvider',
      read: (c) => c.read(buddyByIdProvider(_id).future),
    ),
    (
      name: 'buddySearchProvider',
      read: (c) => c.read(buddySearchProvider(_id).future),
    ),
    (
      name: 'buddyStatsProvider',
      read: (c) => c.read(buddyStatsProvider(_id).future),
    ),
    (
      name: 'diveIdsForBuddyProvider',
      read: (c) => c.read(diveIdsForBuddyProvider(_id).future),
    ),
  ]);

  _tickGroup('certifications', [
    (
      name: 'allBuddyCertificationsProvider',
      read: (c) => c.read(allBuddyCertificationsProvider.future),
    ),
    (
      name: 'allCertificationsProvider',
      read: (c) => c.read(allCertificationsProvider.future),
    ),
    (
      name: 'buddyCertificationsProvider',
      read: (c) => c.read(buddyCertificationsProvider(_id).future),
    ),
    (
      name: 'certificationByIdProvider',
      read: (c) => c.read(certificationByIdProvider(_id).future),
    ),
    (
      name: 'certificationSearchProvider',
      read: (c) => c.read(certificationSearchProvider(_id).future),
    ),
    (
      name: 'certificationsByAgencyProvider',
      read: (c) => c.read(
        certificationsByAgencyProvider(CertificationAgency.padi).future,
      ),
    ),
    (
      name: 'expiredCertificationsProvider',
      read: (c) => c.read(expiredCertificationsProvider.future),
    ),
    (
      name: 'expiringCertificationsProvider',
      read: (c) => c.read(expiringCertificationsProvider(30).future),
    ),
  ]);

  _tickGroup('courses', [
    (
      name: 'allCoursesProvider',
      read: (c) => c.read(allCoursesProvider.future),
    ),
    (
      name: 'completedCoursesProvider',
      read: (c) => c.read(completedCoursesProvider.future),
    ),
    (
      name: 'courseByIdProvider',
      read: (c) => c.read(courseByIdProvider(_id).future),
    ),
    (
      name: 'courseDiveCountProvider',
      read: (c) => c.read(courseDiveCountProvider(_id).future),
    ),
    (
      name: 'courseDivesProvider',
      read: (c) => c.read(courseDivesProvider(_id).future),
    ),
    (
      name: 'courseForCertificationProvider',
      read: (c) => c.read(courseForCertificationProvider(_id).future),
    ),
    (
      name: 'courseForDiveProvider',
      read: (c) => c.read(courseForDiveProvider(_id).future),
    ),
    (
      name: 'courseSearchProvider',
      read: (c) => c.read(courseSearchProvider(_id).future),
    ),
    (
      name: 'coursesByAgencyProvider',
      read: (c) =>
          c.read(coursesByAgencyProvider(CertificationAgency.padi).future),
    ),
    (
      name: 'inProgressCoursesProvider',
      read: (c) => c.read(inProgressCoursesProvider.future),
    ),
  ]);

  _tickGroup('cylinder configs', [
    (
      name: 'cylinderConfigProvider',
      read: (c) => c.read(cylinderConfigProvider(_id).future),
    ),
    (
      name: 'cylinderConfigsForEquipmentProvider',
      read: (c) => c.read(cylinderConfigsForEquipmentProvider(_id).future),
    ),
    (
      name: 'cylinderConfigsProvider',
      read: (c) => c.read(cylinderConfigsProvider.future),
    ),
  ]);

  _tickGroup('dashboard', [
    (
      name: 'dashboardQuickStatsProvider',
      read: (c) => c.read(dashboardQuickStatsProvider.future),
    ),
    (name: 'onThisDayProvider', read: (c) => c.read(onThisDayProvider.future)),
    (
      name: 'recentDivesProvider',
      read: (c) => c.read(recentDivesProvider.future),
    ),
    (
      name: 'recentSitesProvider',
      read: (c) => c.read(recentSitesProvider.future),
    ),
    (
      name: 'yearInReviewProvider',
      read: (c) => c.read(yearInReviewProvider.future),
    ),
  ]);

  _tickGroup('dive centers', [
    (
      name: 'allDiveCentersProvider',
      read: (c) => c.read(allDiveCentersProvider.future),
    ),
    (
      name: 'diveCenterByIdProvider',
      read: (c) => c.read(diveCenterByIdProvider(_id).future),
    ),
    (
      name: 'diveCenterCountriesProvider',
      read: (c) => c.read(diveCenterCountriesProvider.future),
    ),
    (
      name: 'diveCenterDiveCountProvider',
      read: (c) => c.read(diveCenterDiveCountProvider(_id).future),
    ),
    (
      name: 'diveCenterSearchProvider',
      read: (c) => c.read(diveCenterSearchProvider(_id).future),
    ),
    (
      name: 'diveCentersByCountryProvider',
      read: (c) => c.read(diveCentersByCountryProvider(_id).future),
    ),
    (
      name: 'diveCentersWithCoordinatesProvider',
      read: (c) => c.read(diveCentersWithCoordinatesProvider.future),
    ),
  ]);

  _tickGroup('dive computers', [
    (
      name: 'computerDiveIdsProvider',
      read: (c) => c.read(computerDiveIdsProvider(_id).future),
    ),
    (
      name: 'allDiveComputersProvider',
      read: (c) => c.read(allDiveComputersProvider.future),
    ),
    (
      name: 'computersForDiveProvider',
      read: (c) => c.read(computersForDiveProvider(_id).future),
    ),
    (
      name: 'diveComputerByIdProvider',
      read: (c) => c.read(diveComputerByIdProvider(_id).future),
    ),
    (
      name: 'favoriteDiveComputerProvider',
      read: (c) => c.read(favoriteDiveComputerProvider.future),
    ),
    (
      name: 'primaryComputerIdProvider',
      read: (c) => c.read(primaryComputerIdProvider(_id).future),
    ),
  ]);

  _tickGroup('dive log', [
    (
      name: 'customFieldKeySuggestionsProvider',
      read: (c) => c.read(customFieldKeySuggestionsProvider(_id).future),
    ),
    (
      name: 'diveDataSourcesProvider',
      read: (c) => c.read(diveDataSourcesProvider(_id).future),
    ),
    (
      name: 'diveNumberingInfoProvider',
      read: (c) => c.read(diveNumberingInfoProvider.future),
    ),
    (
      name: 'diveProfileProvider',
      read: (c) => c.read(diveProfileProvider(_id).future),
    ),
    (name: 'diveProvider', read: (c) => c.read(diveProvider(_id).future)),
    (
      name: 'diveRecordsProvider',
      read: (c) => c.read(diveRecordsProvider.future),
    ),
    (
      name: 'diveSearchProvider',
      read: (c) => c.read(diveSearchProvider(_id).future),
    ),
    (
      name: 'diveStatisticsProvider',
      read: (c) => c.read(diveStatisticsProvider.future),
    ),
    (name: 'divesProvider', read: (c) => c.read(divesProvider.future)),
    (
      name: 'isMultiDataSourceDiveProvider',
      read: (c) => c.read(isMultiDataSourceDiveProvider(_id).future),
    ),
    (
      name: 'nextDiveNumberProvider',
      read: (c) => c.read(nextDiveNumberProvider.future),
    ),
    (
      name: 'orderedDiveIdsProvider',
      read: (c) => c.read(orderedDiveIdsProvider.future),
    ),
    (
      name: 'sourceProfilesProvider',
      read: (c) => c.read(sourceProfilesProvider(_id).future),
    ),
    (
      name: 'surfaceIntervalProvider',
      read: (c) => c.read(surfaceIntervalProvider(_id).future),
    ),
    (
      name: 'tankPressuresProvider',
      read: (c) => c.read(tankPressuresProvider(_id).future),
    ),
    (
      name: 'analysisDiveProvider',
      read: (c) => c.read(analysisDiveProvider(_id).future),
    ),
    (
      name: 'diveComputerEventsProvider',
      read: (c) => c.read(diveComputerEventsProvider(_id).future),
    ),
    (
      name: 'weeklyOtuProvider',
      read: (c) => c.read(weeklyOtuProvider(_id).future),
    ),
    (
      name: 'tablePresetsProvider',
      read: (c) => c.read(tablePresetsProvider(_id).future),
    ),
  ]);

  _tickGroup('dive sites', [
    (name: 'siteProvider', read: (c) => c.read(siteProvider(_id).future)),
    (
      name: 'siteSearchProvider',
      read: (c) => c.read(siteSearchProvider(_id).future),
    ),
    (name: 'sitesProvider', read: (c) => c.read(sitesProvider.future)),
    (
      name: 'sitesWithCountsProvider',
      read: (c) => c.read(sitesWithCountsProvider.future),
    ),
  ]);

  _tickGroup('dive types', [
    (
      name: 'builtInDiveTypesProvider',
      read: (c) => c.read(builtInDiveTypesProvider.future),
    ),
    (
      name: 'customDiveTypesProvider',
      read: (c) => c.read(customDiveTypesProvider.future),
    ),
    (
      name: 'diveTypeProvider',
      read: (c) => c.read(diveTypeProvider(_id).future),
    ),
    (
      name: 'diveTypeStatisticsProvider',
      read: (c) => c.read(diveTypeStatisticsProvider.future),
    ),
    (name: 'diveTypesProvider', read: (c) => c.read(diveTypesProvider.future)),
  ]);

  _tickGroup('divers', [
    (name: 'allDiversProvider', read: (c) => c.read(allDiversProvider.future)),
    (
      name: 'currentDiverProvider',
      read: (c) => c.read(currentDiverProvider.future),
    ),
    (
      name: 'diverByIdProvider',
      read: (c) => c.read(diverByIdProvider(_id).future),
    ),
    (
      name: 'diverDiveCountProvider',
      read: (c) => c.read(diverDiveCountProvider(_id).future),
    ),
    (
      name: 'diverStatsProvider',
      read: (c) => c.read(diverStatsProvider(_id).future),
    ),
    (
      name: 'diverTotalBottomTimeProvider',
      read: (c) => c.read(diverTotalBottomTimeProvider(_id).future),
    ),
    (
      name: 'validatedCurrentDiverIdProvider',
      read: (c) => c.read(validatedCurrentDiverIdProvider.future),
    ),
  ]);

  _tickGroup('equipment', [
    (
      name: 'activeEquipmentClocksProvider',
      read: (c) => c.read(activeEquipmentClocksProvider.future),
    ),
    (
      name: 'activeEquipmentProvider',
      read: (c) => c.read(activeEquipmentProvider.future),
    ),
    (
      name: 'allEquipmentProvider',
      read: (c) => c.read(allEquipmentProvider.future),
    ),
    (
      name: 'equipmentByStatusProvider',
      read: (c) =>
          c.read(equipmentByStatusProvider(EquipmentStatus.active).future),
    ),
    (
      name: 'equipmentDiveCountProvider',
      read: (c) => c.read(equipmentDiveCountProvider(_id).future),
    ),
    (
      name: 'equipmentItemProvider',
      read: (c) => c.read(equipmentItemProvider(_id).future),
    ),
    (
      name: 'equipmentSearchProvider',
      read: (c) => c.read(equipmentSearchProvider(_id).future),
    ),
    (
      name: 'equipmentTripCountProvider',
      read: (c) => c.read(equipmentTripCountProvider(_id).future),
    ),
    (
      name: 'equipmentTripIdsProvider',
      read: (c) => c.read(equipmentTripIdsProvider(_id).future),
    ),
    (
      name: 'mostRecentServiceRecordProvider',
      read: (c) => c.read(mostRecentServiceRecordProvider(_id).future),
    ),
    (
      name: 'retiredEquipmentProvider',
      read: (c) => c.read(retiredEquipmentProvider.future),
    ),
    (
      name: 'serviceClockStatusesProvider',
      read: (c) => c.read(serviceClockStatusesProvider(_id).future),
    ),
    (
      name: 'serviceDueEquipmentProvider',
      read: (c) => c.read(serviceDueEquipmentProvider.future),
    ),
    (
      name: 'serviceDueSoonWindowDaysProvider',
      read: (c) => c.read(serviceDueSoonWindowDaysProvider.future),
    ),
    (
      name: 'serviceKindsProvider',
      read: (c) => c.read(serviceKindsProvider.future),
    ),
    (
      name: 'serviceRecordByIdProvider',
      read: (c) => c.read(serviceRecordByIdProvider(_id).future),
    ),
    (
      name: 'serviceRecordCountProvider',
      read: (c) => c.read(serviceRecordCountProvider(_id).future),
    ),
    (
      name: 'serviceRecordTotalCostProvider',
      read: (c) => c.read(serviceRecordTotalCostProvider(_id).future),
    ),
    (
      name: 'serviceRecordsForEquipmentProvider',
      read: (c) => c.read(serviceRecordsForEquipmentProvider(_id).future),
    ),
    (
      name: 'serviceSchedulesForEquipmentProvider',
      read: (c) => c.read(serviceSchedulesForEquipmentProvider(_id).future),
    ),
    (
      name: 'tripServiceAlertsProvider',
      read: (c) => c.read(tripServiceAlertsProvider(_id).future),
    ),
    (
      name: 'equipmentSetGeofencesProvider',
      read: (c) => c.read(equipmentSetGeofencesProvider(_id).future),
    ),
    (
      name: 'equipmentSetProvider',
      read: (c) => c.read(equipmentSetProvider(_id).future),
    ),
    (
      name: 'equipmentSetSelectionInputsProvider',
      read: (c) => c.read(equipmentSetSelectionInputsProvider.future),
    ),
    (
      name: 'equipmentSetsProvider',
      read: (c) => c.read(equipmentSetsProvider.future),
    ),
  ]);

  _tickGroup('gps log', [
    (
      name: 'gpsTrackDetailProvider',
      read: (c) => c.read(gpsTrackDetailProvider(_id).future),
    ),
    (
      name: 'gpsTrackGeometryProvider',
      read: (c) =>
          c.read(gpsTrackGeometryProvider((_id, TrackLod.overview)).future),
    ),
    (
      name: 'trackForDiveProvider',
      read: (c) => c.read(trackForDiveProvider(_id).future),
    ),
  ]);

  _tickGroup('maps', [
    (
      name: 'cachedRegionByIdProvider',
      read: (c) => c.read(cachedRegionByIdProvider(_id).future),
    ),
    (
      name: 'cachedRegionsProvider',
      read: (c) => c.read(cachedRegionsProvider.future),
    ),
  ]);

  _tickGroup('marine life', [
    (
      name: 'allSpeciesProvider',
      read: (c) => c.read(allSpeciesProvider.future),
    ),
    (
      name: 'diveSightingsProvider',
      read: (c) => c.read(diveSightingsProvider(_id).future),
    ),
    (
      name: 'siteExpectedSpeciesProvider',
      read: (c) => c.read(siteExpectedSpeciesProvider(_id).future),
    ),
    (
      name: 'siteSpottedSpeciesProvider',
      read: (c) => c.read(siteSpottedSpeciesProvider(_id).future),
    ),
    (
      name: 'speciesByCategoryProvider',
      read: (c) =>
          c.read(speciesByCategoryProvider(SpeciesCategory.fish).future),
    ),
    (name: 'speciesProvider', read: (c) => c.read(speciesProvider(_id).future)),
    (
      name: 'speciesSearchProvider',
      read: (c) => c.read(speciesSearchProvider(_id).future),
    ),
  ]);

  _tickGroup('media', [
    (
      name: 'lightroomAccountProvider',
      read: (c) => c.read(lightroomAccountProvider.future),
    ),
    (
      name: 'pendingSuggestionsForDiveProvider',
      read: (c) => c.read(pendingSuggestionsForDiveProvider(_id).future),
    ),
    (
      name: 'allDivePhotoGpsProvider',
      read: (c) => c.read(allDivePhotoGpsProvider(_id).future),
    ),
    (
      name: 'divePhotoGpsProvider',
      read: (c) => c.read(divePhotoGpsProvider(_id).future),
    ),
    (
      name: 'mediaByIdProvider',
      read: (c) => c.read(mediaByIdProvider(_id).future),
    ),
    (
      name: 'mediaCountForDiveProvider',
      read: (c) => c.read(mediaCountForDiveProvider(_id).future),
    ),
    (
      name: 'mediaForDiveProvider',
      read: (c) => c.read(mediaForDiveProvider(_id).future),
    ),
    (
      name: 'orphanedMediaProvider',
      read: (c) => c.read(orphanedMediaProvider.future),
    ),
    (
      name: 'pendingSuggestionCountProvider',
      read: (c) => c.read(pendingSuggestionCountProvider(_id).future),
    ),
    (
      name: 'manifestSubscriptionsProvider',
      read: (c) => c.read(manifestSubscriptionsProvider.future),
    ),
    (
      name: 'mediaCountForSiteProvider',
      read: (c) => c.read(mediaCountForSiteProvider(_id).future),
    ),
    (
      name: 'mediaForSiteProvider',
      read: (c) => c.read(mediaForSiteProvider(_id).future),
    ),
    (
      name: 'mediaFromDivesAtSiteProvider',
      read: (c) => c.read(mediaFromDivesAtSiteProvider(_id).future),
    ),
    (
      name: 'mediaStoreStatusHintProvider',
      read: (c) => c.read(mediaStoreStatusHintProvider.future),
    ),
  ]);

  _tickGroup('planner', [
    (
      name: 'planComparisonProvider',
      read: (c) => c.read(planComparisonProvider(_id).future),
    ),
    (
      name: 'loggedAverageSacProvider',
      read: (c) => c.read(loggedAverageSacProvider.future),
    ),
  ]);

  _tickGroup('settings', [
    (
      name: 'connectedAccountsWithStatusProvider',
      read: (c) => c.read(connectedAccountsWithStatusProvider.future),
    ),
    (
      name: 'setupGuideStatusProvider',
      read: (c) => c.read(setupGuideStatusProvider.future),
    ),
    (
      name: 'shareByDefaultProvider',
      read: (c) => c.read(shareByDefaultProvider.future),
    ),
  ]);

  _tickGroup('statistics', [
    (
      name: 'filteredDiveStatisticsProvider',
      read: (c) => c.read(filteredDiveStatisticsProvider.future),
    ),
    (
      name: 'filteredDiveRecordsProvider',
      read: (c) => c.read(filteredDiveRecordsProvider.future),
    ),
  ]);

  _tickGroup('tags', [
    (name: 'tagProvider', read: (c) => c.read(tagProvider(_id).future)),
    (
      name: 'tagSearchProvider',
      read: (c) => c.read(tagSearchProvider(_id).future),
    ),
    (
      name: 'tagStatisticsProvider',
      read: (c) => c.read(tagStatisticsProvider.future),
    ),
    (
      name: 'tagsForDiveProvider',
      read: (c) => c.read(tagsForDiveProvider(_id).future),
    ),
    (name: 'tagsProvider', read: (c) => c.read(tagsProvider.future)),
  ]);

  _tickGroup('tank presets', [
    (
      name: 'customTankPresetsProvider',
      read: (c) => c.read(customTankPresetsProvider.future),
    ),
    (
      name: 'tankPresetProvider',
      read: (c) => c.read(tankPresetProvider(_id).future),
    ),
    (
      name: 'tankPresetsProvider',
      read: (c) => c.read(tankPresetsProvider.future),
    ),
  ]);

  _tickGroup('trips', [
    (
      name: 'itineraryDaysProvider',
      read: (c) => c.read(itineraryDaysProvider(_id).future),
    ),
    (
      name: 'liveaboardDetailsProvider',
      read: (c) => c.read(liveaboardDetailsProvider(_id).future),
    ),
    (name: 'allTripsProvider', read: (c) => c.read(allTripsProvider.future)),
    (
      name: 'allTripsWithStatsProvider',
      read: (c) => c.read(allTripsWithStatsProvider.future),
    ),
    (
      name: 'diveIdsForTripProvider',
      read: (c) => c.read(diveIdsForTripProvider(_id).future),
    ),
    (
      name: 'divesForTripProvider',
      read: (c) => c.read(divesForTripProvider(_id).future),
    ),
    (
      name: 'tripByIdProvider',
      read: (c) => c.read(tripByIdProvider(_id).future),
    ),
    (
      name: 'tripForDateProvider',
      read: (c) => c.read(tripForDateProvider(DateTime.utc(2024, 1, 1)).future),
    ),
    (
      name: 'tripSearchProvider',
      read: (c) => c.read(tripSearchProvider(_id).future),
    ),
    (
      name: 'tripWithStatsProvider',
      read: (c) => c.read(tripWithStatsProvider(_id).future),
    ),
    // The 158th tick subscriber, `_equipmentFilteredTripsProvider`, is private
    // to trip_providers.dart. It is only reachable through
    // `filteredTripsProvider` once an equipment filter is set, so drive it
    // that way and wait for the delegated family to settle.
    (
      name: 'filteredTripsProvider (equipment filter)',
      read: _readFilteredTrips,
    ),
  ]);

  _tickGroup('universal import', [
    (
      name: 'userCsvPresetsProvider',
      read: (c) => c.read(userCsvPresetsProvider.future),
    ),
  ]);
}
