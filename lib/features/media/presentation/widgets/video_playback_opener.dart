import 'dart:io';

import 'package:video_player/video_player.dart';

import 'package:submersion/features/media/data/streaming/video_playback_plan.dart';

/// Opens a player for a [VideoPlayback] and reopens it once when a
/// streamed link goes stale (issue #4162).
///
/// A stream tries its candidates in order, the original before the
/// rendition, so a browser that cannot decode the original plays the
/// rendition. A player that fails after it started is reopened from a fresh
/// link at the same position and play state, once: a second failure before
/// playback moves past the resume point is the caller's to show.
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

  /// The candidate playing now, its address, and every address still open.
  StreamCandidate? _candidate;
  Uri? _url;
  final List<(StreamCandidate, Uri)> _open = [];

  /// Where the last reopen resumed; null when none is pending proof.
  Duration? _resumedAt;

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

  /// A new player for the candidate [failed] was playing, at its position
  /// and play state; null when this failure is the second in a row or the
  /// video is not streamed. The caller releases [failed].
  Future<VideoPlayerController?> reopenAfterError(
    VideoPlayerController failed,
  ) async {
    final candidate = _candidate;
    if (candidate == null) return null;
    final position = failed.value.position;
    final resumedAt = _resumedAt;
    if (resumedAt != null && position <= resumedAt) return null;
    final wasPlaying = failed.value.isPlaying;
    final stale = _url;
    final controller = await _openCandidate(candidate);
    if (stale != null) _close(candidate, stale);
    await controller.seekTo(position);
    if (wasPlaying) await controller.play();
    _resumedAt = position;
    return controller;
  }

  /// Lets go of every address still open (relay tickets).
  void dispose() {
    for (final (candidate, url) in List.of(_open)) {
      _close(candidate, url);
    }
  }

  Future<VideoPlayerController> _openCandidate(
    StreamCandidate candidate,
  ) async {
    final url = await candidate.open();
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

  void _close(StreamCandidate candidate, Uri url) {
    _open.removeWhere((entry) => entry.$2 == url);
    candidate.close(url);
  }
}
