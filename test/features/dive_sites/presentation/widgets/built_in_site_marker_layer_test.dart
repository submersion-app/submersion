import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/built_in_site_marker_layer.dart';

ExternalDiveSite ext(String id, double lat, double lng) => ExternalDiveSite(
  externalId: id,
  name: id,
  latitude: lat,
  longitude: lng,
  source: 't',
);

Widget _host(Widget layer) => MaterialApp(
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
    ExternalDiveSite? tapped;
    await tester.pumpWidget(
      _host(
        BuiltInSiteMarkerLayer(
          sites: [ext('a', 10.0, 20.0)],
          selectedExternalId: null,
          onTap: (s) => tapped = s,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('builtInPin_a')), findsOneWidget);
    await tester.tap(find.byKey(const Key('builtInPin_a')));
    expect(tapped?.externalId, 'a');
  });

  testWidgets('renders nothing when there are no sites', (tester) async {
    await tester.pumpWidget(
      _host(
        const BuiltInSiteMarkerLayer(
          sites: [],
          selectedExternalId: null,
          onTap: _noop,
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('builtInPin_a')), findsNothing);
  });
}

void _noop(ExternalDiveSite _) {}
