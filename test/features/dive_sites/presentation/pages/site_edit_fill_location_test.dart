import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

/// Every coordinate source (current location, map pick, seeding from a
/// dive) answers with the same place, so the tests can tell which fields
/// the form chose to fill.
class _FakeLocationService implements LocationService {
  _FakeLocationService(this.place);

  final PlaceLookup place;

  @override
  Future<PlaceLookup> reverseGeocode(
    double latitude,
    double longitude, {
    required String languageCode,
  }) async => place;

  @override
  Future<LocationResult?> getCurrentLocation({
    bool includeGeocoding = true,
    Duration timeout = const Duration(seconds: 15),
    String languageCode = LocationService.defaultLanguageCode,
  }) async => LocationResult(
    latitude: 47.027631,
    longitude: 8.400640,
    accuracy: 5,
    country: place.country,
    region: place.region,
    locality: place.locality,
    bodyOfWater: place.bodyOfWater,
    geocodeUnavailable: place.networkFailed,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _weggis = PlaceLookup(
  country: 'Switzerland',
  region: 'Lucerne',
  locality: 'Weggis',
  bodyOfWater: 'Lake Lucerne',
);

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

  Future<void> pumpEditor(
    WidgetTester tester, {
    String? siteId,
    GeoPoint? initialLocation,
    PlaceLookup place = _weggis,
    DiveSite? seeded,
  }) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => const <Diver>[]),
          shareByDefaultProvider.overrideWith((_) async => false),
          validatedCurrentDiverIdProvider.overrideWith((_) async => null),
          if (seeded != null)
            siteProvider(seeded.id).overrideWith((_) async => seeded),
          locationServiceProvider.overrideWithValue(
            _FakeLocationService(place),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SiteEditPage(
              siteId: siteId,
              initialLocation: initialLocation,
              embedded: true,
              onSaved: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Use my location fills town and body of water', (tester) async {
    await pumpEditor(tester);

    // The Location group rests collapsed; expand it to reach the GPS row.
    await tester.tap(find.text('Add GPS position or altitude'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use My Location'));
    await tester.pumpAndSettle();

    expect(find.text('Weggis'), findsOneWidget);
    expect(find.text('Lake Lucerne'), findsOneWidget);
    expect(find.text('Switzerland'), findsOneWidget);
  });

  testWidgets('Use my location never overwrites a filled field', (
    tester,
  ) async {
    final repo = SiteRepository();
    final seeded = await repo.createSite(
      const DiveSite(id: '', name: 'Hertenstein', city: 'Hertenstein'),
    );
    await pumpEditor(tester, siteId: seeded.id, seeded: seeded);

    // The Location group rests collapsed; expand it to reach the GPS row.
    await tester.tap(find.text('Add GPS position or altitude'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use My Location'));
    await tester.pumpAndSettle();

    expect(find.text('Hertenstein'), findsWidgets);
    expect(find.text('Weggis'), findsNothing);
    expect(find.text('Lake Lucerne'), findsOneWidget);
  });

  testWidgets('seeding from a dive fills town and body of water', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      initialLocation: const GeoPoint(47.027631, 8.400640),
    );

    expect(find.text('Weggis'), findsOneWidget);
    expect(find.text('Lake Lucerne'), findsOneWidget);
  });

  testWidgets('Use my location reports an unreachable geocoder', (
    tester,
  ) async {
    await pumpEditor(tester, place: const PlaceLookup.unavailable());

    await tester.tap(find.text('Add GPS position or altitude'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use My Location'));
    await tester.pumpAndSettle();

    // The coordinates still landed.
    expect(find.text('47.027631'), findsOneWidget);
    expect(
      find.text('Location lookup failed. Check your connection and try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('Location captured'), findsNothing);
  });
}
