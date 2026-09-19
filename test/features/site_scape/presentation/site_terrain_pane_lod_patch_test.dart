import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_lod.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import 'site_terrain_pane_test_support.dart';

/// A minimal, valid single-triangle mesh -- enough to stand in for a real
/// terrain patch mesh without going through the full terrain builder.
SceneLayer _stubPatchLayer() => SceneLayer(
  MeshData(
    positions: Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 0, 1]),
    indices: Uint32List.fromList([0, 1, 2]),
    colors: Float32List(9),
  ),
);

/// A minimal, valid grid to pair with [_stubPatchLayer] -- stands in for the
/// real patch grid a SiteSeascapePatchLayer carries for hover picking.
BathymetryGrid _stubPatchGrid() => BathymetryGrid(
  originLat: 12.15,
  originLon: -68.30,
  cellSizeLatDeg: 0.001,
  cellSizeLonDeg: 0.001,
  rows: 2,
  cols: 2,
  depthsMeters: const [20, 30, 25, 35],
  sourceId: 'gmrt',
  resolutionMeters: 5,
  fetchedAt: DateTime.utc(2026, 7, 28),
);

void main() {
  group('additional LOD patch layer', () {
    testWidgets(
      'no patch is requested and none is merged before the diver zooms in '
      '(default settled zoom is the overview stage)',
      (tester) async {
        var patchCalls = 0;
        await tester.pumpWidget(
          page(
            readyState(),
            extraOverrides: [
              siteSeascapePatchLayerProvider.overrideWith((ref, request) async {
                patchCalls++;
                return null;
              }),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        // The pane watches the patch provider unconditionally -- with the
        // default settled zoom, that request already carries the overview
        // stage (computed at the call site via bathymetryLodStageForZoom).
        // This override still runs once to prove the watch happens.
        expect(patchCalls, 1);
        final viewport = tester.widget<Dive3dInteractiveViewport>(
          find.byType(Dive3dInteractiveViewport),
        );
        expect(viewport.scene.layers.length, readyState().scene.layers.length);
      },
    );

    testWidgets(
      'a settled zoom past the medium threshold merges the patch layer '
      'right after the base terrain layer',
      (tester) async {
        final state = readyState();
        final baseLayerCount = state.scene.layers.length;
        await tester.pumpWidget(
          page(
            state,
            extraOverrides: [
              siteSeascapePatchLayerProvider.overrideWith((ref, request) async {
                if (request.stage != BathymetryLodStage.medium) return null;
                return SiteSeascapePatchLayer(
                  layers: [_stubPatchLayer()],
                  grid: _stubPatchGrid(),
                  stage: BathymetryLodStage.medium,
                  detailLimitReached: false,
                );
              }),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        Dive3dInteractiveViewport viewport() =>
            tester.widget<Dive3dInteractiveViewport>(
              find.byType(Dive3dInteractiveViewport),
            );
        // Simulate the viewport's own debounced zoom settling, without
        // waiting out the real 300ms timer (that behavior is covered by
        // dive_3d_interactive_viewport_test.dart already).
        viewport().onZoomSettled!(3.0);
        await tester.pump();
        await tester.pump();

        expect(viewport().scene.layers.length, baseLayerCount + 1);
        expect(viewport().scene.layers[0], state.scene.layers.first);
        expect(viewport().scene.layers[1].mesh.indices, [0, 1, 2]);
        // The detail-limit hint is not shown at the `medium` stage.
        expect(find.byIcon(Icons.search_off), findsNothing);
      },
    );

    testWidgets(
      'the detail-limit hint appears only at the fine stage when the patch '
      'came back no sharper than the base grid',
      (tester) async {
        await tester.pumpWidget(
          page(
            readyState(),
            extraOverrides: [
              siteSeascapePatchLayerProvider.overrideWith((ref, request) async {
                if (request.stage != BathymetryLodStage.fine) return null;
                return SiteSeascapePatchLayer(
                  layers: [_stubPatchLayer()],
                  grid: _stubPatchGrid(),
                  stage: BathymetryLodStage.fine,
                  detailLimitReached: true,
                );
              }),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        final viewport = tester.widget<Dive3dInteractiveViewport>(
          find.byType(Dive3dInteractiveViewport),
        );
        viewport.onZoomSettled!(6.0);
        await tester.pump();
        await tester.pump();

        expect(find.byIcon(Icons.search_off), findsOneWidget);
      },
    );

    testWidgets(
      'an empty base scene (right after a source switch) with a non-null '
      'patch does not crash on the missing base layer',
      (tester) async {
        final base = readyState();
        final emptyLayersState = SiteSeascapeReady(
          scene: Scene3d(
            layers: const [],
            markers: base.scene.markers,
            bounds: base.scene.bounds,
            scrubPath: base.scene.scrubPath,
          ),
          sourceId: base.sourceId,
          resolutionMeters: base.resolutionMeters,
          grid: base.grid,
          axisInputs: base.axisInputs,
        );
        await tester.pumpWidget(
          page(
            emptyLayersState,
            extraOverrides: [
              siteSeascapePatchLayerProvider.overrideWith(
                (ref, request) async => SiteSeascapePatchLayer(
                  layers: [_stubPatchLayer()],
                  grid: _stubPatchGrid(),
                  stage: BathymetryLodStage.medium,
                  detailLimitReached: false,
                ),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        // Must not throw building displayScene on an empty scene.layers.
        expect(tester.takeException(), isNull);
        final viewport = tester.widget<Dive3dInteractiveViewport>(
          find.byType(Dive3dInteractiveViewport),
        );
        // Falls back to the (empty-layers) scene unchanged: nothing to
        // insert the patch ahead of.
        expect(viewport.scene.layers, isEmpty);
      },
    );
  });

  group('LOD patch stage resets when the pane switches sites', () {
    // Bug: SiteTerrainPane keeps its State across a siteId switch (see
    // SiteSwitchHost's own doc in site_terrain_pane_test_support.dart), so
    // the debounced _settledZoom it tracks for the LOD patch provider used
    // to keep the PREVIOUS site's zoom after switching, requesting the
    // wrong stage for the new site until the diver zoomed again.
    testWidgets(
      'switching siteId resets the settled zoom back to the overview stage, '
      'even if the previous site had zoomed in past it',
      (tester) async {
        final requestedStages = <String, List<BathymetryLodStage>>{};
        final stateA = readyState();
        final stateB = readyState();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsProvider.overrideWith(
                (ref) => TestSettingsNotifier(const AppSettings()),
              ),
              siteSeascapeProvider.overrideWith(
                (ref, id) async => id == 'site-a' ? stateA : stateB,
              ),
              siteFeaturesProvider(
                'site-a',
              ).overrideWith((ref) async => const []),
              siteFeaturesProvider(
                'site-b',
              ).overrideWith((ref) async => const []),
              siteSeascapePatchLayerProvider.overrideWith((ref, request) async {
                (requestedStages[request.siteId] ??= []).add(request.stage);
                return null;
              }),
            ],
            child: const MaterialApp(
              locale: Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SiteSwitchHost(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Zoom site-a in past the fine threshold.
        final viewport = tester.widget<Dive3dInteractiveViewport>(
          find.byType(Dive3dInteractiveViewport),
        );
        viewport.onZoomSettled!(6.0);
        await tester.pump();
        await tester.pump();
        expect(requestedStages['site-a'], contains(BathymetryLodStage.fine));

        // Switch to site-b without ever zooming it in.
        await tester.tap(find.byKey(const ValueKey('switchSiteButton')));
        await tester.pump();
        await tester.pump();

        // If _settledZoom had survived the switch, site-b's very first
        // request would carry `fine` too.
        expect(requestedStages['site-b'], isNotNull);
        expect(
          requestedStages['site-b'],
          everyElement(BathymetryLodStage.overview),
        );
      },
    );
  });

  group('the detail-limit hint does not overlap the docked control card', () {
    testWidgets(
      'the hint and the appearance/chart-mode card render at non-overlapping '
      'positions',
      (tester) async {
        await tester.pumpWidget(
          page(
            readyState(),
            extraOverrides: [
              siteSeascapePatchLayerProvider.overrideWith(
                (ref, request) async => SiteSeascapePatchLayer(
                  layers: [_stubPatchLayer()],
                  grid: _stubPatchGrid(),
                  stage: BathymetryLodStage.fine,
                  detailLimitReached: true,
                ),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        final viewport = tester.widget<Dive3dInteractiveViewport>(
          find.byType(Dive3dInteractiveViewport),
        );
        viewport.onZoomSettled!(6.0);
        await tester.pump();
        await tester.pump();

        final hint = tester.getRect(find.byIcon(Icons.search_off));
        final card = tester.getRect(
          find.byKey(const ValueKey('seascapeAppearanceButton')),
        );
        expect(
          hint.overlaps(card),
          isFalse,
          reason: 'detail-limit hint $hint overlaps the control card $card',
        );
      },
    );
  });
}
