import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

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
}
