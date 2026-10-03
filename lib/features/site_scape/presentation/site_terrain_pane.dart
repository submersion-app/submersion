import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/map_tile_config.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_lod.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_labels.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_3d/application/spatial_providers.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_playback_context.dart';
import 'package:submersion/features/dive_3d/domain/spatial/site_active_path_overlay_builder.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/site_scape/presentation/patch_aware_hover_picker.dart';
import 'package:submersion/features/site_scape/presentation/path_provenance_chip.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_info_sheet.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_axes.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_surface.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_3d/presentation/seascape_chrome.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/hover_picker.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/seascape_depth_legend.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/seascape_hover_tooltip.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/terrain_appearance_sheet.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/time_scrub_bar.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/tissue_tooltip_layout.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Host-agnostic site seascape pane: real bathymetry around the site pin
/// with the site's dives draped in place, plus its own appearance and
/// chart-mode controls (no Scaffold or AppBar; hosts embed it anywhere).
/// Every terminal state renders something, never a permanent spinner.
class SiteTerrainPane extends ConsumerStatefulWidget {
  final String siteId;

  /// Extra actions seated at the START of the pane's docked control card,
  /// ahead of appearance and chart mode. Hosts use this so their own pane
  /// controls (the 2D/3D toggle) read as one cluster with the pane's,
  /// instead of a second card floating over the terrain.
  final List<Widget> leadingActions;

  /// Set when the pane is opened from a dive or an underwater route rather
  /// than from the site directly: additionally plays back that one path
  /// (timeline, provenance caption, and -- for a dive -- the "show measured
  /// route" toggle) on top of the plain site view. `null` (the default)
  /// keeps the exact site-only behavior this pane had before this
  /// parameter existed.
  final SeascapePlaybackContext? playbackContext;

  const SiteTerrainPane({
    super.key,
    required this.siteId,
    this.leadingActions = const [],
    this.playbackContext,
  });

  @override
  ConsumerState<SiteTerrainPane> createState() => _SiteTerrainPaneState();
}

class _SiteTerrainPaneState extends ConsumerState<SiteTerrainPane>
    with SingleTickerProviderStateMixin {
  // Parked at 0 for the plain site view (no timeline there); driven by
  // [_player] once [SiteTerrainPane.playbackContext] is set. The mixin is
  // unconditional (Dart mixins can't be added only for some instances), but
  // [_player] itself is only ever created below when there is a context to
  // play back, so the site-only path pays nothing for it.
  final ValueNotifier<double> _scrub = ValueNotifier(0);
  final ValueNotifier<ScenePick?> _hoverPick = ValueNotifier(null);

  /// Which grid the CURRENT [_hoverPick] value's row/col indices refer to
  /// -- the base grid, or the finer LOD patch grid when the cursor is over
  /// its footprint (see [PatchAwareHoverPicker]). A ValueNotifier, not a
  /// plain field: _hoverTooltip's rebuild is scoped to a listener so a
  /// hover event doesn't force a full pane rebuild, and a plain field
  /// mutated by the picker would never be seen by that listener unless the
  /// pane happened to rebuild for some unrelated reason -- the tooltip
  /// would then show whichever grid was current as of the LAST full
  /// rebuild, not the grid the CURRENT pick actually came from. Set
  /// synchronously by the picker itself, before Dive3dInteractiveViewport
  /// (which calls the picker then assigns [_hoverPick].value right after,
  /// with no await in between) publishes the pick.
  final ValueNotifier<BathymetryGrid?> _hoverPickGrid = ValueNotifier(null);
  final Set<SceneOverlay> _visible = {
    SceneOverlay.markers,
    SceneOverlay.paths,
    SceneOverlay.contours,
    SceneOverlay.features,
  };
  bool _chartMode = false;

  /// The viewport's own camera zoom is a private widget state (see
  /// Dive3dInteractiveViewport), so the pane tracks a DEBOUNCED copy here,
  /// updated only via onZoomSettled, purely to key the LOD patch provider.
  /// Starts at 1.0, the viewport's own default zoom -- below the `medium`
  /// threshold, so no patch fetch fires before the diver actually zooms in.
  double _settledZoom = 1.0;

  /// The playback timeline's driver, created only when
  /// [SiteTerrainPane.playbackContext] is set (see [_syncPlayer]); null for
  /// the plain site view, which has no timeline to drive.
  AnimationController? _player;

  @override
  void initState() {
    super.initState();
    _syncPlayer();
  }

  @override
  void didUpdateWidget(SiteTerrainPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    // SiteTerrainPane is instantiated without a Key keyed to siteId, so
    // switching the displayed site (without leaving 3D mode) reuses this
    // State instead of recreating it. Without this reset, the zoom settled
    // for the PREVIOUS site would keep keying the new site's LOD patch
    // provider, fetching (or displaying) the wrong detail stage until the
    // diver zooms again.
    if (widget.siteId != oldWidget.siteId) {
      _settledZoom = 1.0;
    }
    _syncPlayer();
  }

  /// Creates or disposes [_player] to match whether
  /// [SiteTerrainPane.playbackContext] is currently set. An existing
  /// controller is kept, so a dive-to-dive or route-to-route switch keeps
  /// the timeline position instead of restarting playback from 0.
  void _syncPlayer() {
    if (widget.playbackContext == null) {
      _player?.dispose();
      _player = null;
      _scrub.value = 0;
      return;
    }
    if (_player != null) return;
    _player =
        AnimationController(vsync: this, duration: const Duration(seconds: 45))
          ..addListener(() => _scrub.value = _player!.value)
          // Playback reaching the end stops the controller on its own, with no
          // call to _togglePlay -- without this, the pane never rebuilds for
          // that, so _timeline()'s cached `player.isAnimating` read (captured
          // at the last build) keeps reading true and the pause icon stays up
          // forever after the timeline finishes (code review).
          ..addStatusListener((status) {
            if ((status == AnimationStatus.completed ||
                    status == AnimationStatus.dismissed) &&
                mounted) {
              setState(() {});
            }
          });
  }

  void _togglePlay() {
    final player = _player;
    if (player == null) return;
    setState(() {
      if (player.isAnimating) {
        player.stop();
      } else {
        if (_scrub.value >= 1.0) player.value = 0;
        player.forward(from: _scrub.value);
      }
    });
  }

  @override
  void dispose() {
    _player?.dispose();
    _scrub.dispose();
    _hoverPick.dispose();
    _hoverPickGrid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(siteSeascapeProvider(widget.siteId));
    final appearance = ref.watch(
      settingsProvider.select((s) => s.seascapeAppearance),
    );
    final depthUnit = ref.watch(settingsProvider.select((s) => s.depthUnit));
    // The docked card wraps EVERY state, not just the ready one: hosts
    // inject the way back to 2D through leadingActions, and a site whose
    // seascape comes back empty would otherwise be a dead end. The pane's
    // own actions still need a scene, so they appear only when ready.
    return Stack(
      fit: StackFit.expand,
      children: [
        _paneBody(stateAsync, appearance, depthUnit),
        if (widget.leadingActions.isNotEmpty ||
            stateAsync.valueOrNull is SiteSeascapeReady)
          Positioned(
            top: 8,
            right: 8,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...widget.leadingActions,
                    if (stateAsync.valueOrNull is SiteSeascapeReady) ...[
                      IconButton(
                        key: const ValueKey('seascapeAppearanceButton'),
                        icon: const Icon(Icons.tune, size: 20),
                        tooltip: context.l10n.dive3d_seascape_appearance,
                        onPressed: () => showTerrainAppearanceSheet(
                          context,
                          siteId: widget.siteId,
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('seascapeChartToggle'),
                        icon: Icon(
                          _chartMode ? Icons.view_in_ar : Icons.map_outlined,
                          size: 20,
                        ),
                        tooltip: _chartMode
                            ? context.l10n.dive3d_seascape_orbitView
                            : context.l10n.dive3d_seascape_chartView,
                        onPressed: () =>
                            setState(() => _chartMode = !_chartMode),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _paneBody(
    AsyncValue<SiteSeascapeState> stateAsync,
    SeascapeAppearance appearance,
    DepthUnit depthUnit,
  ) {
    return stateAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) {
        // The fallback text blames missing data; surface the real error
        // in debug builds so a provider failure is never mistaken for it.
        assert(() {
          debugPrint('siteSeascapeProvider failed: $e');
          return true;
        }());
        return Center(child: Text(context.l10n.dive3d_seascape_noData));
      },
      data: (state) => switch (state) {
        SiteSeascapeNoCoordinates() => Center(
          child: Text(context.l10n.dive3d_seascape_noCoordinates),
        ),
        SiteSeascapeNoData() => Center(
          child: Text(context.l10n.dive3d_seascape_noData),
        ),
        SiteSeascapeReady(
          :final scene,
          :final sourceId,
          :final resolutionMeters,
          :final axisInputs,
          :final grid,
          :final contourLabels,
          :final imagery,
        ) =>
          Builder(
            builder: (context) {
              // Watched at this level (not inside the inner Builder) so the
              // detail-limit hint chip below can read the same value without
              // a second, possibly out-of-sync watch.
              final stage = bathymetryLodStageForZoom(_settledZoom);
              // Uses AsyncValue.value (not the project's .valueOrNull
              // extension) on purpose: .value retains the previous patch
              // while a dependency-driven reload (base seascape or
              // settings change) is in flight, whereas .valueOrNull's
              // when()-based implementation returns null for every
              // loading state and would otherwise make the patch flicker
              // away and reappear on each reload.
              final patch = ref
                  .watch(
                    siteSeascapePatchLayerProvider((
                      siteId: widget.siteId,
                      stage: stage,
                    )),
                  )
                  .value;
              // The one dive's or route's path being played back on top of
              // the site scene (see SiteTerrainPane.playbackContext); null
              // for the plain site view, where there is nothing to play.
              final playbackContext = widget.playbackContext;
              final activePathAsync = playbackContext == null
                  ? null
                  : ref.watch(
                      siteActivePathOverlayProvider((
                        siteId: widget.siteId,
                        pathId: switch (playbackContext) {
                          DivePlaybackContext(diveId: final id) => id,
                          NavTrackPlaybackContext(trackId: final id) => id,
                        },
                        source: switch (playbackContext) {
                          DivePlaybackContext() => PathOverlaySource.dive,
                          NavTrackPlaybackContext() =>
                            PathOverlaySource.navTrack,
                        },
                      )),
                    );
              final activePath = activePathAsync?.value;
              // scene.layers can legitimately be empty (e.g. right after a
              // source switch, before the terrain layer has been added);
              // there is then no base layer to insert the patch ahead of,
              // so fall back to the scene unchanged instead of crashing on
              // .first (mirrors the picker guard below).
              final displayScene = patch == null || scene.layers.isEmpty
                  ? scene
                  : Scene3d(
                      layers: [
                        scene.layers.first,
                        ...patch.layers,
                        ...scene.layers.skip(1),
                      ],
                      markers: scene.markers,
                      bounds: scene.bounds,
                      scrubPath: scene.scrubPath,
                    );
              // The active path rides on top of whichever scene (base or
              // patched) is showing: its own ribbon and pins, and the
              // ScrubPath the scrub bar and the viewport's diver marker
              // follow. Terrain and markers are unchanged.
              final scrubbableScene = activePath == null
                  ? displayScene
                  : sceneWithActivePath(displayScene, activePath.overlay);
              return Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Builder(
                            builder: (context) {
                              final axes = _buildAxes(axisInputs);
                              return Dive3dInteractiveViewport(
                                // Keyed on siteId: the pane itself is reused
                                // across an in-place site switch (see
                                // didUpdateWidget above), and so is this
                                // viewport unless forced to remount here.
                                // Without this key the viewport's own
                                // internal camera zoom/pan/pose survived a
                                // site switch even after _settledZoom reset
                                // to the overview stage, so the LOD patch
                                // logic thought the diver was zoomed out
                                // while the camera was still showing the
                                // previous site's close-up view.
                                key: ValueKey(widget.siteId),
                                scene: scrubbableScene,
                                scrubPosition: _scrub,
                                visibleOverlays: {
                                  ..._visible,
                                  if (!_chartMode) SceneOverlay.water,
                                },
                                chartMode: _chartMode,
                                contourLabels: contourLabels,
                                axisFrame: axes.frame,
                                axisLabels: axes.labels,
                                chromeStyle: seascapeChromeStyle(context),
                                chromeMode: SceneChromeMode.axesOnly,
                                // scene.layers can legitimately be empty (e.g.
                                // right after a source switch, before the terrain
                                // layer has been added); hover picking has nothing
                                // to pick against then, so this disables the
                                // picker instead of crashing on .first.
                                //
                                // When a finer LOD patch is showing, its own
                                // grid/mesh is tried FIRST: it visually covers
                                // the base terrain in that area, so a hover
                                // there should read the patch's own depth, not
                                // the coarser base grid underneath it. Outside
                                // the patch's footprint the patch picker finds
                                // nothing within its threshold and returns
                                // null, falling through to the base grid.
                                picker: scene.layers.isEmpty
                                    ? null
                                    : PatchAwareHoverPicker(
                                        patchPicker: patch == null
                                            ? null
                                            : GridHoverPicker(
                                                seascapePickGrid(
                                                  patch.grid,
                                                  patch.layers.first.mesh,
                                                ),
                                              ),
                                        patchGrid: patch?.grid,
                                        basePicker: GridHoverPicker(
                                          seascapePickGrid(
                                            grid,
                                            scene.layers.first.mesh,
                                          ),
                                        ),
                                        baseGrid: grid,
                                        onGridUsed: (g) =>
                                            _hoverPickGrid.value = g,
                                      ),
                                hoverPick: _hoverPick,
                                onMarkerTap: _onMarkerTap,
                                terrainImagery: imagery?.image,
                                imageryWhiteTexel: imagery == null
                                    ? null
                                    : (
                                        u: imagery.frame.whiteU,
                                        v: imagery.frame.whiteV,
                                      ),
                                onZoomSettled: (zoom) {
                                  if (mounted) {
                                    setState(() => _settledZoom = zoom);
                                  }
                                },
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          right: 8,
                          child: _sourceChip(
                            patch?.grid.sourceId ?? sourceId,
                            patch?.grid.resolutionMeters ?? resolutionMeters,
                            stage,
                            depthUnit,
                          ),
                        ),
                        // top: 8, right: 8 is already the pane's docked
                        // appearance/chart-mode card (see build() above),
                        // which paints over anything at that same position
                        // in this inner Stack -- so this sits a row below
                        // it instead, on the right edge under the card.
                        if (patch?.detailLimitReached ?? false)
                          Positioned(
                            top: 56,
                            right: 8,
                            child: _detailLimitHint(context),
                          ),
                        // Sits below the source chip at top: 8 -- only the
                        // dive variant has a provenance to caption; a route
                        // IS the recorded path, nothing to caption. A dive
                        // with no usable path says so, as the standalone
                        // view does, instead of silently showing the site.
                        if (playbackContext is DivePlaybackContext &&
                            (activePathAsync?.hasSettled ?? false))
                          Positioned(
                            top: 40,
                            left: 8,
                            right: 8,
                            child: activePath == null
                                ? SeascapeCaptionChip(
                                    label: context.l10n.dive3d_spatial_noPath,
                                  )
                                : PathProvenanceChip(
                                    overlay: activePath.overlay,
                                  ),
                          ),
                        // The legend describes the depth ramp; a photographed
                        // surface has no ramp to explain. It sits LEFT because the
                        // viewport's zoom column owns the right edge, and on a
                        // phone-sized pane a right-hand legend covers the +/-
                        // buttons outright (issue #1188).
                        if (appearance.surfaceMode !=
                            SeascapeSurfaceMode.imagery)
                          Positioned(
                            top: 72,
                            left: 8,
                            child: SeascapeDepthLegend(
                              maxDepthMeters: axisInputs.maxDepth,
                              hasLand: grid.depthsMeters.any(
                                (d) => d == null || d <= 0,
                              ),
                              appearance: appearance,
                              displayUnitInMeters: depthUnit == DepthUnit.feet
                                  ? 0.3048
                                  : 1.0,
                              depthSymbol: depthUnit.symbol,
                            ),
                          ),
                        if (imagery != null)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: _attributionChip(
                              MapTileConfig.attribution(
                                ref.watch(
                                  settingsProvider.select((s) => s.mapStyle),
                                ),
                              ),
                            ),
                          ),
                        // Sits clear of the compass rose the chrome painter
                        // draws in the bottom-left corner (center at (36,
                        // height-36), radius 18, so its right edge is at x=54)
                        // -- issue #2141 follow-up: the adjustable slider
                        // itself moved into the terrain-appearance sheet; this
                        // stays as a compact read-out of whatever value is
                        // currently in effect, automatic or overridden.
                        Positioned(
                          left: 72,
                          bottom: 24,
                          child: _exaggerationBadge(
                            axisInputs.verticalExaggeration,
                          ),
                        ),
                        _hoverTooltip(grid),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _overlayChips(
                          playbackContext,
                          activePath?.hasLinkedRoute ?? false,
                        ),
                        // Gated on activePath, not just playbackContext: a
                        // dive/route whose path has fewer than two usable
                        // points (siteActivePathOverlayProvider then
                        // returns null) would otherwise show a playable
                        // timeline with no path for it to actually move
                        // along (code review).
                        if (playbackContext != null && activePath != null)
                          _timeline(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
      },
    );
  }

  /// The playback timeline: present only when
  /// [SiteTerrainPane.playbackContext] is set (see [_syncPlayer], which
  /// creates [_player] exactly then).
  Widget _timeline() {
    final player = _player;
    if (player == null) return const SizedBox.shrink();
    return TimeScrubBar(
      position: _scrub,
      playing: player.isAnimating,
      onPlayPause: _togglePlay,
      onScrubStart: () {
        if (player.isAnimating) setState(() => player.stop());
      },
    );
  }

  /// Feature markers are read-only in 3D (placement and editing live on
  /// the 2D map): a tap shows what the diver recorded, nothing more.
  Future<void> _onMarkerTap(SceneMarker marker) async {
    if (marker.kind != SceneMarkerKind.siteFeature) return;
    // Await rather than read: the pane itself never watches the feature
    // list, so a plain read can land on an unresolved provider and drop
    // the tap silently.
    final features = await ref.read(siteFeaturesProvider(widget.siteId).future);
    final feature = features.where((f) => f.id == marker.refId).firstOrNull;
    if (feature == null || !mounted) return;
    // No onEdit: the 2D map owns placement and editing.
    await showSiteFeatureInfoSheet(context, ref, feature);
  }

  /// The hover readout, clamped inside the viewport by the shared layout
  /// delegate and transparent to pointer events so it never steals hover.
  /// [baseGrid] is only the fallback for when nothing has been picked yet
  /// (the tooltip itself renders nothing then); once a pick lands, which
  /// grid to read its row/col against comes from [_hoverPickGrid], NOT a
  /// value closed over at the pane's last full rebuild -- a hover crossing
  /// between the base terrain and a finer LOD patch does not by itself
  /// trigger a full pane rebuild, only _hoverPick/_hoverPickGrid notify, so
  /// this listens to both directly instead of receiving a plain parameter.
  Widget _hoverTooltip(BathymetryGrid baseGrid) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ListenableBuilder(
          listenable: Listenable.merge([_hoverPick, _hoverPickGrid]),
          builder: (context, _) {
            final pick = _hoverPick.value;
            final payload = pick?.payload;
            if (pick == null || payload is! TissuePick) {
              return const SizedBox.shrink();
            }
            return CustomSingleChildLayout(
              delegate: TissueTooltipLayoutDelegate(pick.screenPos),
              child: SeascapeHoverTooltip(
                pick: payload,
                grid: _hoverPickGrid.value ?? baseGrid,
              ),
            );
          },
        ),
      ),
    );
  }

  SeascapeAxes _buildAxes(SeascapeAxisInputs inputs) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    return buildSeascapeAxes(
      projection: seascapeProjection(inputs),
      minEast: inputs.minEast,
      maxEast: inputs.maxEast,
      minNorth: inputs.minNorth,
      maxNorth: inputs.maxNorth,
      maxDepthMeters: inputs.maxDepth,
      displayUnitInMeters: units.depthToMeters(1.0),
      distanceTitle: context.l10n.dive3d_seascape_axis_distance(
        units.depthSymbol,
      ),
      depthTitle: context.l10n.divePlanner_label_depthAxis(units.depthSymbol),
    );
  }

  Widget _sourceChip(
    String sourceId,
    double resolutionMeters,
    BathymetryLodStage stage,
    DepthUnit depthUnit,
  ) {
    // Surfaces the active LOD stage (see bathymetry_lod.dart) so a diver
    // can tell why the terrain just got sharper (or why it stopped
    // getting sharper) without needing to know the underlying zoom
    // threshold. The span respects the diver's own depth unit, like every
    // other measurement on this pane (legend, axes).
    final stageName = switch (stage) {
      BathymetryLodStage.overview =>
        context.l10n.dive3d_seascape_lodStageOverview,
      BathymetryLodStage.medium => context.l10n.dive3d_seascape_lodStageMedium,
      BathymetryLodStage.fine => context.l10n.dive3d_seascape_lodStageFine,
      BathymetryLodStage.superFine =>
        context.l10n.dive3d_seascape_lodStageSuperFine,
    };
    final spanDisplay = DepthUnit.meters.convert(stage.spanMeters, depthUnit);
    final stageLabelText = context.l10n.dive3d_seascape_lodStageLabel(
      stageName,
      '${spanDisplay.round()} ${depthUnit.symbol}',
    );
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '${context.l10n.dive3d_seascape_seafloorSource(bathymetrySourceDisplayName(sourceId), resolutionMeters.round().toString())} · $stageLabelText',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A quiet "no more detail here" hint: shown only at the `fine` LOD stage
  /// when the patch grid came back no meaningfully sharper than the base
  /// grid (see [SiteSeascapePatchLayer.detailLimitReached]'s doc for the
  /// heuristic), so the diver does not keep zooming in expecting more.
  Widget _detailLimitHint(BuildContext context) {
    return Tooltip(
      message: context.l10n.dive3d_seascape_detailLimitReached,
      child: Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        shape: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.search_off, size: 16),
        ),
      ),
    );
  }

  /// Tile-provider credit for the draped imagery, styled like the source
  /// chip. Required by the imagery providers' terms of use.
  Widget _attributionChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  /// Compact, read-only readout of the terrain's current vertical
  /// exaggeration (issue #2141 follow-up) -- automatic or manually
  /// overridden via the slider now in the terrain-appearance sheet, which
  /// is the one place that actually changes it. Deliberately tiny: an
  /// icon plus a short label plus the factor, not a full control.
  Widget _exaggerationBadge(double effectiveExaggeration) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.height, size: 14),
          const SizedBox(width: 2),
          Text(
            '${context.l10n.dive3d_seascape_verticalExaggerationLabel} '
            '${effectiveExaggeration.toStringAsFixed(1)}×',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  /// [playbackContext] and [hasLinkedRoute] add the "show measured route"
  /// toggle for the dive variant only (a route has no alternate path to
  /// switch to -- it IS the recorded one).
  Widget _overlayChips(
    SeascapePlaybackContext? playbackContext,
    bool hasLinkedRoute,
  ) {
    FilterChip chip(SceneOverlay overlay, String label) => FilterChip(
      label: Text(label),
      selected: _visible.contains(overlay),
      onSelected: (on) => setState(() {
        on ? _visible.add(overlay) : _visible.remove(overlay);
      }),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 8,
        children: [
          chip(SceneOverlay.paths, context.l10n.dive3d_seascape_overlay_paths),
          chip(SceneOverlay.markers, context.l10n.dive3d_overlay_markers),
          chip(
            SceneOverlay.contours,
            context.l10n.dive3d_seascape_overlay_contours,
          ),
          chip(
            SceneOverlay.steepWalls,
            context.l10n.dive3d_seascape_overlay_walls,
          ),
          chip(SceneOverlay.features, context.l10n.siteFeature_sectionTitle),
          if (playbackContext is DivePlaybackContext && hasLinkedRoute)
            FilterChip(
              key: const ValueKey('spatial-site-show-route-toggle'),
              label: Text(context.l10n.dive3d_seascape_showUnderwaterTrack),
              selected: ref.watch(
                showMeasuredRouteProvider(playbackContext.diveId),
              ),
              onSelected: (on) =>
                  ref
                          .read(
                            showMeasuredRouteProvider(
                              playbackContext.diveId,
                            ).notifier,
                          )
                          .state =
                      on,
            ),
        ],
      ),
    );
  }
}
