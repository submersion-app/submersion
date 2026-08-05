import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/site_seascape_geometry_service.dart';
import 'package:submersion/features/dive_3d/presentation/pages/site_seascape_page.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SiteSeascapeReady readyState() {
  final grid = BathymetryGrid(
    originLat: 12.15,
    originLon: -68.30,
    cellSizeLatDeg: 0.001,
    cellSizeLonDeg: 0.001,
    rows: 2,
    cols: 2,
    depthsMeters: const [20, 30, 25, 35],
    sourceId: 'gmrt',
    resolutionMeters: 61,
    fetchedAt: DateTime.utc(2026, 7, 28),
  );
  final scene = const SiteSeascapeGeometryService().build(
    SiteSeascapeInput(
      grid: grid,
      center: const GeoPoint(12.151, -68.299),
      siteName: 'Salt Pier',
      siteMaxDepth: 30,
      divePaths: const [],
      nearbySites: const [],
    ),
  );
  final box = BathymetryTerrainBuilder.enuBounds(
    grid,
    const GeoPoint(12.151, -68.299),
  );
  return SiteSeascapeReady(
    scene: scene,
    sourceId: 'gmrt',
    resolutionMeters: 61,
    grid: grid,
    axisInputs: (
      minEast: box.minEast,
      maxEast: box.maxEast,
      minNorth: box.minNorth,
      maxNorth: box.maxNorth,
      maxDepth: 35,
    ),
  );
}

Widget page(SiteSeascapeState state) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    siteSeascapeProvider.overrideWith((ref, id) async => state),
  ],
  child: const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SiteSeascapePage(siteId: 'site-1'),
  ),
);

void main() {
  testWidgets('ready state renders viewport and provenance caption', (
    tester,
  ) async {
    await tester.pumpWidget(page(readyState()));
    await tester.pump(); // resolve the future
    await tester.pump();
    expect(find.byType(Dive3dInteractiveViewport), findsOneWidget);
    expect(find.textContaining('GMRT'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // Distance/depth axes are always-on chrome.
    final viewport = tester.widget<Dive3dInteractiveViewport>(
      find.byType(Dive3dInteractiveViewport),
    );
    expect(viewport.axisFrame, isNotNull);
    expect(viewport.axisLabels, isNotNull);
    expect(viewport.chromeStyle, isNotNull);
    // Hover inspection: pick lattice + notifier wired, tissue chrome not.
    expect(viewport.surfaceGrid, isNotNull);
    expect(viewport.surfaceGrid!.isEmpty, isFalse);
    expect(viewport.hoverPick, isNotNull);
    expect(viewport.axisChromeOnly, isTrue);
  });

  testWidgets('no-coordinates state shows the message, not a spinner', (
    tester,
  ) async {
    await tester.pumpWidget(page(const SiteSeascapeNoCoordinates()));
    await tester.pump();
    await tester.pump();
    expect(find.text('This site has no GPS coordinates'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('no-data state shows the message, not a spinner', (tester) async {
    await tester.pumpWidget(page(const SiteSeascapeNoData()));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('No bathymetry available for this location'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
