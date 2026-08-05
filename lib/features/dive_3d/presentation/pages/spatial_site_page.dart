import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_labels.dart';
import 'package:submersion/features/dive_3d/application/spatial_providers.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_axes.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_surface.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/seascape_chrome.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/seascape_hover_tooltip.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/tissue_tooltip_layout.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
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
  final ValueNotifier<TissuePick?> _hoverPick = ValueNotifier(null);
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
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.dive3d_spatial_title)),
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
                            visibleOverlays: const {SceneOverlay.markers},
                            axisFrame: axes?.frame,
                            axisLabels: axes?.labels,
                            chromeStyle: axes == null
                                ? null
                                : seascapeChromeStyle(context),
                            axisChromeOnly: true,
                            surfaceGrid: grid == null
                                ? null
                                : seascapePickGrid(
                                    grid,
                                    scene.layers.first.mesh,
                                  ),
                            hoverPick: grid == null ? null : _hoverPick,
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
                    if (result.grid != null) _hoverTooltip(result.grid!),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: TimeScrubBar(
                  position: _position,
                  playing: _player.isAnimating,
                  onPlayPause: _togglePlay,
                  onScrubStart: () {
                    if (_player.isAnimating) setState(() => _player.stop());
                  },
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
        child: ValueListenableBuilder<TissuePick?>(
          valueListenable: _hoverPick,
          builder: (context, pick, _) {
            if (pick == null) return const SizedBox.shrink();
            return CustomSingleChildLayout(
              delegate: TissueTooltipLayoutDelegate(pick.screenPos),
              child: SeascapeHoverTooltip(pick: pick, grid: grid),
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
      ],
    );
  }
}
