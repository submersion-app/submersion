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

const _lookupButton = 'Look up from coordinates';

void main() {
  late SharedPreferences prefs;
  late SiteRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    repo = SiteRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpEditor(
    WidgetTester tester, {
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
              siteId: seeded?.id,
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

  /// The Location group rests collapsed for an existing site; tapping its
  /// header expands it.
  Future<void> expandLocation(WidgetTester tester) async {
    await tester.tap(find.text('Location'));
    await tester.pumpAndSettle();
  }

  const coords = GeoPoint(47.027631, 8.400640);

  Future<DiveSite> seedSite({
    String? country,
    String? region,
    String? city,
    String? bodyOfWater,
  }) => repo.createSite(
    DiveSite(
      id: '',
      name: 'Hertenstein',
      location: coords,
      country: country,
      region: region,
      city: city,
      bodyOfWater: bodyOfWater,
    ),
  );

  testWidgets('the button is disabled until coordinates are present', (
    tester,
  ) async {
    await pumpEditor(tester);
    await tester.tap(find.text('Add GPS position or altitude'));
    await tester.pumpAndSettle();

    final button = find.widgetWithText(TextButton, _lookupButton);
    expect(tester.widget<TextButton>(button).onPressed, isNull);

    await tester.tap(find.text('Use My Location'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(button).onPressed, isNotNull);
  });

  testWidgets('fills the empty fields and saves them', (tester) async {
    final seeded = await seedSite();
    await pumpEditor(tester, seeded: seeded);
    await expandLocation(tester);

    await tester.tap(find.text(_lookupButton));
    await tester.pumpAndSettle();

    expect(find.text('Weggis'), findsOneWidget);
    expect(find.text('Lake Lucerne'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = await repo.getSiteById(seeded.id);
    expect(saved!.city, 'Weggis');
    expect(saved.bodyOfWater, 'Lake Lucerne');
    expect(saved.country, 'Switzerland');
  });

  testWidgets('offers to replace when nothing was empty and values differ', (
    tester,
  ) async {
    final seeded = await seedSite(
      country: 'Schweiz',
      region: 'Luzern',
      city: 'Weggis',
      bodyOfWater: 'Vierwaldstättersee',
    );
    await pumpEditor(tester, seeded: seeded);
    await expandLocation(tester);

    await tester.tap(find.text(_lookupButton));
    await tester.pumpAndSettle();

    expect(find.text('Replace location details?'), findsOneWidget);
    // Only the differing fields are listed; the town is identical.
    expect(find.textContaining('Lake Lucerne'), findsOneWidget);
    expect(find.textContaining('Body of Water: '), findsOneWidget);
    expect(find.textContaining('City: '), findsNothing);

    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(find.text('Lake Lucerne'), findsOneWidget);
    expect(find.text('Vierwaldstättersee'), findsNothing);
  });

  testWidgets('Keep leaves the fields alone', (tester) async {
    final seeded = await seedSite(
      country: 'Schweiz',
      region: 'Luzern',
      city: 'Weggis',
      bodyOfWater: 'Vierwaldstättersee',
    );
    await pumpEditor(tester, seeded: seeded);
    await expandLocation(tester);

    await tester.tap(find.text(_lookupButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();

    expect(find.text('Vierwaldstättersee'), findsOneWidget);
    expect(find.text('Lake Lucerne'), findsNothing);
  });

  testWidgets('says so when nothing was found', (tester) async {
    final seeded = await seedSite();
    await pumpEditor(tester, seeded: seeded, place: const PlaceLookup.empty());
    await expandLocation(tester);

    await tester.tap(find.text(_lookupButton));
    await tester.pumpAndSettle();

    expect(
      find.text('No location details found for these coordinates'),
      findsOneWidget,
    );
  });

  testWidgets('reports an unreachable geocoder', (tester) async {
    final seeded = await seedSite();
    await pumpEditor(
      tester,
      seeded: seeded,
      place: const PlaceLookup.unavailable(),
    );
    await expandLocation(tester);

    await tester.tap(find.text(_lookupButton));
    await tester.pumpAndSettle();

    expect(
      find.text('Location lookup failed. Check your connection and try again.'),
      findsOneWidget,
    );
  });
}
