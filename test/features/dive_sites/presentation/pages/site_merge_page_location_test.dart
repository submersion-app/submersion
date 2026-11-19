import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_merge_page.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/identity_section.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/location_section.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/location_picker_map.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/edit_form_scaffold.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/fake_hosts.dart';
import '../../../../helpers/test_database.dart';

/// A geocoder that answers [place] for a lookup, once [hold] completes when
/// one is given, and [fix] for a position.
class _Geocoder implements LocationService {
  _Geocoder({this.place = const PlaceLookup.empty(), this.fix, this.hold});

  final PlaceLookup place;
  final LocationResult? fix;
  final Completer<void>? hold;

  @override
  Future<PlaceLookup> reverseGeocode(
    double latitude,
    double longitude, {
    required String languageCode,
  }) async {
    await hold?.future;
    return place;
  }

  @override
  Future<LocationResult?> getCurrentLocation({
    bool includeGeocoding = true,
    Duration timeout = const Duration(seconds: 15),
    String languageCode = LocationService.defaultLanguageCode,
  }) async => fix;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoElevation extends ElevationService {
  @override
  Future<double?> fetchElevation({
    required double latitude,
    required double longitude,
  }) async => null;
}

/// The merge page's location actions (issue #4527, phase 2, plan 7): Look
/// up from the coordinates, Use my location and Pick from map, as the form
/// had them.
void main() {
  final l = AppLocalizationsEn();
  const belize = PlaceLookup(
    country: 'Belize',
    countryCode: 'BZ',
    region: 'Lighthouse Reef',
    locality: 'Belize City',
    bodyOfWater: 'Caribbean Sea',
  );
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    final sites = SiteRepository();
    await sites.createSite(
      const DiveSite(
        id: 'a',
        name: 'Hole',
        location: GeoPoint(17.3, -87.5),
        region: 'Turneffe',
      ),
    );
    await sites.createSite(const DiveSite(id: 'b', name: 'Hole North'));
  });

  tearDown(tearDownTestDatabase);

  Future<void> pump(WidgetTester tester, _Geocoder geocoder) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          locationServiceProvider.overrideWithValue(geocoder),
          elevationServiceProvider.overrideWithValue(_NoElevation()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SiteMergePage(siteIds: ['a', 'b']),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  IdentitySection identity(WidgetTester tester) =>
      tester.widget<IdentitySection>(find.byType(IdentitySection));

  LocationSection location(WidgetTester tester) =>
      tester.widget<LocationSection>(find.byType(LocationSection));

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('Look up fills the blank names, asks about a differing one, '
      'and says when nothing is left to change', (tester) async {
    await pump(tester, _Geocoder(place: belize));

    await tapText(tester, l.diveSites_edit_gps_lookupFromCoordinates);
    expect(find.text('Region: Lighthouse Reef'), findsOneWidget);
    expect(identity(tester).countryController.text, 'Belize');
    expect(identity(tester).cityController.text, 'Belize City');
    expect(identity(tester).regionController.text, 'Turneffe');

    await tapText(tester, l.diveSites_edit_lookupReplace_replace);
    expect(identity(tester).regionController.text, 'Lighthouse Reef');

    await tapText(tester, l.diveSites_edit_gps_lookupFromCoordinates);
    expect(find.text(l.diveSites_edit_snackbar_lookupNoChanges), findsOne);
  });

  // The answer describes where the site was when Look up was pressed: a
  // position cycled in meanwhile gets none of its names (code review).
  testWidgets('Look up drops a place found for coordinates since cycled away', (
    tester,
  ) async {
    final hold = Completer<void>();
    await pump(tester, _Geocoder(place: belize, hold: hold));

    await tester.ensureVisible(
      find.text(l.diveSites_edit_gps_lookupFromCoordinates),
    );
    await tester.tap(find.text(l.diveSites_edit_gps_lookupFromCoordinates));
    await tester.pump();
    location(tester).coordinatesExtras!.onCycle();
    await tester.pump();
    hold.complete();
    await tester.pumpAndSettle();

    expect(identity(tester).countryController.text, isEmpty);
    expect(find.text('Region: Lighthouse Reef'), findsNothing);
  });

  // A field the diver only taps into (a selection, no new text) is no
  // change, so leaving asks nothing (code review).
  testWidgets('tapping into a field leaves the merge unchanged', (
    tester,
  ) async {
    await pump(tester, _Geocoder());
    bool changed() => tester
        .widget<EditFormScaffold>(find.byType(EditFormScaffold))
        .hasUnsavedChanges;
    final name = find
        .descendant(
          of: find.byType(IdentitySection),
          matching: find.byType(EditableText),
        )
        .first;

    await tester.tap(name);
    await tester.pumpAndSettle();
    expect(changed(), isFalse);

    await tester.enterText(name, 'Hole South');
    await tester.pumpAndSettle();
    expect(changed(), isTrue);
  });

  testWidgets('Keep holds a differing name', (tester) async {
    await pump(tester, _Geocoder(place: belize));

    await tapText(tester, l.diveSites_edit_gps_lookupFromCoordinates);
    await tapText(tester, l.diveSites_edit_lookupReplace_keep);

    expect(identity(tester).regionController.text, 'Turneffe');
    expect(identity(tester).countryController.text, 'Belize');
  });

  for (final (place, message) in [
    (const PlaceLookup.unavailable(), l.diveSites_edit_snackbar_lookupFailed),
    (const PlaceLookup.empty(), l.diveSites_edit_snackbar_lookupNothingFound),
  ]) {
    testWidgets('Look up says "$message"', (tester) async {
      await pump(tester, _Geocoder(place: place));

      await tapText(tester, l.diveSites_edit_gps_lookupFromCoordinates);

      expect(find.text(message), findsOneWidget);
      expect(identity(tester).countryController.text, isEmpty);
    });
  }

  testWidgets('Use my location moves the site and fills the blank names', (
    tester,
  ) async {
    await pump(
      tester,
      _Geocoder(
        fix: const LocationResult(
          latitude: 20.5,
          longitude: -87.1,
          accuracy: 5,
          country: 'Mexico',
        ),
      ),
    );

    await tapText(tester, l.diveSites_edit_gps_useMyLocation);

    expect(location(tester).latitudeController.text, '20.500000');
    expect(location(tester).longitudeController.text, '-87.100000');
    expect(identity(tester).countryController.text, 'Mexico');
    expect(identity(tester).regionController.text, 'Turneffe');
    expect(
      find.text(l.diveSites_edit_snackbar_locationCapturedWithAccuracy('5')),
      findsOneWidget,
    );
  });

  testWidgets('Use my location with the geocoder unreachable keeps the '
      'position and says why the names stay empty', (tester) async {
    await pump(
      tester,
      _Geocoder(
        fix: const LocationResult(
          latitude: 20.5,
          longitude: -87.1,
          geocodeUnavailable: true,
        ),
      ),
    );

    await tapText(tester, l.diveSites_edit_gps_useMyLocation);

    expect(location(tester).latitudeController.text, '20.500000');
    expect(identity(tester).countryController.text, isEmpty);
    expect(find.text(l.diveSites_edit_snackbar_lookupFailed), findsOneWidget);
  });

  testWidgets('Use my location without a position says so and moves nothing', (
    tester,
  ) async {
    await pump(tester, _Geocoder());

    await tapText(tester, l.diveSites_edit_gps_useMyLocation);

    expect(location(tester).latitudeController.text, '17.3');
    expect(
      find.text(l.diveSites_edit_snackbar_locationUnavailableDesktop),
      findsOneWidget,
    );
  });

  testWidgets('Pick from map moves the site to the picked point', (
    tester,
  ) async {
    // The picker names its starting point itself, from Nominatim.
    serveFakeHost('nominatim.openstreetmap.org');
    await pump(tester, _Geocoder());

    await tester.ensureVisible(find.text(l.diveSites_edit_gps_pickFromMap));
    await tester.tap(find.text(l.diveSites_edit_gps_pickFromMap));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    Navigator.of(tester.element(find.byType(LocationPickerMap))).pop(
      const PickedLocation(latitude: 16.5, longitude: -88.2, place: belize),
    );
    await tester.pumpAndSettle();

    expect(location(tester).latitudeController.text, '16.500000');
    expect(identity(tester).countryController.text, 'Belize');
    expect(identity(tester).regionController.text, 'Turneffe');
    expect(
      find.text(l.diveSites_edit_snackbar_locationSelectedFromMap),
      findsOneWidget,
    );
  });
}
