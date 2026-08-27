import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/map_tile_config.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_labels.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_info_sheet.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_axes.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_surface.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_3d/presentation/seascape_chrome.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/hover_picker.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/seascape_depth_legend.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/seascape_hover_tooltip.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/terrain_appearance_sheet.dart';
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

  const SiteTerrainPane({
    super.key,
    required this.siteId,
    this.leadingActions = const [],
  });

  @override
  ConsumerState<SiteTerrainPane> createState() => _SiteTerrainPaneState();
}

class _SiteTerrainPaneState extends ConsumerState<SiteTerrainPane> {
  // No timeline at site level: the scrub cursor stays parked.
  final ValueNotifier<double> _scrub = ValueNotifier(0);
  final ValueNotifier<ScenePick?> _hoverPick = ValueNotifier(null);
  final Set<SceneOverlay> _visible = {
    SceneOverlay.markers,
    SceneOverlay.paths,
    SceneOverlay.contours,
    SceneOverlay.features,
  };
  bool _chartMode = false;

  @override
  void dispose() {
    _scrub.dispose();
    _hoverPick.dispose();
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
                        onPressed: () => showTerrainAppearanceSheet(context),
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
                            picker: GridHoverPicker(
                              seascapePickGrid(grid, scene.layers.first.mesh),
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
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 56,
                      left: 8,
                      right: 8,
                      child: _sourceChip(sourceId, resolutionMeters),
                    ),
                    // The legend describes the depth ramp; a photographed
                    // surface has no ramp to explain. It sits LEFT because the
                    // viewport's zoom column owns the right edge, and on a
                    // phone-sized pane a right-hand legend covers the +/-
                    // buttons outright (issue #1188).
                    if (appearance.surfaceMode != SeascapeSurfaceMode.imagery)
                      Positioned(
                        top: 96,
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
                    _hoverTooltip(grid),
                  ],
                ),
              ),
              SafeArea(top: false, child: _overlayChips()),
            ],
          ),
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
          chip(
            SceneOverlay.contours,
            context.l10n.dive3d_seascape_overlay_contours,
          ),
          chip(
            SceneOverlay.steepWalls,
            context.l10n.dive3d_seascape_overlay_walls,
          ),
          chip(SceneOverlay.features, context.l10n.siteFeature_sectionTitle),
        ],
      ),
    );
  }
}
