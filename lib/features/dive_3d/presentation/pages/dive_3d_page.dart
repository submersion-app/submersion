import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_3d/application/providers.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/preview_painter.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/scene_readout_panel.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/scene_viewport.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/time_scrub_bar.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Fullscreen interactive 3D scene for one dive. Pushed via a plain
/// Navigator route from the dive detail page (same pattern as the
/// fullscreen profile page). Owns the scrub ValueNotifier and the
/// playback AnimationController; the viewport and readout observe them
/// without provider round-trips.
class Dive3dPage extends ConsumerStatefulWidget {
  final String diveId;

  const Dive3dPage({super.key, required this.diveId});

  @override
  ConsumerState<Dive3dPage> createState() => _Dive3dPageState();
}

class _Dive3dPageState extends ConsumerState<Dive3dPage>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _position = ValueNotifier(0);
  late final AnimationController _player;
  SceneMetric _metric = SceneMetric.depth;
  Set<SceneOverlay> _overlays = SceneOverlay.values.toSet();
  bool _glFailed = false;

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
    final sceneData = ref.watch(dive3dSceneDataProvider(widget.diveId)).value;
    final geometry = ref
        .watch(dive3dGeometryProvider((diveId: widget.diveId, metric: _metric)))
        .value;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.dive3d_previewTitle)),
      body: sceneData == null || geometry == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _glFailed
                            ? Column(
                                children: [
                                  Expanded(
                                    child: CustomPaint(
                                      painter: Dive3dPreviewPainter(
                                        geometry: geometry,
                                      ),
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      context.l10n.dive3d_unavailable,
                                    ),
                                  ),
                                ],
                              )
                            : SceneViewport(
                                geometry: geometry,
                                scrubPosition: _position,
                                visibleOverlays: _overlays,
                                onMarkerTap: (marker) =>
                                    _showMarkerSheet(context, marker),
                                onInitFailure: () {
                                  if (mounted) {
                                    setState(() => _glFailed = true);
                                  }
                                },
                              ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: SceneReadoutPanel(
                          data: sceneData,
                          position: _position,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        right: 8,
                        child: _buildControls(sceneData),
                      ),
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
            ),
    );
  }

  Widget _buildControls(Dive3dSceneData sceneData) {
    return Wrap(
      spacing: 6,
      children: [
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
