import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/features/media/presentation/helpers/playhead_glide.dart';

/// Builds what is drawn over a video against where it is now: [playback]'s
/// position carried on between the player's reports, one frame at a time
/// while it plays.
///
/// The player reports its position only every 100 ms or so, so anything
/// drawn straight from those reports moves in steps. The progress bar
/// glides this way (issue #4732); so do the labels that follow a fish
/// (issue #4759).
class VideoPlayheadBuilder extends StatefulWidget {
  const VideoPlayheadBuilder({
    super.key,
    required this.playback,
    required this.builder,
  });

  final ValueListenable<VideoPlayerValue> playback;

  /// Called with the player's latest value and where to draw the playhead.
  final Widget Function(
    BuildContext context,
    VideoPlayerValue value,
    Duration playhead,
  )
  builder;

  @override
  State<VideoPlayheadBuilder> createState() => _VideoPlayheadBuilderState();
}

class _VideoPlayheadBuilderState extends State<VideoPlayheadBuilder>
    with SingleTickerProviderStateMixin {
  late final _glide = PlayheadGlide(this);

  @override
  void initState() {
    super.initState();
    widget.playback.addListener(_onUpdate);
    _glide.report(widget.playback.value);
  }

  @override
  void didUpdateWidget(VideoPlayheadBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playback != widget.playback) {
      oldWidget.playback.removeListener(_onUpdate);
      widget.playback.addListener(_onUpdate);
      _glide
        ..restart()
        ..report(widget.playback.value);
    }
  }

  @override
  void dispose() {
    widget.playback.removeListener(_onUpdate);
    _glide.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (!mounted) return;
    _glide.report(widget.playback.value);
    // The value itself changed too (its size, playing or not).
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Duration>(
    valueListenable: _glide.shown,
    builder: (context, playhead, _) =>
        widget.builder(context, widget.playback.value, playhead),
  );
}
