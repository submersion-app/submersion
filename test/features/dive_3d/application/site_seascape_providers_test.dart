import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_lod.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
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

  group('siteSeascapePatchLayerProvider', () {
    BathymetryGrid finerGrid(double resolutionMeters) => BathymetryGrid(
      originLat: 12.1505,
      originLon: -68.2995,
      cellSizeLatDeg: 0.0002,
      cellSizeLonDeg: 0.0002,
      rows: 2,
      cols: 2,
      depthsMeters: const [22, 28, 24, 30],
      sourceId: 'swissbathy3d',
      resolutionMeters: resolutionMeters,
      fetchedAt: DateTime.utc(2026, 7, 28),
    );

    ProviderContainer patchContainer({required BathymetryGrid? patchGrid}) {
      final c = ProviderContainer(
        overrides: [
          siteProvider(siteId).overrideWith((ref) async => withGps),
          sitesProvider.overrideWith((ref) async => [withGps]),
          divesProvider.overrideWith((ref) async => []),
          bathymetryGridProvider.overrideWith((ref, cell) async => smallGrid()),
          bathymetryPatchGridProvider.overrideWith(
            (ref, request) async => patchGrid,
          ),
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('the overview stage never fetches a patch', () async {
      final c = patchContainer(patchGrid: finerGrid(2));
      final layer = await c.read(
        siteSeascapePatchLayerProvider((
          siteId: siteId,
          stage: BathymetryLodStage.overview,
        )).future,
      );
      expect(layer, isNull);
    });

    test('a zoomed-in stage with no patch grid available yields no layer '
        '(the source could not deliver anything for this span)', () async {
      final c = patchContainer(patchGrid: null);
      final layer = await c.read(
        siteSeascapePatchLayerProvider((
          siteId: siteId,
          stage: BathymetryLodStage.medium,
        )).future,
      );
      expect(layer, isNull);
    });

    test('the medium stage with a patch grid yields a layer, drapes it on the '
        'terrain for shared depth sorting, and never flags the detail limit '
        '(that heuristic only applies at the fine stage)', () async {
      final c = patchContainer(patchGrid: finerGrid(2));
      final layer = await c.read(
        siteSeascapePatchLayerProvider((
          siteId: siteId,
          stage: BathymetryLodStage.medium,
        )).future,
      );
      expect(layer, isNotNull);
      expect(layer!.stage, BathymetryLodStage.medium);
      expect(layer.layer.mesh.positions, isNotEmpty);
      expect(layer.layer.drapedOnTerrain, isTrue);
      expect(layer.detailLimitReached, isFalse);
    });

    test('the fine stage flags the detail limit when the patch is no sharper '
        'than the base grid (>= 90% of its resolution)', () async {
      // Base grid resolves at 61 m; a "fine" patch at 60 m is not a
      // meaningful improvement (>= 90% of 61).
      final c = patchContainer(patchGrid: finerGrid(60));
      final layer = await c.read(
        siteSeascapePatchLayerProvider((
          siteId: siteId,
          stage: BathymetryLodStage.fine,
        )).future,
      );
      expect(layer, isNotNull);
      expect(layer!.stage, BathymetryLodStage.fine);
      expect(layer.detailLimitReached, isTrue);
    });

    test('the fine stage does not flag the detail limit when the patch is '
        'genuinely sharper than the base grid', () async {
      final c = patchContainer(patchGrid: finerGrid(2));
      final layer = await c.read(
        siteSeascapePatchLayerProvider((
          siteId: siteId,
          stage: BathymetryLodStage.fine,
        )).future,
      );
      expect(layer, isNotNull);
      expect(layer!.detailLimitReached, isFalse);
    });

    test(
      'the family key is the discrete stage, not a raw zoom value -- two '
      'different requests for the same stage are the SAME provider entry',
      () async {
        final c = patchContainer(patchGrid: finerGrid(2));
        final a = siteSeascapePatchLayerProvider((
          siteId: siteId,
          stage: BathymetryLodStage.medium,
        ));
        final b = siteSeascapePatchLayerProvider((
          siteId: siteId,
          stage: BathymetryLodStage.medium,
        ));
        // Riverpod family instances compare equal (and so share state) when
        // their arguments are equal -- a plain identical() check would be
        // wrong since these are two separately constructed records.
        expect(a, equals(b));
        // Both reads must be issued before either is awaited: with
        // `autoDispose`, a read with no listener left standing can dispose
        // the entry as soon as its own await completes, so awaiting them
        // one after another would spuriously rebuild for the second read
        // even for the SAME key, rather than proving the key is shared.
        final results = await Future.wait([c.read(a.future), c.read(b.future)]);
        expect(identical(results[0], results[1]), isTrue);
      },
    );
  });
}
