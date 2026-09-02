import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/map_tile_config.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_labels.dart';
import 'package:submersion/features/dive_3d/application/spatial_providers.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_axes.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_surface.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/seascape_chrome.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/seascape_depth_legend.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/seascape_hover_tooltip.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/terrain_appearance_sheet.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/tissue_tooltip_layout.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/hover_picker.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/time_scrub_bar.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Fullscreen spatial seascape: the dive's reconstructed swim path threaded
/// through a synthesized seafloor, viewable above and below the waterline.
/// Two captions keep the reconstruction honest (estimated path / synthesized
/// seafloor). The scrub timeline moves the diver along the route.
class SpatialSitePage extends ConsumerStatefulWidget {
  final String diveId;

  const SpatialSitePage({super.key, required this.diveId});

  @override
  ConsumerState<SpatialSitePage> createState() => _SpatialSitePageState();
}

class _SpatialSitePageState extends ConsumerState<SpatialSitePage>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _position = ValueNotifier(0);
  final ValueNotifier<ScenePick?> _hoverPick = ValueNotifier(null);
  final Set<SceneOverlay> _visible = {
    SceneOverlay.markers,
    SceneOverlay.contours,
  };
  late final AnimationController _player;

  @override
  void initState() {
    super.initState();
    _player = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 45),
    )..addListener(() => _position.value = _player.value);
  }

  @override
  void dispose() {
    _player.dispose();
    _position.dispose();
    _hoverPick.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (_player.isAnimating) {
        _player.stop();
      } else {
        if (_position.value >= 1.0) _player.value = 0;
        _player.forward(from: _position.value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sceneAsync = ref.watch(spatialGeometryProvider(widget.diveId));
    final appearance = ref.watch(
      settingsProvider.select((s) => s.seascapeAppearance),
    );
    final depthUnit = ref.watch(settingsProvider.select((s) => s.depthUnit));
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.dive3d_spatial_title),
        actions: [
          IconButton(
            key: const ValueKey('seascapeAppearanceButton'),
            icon: const Icon(Icons.tune),
            tooltip: context.l10n.dive3d_seascape_appearance,
            onPressed: () => showTerrainAppearanceSheet(context),
          ),
        ],
      ),
      body: sceneAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          // The fallback text blames missing data; surface the real error
          // in debug builds so a provider failure is never mistaken for it.
          assert(() {
            debugPrint('spatialGeometryProvider failed: $e');
            return true;
          }());
          return Center(child: Text(context.l10n.dive3d_spatial_noPath));
        },
        data: (result) {
          final scene = result?.scene;
          if (scene == null || scene.layers.isEmpty) {
            return Center(child: Text(context.l10n.dive3d_spatial_noPath));
          }
          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Builder(
                        builder: (context) {
                          final axes = _buildAxes(result!.axisInputs);
                          final grid = result.grid;
                          return Dive3dInteractiveViewport(
                            scene: scene,
                            scrubPosition: _position,
                            visibleOverlays: {..._visible, SceneOverlay.water},
                            contourLabels: result.contourLabels,
                            axisFrame: axes?.frame,
                            axisLabels: axes?.labels,
                            chromeStyle: axes == null
                                ? null
                                : seascapeChromeStyle(context),
                            chromeMode: SceneChromeMode.axesOnly,
                            picker: grid == null
                                ? null
                                : GridHoverPicker(
                                    seascapePickGrid(
                                      grid,
                                      scene.layers.first.mesh,
                                    ),
                                  ),
                            hoverPick: grid == null ? null : _hoverPick,
                            terrainImagery: result.imagery?.image,
                            imageryWhiteTexel: result.imagery == null
                                ? null
                                : (
                                    u: result.imagery!.frame.whiteU,
                                    v: result.imagery!.frame.whiteV,
                                  ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: _captions(result!),
                    ),
                    // The legend describes the depth ramp; a photographed
                    // surface has no ramp to explain. It sits LEFT because the
                    // viewport's zoom column owns the right edge, and on a
                    // phone-sized pane a right-hand legend covers the +/-
                    // buttons outright (issue #1188).
                    if (result.grid != null &&
                        result.axisInputs != null &&
                        appearance.surfaceMode != SeascapeSurfaceMode.imagery)
                      Positioned(
                        top: 40,
                        left: 8,
                        child: SeascapeDepthLegend(
                          maxDepthMeters: result.axisInputs!.maxDepth,
                          hasLand: result.grid!.depthsMeters.any(
                            (d) => d == null || d <= 0,
                          ),
                          appearance: appearance,
                          displayUnitInMeters: depthUnit == DepthUnit.feet
                              ? 0.3048
                              : 1.0,
                          depthSymbol: depthUnit.symbol,
                        ),
                      ),
                    if (result.grid != null) _hoverTooltip(result.grid!),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (result.grid != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Wrap(
                          spacing: 8,
                          children: [
                            FilterChip(
                              label: Text(
                                context.l10n.dive3d_seascape_overlay_contours,
                              ),
                              selected: _visible.contains(
                                SceneOverlay.contours,
                              ),
                              onSelected: (on) => setState(() {
                                on
                                    ? _visible.add(SceneOverlay.contours)
                                    : _visible.remove(SceneOverlay.contours);
                              }),
                            ),
                            FilterChip(
                              label: Text(
                                context.l10n.dive3d_seascape_overlay_walls,
                              ),
                              selected: _visible.contains(
                                SceneOverlay.steepWalls,
                              ),
                              onSelected: (on) => setState(() {
                                on
                                    ? _visible.add(SceneOverlay.steepWalls)
                                    : _visible.remove(SceneOverlay.steepWalls);
                              }),
                            ),
                          ],
                        ),
                      ),
                    TimeScrubBar(
                      position: _position,
                      playing: _player.isAnimating,
                      onPlayPause: _togglePlay,
                      onScrubStart: () {
                        if (_player.isAnimating) setState(() => _player.stop());
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The hover readout, clamped inside the viewport by the shared layout
  /// delegate and transparent to pointer events so it never steals hover.
  Widget _hoverTooltip(BathymetryGrid grid) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ValueListenableBuilder<ScenePick?>(
          valueListenable: _hoverPick,
          builder: (context, pick, _) {
            final payload = pick?.payload;
            if (pick == null || payload is! TissuePick) {
              return const SizedBox.shrink();
            }
            return CustomSingleChildLayout(
              delegate: TissueTooltipLayoutDelegate(pick.screenPos),
              child: SeascapeHoverTooltip(pick: payload, grid: grid),
            );
          },
        ),
      ),
    );
  }

  SeascapeAxes? _buildAxes(SeascapeAxisInputs? inputs) {
    if (inputs == null) return null;
    final units = UnitFormatter(ref.watch(settingsProvider));
    return buildSeascapeAxes(
      projection: SpatialProjection(
        minEast: inputs.minEast,
        maxEast: inputs.maxEast,
        minNorth: inputs.minNorth,
        maxNorth: inputs.maxNorth,
        maxDepth: inputs.maxDepth,
      ),
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

  Widget _captions(SpatialSceneResult result) {
    Widget chip(String text) => Container(
      margin: const EdgeInsets.only(right: 6, bottom: 6),
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
          Text(text, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
    // The path caption is an always-true honesty label: the swim path is
    // always an estimate (dead reckoning or straight-line fallback). The
    // seafloor chip states provenance: real bathymetry when a grid won,
    // otherwise the honest synthesized label.
    final sourceId = result.bathymetrySourceId;
    final resolution = result.bathymetryResolutionMeters;
    return Wrap(
      children: [
        chip(context.l10n.dive3d_spatial_estimatedPath),
        if (sourceId != null && resolution != null)
          chip(
            context.l10n.dive3d_seascape_seafloorSource(
              bathymetrySourceDisplayName(sourceId),
              resolution.round().toString(),
            ),
          )
        else
          chip(context.l10n.dive3d_spatial_synthesizedSeafloor),
        // Tile-provider credit for the draped imagery, required by the
        // imagery providers' terms of use.
        if (result.imagery != null)
          chip(
            MapTileConfig.attribution(
              ref.watch(settingsProvider.select((s) => s.mapStyle)),
            ),
          ),
      ],
    );
  }
}
