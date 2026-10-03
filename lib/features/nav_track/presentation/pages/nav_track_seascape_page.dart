import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_playback_context.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/time_scrub_bar.dart';
import 'package:submersion/features/nav_track/application/nav_track_scene_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_terrain_pane.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The route's own 3D view, with no dive required (spec
/// 2026-09-10-underwater-nav-track-design.md, "Route seascape").
///
/// Routes to whichever the route actually has:
/// - a site (`NavTrack.siteId`) with renderable terrain -> `SiteTerrainPane` with a
///   [NavTrackPlaybackContext], the same shared base the dive seascape and
///   the site-only view use, which gives the route the site's markers,
///   features and LOD it otherwise has no way to show.
/// - no site, or one with no coordinates or bathymetry ->
///   [_NavTrackSeascapeStandalone], this page's original
///   implementation: just the viewport and a scrub bar over
///   `navTrackSceneProvider`'s anchor-point terrain, with no markers,
///   features or LOD -- there is no site record to hang those on. Not a
///   regression: this is the same limitation the route always had.
class NavTrackSeascapePage extends ConsumerWidget {
  const NavTrackSeascapePage({super.key, required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackAsync = ref.watch(navTrackByIdProvider(trackId));
    // Waits for the route to resolve rather than reading .valueOrNull before
    // routing: that would read as "no site" while still loading and start
    // the standalone implementation's own terrain fetch, only to discard it
    // a frame later once the route (with a site) resolves and this switches
    // to SiteTerrainPane instead (code review).
    if (!trackAsync.hasSettled) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.navTrack_seascape_trackTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final siteId = trackAsync.valueOrNull?.siteId;
    if (siteId == null) {
      return _NavTrackSeascapeStandalone(trackId: trackId);
    }
    // A site that cannot render terrain (no coordinates, or no bathymetry
    // reachable) would leave SiteTerrainPane showing only a message, with
    // no path or timeline at all; the standalone view still shows the
    // route's path there, over terrain centered on its own fix or a
    // synthesized seafloor.
    final siteSceneAsync = ref.watch(siteSeascapeProvider(siteId));
    if (!siteSceneAsync.hasSettled) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.navTrack_seascape_trackTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (siteSceneAsync.valueOrNull is! SiteSeascapeReady) {
      return _NavTrackSeascapeStandalone(trackId: trackId);
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.navTrack_seascape_trackTitle)),
      body: SiteTerrainPane(
        siteId: siteId,
        playbackContext: NavTrackPlaybackContext(trackId),
      ),
    );
  }
}

class _NavTrackSeascapeStandalone extends ConsumerStatefulWidget {
  const _NavTrackSeascapeStandalone({required this.trackId});

  final String trackId;

  @override
  ConsumerState<_NavTrackSeascapeStandalone> createState() =>
      _NavTrackSeascapeStandaloneState();
}

class _NavTrackSeascapeStandaloneState
    extends ConsumerState<_NavTrackSeascapeStandalone>
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
      appBar: AppBar(title: Text(l10n.navTrack_seascape_trackTitle)),
      body: sceneAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(l10n.navTrack_seascape_trackNoScene)),
        data: (result) {
          final scene = result?.scene;
          if (scene == null || scene.layers.isEmpty) {
            return Center(child: Text(l10n.navTrack_seascape_trackNoScene));
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
