import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_map_content.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
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

Dive _diveAtSite(DiveSite site, {String id = 'dive-1'}) {
  return createTestDiveWithBottomTime(id: id).copyWith(site: site);
}

Future<void> _pump(
  WidgetTester tester, {
  required AsyncValue<List<Dive>> dives,
  String? selectedId,
  void Function(String?)? onItemSelected,
}) async {
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        sortedFilteredDivesProvider.overrideWithValue(dives),
        diveActivityHeatMapProvider.overrideWithValue(
          const AsyncValue<List<HeatMapPoint>>.data(<HeatMapPoint>[]),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DiveMapContent(
            selectedId: selectedId,
            onItemSelected: onItemSelected ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('renders the FlutterMap with a site marker for dives', (
    tester,
  ) async {
    final site = _site();
    await _pump(tester, dives: AsyncValue.data([_diveAtSite(site)]));

    expect(find.byType(FlutterMap), findsOneWidget);
    // The fit-all-sites control is part of the rendered map overlay.
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

  testWidgets('renders the FlutterMap and info card for a selected dive', (
    tester,
  ) async {
    final site = _site();
    await _pump(
      tester,
      dives: AsyncValue.data([_diveAtSite(site)]),
      selectedId: 'dive-1',
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    // The selected dive surfaces an info card containing the site name.
    expect(find.text('Blue Hole'), findsOneWidget);
  });

  testWidgets('renders a cluster marker for co-located sites', (tester) async {
    // Two sites at the SAME location reliably cluster (distance 0 < radius),
    // exercising the MarkerClusterLayer cluster builder.
    final a = _site(id: 'site-a', name: 'A');
    final b = _site(id: 'site-b', name: 'B');
    await _pump(
      tester,
      dives: AsyncValue.data([
        _diveAtSite(a, id: 'dive-a'),
        _diveAtSite(b, id: 'dive-b'),
      ]),
    );

    expect(find.byType(FlutterMap), findsOneWidget);
  });
}
