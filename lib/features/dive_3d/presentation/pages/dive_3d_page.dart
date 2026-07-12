import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_3d/application/compare_providers.dart';
import 'package:submersion/features/dive_3d/application/providers.dart';
import 'package:submersion/features/dive_3d/application/tissue_providers.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/compare_profile_3d_view.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/scene_readout_panel.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/time_scrub_bar.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/tissue_legend.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/tissue_readout_panel.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Which scene the 3D page is showing.
enum SceneKind { dive, tissue, computers }

/// Fullscreen interactive 3D scene for one dive. Pushed via a plain
/// Navigator route from the dive detail page. Owns the scrub ValueNotifier
/// and the playback AnimationController; the viewport and readout observe
/// them without provider round-trips. Switches between the single-dive
/// scene and the repetitive-chain tissue landscape.
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
  late final AnimationController _player;
  late SceneKind _sceneKind;
  SceneMetric _metric = SceneMetric.depth;
  Set<SceneOverlay> _overlays = SceneOverlay.values.toSet();

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
    final scene = ref
        .watch(dive3dGeometryProvider((diveId: widget.diveId, metric: _metric)))
        .value;
    if (sceneData == null || scene == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _sceneScaffold(
      scene: scene,
      readout: SceneReadoutPanel(data: sceneData, position: _position),
      controls: _buildDiveControls(sceneData),
      onMarkerTap: (marker) => _showMarkerSheet(context, marker),
    );
  }

  Widget _buildTissueBody() {
    final scene = ref.watch(tissue3dSceneProvider(widget.diveId)).value;
    final statuses = ref.watch(tissueDecoStatusesProvider(widget.diveId)).value;
    if (scene == null || statuses == null || statuses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final colorFn = colorFnForScheme(ref.watch(tissueColorSchemeProvider));
    return _sceneScaffold(
      scene: scene,
      readout: TissueReadoutPanel(statuses: statuses, position: _position),
      controls: _buildTissueControls(),
      onMarkerTap: null,
      cornerOverlay: TissueLegend(colorFn: colorFn),
    );
  }

  Widget _buildComputersBody() {
    return CompareProfile3dView(
      profiles: ref.watch(computerComparisonProfilesProvider(widget.diveId)),
      title: context.l10n.dive3d_compare_computers_title,
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
  }) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Dive3dInteractiveViewport(
                  scene: scene,
                  scrubPosition: _position,
                  visibleOverlays: _overlays,
                  onMarkerTap: onMarkerTap,
                ),
              ),
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
          ),
        ),
      ],
    );
  }

  Widget _sceneSwitcher() {
    final multiSource =
        ref.watch(isMultiDataSourceDiveProvider(widget.diveId)).value ?? false;
    return SegmentedButton<SceneKind>(
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        ButtonSegment(
          value: SceneKind.dive,
          label: Text(context.l10n.dive3d_scene_dive),
        ),
        ButtonSegment(
          value: SceneKind.tissue,
          label: Text(context.l10n.dive3d_scene_tissue),
        ),
        if (multiSource)
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
        for (final metric in sceneData.availableMetrics)
          ChoiceChip(
            label: Text(_metricLabel(metric)),
            selected: _metric == metric,
            onSelected: (_) => setState(() => _metric = metric),
          ),
        PopupMenuButton<SceneOverlay>(
          icon: const Icon(Icons.layers),
          tooltip: context.l10n.dive3d_overlays,
          itemBuilder: (context) => [
            for (final overlay in SceneOverlay.values)
              CheckedPopupMenuItem(
                value: overlay,
                checked: _overlays.contains(overlay),
                child: Text(switch (overlay) {
                  SceneOverlay.strata => context.l10n.dive3d_overlay_strata,
                  SceneOverlay.ceiling => context.l10n.dive3d_overlay_ceiling,
                  SceneOverlay.curtain => context.l10n.dive3d_overlay_curtain,
                  SceneOverlay.markers => context.l10n.dive3d_overlay_markers,
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

  Widget _buildTissueControls() {
    // The color scale follows the diver's tissue heat-map scheme setting,
    // so the 3D and 2D graphs always match. Only the scene switcher here.
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [_sceneSwitcher()],
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
    };
  }

  void _showMarkerSheet(BuildContext context, SceneMarker marker) {
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
            Text('${marker.timestampSeconds ~/ 60} min'),
          ],
        ),
      ),
    );
  }
}
