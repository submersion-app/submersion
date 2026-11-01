import 'package:flutter/widgets.dart';

import 'package:submersion/features/dive_3d/presentation/scene_player.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/time_scrub_bar.dart';

/// [TimeScrubBar] wired to a [ScenePlayer]: the bar follows the player on its
/// own, so a play toggle or the timeline ending never rebuilds the page.
class ScenePlayerBar extends StatelessWidget {
  final ScenePlayer player;

  const ScenePlayerBar({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) => TimeScrubBar(
        position: player.position,
        playing: player.isPlaying,
        onPlayPause: player.togglePlay,
        onScrubStart: player.stop,
      ),
    );
  }
}
