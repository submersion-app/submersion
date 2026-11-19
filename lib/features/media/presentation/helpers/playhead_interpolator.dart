/// Smooths a video's playhead between the player's position reports.
///
/// The player reports where it is only every 100 ms or so while playing, so
/// a bar drawn straight from those reports moves in steps (issue #4732).
/// This carries the playhead on from the latest report at the playback
/// speed, one frame at a time, so the bar glides.
///
/// The clock is whatever drives the frames (a ticker's elapsed time): each
/// [advance] passes the time of the frame being drawn. A report is timed
/// from the first frame after it, which keeps one clock throughout.
class PlayheadInterpolator {
  /// How far the playhead may run past the latest report. Well beyond the
  /// gap between reports, yet short enough that a player stalled without
  /// saying so (buffering, say) leaves the bar barely ahead of the video.
  static const maxLead = Duration(milliseconds: 500);

  Duration _reported = Duration.zero;
  Duration _shown = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 0;

  /// Whether the video moves on between reports.
  bool _advancing = false;

  /// The frame time of the latest report; null until the frame after it.
  Duration? _reportedAt;

  /// Whether the playhead can move on from the latest report, until the
  /// lead cap or the clip's end stops it.
  bool _canMove = false;

  /// Where a seek sent to the player will land, until its report arrives.
  Duration? _seekTarget;

  /// Where to draw the playhead.
  Duration get shown => _shown;

  /// Tells the playhead a seek to [target] was sent to the player, so the
  /// report of its landing is followed even when it lands just behind the
  /// playhead, where a late poll would be held. Null once the seeks are
  /// over: one that failed, or moved nothing, sends no report to match.
  void expectSeek(Duration? target) => _seekTarget = target;

  /// Takes a report from the player: it is at [position] in a clip of
  /// [duration], moving on at [speed] while [advancing]. Returns whether
  /// the playhead can move on from here, and so needs frames: not while
  /// paused, nor at rest when this report moves nothing on.
  ///
  /// Paused or buffering, the player's position is its last poll: neither
  /// pause() nor a buffering flag refreshes it. The playhead then stays
  /// where it was drawn, the closer guess at the frame on screen, until a
  /// report moves it.
  bool report({
    required Duration position,
    required bool advancing,
    required double speed,
    required Duration duration,
  }) {
    final wentBack = position < _reported;
    final landed = _seekTarget != null && position == _clamp(_seekTarget!);
    if (landed) _seekTarget = null;
    final wasAdvancing = _advancing;
    final moved = position != _reported;
    final sameMotion = !moved && speed == _speed;
    _reported = position;
    _duration = duration;
    _speed = speed;
    _advancing = advancing && speed > 0;
    // The player also notifies for what does not move the playhead (its
    // buffered ranges, a caption). Timing such a report afresh would restart
    // the glide from a position already passed and stall the bar.
    if (!(_advancing && wasAdvancing && sameMotion)) {
      _reportedAt = null;
      _canMove = _advancing;
    }
    // Gone back, the player was sought back or looped; landed, a seek sent
    // from the bar arrived: the playhead follows either at once, as it does
    // a paused report that moves it. Otherwise a report just behind the
    // playhead is one taken a moment before this frame, or a pause on the
    // last poll: holding keeps the bar from twitching backwards.
    if (wentBack || landed || position > _shown || (!_advancing && moved)) {
      _shown = position;
    }
    // Clamped again in case the report brought a shorter clip.
    _shown = _clamp(_shown);
    return _canMove;
  }

  /// Moves the playhead on to the frame drawn at [now]. Returns whether it
  /// can move further without another report, so the caller knows whether
  /// to keep asking for frames.
  bool advance(Duration now) {
    if (!_advancing) return false;
    final reportedAt = _reportedAt ??= now;
    final elapsed = now - reportedAt;
    final lead = elapsed * _speed;
    final capped = lead < maxLead ? lead : maxLead;
    final estimate = _clamp(_reported + capped);
    if (estimate > _shown) _shown = estimate;
    return _canMove = lead < maxLead && _shown < _duration;
  }

  Duration _clamp(Duration position) {
    if (position < Duration.zero) return Duration.zero;
    return position > _duration ? _duration : position;
  }
}
