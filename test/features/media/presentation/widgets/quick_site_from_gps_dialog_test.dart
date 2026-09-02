import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/presentation/widgets/quick_site_from_gps_dialog.dart';

import '../support/fake_location_service.dart';
import '../support/media_widget_harness.dart';

void main() {
  Future<Future<DiveSite?>> open(
    WidgetTester tester,
    LocationService geocoder,
  ) async {
    late Future<DiveSite?> result;
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [locationServiceProvider.overrideWithValue(geocoder)],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                result = QuickSiteFromGpsDialog.show(
                  context,
                  latitude: 20.5,
                  longitude: -87.25,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('prefills country, region and city from the geocoder', (
    tester,
  ) async {
    final geocoder = FakeLocationService(
      const PlaceLookup(
        country: 'Mexico',
        region: 'Quintana Roo',
        locality: 'Tulum',
      ),
    );
    final pending = await open(tester, geocoder);
    final fieldTexts = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .map((f) => f.controller?.text)
        .toList();
    expect(fieldTexts, containsAll(['Mexico', 'Quintana Roo', 'Tulum']));
    expect(geocoder.calls.single.lat, 20.5);

    await tester.enterText(find.byType(TextFormField).first, 'Cenote Wall');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Site'));
    await tester.pumpAndSettle();
    final site = await pending;
    expect(site?.name, 'Cenote Wall');
    expect(site?.country, 'Mexico');
    expect(site?.region, 'Quintana Roo');
    expect(site?.city, 'Tulum');
    expect(site?.location, const GeoPoint(20.5, -87.25));
  });

  testWidgets('a failed geocode leaves the fields empty and still creates', (
    tester,
  ) async {
    final geocoder = FakeLocationService(const PlaceLookup.empty(), fail: true);
    final pending = await open(tester, geocoder);
    await tester.enterText(find.byType(TextFormField).first, 'Somewhere');
    await tester.tap(find.widgetWithText(FilledButton, 'Create Site'));
    await tester.pumpAndSettle();
    final site = await pending;
    expect(site?.name, 'Somewhere');
    expect(site?.country, isNull);
    expect(site?.city, isNull);
  });

  testWidgets('the coordinates semantics label is localized', (tester) async {
    final geocoder = FakeLocationService(const PlaceLookup.empty());
    await open(tester, geocoder);

    // The label reuses media_gpsBanner_coordinates rather than an English
    // literal, so a screen reader follows the app's language.
    expect(find.bySemanticsLabel(RegExp(r'^Coordinates: ')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('GPS coordinates:')), findsNothing);
  });
}
