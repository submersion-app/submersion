import 'dart:ui' as ui;

import 'package:flutter/material.dart';
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' as riverpod show Override;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/bathymetry/data/terrain_imagery_service.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/terrain_imagery_frame.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/site_seascape_geometry_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_terrain_pane.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Shared fixtures for site_terrain_pane_test.dart and
/// site_terrain_pane_lod_patch_test.dart -- split out (rather than one file
/// importing the other) because these are test-only helpers, not
/// production code with a natural single owner.
typedef Override = riverpod.Override;

class TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  TestSettingsNotifier([super.initial = const AppSettings()]);

  /// Publishes a new settings value from outside the notifier, which
  /// `StateNotifier.state` alone does not allow (its setter is protected).
  /// A widget test needs this to drive a settings change and so trigger a
  /// dependency-driven reload in every provider that watches settings.
  void publish(AppSettings next) => state = next;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<TerrainImagery> testImagery() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF00FF00),
  );
  final image = await recorder.endRecording().toImage(4, 4);
  return TerrainImagery(
    image: image,
    frame: const TerrainImageryFrame(
      u0MercX: 0.4,
      u1MercX: 0.6,
      v0MercY: 0.4,
      v1MercY: 0.6,
      whiteU: 0.5,
      whiteV: 0.9,
    ),
  );
}

SiteSeascapeReady readyState({TerrainImagery? imagery}) {
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
    imagery: imagery,
    axisInputs: (
      minEast: box.minEast,
      maxEast: box.maxEast,
      minNorth: box.minNorth,
      maxNorth: box.maxNorth,
      maxDepth: 35,
      verticalExaggeration: 1.0,
    ),
  );
}

Widget page(
  SiteSeascapeState state, {
  AppSettings settings = const AppSettings(),
  List<SiteFeature> features = const [],
  List<Override> extraOverrides = const [],
}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith((ref) => TestSettingsNotifier(settings)),
    siteSeascapeProvider.overrideWith((ref, id) async => state),
    siteFeaturesProvider('site-1').overrideWith((ref) async => features),
    ...extraOverrides,
  ],
  child: const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SiteTerrainPane(siteId: 'site-1')),
  ),
);

/// Mirrors how [SiteScapeView] actually swaps sites in production: the
/// parent state's siteId changes and [SiteTerrainPane] is reconstructed at
/// the SAME position in the tree with no explicit Key (see
/// site_scape_view.dart) — never a fresh page push. Bug 7 alleged that this
/// path leaves the pane showing the previously-selected site's bathymetry.
class SiteSwitchHost extends StatefulWidget {
  const SiteSwitchHost({super.key});

  @override
  State<SiteSwitchHost> createState() => _SiteSwitchHostState();
}

class _SiteSwitchHostState extends State<SiteSwitchHost> {
  String _siteId = 'site-a';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            key: const ValueKey('switchSiteButton'),
            onPressed: () => setState(() => _siteId = 'site-b'),
            child: const Text('switch'),
          ),
          Expanded(child: SiteTerrainPane(siteId: _siteId)),
        ],
      ),
    );
  }
}
