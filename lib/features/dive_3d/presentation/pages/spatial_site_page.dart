import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_3d/application/spatial_providers.dart';
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
        error: (_, _) =>
            Center(child: Text(context.l10n.dive3d_spatial_noPath)),
        data: (scene) {
          if (scene == null || scene.layers.isEmpty) {
            return Center(child: Text(context.l10n.dive3d_spatial_noPath));
          }
          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Dive3dInteractiveViewport(
                        scene: scene,
                        scrubPosition: _position,
                        visibleOverlays: const {SceneOverlay.markers},
                      ),
                    ),
                    Positioned(top: 8, left: 8, right: 8, child: _captions()),
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

  Widget _captions() {
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
    return Wrap(
      children: [
        // Both captions are always-true honesty labels: the swim path is
        // always an estimate (dead reckoning or straight-line fallback) and
        // the seafloor is always synthesized.
        chip(context.l10n.dive3d_spatial_estimatedPath),
        chip(context.l10n.dive3d_spatial_synthesizedSeafloor),
      ],
    );
  }
}
