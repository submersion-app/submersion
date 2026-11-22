import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/presentation/helpers/elapsed_time_format.dart';
import 'package:submersion/features/media/presentation/helpers/playhead_glide.dart';
import 'package:submersion/features/media/presentation/helpers/viewer_audio.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/video_tag_marks.dart';
import 'package:submersion/features/media/presentation/widgets/video_volume_control.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/species_id/presentation/widgets/video_analysed_stretches.dart';

/// Video playback controls: elapsed time, a scrub bar, and total time.
///
/// The bar seeks on a tap and scrubs on a horizontal drag (issue #4487). A
/// drag that starts on the bar wins the gesture arena against the enclosing
/// media pager, being the innermost horizontal recognizer, so swiping
/// anywhere else on the video still turns the page. Scrubbing pauses a
/// playing video and resumes it on release, as video_player's own scrubber
/// does.
///
/// The bar always runs left to right: a media timeline is not mirrored in
/// right-to-left languages.
///
/// While the video plays, the thumb glides from frame to frame rather than
/// stepping each time the player reports its position (issue #4732).
class VideoControlsBar extends StatefulWidget {
  final VideoPlayerController controller;

  /// The video, whose tagged moments are marked on the bar (issue #1745).
  final String mediaId;

  /// Whether a host that hides its controls on a timer should hold them up:
  /// true while a drag scrub is under way, the mouse rests on the bar, or the
  /// volume slider is in use (keyboard focus in it, or a drag on it), false
  /// once all are over. A tap or a screen-reader step is a seek that settles
  /// at once, so it reports false alone (unless one of those still holds),
  /// letting the host restart its clock.
  final ValueChanged<bool>? onHoldChanged;

  /// The viewer's sound: when set, a mute button and volume slider follow the
  /// total time (issue #4817). The slider shows on hover, keyboard focus or a
  /// drag, and [onHoldChanged] holds the controls up for each.
  final ViewerAudio? audio;

  /// The bar's touch area, for tests that tap or drag along it.
  @visibleForTesting
  static const trackKey = ValueKey('videoControlsBar.track');

  /// The thumb, for tests that check where the bar shows the playhead.
  @visibleForTesting
  static const thumbKey = ValueKey('videoControlsBar.thumb');

  /// How far a screen reader's increase and decrease actions move.
  static const accessibilityStep = Duration(seconds: 5);

  /// The bar's height, which is also its touch area's.
  static const double height = 40;

  const VideoControlsBar({
    super.key,
    required this.controller,
    required this.mediaId,
    this.onHoldChanged,
    this.audio,
  });

  @override
  State<VideoControlsBar> createState() => _VideoControlsBarState();
}

class _VideoControlsBarState extends State<VideoControlsBar>
    with SingleTickerProviderStateMixin {
  static final _log = LoggerService.forClass(VideoControlsBar);

  /// Carries the playhead on between the player's position reports. Where
  /// it draws the playhead changes every frame while the video plays, so
  /// only the track and thumb listen to it.
  late final _glide = PlayheadGlide(this);

  /// Where the finger is along the track while scrubbing, as a fraction of
  /// its width; null when not scrubbing. The thumb and elapsed time follow
  /// this rather than the player, so they never lag behind a pending seek.
  double? _scrubFraction;

  /// Whether the mouse rests on the bar, which holds the host's controls.
  bool _hovered = false;

  /// Whether the volume slider is in use (keyboard focus in it, or a drag
  /// that may have strayed off the bar), which holds them too: a hidden bar
  /// would take the slider from under the arrow keys or the pointer.
  bool _volumeHeld = false;

  /// Whether the video was playing when the current scrub began.
  bool _resumeAfterScrub = false;

  /// Bumped on each scrub start, so a release still finishing its seek does
  /// not clear a newer scrub's state.
  int _scrubId = 0;

  /// The latest target not yet sent to the player. Drag updates arrive far
  /// faster than a decoder seeks, so only the newest is kept.
  Duration? _pendingSeek;

  /// The running seek loop, if any; completes once no seek is pending.
  Future<void>? _seeking;

  /// Bumped when the controller is replaced, retiring any seek loop still
  /// running on the old one so it cannot hold up or clear the new one's.
  int _seekGeneration = 0;

  /// The newest seek requested, which the player reaches once [_seeking]
  /// completes.
  Duration _seekTarget = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onVideoUpdate);
    _reportPlayhead();
  }

  @override
  void didUpdateWidget(VideoControlsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onVideoUpdate);
      widget.controller.addListener(_onVideoUpdate);
      // A scrub in progress belonged to the old video: drop it rather than
      // seek or resume the new one with it. The host hears after this frame,
      // as it may rebuild in answer and this runs during build.
      final onHoldChanged = widget.onHoldChanged;
      if (_scrubFraction != null && onHoldChanged != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) onHoldChanged(_hovered || _volumeHeld);
        });
      }
      _scrubId++;
      _scrubFraction = null;
      _resumeAfterScrub = false;
      _pendingSeek = null;
      _seekGeneration++;
      _seeking = null;
      _glide.restart();
      _reportPlayhead();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onVideoUpdate);
    _glide.dispose();
    // Gone mid-scrub or under the mouse (Space can hide the overlay during
    // a drag): release the host's hold, or its controls never hide again.
    // After this frame, since the host may rebuild in answer.
    final onHoldChanged = widget.onHoldChanged;
    if ((_scrubFraction != null || _hovered || _volumeHeld) &&
        onHoldChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onHoldChanged(false));
    }
    super.dispose();
  }

  /// Tells the host whether to hold its controls: while [scrubbing], while
  /// the mouse rests on the bar, or while the volume slider is in use.
  void _reportHold({required bool scrubbing}) =>
      widget.onHoldChanged?.call(scrubbing || _hovered || _volumeHeld);

  void _onVolumeHold(bool held) {
    _volumeHeld = held;
    _reportHold(scrubbing: _scrubFraction != null);
  }

  void _onPointerOver(bool hovered) {
    _hovered = hovered;
    _reportHold(scrubbing: _scrubFraction != null);
  }

  void _onVideoUpdate() {
    if (mounted) {
      _reportPlayhead();
      setState(() {});
    }
  }

  /// Hands the player's latest position to the playhead.
  void _reportPlayhead() => _glide.report(widget.controller.value);

  String _formatDuration(Duration duration) =>
      formatElapsedMmSs(duration.inSeconds);

  /// Where the video is headed: the newest seek while one is under way,
  /// else where it is. Steps build on this, so quick steps add up.
  Duration get _heading =>
      _seeking != null ? _seekTarget : widget.controller.value.position;

  void _step(Duration delta) {
    unawaited(_seekTo(_stepped(_heading, delta)));
    // Rebuild so the slider announces where the video is now headed.
    setState(() {});
    _reportHold(scrubbing: false);
  }

  /// [position] moved by [delta], kept inside the clip.
  Duration _stepped(Duration position, Duration delta) {
    final duration = widget.controller.value.duration;
    final target = position + delta;
    if (target < Duration.zero) return Duration.zero;
    return target > duration ? duration : target;
  }

  double _fractionAt(double x, double width) =>
      width <= 0 ? 0.0 : (x / width).clamp(0.0, 1.0);

  /// How far through a clip of [duration] the bar shows [position].
  double _fractionOf(Duration position, Duration duration) =>
      duration.inMilliseconds > 0
      ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
      : 0.0;

  Duration _positionAt(double fraction) => Duration(
    milliseconds: (fraction * widget.controller.value.duration.inMilliseconds)
        .round(),
  );

  /// Seeks to [target], coalescing with any seek already in flight. The
  /// returned future completes once the player has reached the newest target.
  Future<void> _seekTo(Duration target) {
    _pendingSeek = target;
    _seekTarget = target;
    _glide.expectSeek(target);
    return _seeking ??= _drainSeeks(widget.controller, _seekGeneration);
  }

  /// Sends pending seeks to [controller] one at a time until none is left,
  /// or until a controller swap retires [generation].
  Future<void> _drainSeeks(
    VideoPlayerController controller,
    int generation,
  ) async {
    // Read now: after a controller swap the widget names another video.
    final mediaId = widget.mediaId;
    bool current() => generation == _seekGeneration;
    try {
      while (current() && _pendingSeek != null) {
        final target = _pendingSeek!;
        _pendingSeek = null;
        await controller.seekTo(target);
      }
    } catch (e, stackTrace) {
      if (current()) _pendingSeek = null;
      _log.error(
        'Failed to seek video $mediaId',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      if (current()) {
        _seeking = null;
        // Every seek has landed or failed: none is left for the playhead to
        // wait on.
        _glide.expectSeek(null);
      }
    }
  }

  void _onTapDown(TapDownDetails details, double width) {
    unawaited(
      _seekTo(_positionAt(_fractionAt(details.localPosition.dx, width))),
    );
    _reportHold(scrubbing: false);
  }

  void _onScrubStart(DragStartDetails details, double width) {
    final controller = widget.controller;
    if (!controller.value.isInitialized) return;
    _scrubId++;
    // A release still settling has not resumed yet: this scrub inherits it.
    final settling = _scrubFraction != null && _resumeAfterScrub;
    _resumeAfterScrub = settling || controller.value.isPlaying;
    if (controller.value.isPlaying) unawaited(controller.pause());
    _scrubTo(details.localPosition.dx, width);
    _reportHold(scrubbing: true);
  }

  void _onScrubUpdate(DragUpdateDetails details, double width) {
    if (_scrubFraction == null) return;
    _scrubTo(details.localPosition.dx, width);
  }

  void _scrubTo(double x, double width) {
    final fraction = _fractionAt(x, width);
    setState(() => _scrubFraction = fraction);
    unawaited(_seekTo(_positionAt(fraction)));
  }

  Future<void> _onScrubEnd() async {
    final fraction = _scrubFraction;
    if (fraction == null) return;
    final scrub = _scrubId;
    await _seekTo(_positionAt(fraction));
    // Superseded by a newer scrub, which took over the resume.
    if (!mounted || scrub != _scrubId) return;
    final resume = _resumeAfterScrub;
    _resumeAfterScrub = false;
    setState(() => _scrubFraction = null);
    final value = widget.controller.value;
    // Released at the very end: play() would restart the clip from zero.
    if (resume && value.position < value.duration) {
      unawaited(widget.controller.play());
    }
    _reportHold(scrubbing: false);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final duration = value.duration;
    final canSeek = value.isInitialized && duration > Duration.zero;
    final scrubFraction = _scrubFraction;
    final position = scrubFraction != null
        ? _positionAt(scrubFraction)
        : value.position;
    // What a screen reader hears: where the video is headed, so quick steps
    // announce their sum rather than the frame still on screen.
    final announced = scrubFraction != null ? position : _heading;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: MouseRegion(
        onEnter: (_) => _onPointerOver(true),
        onExit: (_) => _onPointerOver(false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Current time
              SizedBox(
                width: 48,
                child: Text(
                  _formatDuration(position),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Scrub bar: tap to jump, drag to scrub.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    // Analysed for marine life (#4825). Made once here, not
                    // on each tick of the playhead below: the same widget
                    // handed back is not built again.
                    final analysed = VideoAnalysedStretches(
                      mediaId: widget.mediaId,
                      width: width,
                    );
                    // A slider to assistive tech, stepping by a few seconds,
                    // since a screen reader cannot tap a point or drag.
                    return Semantics(
                      label: context.l10n.media_photoViewer_seekVideoLabel,
                      slider: true,
                      value: _formatDuration(announced),
                      increasedValue: canSeek
                          ? _formatDuration(
                              _stepped(
                                announced,
                                VideoControlsBar.accessibilityStep,
                              ),
                            )
                          : null,
                      decreasedValue: canSeek
                          ? _formatDuration(
                              _stepped(
                                announced,
                                -VideoControlsBar.accessibilityStep,
                              ),
                            )
                          : null,
                      onIncrease: canSeek
                          ? () => _step(VideoControlsBar.accessibilityStep)
                          : null,
                      onDecrease: canSeek
                          ? () => _step(-VideoControlsBar.accessibilityStep)
                          : null,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        // The slider above is the bar's whole semantic face.
                        // The detector's own tap and scroll actions would fake
                        // a gesture at the bar's centre and jump there.
                        excludeFromSemantics: true,
                        onTapDown: (details) => _onTapDown(details, width),
                        onHorizontalDragStart: (details) =>
                            _onScrubStart(details, width),
                        onHorizontalDragUpdate: (details) =>
                            _onScrubUpdate(details, width),
                        onHorizontalDragEnd: (_) => unawaited(_onScrubEnd()),
                        onHorizontalDragCancel: () => unawaited(_onScrubEnd()),
                        child: SizedBox(
                          key: VideoControlsBar.trackKey,
                          height: VideoControlsBar.height,
                          child: Center(
                            child: ValueListenableBuilder<Duration>(
                              valueListenable: _glide.shown,
                              // Still between frames: built once per update.
                              child: VideoTagMarks(
                                mediaId: widget.mediaId,
                                duration: duration,
                                width: width,
                              ),
                              builder: (context, shown, tagMarks) {
                                final progress =
                                    scrubFraction ??
                                    _fractionOf(shown, duration);
                                return Stack(
                                  // The thumb and tag marks overhang the 4 px
                                  // track; clipping drew the thumb as a
                                  // sliver.
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Background track
                                    Container(
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    analysed,
                                    // Progress track
                                    FractionallySizedBox(
                                      widthFactor: progress,
                                      child: Container(
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Tagged moments (issue #1745)
                                    tagMarks!,
                                    // Thumb indicator
                                    Positioned(
                                      left: (width * progress) - 8,
                                      top: -6,
                                      child: Container(
                                        key: VideoControlsBar.thumbKey,
                                        width: 16,
                                        height: 16,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Total time
              SizedBox(
                width: 48,
                child: Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (widget.audio case final audio?)
                VideoVolumeControl(audio: audio, onHoldChanged: _onVolumeHold),
            ],
          ),
        ),
      ),
    );
  }
}
