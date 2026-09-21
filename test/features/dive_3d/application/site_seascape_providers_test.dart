import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The provider watches settingsProvider for the terrain appearance and
/// depth unit; the real notifier needs SharedPreferences, so tests swap in
/// a notifier that just holds defaults.
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BathymetryGrid smallGrid() => BathymetryGrid(
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

void main() {
  const siteId = 'site-1';
  const withGps = DiveSite(
    id: siteId,
    name: 'Salt Pier',
    location: GeoPoint(12.151, -68.299),
    maxDepth: 30,
  );
  const noGps = DiveSite(id: siteId, name: 'Mystery Site');

  ProviderContainer container({DiveSite? site, BathymetryGrid? grid}) {
    final c = ProviderContainer(
      overrides: [
        siteProvider(siteId).overrideWith((ref) async => site),
        sitesProvider.overrideWith((ref) async => [?site]),
        divesProvider.overrideWith((ref) async => []),
        bathymetryGridProvider.overrideWith((ref, cell) async => grid),
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('site without coordinates yields SiteSeascapeNoCoordinates', () async {
    final c = container(site: noGps, grid: smallGrid());
    final state = await c.read(siteSeascapeProvider(siteId).future);
    expect(state, isA<SiteSeascapeNoCoordinates>());
  });

  test('no grid (empty or transient) yields SiteSeascapeNoData', () async {
    final c = container(site: withGps, grid: null);
    final state = await c.read(siteSeascapeProvider(siteId).future);
    expect(state, isA<SiteSeascapeNoData>());
  });

  test('grid + site yields a ready scene with provenance', () async {
    final c = container(site: withGps, grid: smallGrid());
    final state = await c.read(siteSeascapeProvider(siteId).future);
    final ready = state as SiteSeascapeReady;
    expect(ready.sourceId, 'gmrt');
    expect(ready.resolutionMeters, 61);
    expect(ready.scene.layers, isNotEmpty);
    expect(ready.scene.markers.first.label, 'Salt Pier');
  });

  test(
    'missing site yields SiteSeascapeNoCoordinates (never a throw)',
    () async {
      final c = container(site: null, grid: smallGrid());
      final state = await c.read(siteSeascapeProvider(siteId).future);
      expect(state, isA<SiteSeascapeNoCoordinates>());
    },
  );

  test('axisInputs carries the same verticalExaggeration the terrain was '
      'built with (issue #2141 regression: a stale SeascapeAxisInputs would '
      'default to 1.0 and the depth axis would no longer agree with the '
      'exaggerated terrain it labels)', () async {
    // 3 km cell spacing, shallow (20-30 m) depths matching the site's own
    // recorded max depth: a true-to-scale rendering would read as flat,
    // so this site must get exaggerated beyond 1.0.
    final wideGrid = BathymetryGrid(
      originLat: 12.15,
      originLon: -68.30,
      cellSizeLatDeg: 3000.0 / 110540.0,
      cellSizeLonDeg: 3000.0 / 111320.0,
      rows: 2,
      cols: 2,
      depthsMeters: const [20, 25, 25, 30],
      sourceId: 'gmrt',
      resolutionMeters: 3000,
      fetchedAt: DateTime.utc(2026, 7, 28),
    );
    final c = container(site: withGps, grid: wideGrid);
    final state = await c.read(siteSeascapeProvider(siteId).future);
    final ready = state as SiteSeascapeReady;

    expect(ready.axisInputs.verticalExaggeration, greaterThan(1.0));

    // Reproducing what _buildAxes does in the presentation layer: a
    // SpatialProjection built from axisInputs must reach exactly the
    // terrain's own scene floor, not a true-to-scale one.
    final axisProj = SpatialProjection(
      minEast: ready.axisInputs.minEast,
      maxEast: ready.axisInputs.maxEast,
      minNorth: ready.axisInputs.minNorth,
      maxNorth: ready.axisInputs.maxNorth,
      maxDepth: ready.axisInputs.maxDepth,
      verticalExaggeration: ready.axisInputs.verticalExaggeration,
    );
    expect(
      axisProj.yOf(ready.axisInputs.maxDepth),
      closeTo(ready.scene.bounds.sceneMinY, 1e-9),
    );
  });
}
