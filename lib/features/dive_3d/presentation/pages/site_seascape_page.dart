import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_labels.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_axes.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_surface.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_3d/presentation/seascape_chrome.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/seascape_hover_tooltip.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/tissue_tooltip_layout.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Fullscreen site seascape: real bathymetry around the site pin with the
/// site's dives draped in place. Every terminal state renders something —
/// a scene, or an explicit message; never a permanent spinner.
class SiteSeascapePage extends ConsumerStatefulWidget {
  final String siteId;

  const SiteSeascapePage({super.key, required this.siteId});

  @override
  ConsumerState<SiteSeascapePage> createState() => _SiteSeascapePageState();
}

class _SiteSeascapePageState extends ConsumerState<SiteSeascapePage> {
  // No timeline at site level: the scrub cursor stays parked.
  final ValueNotifier<double> _scrub = ValueNotifier(0);
  final ValueNotifier<TissuePick?> _hoverPick = ValueNotifier(null);
  final Set<SceneOverlay> _visible = {SceneOverlay.markers, SceneOverlay.paths};

  @override
  void dispose() {
    _scrub.dispose();
    _hoverPick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(siteSeascapeProvider(widget.siteId));
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.dive3d_seascape_siteTitle)),
      body: stateAsync.when(
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
          ) =>
            Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Builder(
                          builder: (context) {
                            final axes = _buildAxes(axisInputs);
                            return Dive3dInteractiveViewport(
                              scene: scene,
                              scrubPosition: _scrub,
                              visibleOverlays: _visible,
                              axisFrame: axes.frame,
                              axisLabels: axes.labels,
                              chromeStyle: seascapeChromeStyle(context),
                              axisChromeOnly: true,
                              surfaceGrid: seascapePickGrid(
                                grid,
                                scene.layers.first.mesh,
                              ),
                              hoverPick: _hoverPick,
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        right: 8,
                        child: _sourceChip(sourceId, resolutionMeters),
                      ),
                      _hoverTooltip(grid),
                    ],
                  ),
                ),
                SafeArea(top: false, child: _overlayChips()),
              ],
            ),
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

  SeascapeAxes _buildAxes(SeascapeAxisInputs inputs) {
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

  Widget _sourceChip(String sourceId, double resolutionMeters) {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
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
            Text(
              context.l10n.dive3d_seascape_seafloorSource(
                bathymetrySourceDisplayName(sourceId),
                resolutionMeters.round().toString(),
              ),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _overlayChips() {
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
        ],
      ),
    );
  }
}
