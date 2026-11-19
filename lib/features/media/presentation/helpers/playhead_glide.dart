import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/features/media/presentation/helpers/playhead_interpolator.dart';

/// Glides a video's playhead from frame to frame: hands the player's
/// reports to a [PlayheadInterpolator], and asks for frames from a ticker
/// while the playhead can move on, and no longer.
///
/// The progress bar (issue #4732) and the labels that follow a fish (issue
/// #4759) both draw against [shown].
class PlayheadGlide {
  PlayheadGlide(TickerProvider vsync) {
    _ticker = vsync.createTicker(_onTick);
  }

  late final Ticker _ticker;
  var _playhead = PlayheadInterpolator();

  final _shown = ValueNotifier<Duration>(Duration.zero);

  /// Where to draw the playhead. It changes every frame while the video
  /// plays, so only what moves with it should listen.
  ValueListenable<Duration> get shown => _shown;

  /// Takes the player's latest [value], and starts or stops the frames
  /// that carry the playhead on from it.
  void report(VideoPlayerValue value) {
    final moving = _playhead.report(
      position: value.position,
      advancing: value.isPlaying && !value.isBuffering,
      speed: value.playbackSpeed,
      duration: value.duration,
    );
    _shown.value = _playhead.shown;
    if (!moving) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      unawaited(_ticker.start());
    }
  }

  /// See [PlayheadInterpolator.expectSeek].
  void expectSeek(Duration? target) => _playhead.expectSeek(target);

  /// Forgets the video so far, for another one. [report] it next.
  void restart() => _playhead = PlayheadInterpolator();

  void dispose() {
    _ticker.dispose();
    _shown.dispose();
  }

  void _onTick(Duration elapsed) {
    final moving = _playhead.advance(elapsed);
    _shown.value = _playhead.shown;
    // A stalled player, or the end of the clip: rest until the next report.
    if (!moving) _ticker.stop();
  }
}
