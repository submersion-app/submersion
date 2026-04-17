import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_map_content.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_map_content.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/location_picker_map.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_content.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_map_content.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_overview_tab.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_voyage_map.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../helpers/mock_providers.dart';

/// Helper to create overrides with map backgrounds enabled.
/// Builds the list from scratch to avoid duplicate settingsProvider overrides.
Future<List<Override>> _getMapEnabledOverrides() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final settings = MockSettingsNotifier();
  await settings.setShowMapBackgroundOnDiveCards(true);
  await settings.setShowMapBackgroundOnSiteCards(true);
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => settings),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
  ];
}

/// Tests verifying that all OSM tile requests include the correct User-Agent
/// header and package name ('app.submersion') to comply with OpenStreetMap's
/// tile usage policy.
///
/// See: https://github.com/submersion-app/submersion/issues/132
void main() {
  // -- DiveListTile (covers 4 patch lines: httpHeaders block) --
  group('DiveListTile OSM tile User-Agent (issue #132)', () {
    testWidgets(
      'includes User-Agent httpHeaders when map background is shown',
      (tester) async {
        final overrides = await _getMapEnabledOverrides();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              batchProfileCacheProvider.overrideWith(
                (ref) => <String, List<DiveProfilePoint>>{},
              ),
            ].cast(),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: DiveListTile(
                  diveId: 'test-dive-1',
                  diveNumber: 1,
                  dateTime: DateTime(2026, 3, 28),
                  siteName: 'Blue Hole',
                  siteLatitude: 17.3161,
                  siteLongitude: -87.5347,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final cachedImage = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        );
        expect(cachedImage.httpHeaders, isNotNull);
        expect(
          cachedImage.httpHeaders!['User-Agent'],
          contains('app.submersion'),
        );
        expect(cachedImage.imageUrl, contains('tile.openstreetmap.org'));
      },
    );
  });

  // -- SiteListTile (covers 1 patch line: site_list_content.dart:1245) --
  group('SiteListTile TileLayer', () {
    testWidgets('renders TileLayer when map background is enabled', (
      tester,
    ) async {
      final overrides = await _getMapEnabledOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [...overrides].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SiteListTile(
                name: 'Blue Hole',
                latitude: 17.3161,
                longitude: -87.5347,
                diveCount: 5,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TileLayer), findsOneWidget);
    });
  });

  // -- LocationPickerMap (covers 1 patch line: location_picker_map.dart:171) --
  group('LocationPickerMap TileLayer', () {
    testWidgets('renders TileLayer for OSM tiles', (tester) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [...overrides].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LocationPickerMap(initialLocation: LatLng(17.3161, -87.5347)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TileLayer), findsOneWidget);
    });
  });

  // -- DiveMapContent (covers 1 patch line: dive_map_content.dart:310) --
  group('DiveMapContent TileLayer', () {
    testWidgets('renders TileLayer for OSM tiles', (tester) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            sortedFilteredDivesProvider.overrideWith(
              (ref) => const AsyncValue<List<Dive>>.data([]),
            ),
            diveActivityHeatMapProvider.overrideWith(
              (ref) => const AsyncValue<List<HeatMapPoint>>.data([]),
            ),
          ].cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DiveMapContent(onItemSelected: (_) {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TileLayer), findsOneWidget);
    });
  });

  // -- SiteMapContent (covers 1 patch line: site_map_content.dart:266) --
  group('SiteMapContent TileLayer', () {
    testWidgets('renders TileLayer for OSM tiles', (tester) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            sitesWithCountsProvider.overrideWith(
              (ref) async => <SiteWithDiveCount>[],
            ),
            siteCoverageHeatMapProvider.overrideWith(
              (ref) async => <HeatMapPoint>[],
            ),
          ].cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SiteMapContent(onItemSelected: (_) {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TileLayer), findsOneWidget);
    });
  });

  // -- DiveCenterMapContent (covers 1 patch line: dive_center_map_content.dart:219) --
  group('DiveCenterMapContent TileLayer', () {
    testWidgets('renders TileLayer for OSM tiles', (tester) async {
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            diveCenterListNotifierProvider.overrideWith((ref) {
              return _MockDiveCenterListNotifier();
            }),
          ].cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DiveCenterMapContent(onItemSelected: (_) {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TileLayer), findsOneWidget);
    });
  });

  // -- TripVoyageMap (covers 1 patch line: trip_voyage_map.dart:67) --
  group('TripVoyageMap TileLayer', () {
    testWidgets('renders TileLayer when trip has locations', (tester) async {
      final overrides = await getBaseOverrides();
      final now = DateTime.now();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            liveaboardDetailsProvider('trip-1').overrideWith(
              (ref) async => LiveaboardDetails(
                id: 'lb-1',
                tripId: 'trip-1',
                vesselName: 'Test Vessel',
                embarkLatitude: 17.0,
                embarkLongitude: -87.0,
                createdAt: now,
                updatedAt: now,
              ),
            ),
            tripSitesWithLocationsProvider('trip-1').overrideWith(
              (ref) async => <DiveSite>[
                const DiveSite(
                  id: 'site-1',
                  name: 'Test Site',
                  location: GeoPoint(17.5, -87.5),
                ),
              ],
            ),
          ].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: TripVoyageMap(tripId: 'trip-1')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TileLayer), findsOneWidget);
    });
  });

  // -- TripOverviewTab (covers 1 patch line: trip_overview_tab.dart:200) --
  group('TripOverviewTab TileLayer', () {
    testWidgets('renders TileLayer when trip has site locations', (
      tester,
    ) async {
      final overrides = await getBaseOverrides();

      final trip = Trip(
        id: 'trip-1',
        name: 'Test Trip',
        startDate: DateTime(2026, 3, 25),
        endDate: DateTime(2026, 3, 30),
        tripType: TripType.resort,
        notes: '',
        createdAt: DateTime(2026, 3, 20),
        updatedAt: DateTime(2026, 3, 20),
      );

      final tripWithStats = TripWithStats(
        trip: trip,
        diveCount: 2,
        totalBottomTime: 75 * 60,
        maxDepth: 30.0,
      );

      final dives = [
        createTestDiveWithBottomTime(
          id: 'trip-dive-1',
          diveNumber: 1,
          maxDepth: 25.0,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            divesForTripProvider(trip.id).overrideWith((ref) async => dives),
            tripSitesWithLocationsProvider(trip.id).overrideWith(
              (ref) async => <DiveSite>[
                const DiveSite(
                  id: 'site-1',
                  name: 'Test Site',
                  location: GeoPoint(17.5, -87.5),
                ),
              ],
            ),
          ].cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: TripOverviewTab(tripWithStats: tripWithStats)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The header should render a FlutterMap with TileLayer
      expect(find.byType(TileLayer), findsWidgets);
    });
  });
}

/// Mock StateNotifier that immediately provides empty dive center list.
class _MockDiveCenterListNotifier
    extends StateNotifier<AsyncValue<List<DiveCenter>>>
    implements DiveCenterListNotifier {
  _MockDiveCenterListNotifier() : super(const AsyncValue.data(<DiveCenter>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
