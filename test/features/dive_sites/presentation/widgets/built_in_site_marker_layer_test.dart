import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_site_marker_layer.dart';

CatalogueSite ext(String id, double lat, double lng) => CatalogueSite(
  id: id,
  name: id,
  location: GeoPoint(lat, lng),
  source: 'osm',
);

Widget _host(Widget layer) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: FlutterMap(
      options: const MapOptions(initialCenter: LatLng(10, 20), initialZoom: 8),
      children: [layer],
    ),
  ),
);

void main() {
  testWidgets('renders a pin per built-in site and reports taps', (
    tester,
  ) async {
    CatalogueSite? tapped;
    await tester.pumpWidget(
      _host(
        BuiltInSiteMarkerLayer(
          sites: [ext('a', 10.0, 20.0)],
          selectedCatalogueId: null,
          onTap: (s) => tapped = s,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('builtInPin_a')), findsOneWidget);
    await tester.tap(find.byKey(const Key('builtInPin_a')));
    expect(tapped?.id, 'a');
  });

  testWidgets('exposes a semantics label for each built-in pin', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        BuiltInSiteMarkerLayer(
          sites: [ext('Blue Hole', 10.0, 20.0)],
          selectedCatalogueId: null,
          onTap: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(
      find.bySemanticsLabel('Built-in dive site: Blue Hole'),
      findsOneWidget,
    );
  });

  group('a pin says what kind of record it marks', () {
    CatalogueSite wreck(String id) => CatalogueSite(
      id: id,
      name: id,
      location: const GeoPoint(10, 20),
      source: 'ukho',
      kind: CatalogueKind.register,
    );

    Icon pin(WidgetTester tester, String id) => tester.widget<Icon>(
      find.descendant(
        of: find.byKey(Key('builtInPin_$id')),
        matching: find.byType(Icon),
      ),
    );

    testWidgets('a dive site keeps the hollow pin', (tester) async {
      await tester.pumpWidget(
        _host(
          BuiltInSiteMarkerLayer(
            sites: [ext('a', 10.0, 20.0)],
            selectedCatalogueId: null,
            onTap: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(pin(tester, 'a').icon, Icons.location_on_outlined);
    });

    testWidgets('a charted wreck or reef is an anchor, and says so', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          BuiltInSiteMarkerLayer(
            sites: [wreck('Tabarka')],
            selectedCatalogueId: null,
            onTap: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(pin(tester, 'Tabarka').icon, Icons.anchor);
      expect(
        find.bySemanticsLabel('Charted wreck or reef: Tabarka'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Built-in dive site: Tabarka'),
        findsNothing,
      );
    });

    testWidgets('a selected anchor takes the primary colour', (tester) async {
      await tester.pumpWidget(
        _host(
          BuiltInSiteMarkerLayer(
            sites: [wreck('w')],
            selectedCatalogueId: 'w',
            onTap: (_) {},
          ),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byKey(const Key('builtInPin_w')));
      expect(pin(tester, 'w').color, Theme.of(context).colorScheme.primary);
    });
  });

  testWidgets('renders a cluster bubble for co-located built-in sites', (
    tester,
  ) async {
    // Two built-in sites at the same point reliably cluster, exercising the
    // recessive cluster-bubble builder.
    await tester.pumpWidget(
      _host(
        BuiltInSiteMarkerLayer(
          sites: [ext('a', 10.0, 20.0), ext('b', 10.0, 20.0)],
          selectedCatalogueId: 'a',
          onTap: (_) {},
        ),
      ),
    );
    await tester.pump();

    // The cluster bubble shows the count of clustered built-in sites.
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('renders nothing when there are no sites', (tester) async {
    await tester.pumpWidget(
      _host(
        const BuiltInSiteMarkerLayer(
          sites: [],
          selectedCatalogueId: null,
          onTap: _noop,
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('builtInPin_a')), findsNothing);
  });
}

void _noop(CatalogueSite _) {}
