import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_location_card_editor.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/location_picker_map.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/forms/coordinate_field_group.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

import 'site_editor_harness.dart';

class _FakeLocation implements LocationService {
  _FakeLocation(this.place);

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
    latitude: 17.3,
    longitude: -87.5,
    accuracy: 5,
    country: place.country,
    countryCode: place.countryCode,
    region: place.region,
    locality: place.locality,
    bodyOfWater: place.bodyOfWater,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A phone that finds no position, and records the settings it opens.
class _NoFix extends _FakeLocation {
  _NoFix(super.place);

  var settingsOpened = 0;

  @override
  Future<LocationResult?> getCurrentLocation({
    bool includeGeocoding = true,
    Duration timeout = const Duration(seconds: 15),
    String languageCode = LocationService.defaultLanguageCode,
  }) async => null;

  @override
  Future<bool> openAppSettings() async {
    settingsOpened++;
    return true;
  }
}

/// A position that answers only when [answer] completes.
class _SlowFix extends _FakeLocation {
  _SlowFix(super.place);

  final answer = Completer<void>();

  @override
  Future<LocationResult?> getCurrentLocation({
    bool includeGeocoding = true,
    Duration timeout = const Duration(seconds: 15),
    String languageCode = LocationService.defaultLanguageCode,
  }) async {
    await answer.future;
    return super.getCurrentLocation();
  }
}

class _FakeElevation extends ElevationService {
  _FakeElevation(this.metres);

  final double? metres;

  @override
  Future<double?> fetchElevation({
    required double latitude,
    required double longitude,
  }) async => metres;
}

/// The site's Location card edited in place (issue #4527, phase 2, plan 2).
void main() {
  final l = AppLocalizationsEn();
  const place = PlaceLookup(
    country: 'Belize',
    countryCode: 'BZ',
    region: 'Lighthouse Reef',
    locality: 'Belize City',
    bodyOfWater: 'Caribbean Sea',
  );

  Future<SiteEditorHarness> pump(
    WidgetTester tester, {
    DiveSite site = const DiveSite(id: 's1', name: 'Hole'),
    PlaceLookup lookup = place,
    double? elevation = 12,
  }) => pumpSiteEditor(
    tester,
    site,
    (session) => SiteLocationCardEditor(
      session: session,
      pickLocation: (_, _) async =>
          PickedLocation(latitude: 20.5, longitude: -87.1, place: lookup),
    ),
    overrides: [
      locationServiceProvider.overrideWithValue(_FakeLocation(lookup)),
      elevationServiceProvider.overrideWithValue(_FakeElevation(elevation)),
    ],
  );

  Finder field(String label) => find.descendant(
    of: find.widgetWithText(SuggestionFormRow, label),
    matching: find.byType(TextField),
  );

  Future<void> typeCoordinates(WidgetTester t, String lat, String lon) async {
    final fields = find.byType(TextField);
    await t.enterText(fields.at(0), lat);
    await t.enterText(fields.at(1), lon);
    await t.pump();
  }

  testWidgets('a typed country carries its code', (tester) async {
    final h = await pump(tester);

    await tester.enterText(
      field(l.diveSites_edit_field_country_label),
      'Belize',
    );
    await tester.pump();

    expect(h.session.valueOf(siteCountryCodeField), 'BZ');
  });

  testWidgets('a country that names none carries no code', (tester) async {
    final h = await pump(
      tester,
      site: const DiveSite(
        id: 's1',
        name: 'Hole',
        country: 'Belize',
        countryCode: 'BZ',
      ),
    );

    await tester.enterText(
      field(l.diveSites_edit_field_country_label),
      'Atlantis',
    );
    await tester.pump();

    expect(h.session.valueOf(siteCountryCodeField), isNull);
  });

  testWidgets('typed coordinates reach the sitting once both read', (
    tester,
  ) async {
    final h = await pump(tester);

    await typeCoordinates(tester, '17.3', '-87.5');

    expect(h.session.valueOf(siteLocationField), const GeoPoint(17.3, -87.5));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('half-typed coordinates keep the card open and refuse Save', (
    tester,
  ) async {
    final h = await pump(tester);

    await typeCoordinates(tester, '17.3', '');

    expect(h.session.valueOf(siteLocationField), isNull);
    expect(h.controller.invalidCardIds, contains('location'));
  });

  testWidgets('Use my location fills the position and the empty names', (
    tester,
  ) async {
    final h = await pump(tester);

    await tester.tap(find.text(l.diveSites_edit_gps_useMyLocation));
    await tester.pumpAndSettle();

    expect(h.session.valueOf(siteLocationField), const GeoPoint(17.3, -87.5));
    expect(h.session.valueOf(siteCountryField), 'Belize');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Look up asks before replacing differing names', (tester) async {
    final h = await pump(
      tester,
      site: const DiveSite(
        id: 's1',
        name: 'Hole',
        location: GeoPoint(17.3, -87.5),
        region: 'Turneffe',
      ),
    );

    await tester.tap(find.text(l.diveSites_edit_gps_lookupFromCoordinates));
    await tester.pumpAndSettle();
    // Empty names are filled at once; the differing region is asked about.
    expect(h.session.valueOf(siteCountryField), 'Belize');
    expect(find.text(l.diveSites_edit_lookupReplace_title), findsOneWidget);

    await tester.tap(find.text(l.diveSites_edit_lookupReplace_replace));
    await tester.pumpAndSettle();
    expect(h.session.valueOf(siteRegionField), 'Lighthouse Reef');
  });

  testWidgets('new coordinates fill an empty altitude a second later', (
    tester,
  ) async {
    final h = await pump(tester);

    await typeCoordinates(tester, '17.3', '-87.5');
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();

    expect(h.session.valueOf(siteAltitudeField), 12);
  });

  testWidgets('a pick from the map fills the position and the empty names', (
    tester,
  ) async {
    final h = await pump(tester);

    await tester.tap(find.text(l.diveSites_edit_gps_pickFromMap));
    await tester.pumpAndSettle();

    expect(h.session.valueOf(siteLocationField), const GeoPoint(20.5, -87.1));
    expect(h.session.valueOf(siteCountryField), 'Belize');
    expect(
      find.text(l.diveSites_edit_snackbar_locationSelectedFromMap),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a pick from the map replaces half-typed coordinates', (
    tester,
  ) async {
    final h = await pump(tester);
    await typeCoordinates(tester, '17.3', '');
    expect(h.controller.invalidCardIds, contains('location'));

    await tester.tap(find.text(l.diveSites_edit_gps_pickFromMap));
    await tester.pumpAndSettle();

    // The rows show the picked point, and nothing holds Save back.
    expect(h.session.valueOf(siteLocationField), const GeoPoint(20.5, -87.1));
    expect(
      tester
          .widget<CoordinateFieldGroup>(find.byType(CoordinateFieldGroup))
          .errorText,
      isNull,
    );
    expect(h.controller.invalidCardIds, isNot(contains('location')));
    final fields = find.byType(TextField);
    String text(int i) =>
        tester.widget<TextField>(fields.at(i)).controller!.text;
    expect(double.parse(text(0)), 20.5);
    expect(double.parse(text(1)), -87.1);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('no position on a phone offers the location settings, as the '
      'form', (tester) async {
    final noFix = _NoFix(place);
    await pumpSiteEditor(
      tester,
      const DiveSite(id: 's1', name: 'Hole'),
      (session) => SiteLocationCardEditor(session: session, isPhone: true),
      overrides: [locationServiceProvider.overrideWithValue(noFix)],
    );

    await tester.tap(find.text(l.diveSites_edit_gps_useMyLocation));
    await tester.pumpAndSettle();
    expect(
      find.text(l.diveSites_edit_snackbar_locationUnavailableMobile),
      findsOneWidget,
    );
    await tester.tap(find.text(l.diveSites_edit_snackbar_locationSettings));
    await tester.pumpAndSettle();

    expect(noFix.settingsOpened, 1);
  });

  testWidgets('Pick from map waits while the location is being found', (
    tester,
  ) async {
    final slow = _SlowFix(place);
    await pumpSiteEditor(
      tester,
      const DiveSite(id: 's1', name: 'Hole'),
      (session) => SiteLocationCardEditor(session: session),
      overrides: [locationServiceProvider.overrideWithValue(slow)],
    );
    ButtonStyleButton pick() => tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(l.diveSites_edit_gps_pickFromMap),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );

    await tester.tap(find.text(l.diveSites_edit_gps_useMyLocation));
    await tester.pump();
    // A pick now would be overwritten by the position still on its way.
    expect(pick().onPressed, isNull);

    slow.answer.complete();
    await tester.pumpAndSettle();
    expect(pick().onPressed, isNotNull);
    await tester.pump(const Duration(seconds: 2));
  });
}
