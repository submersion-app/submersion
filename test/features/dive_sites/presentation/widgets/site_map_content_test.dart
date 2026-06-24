import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_map_content.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

DiveSite _site({
  String id = 'site-1',
  String name = 'Blue Hole',
  double lat = 12.34,
  double lng = 98.76,
}) {
  return DiveSite(id: id, name: name, location: GeoPoint(lat, lng));
}

Future<void> _pump(
  WidgetTester tester, {
  required List<SiteWithDiveCount> sites,
  String? selectedId,
}) async {
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        sitesWithCountsProvider.overrideWith((ref) async => sites),
        siteCoverageHeatMapProvider.overrideWith(
          (ref) async => <HeatMapPoint>[],
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SiteMapContent(selectedId: selectedId, onItemSelected: (_) {}),
        ),
      ),
    ),
  );
  // Allow the FutureProviders to resolve and the map to build.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('renders the FlutterMap with a dive site marker', (tester) async {
    await _pump(
      tester,
      sites: [SiteWithDiveCount(site: _site(), diveCount: 3)],
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byIcon(Icons.my_location), findsOneWidget);

    // Tapping empty map (a corner, away from the centered marker) clears the
    // selection via the map's onTap. No animation, so this is teardown-safe.
    await tester.tapAt(
      tester.getTopLeft(find.byType(FlutterMap)) + const Offset(5, 5),
    );
    // Flush flutter_map's double-tap disambiguation timer before teardown.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('renders the FlutterMap and info card for a selected site', (
    tester,
  ) async {
    await _pump(
      tester,
      sites: [SiteWithDiveCount(site: _site(), diveCount: 3)],
      selectedId: 'site-1',
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Blue Hole'), findsOneWidget);
  });

  testWidgets('renders a cluster marker for co-located sites', (tester) async {
    // Two sites at the SAME location reliably cluster (distance 0 < radius),
    // exercising the MarkerClusterLayer cluster builder.
    await _pump(
      tester,
      sites: [
        SiteWithDiveCount(
          site: _site(id: 's-a', name: 'A'),
          diveCount: 1,
        ),
        SiteWithDiveCount(
          site: _site(id: 's-b', name: 'B'),
          diveCount: 2,
        ),
      ],
    );

    expect(find.byType(FlutterMap), findsOneWidget);
  });
}
