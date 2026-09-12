import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/time_scrub_bar.dart';
import 'package:submersion/features/nav_track/application/nav_track_scene_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The route's own 3D view, with no dive required (spec
/// 2026-09-10-underwater-nav-track-design.md, "Route seascape").
///
/// The design calls for extracting `SpatialSitePage`'s body (viewport, scrub
/// bar, chrome, captions) into a widget shared between the dive seascape and
/// this page. That file was touched very recently by other work on this same
/// branch (the provenance caption chip) and is not otherwise owned by this
/// change, so extracting it here risked destabilizing code that was just
/// stabilized. This page instead reuses the lower-level pieces
/// (`Dive3dInteractiveViewport`, `TimeScrubBar`) directly, deliberately
/// simpler than `SpatialSitePage`: no hover tooltip, no bathymetry pick, no
/// depth legend, no appearance sheet -- just the viewport and a scrub bar
/// over `navTrackSceneProvider`. Revisit once the extraction lands as its
/// own change.
class NavTrackSeascapePage extends ConsumerStatefulWidget {
  const NavTrackSeascapePage({super.key, required this.trackId});

  final String trackId;

  @override
  ConsumerState<NavTrackSeascapePage> createState() =>
      _NavTrackSeascapePageState();
}

class _NavTrackSeascapePageState extends ConsumerState<NavTrackSeascapePage>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _position = ValueNotifier(0);
  late final AnimationController _player;

  @override
  void initState() {
    super.initState();
    _player = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
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
    final sceneAsync = ref.watch(navTrackSceneProvider(widget.trackId));
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navTrack_seascape_title)),
      body: sceneAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.navTrack_seascape_noScene)),
        data: (result) {
          final scene = result?.scene;
          if (scene == null || scene.layers.isEmpty) {
            return Center(child: Text(l10n.navTrack_seascape_noScene));
          }
          return Column(
            children: [
              Expanded(
                child: Dive3dInteractiveViewport(
                  scene: scene,
                  scrubPosition: _position,
                  visibleOverlays: const {
                    SceneOverlay.markers,
                    SceneOverlay.water,
                  },
                  contourLabels: result!.contourLabels,
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
}
