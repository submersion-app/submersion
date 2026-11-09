import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/streaming/video_playback_plan.dart';

/// Opens a player for a [VideoPlayback] and reopens it once when a
/// streamed link goes stale (issue #4162).
///
/// A stream tries its candidates in order, the original before the
/// rendition, so a browser that cannot decode the original plays the
/// rendition. A [watch]ed player that fails after it started is reopened
/// from a fresh link at the same position and play state, once: a second
/// failure before playback moves past the resume point moves on to the next
/// candidate, and with none left the caller is told there is nothing.
class VideoPlaybackOpener {
  VideoPlaybackOpener(
    this.playback, {
    required void Function(VideoPlayerController controller) release,
    VideoPlayerController Function(Uri url)? network,
    VideoPlayerController Function(String path)? file,
  }) : _release = release,
       _network = network ?? VideoPlayerController.networkUrl,
       _file = file ?? ((path) => VideoPlayerController.file(File(path)));

  final VideoPlayback playback;
  final void Function(VideoPlayerController controller) _release;
  final VideoPlayerController Function(Uri url) _network;
  final VideoPlayerController Function(String path) _file;

  static const _log = LoggerService(
    'VideoPlaybackOpener',
    category: LogCategory.media,
  );

  /// The candidate playing now, its address, and every address still open.
  StreamCandidate? _candidate;
  Uri? _url;
  final List<(StreamCandidate, Uri)> _open = [];

  /// Where the last reopen resumed; null when none is pending proof.
  Duration? _resumedAt;

  /// The player [watch] follows, and its listener.
  VideoPlayerController? _watched;
  VoidCallback? _onWatchedValue;

  /// Where the watched player last was, and whether it was playing, from
  /// its last value without an error. An error replaces a controller's
  /// whole value (`VideoPlayerValue.erroneous`: position zero, paused), so
  /// the failed player itself no longer knows.
  Duration _lastPosition = Duration.zero;
  bool _lastPlaying = false;

  /// Set by [dispose]: an address that arrives afterwards is let go at once.
  bool _disposed = false;

  /// An initialised player, or the last candidate's error.
  Future<VideoPlayerController> open() async {
    switch (playback) {
      case FilePlayback(:final path):
        final controller = _file(path);
        try {
          await controller.initialize();
          return controller;
        } on Object {
          _release(controller);
          rethrow;
        }
      case StreamPlayback(:final candidates):
        Object? lastError;
        StackTrace? lastStack;
        for (final candidate in candidates) {
          try {
            return await _openCandidate(candidate);
          } on Object catch (e, stack) {
            lastError = e;
            lastStack = stack;
          }
        }
        if (lastError != null) {
          Error.throwWithStackTrace(lastError, lastStack!);
        }
        throw StateError('a stream with no candidates');
      case NoPlayback():
        throw StateError('nothing to open');
    }
  }

  /// Follows [controller], a streamed player, until [dispose]: when it
  /// fails, it is reopened as [reopenAfterError] says and [onReplaced] gets
  /// the new player, which is followed in turn, or null when none could be
  /// opened. The failed player is released once [onReplaced] returns; after
  /// [dispose] it is the caller's, and a player reopened too late is
  /// released here. A file is not followed: it has no link to go stale.
  void watch(
    VideoPlayerController controller, {
    required void Function(VideoPlayerController? next) onReplaced,
  }) {
    if (_disposed || playback is! StreamPlayback) return;
    _unwatch();
    void onValue() {
      final value = controller.value;
      if (!value.hasError) {
        _lastPosition = value.position;
        _lastPlaying = value.isPlaying;
        return;
      }
      _unwatch();
      unawaited(_replace(controller, onReplaced));
    }

    _watched = controller;
    _onWatchedValue = onValue;
    controller.addListener(onValue);
    // A player can fail before anyone listens: during a reopen's seek or
    // play. Its value already says so, and no later change would.
    onValue();
  }

  /// A new player for what [failed] was playing, at its position and play
  /// state: the same candidate from a fresh address, or, when it failed
  /// again before playing past the last resume point (it will not decode),
  /// the next candidate. Null when there is none left or the video is not
  /// streamed. The caller releases [failed].
  Future<VideoPlayerController?> reopenAfterError(
    VideoPlayerController failed,
  ) async {
    final current = _candidate;
    if (current == null) return null;
    final value = failed.value;
    final position = value.hasError ? _lastPosition : value.position;
    final wasPlaying = value.hasError ? _lastPlaying : value.isPlaying;
    final resumedAt = _resumedAt;
    final candidate = resumedAt != null && position <= resumedAt
        ? _after(current)
        : current;
    if (candidate == null) return null;
    final stale = _url;
    final controller = await _openCandidate(candidate);
    if (stale != null) _close(current, stale);
    try {
      await controller.seekTo(position);
      if (wasPlaying) await controller.play();
    } on Object {
      // Never handed over, so nobody else would let it go.
      _release(controller);
      final opened = _url;
      if (opened != null) _close(candidate, opened);
      _url = null;
      rethrow;
    }
    _resumedAt = position;
    return controller;
  }

  /// Lets go of every address still open (relay tickets) and stops
  /// following the watched player.
  void dispose() {
    _disposed = true;
    _unwatch();
    for (final (candidate, url) in List.of(_open)) {
      _close(candidate, url);
    }
  }

  Future<void> _replace(
    VideoPlayerController failed,
    void Function(VideoPlayerController? next) onReplaced,
  ) async {
    VideoPlayerController? next;
    try {
      next = await reopenAfterError(failed);
    } on Object catch (e, stackTrace) {
      _log.warning(
        'A streamed video could not be reopened',
        error: e,
        stackTrace: stackTrace,
      );
    }
    if (_disposed) {
      // The caller let go meanwhile and releases [failed] itself.
      if (next != null) _release(next);
      return;
    }
    onReplaced(next);
    _release(failed);
    if (next != null) watch(next, onReplaced: onReplaced);
  }

  void _unwatch() {
    final watched = _watched;
    final onValue = _onWatchedValue;
    if (watched != null && onValue != null) watched.removeListener(onValue);
    _watched = null;
    _onWatchedValue = null;
  }

  Future<VideoPlayerController> _openCandidate(
    StreamCandidate candidate,
  ) async {
    final url = await candidate.open();
    if (_disposed) {
      candidate.close(url);
      throw StateError('the opener was disposed');
    }
    _open.add((candidate, url));
    final controller = _network(url);
    try {
      await controller.initialize();
    } on Object {
      _release(controller);
      _close(candidate, url);
      rethrow;
    }
    _candidate = candidate;
    _url = url;
    return controller;
  }

  /// The candidate after [candidate], or null when it is the last.
  StreamCandidate? _after(StreamCandidate candidate) {
    final playback = this.playback;
    if (playback is! StreamPlayback) return null;
    final index = playback.candidates.indexOf(candidate);
    return index >= 0 && index + 1 < playback.candidates.length
        ? playback.candidates[index + 1]
        : null;
  }

  void _close(StreamCandidate candidate, Uri url) {
    _open.removeWhere((entry) => entry.$2 == url);
    candidate.close(url);
  }
}
