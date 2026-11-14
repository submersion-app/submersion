import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/models/site_area_anchor.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/catalogue_site_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import 'site_picker_built_in_harness.dart';

void main() {
  group('with the flag off', () {
    testWidgets('shows no built-in sites and never asks the catalogue', (
      tester,
    ) async {
      final h = await pumpPicker(
        tester,
        showBuiltIn: false,
        diveLocation: saltPier,
        sites: const [
          DiveSite(id: 'mine', name: 'My Reef', location: saltPier),
        ],
      );

      await tester.enterText(find.byType(TextField), 'angel');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byType(CatalogueSiteTile), findsNothing);
      expect(h.catalogue.nearCalls, 0);
      expect(h.catalogue.searchCalls, 0);
    });
  });

  group('by area', () {
    testWidgets('a dive location lists built-in sites nearest first, with '
        'distances', (tester) async {
      await pumpPicker(tester, diveLocation: saltPier);

      expect(find.text('More sites nearby'), findsOneWidget);
      expect(builtInTitles(tester), [
        'Windsock',
        'Hilma Hooker',
        'Cliff',
        'Oil Slick Leap',
        'Karpata',
      ]);
      // Windsock is 500 m from the dive, in the diver's distance unit.
      final halfKm = const UnitFormatter(AppSettings()).formatGeoDistance(500);
      expect(find.text('$halfKm away'), findsOneWidget);
      expect(find.textContaining(' away'), findsNWidgets(5));
    });

    testWidgets('an inferred area lists them by name under the place, with '
        'no distances', (tester) async {
      await pumpPicker(tester, areaAnchor: inferredBonaire);

      expect(find.text('More sites near Bonaire'), findsOneWidget);
      expect(builtInTitles(tester), [
        'Angel City',
        'Bari Reef',
        'Cliff',
        'Front Porch',
        'Hilma Hooker',
      ]);
      expect(find.textContaining(' away'), findsNothing);
      expect(find.text('Near the sites of your other dives'), findsOneWidget);
    });

    testWidgets('a search typed before the device fix arrives is run again '
        'around it', (tester) async {
      // The fix can take seconds. A search typed meanwhile knew no area; it
      // must not keep that order for the rest of the sheet's life.
      final fix = Completer<void>();
      await pumpPicker(
        tester,
        catalogueSites: [
          builtInSite('far', 'Alpha Reef', north: 200000),
          builtInSite('near', 'Zulu Reef', north: 1000),
        ],
        deviceLocation: LocationResult(
          latitude: saltPier.latitude,
          longitude: saltPier.longitude,
        ),
        locationGate: fix,
      );
      await tester.enterText(find.byType(TextField), 'reef');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(builtInTitles(tester), ['Alpha Reef', 'Zulu Reef']);

      fix.complete();
      await tester.pumpAndSettle();

      expect(builtInTitles(tester), ['Zulu Reef', 'Alpha Reef']);
    });

    testWidgets('the by-name list ignores case and accents', (tester) async {
      await pumpPicker(
        tester,
        areaAnchor: inferredBonaire,
        catalogueSites: [
          builtInSite('z', 'Zenobia', north: 100),
          builtInSite('l', 'little shark', north: 200),
          builtInSite('e', 'Épave du Donator', north: 300),
          builtInSite('a', 'Angel City', north: 400),
        ],
      );

      expect(builtInTitles(tester), [
        'Angel City',
        'Épave du Donator',
        'little shark',
        'Zenobia',
      ]);
    });

    testWidgets('an inferred area without a place name says nearby', (
      tester,
    ) async {
      await pumpPicker(
        tester,
        areaAnchor: const SiteAreaAnchor(point: saltPier),
      );

      expect(find.text('More sites nearby'), findsOneWidget);
    });

    testWidgets("an inferred area lists the diver's own nearby sites by "
        'name too', (tester) async {
      await pumpPicker(
        tester,
        areaAnchor: inferredBonaire,
        catalogueSites: const [],
        sites: [
          DiveSite(
            id: 'z',
            name: 'Zebra Reef',
            location: GeoPoint(saltPier.latitude + 0.001, saltPier.longitude),
          ),
          DiveSite(
            id: 'a',
            name: 'Alpha Reef',
            location: GeoPoint(saltPier.latitude + 0.05, saltPier.longitude),
          ),
        ],
      );

      expect(pickerRowTitles(tester).take(2), ['Alpha Reef', 'Zebra Reef']);
      expect(find.textContaining(' away'), findsNothing);
    });

    testWidgets('an inferred area does not ask the device where it is', (
      tester,
    ) async {
      final h = await pumpPicker(tester, areaAnchor: inferredBonaire);

      expect(h.location.calls, 0);
    });

    testWidgets('with no dive location or area the device fix is used', (
      tester,
    ) async {
      final h = await pumpPicker(
        tester,
        deviceLocation: LocationResult(
          latitude: saltPier.latitude,
          longitude: saltPier.longitude,
        ),
      );

      expect(h.location.calls, 1);
      expect(find.text('More sites nearby'), findsOneWidget);
      expect(builtInTitles(tester).first, 'Windsock');
    });

    testWidgets('five rows show, then "Show all" expands in place', (
      tester,
    ) async {
      await pumpPicker(tester, areaAnchor: inferredBonaire);

      expect(builtInTitles(tester), hasLength(5));
      expect(find.text('Show all 9'), findsOneWidget);

      await tester.tap(find.text('Show all 9'));
      await tester.pumpAndSettle();

      expect(builtInTitles(tester), hasLength(9));
      expect(find.text('Show all 9'), findsNothing);
    });

    testWidgets('five or fewer sites show no "Show all" row', (tester) async {
      await pumpPicker(
        tester,
        areaAnchor: inferredBonaire,
        catalogueSites: bonaireSites.take(5).toList(),
      );

      expect(builtInTitles(tester), hasLength(5));
      expect(find.textContaining('Show all'), findsNothing);
    });

    testWidgets("the diver's nearby sites come first, then built-in sites, "
        'then the grouped list', (tester) async {
      await pumpPicker(
        tester,
        diveLocation: saltPier,
        catalogueSites: [builtInSite('c1', 'Angel City', north: 9000)],
        sites: const [
          DiveSite(id: 'near', name: 'My House Reef', location: saltPier),
          DiveSite(
            id: 'far',
            name: 'Blue Hole',
            location: GeoPoint(28.57, 34.54),
            country: 'Egypt',
          ),
        ],
      );

      final titles = pickerRowTitles(tester);
      expect(titles.indexOf('My House Reef'), 0);
      expect(titles.indexOf('Angel City'), 1);
      // The grouped list follows: its Egypt group sits below the built-in
      // row (folded, so Blue Hole itself is not a row yet).
      expect(
        tester.getTopLeft(find.text('Egypt')).dy,
        greaterThan(tester.getTopLeft(find.text('Angel City')).dy),
      );
    });

    testWidgets('a diver with no sites still sees the built-in section', (
      tester,
    ) async {
      await pumpPicker(tester, areaAnchor: inferredBonaire);

      expect(find.text('More sites near Bonaire'), findsOneWidget);
      expect(builtInTitles(tester), isNotEmpty);
    });

    testWidgets('a diver with no sites and no built-in sites sees the empty '
        'state', (tester) async {
      await pumpPicker(
        tester,
        areaAnchor: inferredBonaire,
        catalogueSites: const [],
      );

      expect(find.text('No dive sites yet'), findsOneWidget);
    });

    testWidgets('an adopted site is not offered, its neighbour 100 m away '
        'is', (tester) async {
      await pumpPicker(
        tester,
        areaAnchor: inferredBonaire,
        catalogueSites: [
          builtInSite('east', 'Barracuda East'),
          builtInSite('west', 'Barracuda West', north: 100),
        ],
        sites: const [
          DiveSite(
            id: 'mine',
            name: 'Barracuda East',
            location: saltPier,
            catalogueId: 'east',
          ),
        ],
      );

      expect(builtInTitles(tester), ['Barracuda West']);
    });

    testWidgets("a site beside the diver's own unlinked site is hidden", (
      tester,
    ) async {
      await pumpPicker(
        tester,
        areaAnchor: inferredBonaire,
        catalogueSites: [
          builtInSite('east', 'Barracuda East'),
          builtInSite('far', 'Cliff', north: 3000),
        ],
        sites: const [
          DiveSite(id: 'mine', name: 'My Barracuda', location: saltPier),
        ],
      );

      expect(builtInTitles(tester), ['Cliff']);
    });

    testWidgets('built-in sites appear when the catalogue becomes ready', (
      tester,
    ) async {
      final h = await pumpPicker(
        tester,
        areaAnchor: inferredBonaire,
        catalogueSites: const [],
      );
      expect(find.byType(CatalogueSiteTile), findsNothing);

      // The first import of this app run lands.
      h.catalogue.sites = bonaireSites;
      h.container.read(siteCatalogueRevisionProvider.notifier).state++;
      await tester.pumpAndSettle();

      expect(builtInTitles(tester), hasLength(5));
    });
  });

  group('searching', () {
    testWidgets('two characters search the catalogue, one does not', (
      tester,
    ) async {
      final h = await pumpPicker(tester, areaAnchor: inferredBonaire);

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(h.catalogue.searchCalls, 0);

      await tester.enterText(find.byType(TextField), 'an');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(h.catalogue.searches, ['an']);
      expect(find.text('Built-in sites'), findsOneWidget);
      expect(builtInTitles(tester), ['Angel City']);
    });

    testWidgets('typing quickly searches once, for the last text', (
      tester,
    ) async {
      final h = await pumpPicker(tester, areaAnchor: inferredBonaire);

      await tester.enterText(find.byType(TextField), 'an');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'ang');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'ange');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(h.catalogue.searches, ['ange']);
    });

    testWidgets('clearing the search brings the area list back', (
      tester,
    ) async {
      await pumpPicker(tester, areaAnchor: inferredBonaire);
      await tester.enterText(find.byType(TextField), 'angel');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Built-in sites'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      expect(find.text('Built-in sites'), findsNothing);
      expect(find.text('More sites near Bonaire'), findsOneWidget);
    });

    testWidgets("the diver's own matches come before built-in matches", (
      tester,
    ) async {
      await pumpPicker(
        tester,
        areaAnchor: inferredBonaire,
        catalogueSites: [
          builtInSite('c1', 'Angel Reef', north: 9000),
          builtInSite('c2', 'Bari Reef', north: 8000),
        ],
        sites: [
          // One of theirs nearby, one far away (so it is only in the
          // grouped list).
          DiveSite(
            id: 'near',
            name: 'My House Reef',
            location: GeoPoint(saltPier.latitude + 0.001, saltPier.longitude),
            country: 'Caribbean Netherlands',
          ),
          const DiveSite(
            id: 'far',
            name: 'Shaab Reef',
            location: GeoPoint(27.0, 34.0),
            country: 'Egypt',
          ),
        ],
      );

      await tester.enterText(find.byType(TextField), 'reef');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final titles = pickerRowTitles(tester);
      final firstBuiltIn = titles.indexOf('Angel Reef');
      expect(firstBuiltIn, greaterThan(titles.lastIndexOf('My House Reef')));
      expect(firstBuiltIn, greaterThan(titles.lastIndexOf('Shaab Reef')));
      // The section label sits between them.
      expect(
        tester.getTopLeft(find.text('Built-in sites')).dy,
        greaterThan(tester.getTopLeft(find.text('Shaab Reef').last).dy),
      );
    });

    testWidgets("a match shows even when none of the diver's sites match", (
      tester,
    ) async {
      await pumpPicker(
        tester,
        areaAnchor: inferredBonaire,
        sites: const [DiveSite(id: 'mine', name: 'My Reef')],
      );

      await tester.enterText(find.byType(TextField), 'angel');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(builtInTitles(tester), ['Angel City']);
    });

    testWidgets('search results skip the position rule but not the link '
        'rule', (tester) async {
      await pumpPicker(
        tester,
        catalogueSites: [
          builtInSite('east', 'Barracuda East'),
          builtInSite('west', 'Barracuda West', north: 100),
        ],
        sites: [
          const DiveSite(
            id: 'adopted',
            name: 'Barracuda East',
            location: saltPier,
            catalogueId: 'east',
          ),
          // Unlinked, and on top of Barracuda West.
          DiveSite(
            id: 'mine',
            name: 'My Spot',
            location: GeoPoint(saltPier.latitude + 100 / 111320.0, -68.28),
          ),
        ],
      );

      await tester.enterText(find.byType(TextField), 'barracuda');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(builtInTitles(tester), ['Barracuda West']);
    });

    testWidgets('closing the sheet with a search pending leaves no timer', (
      tester,
    ) async {
      await pumpPicker(tester, areaAnchor: inferredBonaire);

      await tester.enterText(find.byType(TextField), 'angel');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
      // The test framework fails a test that ends with a timer pending.
    });
  });
}
