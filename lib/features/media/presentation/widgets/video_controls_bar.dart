import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/presentation/helpers/elapsed_time_format.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/video_tag_marks.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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
class VideoControlsBar extends StatefulWidget {
  final VideoPlayerController controller;

  /// The video, whose tagged moments are marked on the bar (issue #1745).
  final String mediaId;

  /// Told true when a drag scrub begins and false once it has settled, so a
  /// host that hides its controls on a timer can hold them up meanwhile.
  final ValueChanged<bool>? onScrubbingChanged;

  /// The bar's touch area, for tests that tap or drag along it.
  @visibleForTesting
  static const trackKey = ValueKey('videoControlsBar.track');

  /// How far a screen reader's increase and decrease actions move.
  static const accessibilityStep = Duration(seconds: 5);

  const VideoControlsBar({
    super.key,
    required this.controller,
    required this.mediaId,
    this.onScrubbingChanged,
  });

  @override
  State<VideoControlsBar> createState() => _VideoControlsBarState();
}

class _VideoControlsBarState extends State<VideoControlsBar> {
  static final _log = LoggerService.forClass(VideoControlsBar);

  /// Where the finger is along the track while scrubbing, as a fraction of
  /// its width; null when not scrubbing. The thumb and elapsed time follow
  /// this rather than the player, so they never lag behind a pending seek.
  double? _scrubFraction;

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

  /// The newest seek requested, which the player reaches once [_seeking]
  /// completes.
  Duration _seekTarget = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onVideoUpdate);
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
      final onScrubbingChanged = widget.onScrubbingChanged;
      if (_scrubFraction != null && onScrubbingChanged != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) onScrubbingChanged(false);
        });
      }
      _scrubId++;
      _scrubFraction = null;
      _resumeAfterScrub = false;
      _pendingSeek = null;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onVideoUpdate);
    super.dispose();
  }

  void _onVideoUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  String _formatDuration(Duration duration) =>
      formatElapsedMmSs(duration.inSeconds);

  /// Where the video is headed: the newest seek while one is under way,
  /// else where it is. Steps build on this, so quick steps add up.
  Duration get _heading =>
      _seeking != null ? _seekTarget : widget.controller.value.position;

  void _step(Duration delta) => unawaited(_seekTo(_stepped(_heading, delta)));

  /// [position] moved by [delta], kept inside the clip.
  Duration _stepped(Duration position, Duration delta) {
    final duration = widget.controller.value.duration;
    final target = position + delta;
    if (target < Duration.zero) return Duration.zero;
    return target > duration ? duration : target;
  }

  double _fractionAt(double x, double width) =>
      width <= 0 ? 0.0 : (x / width).clamp(0.0, 1.0);

  Duration _positionAt(double fraction) => Duration(
    milliseconds: (fraction * widget.controller.value.duration.inMilliseconds)
        .round(),
  );

  /// Seeks to [target], coalescing with any seek already in flight. The
  /// returned future completes once the player has reached the newest target.
  Future<void> _seekTo(Duration target) {
    _pendingSeek = target;
    _seekTarget = target;
    return _seeking ??= _drainSeeks();
  }

  Future<void> _drainSeeks() async {
    try {
      while (_pendingSeek != null) {
        final target = _pendingSeek!;
        _pendingSeek = null;
        await widget.controller.seekTo(target);
      }
    } catch (e, stackTrace) {
      _pendingSeek = null;
      _log.error(
        'Failed to seek video ${widget.mediaId}',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _seeking = null;
    }
  }

  void _onTapDown(TapDownDetails details, double width) {
    unawaited(
      _seekTo(_positionAt(_fractionAt(details.localPosition.dx, width))),
    );
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
    widget.onScrubbingChanged?.call(true);
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
    widget.onScrubbingChanged?.call(false);
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
    final progress =
        scrubFraction ??
        (duration.inMilliseconds > 0
            ? (position.inMilliseconds / duration.inMilliseconds).clamp(
                0.0,
                1.0,
              )
            : 0.0);

    return Directionality(
      textDirection: TextDirection.ltr,
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
                  // A slider to assistive tech, stepping by a few seconds,
                  // since a screen reader cannot tap a point or drag.
                  return Semantics(
                    label: context.l10n.media_photoViewer_seekVideoLabel,
                    slider: true,
                    value: _formatDuration(position),
                    increasedValue: canSeek
                        ? _formatDuration(
                            _stepped(
                              position,
                              VideoControlsBar.accessibilityStep,
                            ),
                          )
                        : null,
                    decreasedValue: canSeek
                        ? _formatDuration(
                            _stepped(
                              position,
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
                        height: 40, // Larger touch target
                        child: Center(
                          child: Stack(
                            // The thumb and tag marks overhang the 4 px
                            // track; clipping drew the thumb as a sliver.
                            clipBehavior: Clip.none,
                            children: [
                              // Background track
                              Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              // Progress track
                              FractionallySizedBox(
                                widthFactor: progress,
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              // Tagged moments (issue #1745)
                              VideoTagMarks(
                                mediaId: widget.mediaId,
                                duration: duration,
                                width: width,
                              ),
                              // Thumb indicator
                              Positioned(
                                left: (width * progress) - 8,
                                top: -6,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
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
          ],
        ),
      ),
    );
  }
}
