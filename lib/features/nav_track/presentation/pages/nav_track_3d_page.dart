import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/domain/geometry/dive_axes.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/presentation/dive_chrome.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/hover_picker.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/time_scrub_bar.dart';
import 'package:submersion/features/nav_track/domain/track_3d/nav_track_3d_scene_data.dart';
import 'package:submersion/features/nav_track/domain/track_3d/track_scene_metric.dart';
import 'package:submersion/features/nav_track/domain/track_3d/track_z_axis_input.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_3d_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/track_readout_panel.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Fullscreen interactive 3D scene for one underwater track. Built on top
/// of the same CustomPaint renderer as [Dive3dPage]: depth runs up the
/// left edge, elapsed time along the floor, and the path color follows
/// whichever metric the diver picks. Any of those metrics (depth included,
/// although depth already drives the vertical axis) can be put on the
/// optional Z axis, the same way [Dive3dPage] offers one. No markers and no
/// tissue chrome: a track has neither.
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
  TrackSceneMetric? _zMetric;
  bool _zInitialized = false;
  // Color follows the Z metric until the diver picks a color chip,
  // mirroring Dive3dPage's own _colorFollowsZ.
  bool _colorFollowsZ = true;

  // One set of readout lookups per scene data: both the scrub panel (frame
  // rate) and a future hover tooltip would read through the same lookup,
  // mirroring DiveReadoutLookups' own reason for caching it.
  TrackReadoutLookups? _readoutLookups;

  // availableMetrics and zAxisMetrics each rescan the full-resolution
  // series, and every setState (play, a chip, the Z menu) rebuilds the
  // controls that read them, so they are held once per scene data like the
  // lookups above.
  NavTrack3dSceneData? _metricsData;
  Set<TrackSceneMetric> _availableMetrics = const {};
  Set<TrackSceneMetric> _zAxisMetrics = const {};

  void _cacheMetrics(NavTrack3dSceneData data) {
    if (identical(_metricsData, data)) return;
    _metricsData = data;
    _availableMetrics = data.availableMetrics;
    _zAxisMetrics = data.zAxisMetrics;
  }

  void _initZ() {
    if (_zInitialized) return;
    _zInitialized = true;
    final z = _zAxisMetrics.contains(TrackSceneMetric.temperature)
        ? TrackSceneMetric.temperature
        : null;
    _zMetric = z;
    if (_colorFollowsZ) _colorMetric = z ?? TrackSceneMetric.depth;
  }

  void _selectZ(TrackSceneMetric? z) {
    setState(() {
      _zMetric = z;
      if (_colorFollowsZ) _colorMetric = z ?? TrackSceneMetric.depth;
    });
  }

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
    final sceneDataAsync = ref.watch(
      navTrack3dSceneDataProvider(widget.trackId),
    );
    // A reload (navTrackByIdProvider refreshing for a write to this route)
    // keeps the current scene on screen, as Dive3dPage's `.value` read
    // does: a spinner would remount the viewport and lose the orbit.
    return sceneDataAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          Center(child: Text(context.l10n.navTrack_common_trackLoadError)),
      data: (sceneData) {
        if (sceneData == null) {
          return Center(child: Text(context.l10n.navTrack3d_noProfile));
        }
        return _buildScene(sceneData);
      },
    );
  }

  Widget _buildScene(NavTrack3dSceneData sceneData) {
    _cacheMetrics(sceneData);
    _initZ();
    if (!_availableMetrics.contains(_colorMetric)) {
      _colorMetric = TrackSceneMetric.depth;
    }
    final sceneAsync = ref.watch(
      navTrack3dGeometryProvider((
        trackId: widget.trackId,
        colorMetric: _colorMetric,
        zMetric: _zMetric,
      )),
    );
    return sceneAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          Center(child: Text(context.l10n.navTrack_common_trackLoadError)),
      data: (scene) {
        if (scene == null) {
          return Center(child: Text(context.l10n.navTrack3d_noProfile));
        }
        return _buildViewport(sceneData, scene);
      },
    );
  }

  Widget _buildViewport(NavTrack3dSceneData sceneData, Scene3d scene) {
    final zAxis = ref.watch(
      navTrack3dZAxisProvider((trackId: widget.trackId, zMetric: _zMetric)),
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
                  emphasize: _zMetric,
                ),
              ),
              Positioned(top: 8, left: 8, right: 8, child: _buildControls()),
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

  Widget _buildControls() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        PopupMenuButton<String>(
          key: const ValueKey('navTrack3dZAxisMenu'),
          tooltip: context.l10n.dive3d_zAxis,
          onSelected: (v) =>
              _selectZ(v == 'none' ? null : TrackSceneMetric.values.byName(v)),
          itemBuilder: (context) => [
            CheckedPopupMenuItem(
              value: 'none',
              checked: _zMetric == null,
              child: Text(context.l10n.dive3d_zAxis_none),
            ),
            for (final metric in _zAxisMetrics)
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
        for (final metric in _availableMetrics)
          ChoiceChip(
            label: Text(_metricLabel(metric)),
            selected: _colorMetric == metric,
            onSelected: (_) => setState(() {
              _colorMetric = metric;
              _colorFollowsZ = false;
            }),
          ),
      ],
    );
  }

  String _zTitle(TrackZAxisInput z) {
    final metric = _zMetric;
    if (metric == null) return z.spec.symbol;
    final name = _metricLabel(metric);
    return z.spec.symbol.isEmpty ? name : '$name (${z.spec.symbol})';
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
