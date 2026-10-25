import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/domain/geometry/dive_axes.dart';
import 'package:submersion/features/dive_3d/presentation/dive_chrome.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/hover_picker.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/time_scrub_bar.dart';
import 'package:submersion/features/nav_track/domain/track_3d/nav_track_3d_scene_data.dart';
import 'package:submersion/features/nav_track/domain/track_3d/track_scene_metric.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_3d_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/track_readout_panel.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Fullscreen interactive 3D scene for one underwater track. Built on top
/// of the same CustomPaint renderer as [Dive3dPage]: depth runs up the
/// left edge, elapsed time along the floor, and the path color follows
/// whichever metric the diver picks. No Z metric, no markers, no tissue --
/// a track has nothing to put on a third axis or event list.
class NavTrack3dPage extends ConsumerStatefulWidget {
  final String trackId;

  const NavTrack3dPage({super.key, required this.trackId});

  @override
  ConsumerState<NavTrack3dPage> createState() => _NavTrack3dPageState();
}

class _NavTrack3dPageState extends ConsumerState<NavTrack3dPage>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _position = ValueNotifier(0);
  late final AnimationController _player;
  TrackSceneMetric _colorMetric = TrackSceneMetric.depth;

  // One set of readout lookups per scene data: both the scrub panel (frame
  // rate) and a future hover tooltip would read through the same lookup,
  // mirroring DiveReadoutLookups' own reason for caching it.
  TrackReadoutLookups? _readoutLookups;

  TrackReadoutLookups _lookupsFor(NavTrack3dSceneData data) {
    final cached = _readoutLookups;
    if (cached != null && identical(cached.data, data)) return cached;
    return _readoutLookups = TrackReadoutLookups(data);
  }

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
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.navTrack3d_previewTitle)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final sceneData = ref
        .watch(navTrack3dSceneDataProvider(widget.trackId))
        .value;
    if (sceneData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!sceneData.availableMetrics.contains(_colorMetric)) {
      _colorMetric = TrackSceneMetric.depth;
    }
    final scene = ref
        .watch(navTrack3dGeometryProvider((widget.trackId, _colorMetric)))
        .value;
    if (scene == null) {
      return const Center(child: CircularProgressIndicator());
    }
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
      depthTitle: l10n.dive3d_axis_depth(units.depthSymbol),
      timeTitle: l10n.dive3d_axis_time,
    );
    final scrubPath = scene.scrubPath!;
    final lookups = _lookupsFor(sceneData);
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                top: 52,
                child: Dive3dInteractiveViewport(
                  scene: scene,
                  scrubPosition: _position,
                  visibleOverlays: const {},
                  onMarkerTap: null,
                  axisFrame: axes.frame,
                  axisLabels: axes.labels,
                  chromeStyle: diveChromeStyle(context),
                  chromeMode: SceneChromeMode.framed,
                  picker: PathHoverPicker(scrubPath),
                  scrubCursor: ScrubCursorStyle.dot,
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: TrackReadoutPanel(
                  lookups: lookups,
                  position: _position,
                  emphasize: _colorMetric,
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
            onScrubStart: () {
              if (_player.isAnimating) setState(() => _player.stop());
            },
          ),
        ),
      ],
    );
  }

  Widget _buildControls(NavTrack3dSceneData sceneData) {
    return SegmentedButton<TrackSceneMetric>(
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        for (final metric in sceneData.availableMetrics)
          ButtonSegment(value: metric, label: Text(_metricLabel(metric))),
      ],
      selected: {_colorMetric},
      onSelectionChanged: (s) => setState(() => _colorMetric = s.first),
      showSelectedIcon: false,
    );
  }

  String _metricLabel(TrackSceneMetric metric) {
    return switch (metric) {
      TrackSceneMetric.depth => context.l10n.dive3d_metric_depth,
      TrackSceneMetric.temperature => context.l10n.dive3d_metric_temperature,
      TrackSceneMetric.speed => context.l10n.navTrack3d_metric_speed,
      TrackSceneMetric.batteryVoltage =>
        context.l10n.navTrack3d_metric_batteryVoltage,
    };
  }
}
