import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_location_card_editor.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import 'site_editor_harness.dart';

/// A geocoder that answers [place], records the language it was asked in,
/// and holds each answer until [gate] completes when one is set.
class _Geocoder implements LocationService {
  _Geocoder(this.place, {this.gate, this.fixUnavailable = false});

  final PlaceLookup place;
  final Completer<void>? gate;

  /// Whether a position is found with its place unreachable.
  final bool fixUnavailable;
  final languages = <String>[];

  @override
  Future<PlaceLookup> reverseGeocode(
    double latitude,
    double longitude, {
    required String languageCode,
  }) async {
    languages.add(languageCode);
    await gate?.future;
    return place;
  }

  @override
  Future<LocationResult?> getCurrentLocation({
    bool includeGeocoding = true,
    Duration timeout = const Duration(seconds: 15),
    String languageCode = LocationService.defaultLanguageCode,
  }) async {
    languages.add(languageCode);
    return LocationResult(
      latitude: 17.3,
      longitude: -87.5,
      accuracy: 5,
      country: fixUnavailable ? null : place.country,
      geocodeUnavailable: fixUnavailable,
    );
  }

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

/// Look up from the coordinates on the site's Location card (issue #4527,
/// phase 2): the cases the old site form pinned, on the card that replaced
/// it (plan 7).
void main() {
  final l = AppLocalizationsEn();
  const place = PlaceLookup(
    country: 'Belize',
    countryCode: 'BZ',
    region: 'Lighthouse Reef',
    locality: 'Belize City',
    bodyOfWater: 'Caribbean Sea',
  );
  const at = GeoPoint(17.3, -87.5);

  Future<SiteEditorHarness> pump(
    WidgetTester tester,
    _Geocoder geocoder, {
    DiveSite site = const DiveSite(id: 's1', name: 'Hole', location: at),
    AppSettings settings = const AppSettings(),
  }) => pumpSiteEditor(
    tester,
    site,
    (session) => SiteLocationCardEditor(
      session: session,
      pickLocation: (_, _) async => null,
    ),
    settings: settings,
    overrides: [
      locationServiceProvider.overrideWithValue(geocoder),
      elevationServiceProvider.overrideWithValue(_NoElevation()),
    ],
  );

  Finder lookUp() => find.text(l.diveSites_edit_gps_lookupFromCoordinates);

  ButtonStyleButton lookUpButton(WidgetTester tester) =>
      tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: lookUp(),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );

  Future<void> tapLookUp(WidgetTester tester) async {
    await tester.tap(lookUp());
    await tester.pumpAndSettle();
  }

  testWidgets('Look up waits for coordinates and says why', (tester) async {
    await pump(
      tester,
      _Geocoder(place),
      site: const DiveSite(id: 's1', name: 'Hole'),
    );

    expect(lookUpButton(tester).onPressed, isNull);
    expect(find.text(l.diveSites_edit_gps_lookupNeedsCoordinates), findsOne);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '17.3');
    await tester.enterText(fields.at(1), '-87.5');
    await tester.pump();

    expect(lookUpButton(tester).onPressed, isNotNull);
    expect(
      find.text(l.diveSites_edit_gps_lookupNeedsCoordinates),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a running lookup shows its progress, then fills the names', (
    tester,
  ) async {
    final gate = Completer<void>();
    final h = await pump(tester, _Geocoder(place, gate: gate));

    await tester.tap(lookUp());
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(lookUpButton(tester).onPressed, isNull);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(h.session.valueOf(siteCountryField), 'Belize');
  });

  testWidgets('an answer for a position the site has left is dropped', (
    tester,
  ) async {
    final gate = Completer<void>();
    final h = await pump(tester, _Geocoder(place, gate: gate));

    await tester.tap(lookUp());
    await tester.pump();
    h.session.set(siteLocationField, const GeoPoint(20.5, -87.1));
    gate.complete();
    await tester.pumpAndSettle();

    expect(h.session.valueOf(siteCountryField), isNull);
    expect(h.session.valueOf(siteCityField), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('one press fills the blanks and asks only about the names '
      'that differ', (tester) async {
    final h = await pump(
      tester,
      _Geocoder(place),
      site: const DiveSite(
        id: 's1',
        name: 'Hole',
        location: at,
        region: 'Turneffe',
      ),
    );

    await tapLookUp(tester);

    expect(find.text(l.diveSites_edit_lookupReplace_title), findsOneWidget);
    expect(find.text('Region: Lighthouse Reef'), findsOneWidget);
    expect(find.textContaining('Country: '), findsNothing);
    expect(find.textContaining('City: '), findsNothing);
    expect(find.textContaining('Body of Water: '), findsNothing);

    // Keep holds the differing name, and the filled blanks stay filled.
    await tester.tap(find.text(l.diveSites_edit_lookupReplace_keep));
    await tester.pumpAndSettle();
    expect(h.session.valueOf(siteRegionField), 'Turneffe');
    expect(h.session.valueOf(siteCountryField), 'Belize');
    expect(h.session.valueOf(siteCityField), 'Belize City');
  });

  testWidgets('says so when every name already matches', (tester) async {
    await pump(
      tester,
      _Geocoder(place),
      site: const DiveSite(
        id: 's1',
        name: 'Hole',
        location: at,
        country: 'Belize',
        countryCode: 'BZ',
        region: 'Lighthouse Reef',
        city: 'Belize City',
        bodyOfWater: 'Caribbean Sea',
      ),
    );

    await tapLookUp(tester);

    expect(find.text(l.diveSites_edit_snackbar_lookupNoChanges), findsOne);
    expect(find.text(l.diveSites_edit_lookupReplace_title), findsNothing);
  });

  testWidgets('says so when nothing was found', (tester) async {
    final h = await pump(tester, _Geocoder(const PlaceLookup.empty()));

    await tapLookUp(tester);

    expect(find.text(l.diveSites_edit_snackbar_lookupNothingFound), findsOne);
    expect(h.session.valueOf(siteCountryField), isNull);
  });

  testWidgets('says so when the geocoder is unreachable', (tester) async {
    final h = await pump(tester, _Geocoder(const PlaceLookup.unavailable()));

    await tapLookUp(tester);

    expect(find.text(l.diveSites_edit_snackbar_lookupFailed), findsOne);
    expect(h.session.valueOf(siteCountryField), isNull);
  });

  testWidgets('Use my location with the geocoder unreachable keeps the '
      'position and says why the names stay empty', (tester) async {
    final h = await pump(
      tester,
      _Geocoder(place, fixUnavailable: true),
      site: const DiveSite(id: 's1', name: 'Hole'),
    );

    await tester.tap(find.text(l.diveSites_edit_gps_useMyLocation));
    await tester.pumpAndSettle();

    expect(h.session.valueOf(siteLocationField), at);
    expect(h.session.valueOf(siteCountryField), isNull);
    expect(find.text(l.diveSites_edit_snackbar_lookupFailed), findsOne);
    expect(
      find.text(l.diveSites_edit_snackbar_locationCapturedWithAccuracy('5')),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Look up and Use my location ask in the place name language', (
    tester,
  ) async {
    final geocoder = _Geocoder(place);
    await pump(
      tester,
      geocoder,
      settings: const AppSettings(placeNameLanguage: 'de'),
    );

    await tapLookUp(tester);
    await tester.tap(find.text(l.diveSites_edit_gps_useMyLocation));
    await tester.pumpAndSettle();

    expect(geocoder.languages, ['de', 'de']);
    await tester.pump(const Duration(seconds: 2));
  });
}
