import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/features/media/presentation/helpers/playhead_interpolator.dart';

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
  var _playhead = PlayheadInterpolator();

  /// Asks for frames while the playhead can glide on, and no longer.
  late final Ticker _ticker = createTicker(_onTick);

  @override
  void initState() {
    super.initState();
    widget.playback.addListener(_onUpdate);
    _report();
  }

  @override
  void didUpdateWidget(VideoPlayheadBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playback != widget.playback) {
      oldWidget.playback.removeListener(_onUpdate);
      widget.playback.addListener(_onUpdate);
      _playhead = PlayheadInterpolator();
      _report();
    }
  }

  @override
  void dispose() {
    widget.playback.removeListener(_onUpdate);
    _ticker.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(_report);
  }

  /// Hands the player's latest position to the playhead, and starts or stops
  /// the frames that carry it on.
  void _report() {
    final value = widget.playback.value;
    final moving = _playhead.report(
      position: value.position,
      advancing: value.isPlaying && !value.isBuffering,
      speed: value.playbackSpeed,
      duration: value.duration,
    );
    if (!moving) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      unawaited(_ticker.start());
    }
  }

  void _onTick(Duration elapsed) {
    final before = _playhead.shown;
    final moving = _playhead.advance(elapsed);
    if (_playhead.shown != before) setState(() {});
    // A stalled player, or the end of the clip: rest until the next report.
    if (!moving) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, widget.playback.value, _playhead.shown);
}
