import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_locations_map.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(child: SizedBox(width: 300, height: 300, child: child)),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('renders entry, exit, site markers and a track line', (
    tester,
  ) async {
    await _pump(
      tester,
      const DiveLocationsMap(
        entry: GeoPoint(12.34567, 98.76543),
        exit: GeoPoint(12.34612, 98.76489),
        site: GeoPoint(12.34000, 98.76000),
      ),
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const ValueKey('gps-entry-marker')), findsOneWidget);
    expect(find.byKey(const ValueKey('gps-exit-marker')), findsOneWidget);
    expect(find.byKey(const ValueKey('gps-site-marker')), findsOneWidget);
    // The site marker uses the diver glyph, matching the Sites map.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('gps-site-marker')),
        matching: find.byIcon(Icons.scuba_diving),
      ),
      findsOneWidget,
    );
    expect(find.byType(PolylineLayer), findsOneWidget);
  });

  testWidgets('entry-only: no track line, no exit/site markers', (
    tester,
  ) async {
    await _pump(
      tester,
      const DiveLocationsMap(entry: GeoPoint(12.34567, 98.76543)),
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(PolylineLayer), findsNothing);
    expect(find.byKey(const ValueKey('gps-entry-marker')), findsOneWidget);
    expect(find.byKey(const ValueKey('gps-exit-marker')), findsNothing);
    expect(find.byKey(const ValueKey('gps-site-marker')), findsNothing);
  });

  testWidgets('renders nothing when no points are provided', (tester) async {
    await _pump(tester, const DiveLocationsMap());
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('clamps fit zoom so tiles render for tightly clustered points', (
    tester,
  ) async {
    final controller = MapController();
    await _pump(
      tester,
      DiveLocationsMap(
        controller: controller,
        entry: const GeoPoint(12.345670, 98.765430),
        exit: const GeoPoint(12.345690, 98.765450),
        site: const GeoPoint(12.345680, 98.765440),
      ),
    );

    // Real entry/exit/site fixes sit within meters of each other. Fitting their
    // bounds must not zoom past the tile provider's max (~19 for OSM), or the
    // map renders blank with only markers showing.
    expect(controller.camera.zoom, lessThanOrEqualTo(16.0));
  });
}
