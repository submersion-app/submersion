import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

/// Records the coordinates it was asked to reverse-geocode and returns a fixed
/// placemark, so tests can prove the seed path fires geocoding. (The
/// fill-only-empty write of country/region is already covered by the existing
/// site_edit_page_test.dart geocode tests.)
class _RecordingLocationService implements LocationService {
  ({double lat, double lng})? geocodedWith;

  @override
  Future<PlaceLookup> reverseGeocode(
    double latitude,
    double longitude, {
    required String languageCode,
  }) async {
    geocodedWith = (lat: latitude, lng: longitude);
    return const PlaceLookup(country: 'Testland', region: 'Test Region');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Diver> _divers() => [
  Diver(
    id: 'd1',
    name: 'Me',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  ),
];

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets('seeds coordinates and fires geocoding from initialLocation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final geocoder = _RecordingLocationService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => _divers()),
          shareByDefaultProvider.overrideWith((_) async => false),
          locationServiceProvider.overrideWithValue(geocoder),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SiteEditPage(initialLocation: GeoPoint(34.0182, -118.4965)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Location section is collapsed by default; its summary is "{lat}, {lng}".
    expect(find.text('34.018200, -118.496500'), findsOneWidget);
    // Seeding fired a reverse-geocode for exactly those coordinates.
    expect(geocoder.geocodedWith, isNotNull);
    expect(geocoder.geocodedWith!.lat, closeTo(34.0182, 1e-9));
    expect(geocoder.geocodedWith!.lng, closeTo(-118.4965, 1e-9));
  });

  testWidgets('/sites/new maps a GeoPoint extra into initialLocation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => context.push(
                    '/sites/new',
                    extra: const GeoPoint(1.5, 2.5),
                  ),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/sites/new',
          builder: (context, state) => SiteEditPage(
            initialLocation: state.extra is GeoPoint
                ? state.extra as GeoPoint
                : null,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => _divers()),
          shareByDefaultProvider.overrideWith((_) async => false),
          locationServiceProvider.overrideWithValue(
            _RecordingLocationService(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('1.500000, 2.500000'), findsOneWidget);
  });
}
