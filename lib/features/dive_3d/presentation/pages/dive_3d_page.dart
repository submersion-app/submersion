import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/application/compare_providers.dart';
import 'package:submersion/features/dive_3d/application/providers.dart';
import 'package:submersion/features/dive_3d/application/tissue_providers.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/axis_frame.dart';
import 'package:submersion/features/dive_3d/domain/geometry/dive_axes.dart';
import 'package:submersion/features/dive_3d/domain/geometry/z_axis_spec.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/tissue/subsurface_tissue_builder.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_grid.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/axis_labels.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/hover_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart';
import 'package:submersion/features/dive_3d/presentation/dive_chrome.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/compare_profile_3d_view.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_hover_tooltip.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_readout_rows.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/scene_readout_panel.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/time_scrub_bar.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/tissue_hover_tooltip.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/tissue_legend.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/tissue_tooltip_layout.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/tissue_readout_panel.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart'
    show settingsProvider;
import 'package:submersion/l10n/l10n_extension.dart';

/// Which scene the 3D page is showing.
enum SceneKind { dive, tissue, computers }

/// Fullscreen interactive 3D scene for one dive. Pushed via a plain
/// Navigator route from the dive detail page. Owns the scrub ValueNotifier
/// and the playback AnimationController; the viewport and readout observe
/// them without provider round-trips. The profile chart opens the dive
/// scene (switchable to the computers comparison on multi-source dives);
/// the tissue loading card opens the tissue landscape directly.
class Dive3dPage extends ConsumerStatefulWidget {
  final String diveId;
  final SceneKind initialMode;

  const Dive3dPage({
    super.key,
    required this.diveId,
    this.initialMode = SceneKind.dive,
  });

  @override
  ConsumerState<Dive3dPage> createState() => _Dive3dPageState();
}

class _Dive3dPageState extends ConsumerState<Dive3dPage>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _position = ValueNotifier(0);
  final ValueNotifier<ScenePick?> _hoverPick = ValueNotifier(null);
  late final AnimationController _player;
  late SceneKind _sceneKind;
  SceneMetric _colorMetric = SceneMetric.depth;
  SceneMetric? _zMetric;
  bool _zInitialized = false;
  // Color follows the Z metric until the diver picks a color chip.
  bool _colorFollowsZ = true;
  Set<SceneOverlay> _overlays = {
    SceneOverlay.ceiling,
    SceneOverlay.markers,
    SceneOverlay.shadows,
  };

  // One set of readout lookups per scene data: the tank-pressure lookups
  // copy their series, and both the scrub panel (frame rate) and the hover
  // tooltip (every mouse move) read through them.
  DiveReadoutLookups? _readoutLookups;

  DiveReadoutLookups _lookupsFor(Dive3dSceneData data) {
    final cached = _readoutLookups;
    if (cached != null && identical(cached.data, data)) return cached;
    return _readoutLookups = DiveReadoutLookups(data);
  }

  void _initZ(Dive3dSceneData data) {
    if (_zInitialized) return;
    _zInitialized = true;
    final z = data.zAxisMetrics.contains(SceneMetric.temperature)
        ? SceneMetric.temperature
        : null;
    _zMetric = z;
    if (_colorFollowsZ) _colorMetric = z ?? SceneMetric.depth;
  }

  void _selectZ(SceneMetric? z) {
    setState(() {
      _zMetric = z;
      if (_colorFollowsZ) _colorMetric = z ?? SceneMetric.depth;
    });
  }

  String _zTitle(ZAxisInput z) {
    final name = _metricLabel(z.metric);
    return z.spec.symbol.isEmpty ? name : '$name (${z.spec.symbol})';
  }

  @override
  void initState() {
    super.initState();
    _sceneKind = widget.initialMode;
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
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.dive3d_previewTitle)),
      body: switch (_sceneKind) {
        SceneKind.dive => _buildDiveBody(),
        SceneKind.tissue => _buildTissueBody(),
        SceneKind.computers => _buildComputersBody(),
      },
    );
  }

  Widget _buildDiveBody() {
    final sceneData = ref.watch(dive3dSceneDataProvider(widget.diveId)).value;
    if (sceneData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    _initZ(sceneData);
    final scene = ref
        .watch(
          dive3dGeometryProvider((
            diveId: widget.diveId,
            colorMetric: _colorMetric,
            zMetric: _zMetric,
          )),
        )
        .value;
    if (scene == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final zAxis = ref.watch(
      dive3dZAxisProvider((diveId: widget.diveId, zMetric: _zMetric)),
    );
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final l10n = context.l10n;
    final axes = buildDiveAxes(
      bounds: scene.bounds,
      depthTicks: depthAxisTicks(
        maxDepthMeters: sceneData.maxDepthMeters,
        stepMeters: settings.depthUnit == DepthUnit.feet ? 7.62 : 10.0,
        toDisplay: units.convertDepth,
      ),
      timeTicks: timeAxisTicks(sceneData.durationSeconds),
      zAxis: zAxis?.spec,
      depthTitle: l10n.dive3d_axis_depth(units.depthSymbol),
      timeTitle: l10n.dive3d_axis_time,
      zTitle: zAxis == null ? null : _zTitle(zAxis),
    );
    final scrubPath = scene.scrubPath!;
    final lookups = _lookupsFor(sceneData);
    return _sceneScaffold(
      scene: scene,
      readout: SceneReadoutPanel(
        lookups: lookups,
        position: _position,
        emphasize: _zMetric,
      ),
      controls: _buildDiveControls(sceneData),
      onMarkerTap: (marker) => _showMarkerSheet(context, lookups, marker),
      chromeMode: SceneChromeMode.framed,
      picker: PathHoverPicker(scrubPath),
      axisFrame: axes.frame,
      axisLabels: axes.labels,
      chromeStyle: diveChromeStyle(context),
      showPosePresets: true,
      tooltip: ValueListenableBuilder<ScenePick?>(
        valueListenable: _hoverPick,
        builder: (context, pick, _) {
          final payload = pick?.payload;
          if (pick == null || payload is! PathPick) {
            return const SizedBox.shrink();
          }
          final t =
              scrubPath.normalizedTimes[payload.index] *
              sceneData.durationSeconds;
          return CustomSingleChildLayout(
            delegate: TissueTooltipLayoutDelegate(pick.screenPos),
            child: DiveHoverTooltip(
              lookups: lookups,
              timestampSeconds: t,
              emphasize: _zMetric,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTissueBody() {
    final surface = ref.watch(tissueSurfaceProvider(widget.diveId)).value;
    final statuses = ref.watch(tissueDecoStatusesProvider(widget.diveId)).value;
    if (surface == null || statuses == null || statuses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final runtime = ref
        .watch(tissueRuntimeSecondsProvider(widget.diveId))
        .value;
    final colorFn = colorFnForScheme(ref.watch(tissueColorSchemeProvider));
    final frame = AxisFrame.build(
      surface.scene.bounds,
      referenceY: SubsurfaceTissueBuilder.referenceHeight,
      // surface != null guarantees a non-empty grid (tissueSurfaceProvider
      // returns null on empty compartments), so compartments is always > 0.
      compartments: surface.grid.compartments,
    );
    final labels = buildTissueAxisLabels(
      bounds: surface.scene.bounds,
      grid: surface.grid,
      referenceY: SubsurfaceTissueBuilder.referenceHeight,
      timeTitle: context.l10n.dive3d_tissue_axisTime,
      saturationTitle: context.l10n.dive3d_tissue_axisSaturation,
      compartmentTitle: context.l10n.dive3d_tissue_axisCompartment,
      runtimeSeconds: runtime,
    );
    return _sceneScaffold(
      scene: surface.scene,
      readout: TissueReadoutPanel(statuses: statuses, position: _position),
      controls: const SizedBox.shrink(),
      onMarkerTap: null,
      cornerOverlay: TissueLegend(colorFn: colorFn),
      chromeMode: SceneChromeMode.tissue,
      picker: GridHoverPicker(surface.grid),
      surfaceGrid: surface.grid,
      axisFrame: frame,
      axisLabels: labels,
      tooltip: ValueListenableBuilder<ScenePick?>(
        valueListenable: _hoverPick,
        builder: (context, pick, _) {
          final payload = pick?.payload;
          if (pick == null || payload is! TissuePick) {
            return const SizedBox.shrink();
          }
          return CustomSingleChildLayout(
            delegate: TissueTooltipLayoutDelegate(pick.screenPos),
            child: TissueHoverTooltip(
              pick: payload,
              grid: surface.grid,
              runtimeSeconds: runtime,
              colorFn: colorFn,
            ),
          );
        },
      ),
    );
  }

  /// Theme-resolved colors for the tissue chrome. Axis colors avoid red so the
  /// red M-value plane stays unambiguous; grid/wireframe/marker follow the
  /// theme so they read in light and dark.
  TissueChromeStyle _chromeStyle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TissueChromeStyle(
      axisX: const Color(0xFFFFB300), // time (amber)
      axisY: const Color(0xFF66BB6A), // saturation % (green)
      axisZ: const Color(0xFF42A5F5), // compartment (blue)
      grid: scheme.outline.withValues(alpha: 0.18),
      wireframe: scheme.onSurface.withValues(alpha: 0.16),
      marker: scheme.onSurface,
      markerOutline: scheme.surface,
      label: scheme.onSurface,
    );
  }

  Widget _buildComputersBody() {
    return CompareProfile3dView(
      profiles: ref.watch(computerComparisonProfilesProvider(widget.diveId)),
      initialLayout: CompareLayout.overlay,
      leading: _sceneSwitcher(),
    );
  }

  Widget _sceneScaffold({
    required Scene3d scene,
    required Widget readout,
    required Widget controls,
    required void Function(SceneMarker)? onMarkerTap,
    Widget? cornerOverlay,
    TissueSurfaceGrid? surfaceGrid,
    AxisFrame? axisFrame,
    AxisLabelSet? axisLabels,
    Widget? tooltip,
    SceneChromeMode chromeMode = SceneChromeMode.none,
    HoverPicker? picker,
    TissueChromeStyle? chromeStyle,
    bool showPosePresets = false,
  }) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              // Inset below the control row so the scene's top edge and the
              // depth title never hide under the chips.
              Positioned.fill(
                top: 52,
                child: Dive3dInteractiveViewport(
                  scene: scene,
                  scrubPosition: _position,
                  visibleOverlays: _overlays,
                  onMarkerTap: onMarkerTap,
                  surfaceGrid: surfaceGrid,
                  axisFrame: axisFrame,
                  axisLabels: axisLabels,
                  chromeStyle:
                      chromeStyle ??
                      (axisFrame == null ? null : _chromeStyle(context)),
                  showPosePresets: showPosePresets,
                  hoverPick: chromeMode == SceneChromeMode.none
                      ? null
                      : _hoverPick,
                  chromeMode: chromeMode,
                  picker: picker,
                ),
              ),
              if (tooltip != null)
                Positioned.fill(child: IgnorePointer(child: tooltip)),
              if (cornerOverlay != null)
                Positioned(top: 56, left: 8, child: cornerOverlay),
              Positioned(left: 12, right: 12, bottom: 12, child: readout),
              Positioned(top: 8, left: 8, right: 8, child: controls),
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
  }

  /// Dive/computers scene toggle. The tissue scene is not offered here: it
  /// has its own entry point on the tissue loading card of the dive detail
  /// page. With tissue gone, the switcher only has a job on multi-source
  /// dives, so it disappears entirely for single-source ones.
  Widget _sceneSwitcher() {
    final multiSource =
        ref.watch(isMultiDataSourceDiveProvider(widget.diveId)).value ?? false;
    if (!multiSource) return const SizedBox.shrink();
    return SegmentedButton<SceneKind>(
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        ButtonSegment(
          value: SceneKind.dive,
          label: Text(context.l10n.dive3d_scene_dive),
        ),
        ButtonSegment(
          value: SceneKind.computers,
          label: Text(context.l10n.dive3d_scene_computers),
        ),
      ],
      selected: {_sceneKind},
      onSelectionChanged: (s) => setState(() => _sceneKind = s.first),
      showSelectedIcon: false,
    );
  }

  Widget _buildDiveControls(Dive3dSceneData sceneData) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _sceneSwitcher(),
        PopupMenuButton<String>(
          key: const ValueKey('dive3dZAxisMenu'),
          tooltip: context.l10n.dive3d_zAxis,
          onSelected: (v) =>
              _selectZ(v == 'none' ? null : SceneMetric.values.byName(v)),
          itemBuilder: (context) => [
            CheckedPopupMenuItem(
              value: 'none',
              checked: _zMetric == null,
              child: Text(context.l10n.dive3d_zAxis_none),
            ),
            for (final metric in sceneData.zAxisMetrics)
              CheckedPopupMenuItem(
                value: metric.name,
                checked: _zMetric == metric,
                child: Text(_metricLabel(metric)),
              ),
          ],
          child: Chip(
            avatar: const Icon(Icons.swap_vert, size: 16),
            label: Text(
              '${context.l10n.dive3d_zAxis}: '
              '${_zMetric == null ? context.l10n.dive3d_zAxis_none : _metricLabel(_zMetric!)}',
            ),
          ),
        ),
        for (final metric in sceneData.availableMetrics)
          ChoiceChip(
            label: Text(_metricLabel(metric)),
            selected: _colorMetric == metric,
            onSelected: (_) => setState(() {
              _colorMetric = metric;
              _colorFollowsZ = false;
            }),
          ),
        PopupMenuButton<SceneOverlay>(
          icon: const Icon(Icons.layers),
          tooltip: context.l10n.dive3d_overlays,
          itemBuilder: (context) => [
            // The paths/contours/water/walls/features overlays belong to
            // the spatial/site seascape scenes; they have no meaning in
            // this analytical view.
            for (final overlay in SceneOverlay.values)
              if (!const {
                SceneOverlay.paths,
                SceneOverlay.contours,
                SceneOverlay.water,
                SceneOverlay.steepWalls,
                SceneOverlay.features,
              }.contains(overlay))
                CheckedPopupMenuItem(
                  value: overlay,
                  checked: _overlays.contains(overlay),
                  child: Text(switch (overlay) {
                    SceneOverlay.strata => context.l10n.dive3d_overlay_strata,
                    SceneOverlay.ceiling => context.l10n.dive3d_overlay_ceiling,
                    SceneOverlay.curtain => context.l10n.dive3d_overlay_curtain,
                    SceneOverlay.markers => context.l10n.dive3d_overlay_markers,
                    SceneOverlay.shadows => context.l10n.dive3d_overlay_shadows,
                    SceneOverlay.paths =>
                      context.l10n.dive3d_seascape_overlay_paths,
                    SceneOverlay.contours =>
                      context.l10n.dive3d_seascape_overlay_contours,
                    SceneOverlay.water => context.l10n.dive3d_overlay_water,
                    SceneOverlay.steepWalls =>
                      context.l10n.dive3d_seascape_overlay_walls,
                    SceneOverlay.features =>
                      context.l10n.siteFeature_sectionTitle,
                  }),
                ),
          ],
          onSelected: (overlay) => setState(() {
            _overlays = _overlays.contains(overlay)
                ? ({..._overlays}..remove(overlay))
                : {..._overlays, overlay};
          }),
        ),
      ],
    );
  }

  String _metricLabel(SceneMetric metric) {
    return switch (metric) {
      SceneMetric.depth => context.l10n.dive3d_metric_depth,
      SceneMetric.temperature => context.l10n.dive3d_metric_temperature,
      SceneMetric.ascentRate => context.l10n.dive3d_metric_ascentRate,
      SceneMetric.ppO2 => context.l10n.dive3d_metric_ppO2,
      SceneMetric.cns => context.l10n.dive3d_metric_cns,
      SceneMetric.heartRate => context.l10n.dive3d_metric_heartRate,
      SceneMetric.tankPressure => context.l10n.dive3d_metric_tankPressure,
      SceneMetric.tts => context.l10n.dive3d_metric_tts,
    };
  }

  void _showMarkerSheet(
    BuildContext context,
    DiveReadoutLookups lookups,
    SceneMarker marker,
  ) {
    final rows = diveReadoutRows(
      lookups: lookups,
      timestampSeconds: marker.timestampSeconds.toDouble(),
      units: UnitFormatter(ref.read(settingsProvider)),
      l10n: context.l10n,
      emphasize: _zMetric,
    );
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              marker.label.isEmpty ? marker.kind.name : marker.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(row.label)),
                    Text(
                      row.value,
                      style: TextStyle(
                        fontWeight: row.emphasized
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
