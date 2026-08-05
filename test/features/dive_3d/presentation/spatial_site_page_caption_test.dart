import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/application/spatial_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_geometry_service.dart';
import 'package:submersion/features/dive_3d/presentation/pages/spatial_site_page.dart';
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

ReckonedPath _path() => const ReckonedPath(
  points: [
    ReckonedPoint(east: 0, north: 0, depth: 5, timeSeconds: 0),
    ReckonedPoint(east: 40, north: 20, depth: 18, timeSeconds: 600),
  ],
  reconstructed: true,
  minEast: 0,
  maxEast: 40,
  minNorth: 0,
  maxNorth: 20,
  maxDepth: 18,
  durationSeconds: 600,
);

Widget page(SpatialSceneResult? result) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    spatialGeometryProvider.overrideWith((ref, id) async => result),
  ],
  child: const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SpatialSitePage(diveId: 'd1'),
  ),
);

void main() {
  final synthesized = SpatialSceneResult(
    scene: const SpatialGeometryService().build(_path(), siteMaxDepth: 30),
  );
  // The pick lattice requires the terrain mesh to match the grid's cell
  // count, so build the real-terrain scene FROM the grid.
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
  final real = SpatialSceneResult(
    scene: const SpatialGeometryService().build(
      _path(),
      siteMaxDepth: 30,
      grid: grid,
      gridCenter: const GeoPoint(12.151, -68.299),
    ),
    bathymetrySourceId: 'gmrt',
    bathymetryResolutionMeters: 61,
    grid: grid,
    axisInputs: (
      minEast: -100.0,
      maxEast: 200.0,
      minNorth: -100.0,
      maxNorth: 200.0,
      maxDepth: 30.0,
    ),
  );

  testWidgets('real terrain shows the provenance chip, not synthesized', (
    tester,
  ) async {
    await tester.pumpWidget(page(real));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('GMRT'), findsOneWidget);
    expect(find.text('Synthesized seafloor'), findsNothing);
    expect(find.text('Estimated path (dead reckoning)'), findsOneWidget);
    // Distance/depth axes render whenever the scene carries axis inputs.
    final viewport = tester.widget<Dive3dInteractiveViewport>(
      find.byType(Dive3dInteractiveViewport),
    );
    expect(viewport.axisFrame, isNotNull);
    expect(viewport.chromeStyle, isNotNull);
    // Real terrain also gets hover inspection.
    expect(viewport.surfaceGrid, isNotNull);
    expect(viewport.surfaceGrid!.isEmpty, isFalse);
    expect(viewport.hoverPick, isNotNull);
  });

  testWidgets('synthesized fallback has no hover inspection', (tester) async {
    await tester.pumpWidget(page(synthesized));
    await tester.pump();
    await tester.pump();
    final viewport = tester.widget<Dive3dInteractiveViewport>(
      find.byType(Dive3dInteractiveViewport),
    );
    expect(viewport.surfaceGrid, isNull);
    expect(viewport.hoverPick, isNull);
  });

  testWidgets('fallback shows the synthesized chip', (tester) async {
    await tester.pumpWidget(page(synthesized));
    await tester.pump();
    await tester.pump();
    expect(find.text('Synthesized seafloor'), findsOneWidget);
    expect(find.textContaining('GMRT'), findsNothing);
  });

  testWidgets('no path renders the message, never a spinner', (tester) async {
    await tester.pumpWidget(page(null));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Not enough data to reconstruct the dive path'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
