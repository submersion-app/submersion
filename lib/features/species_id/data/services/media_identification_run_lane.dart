part of 'media_identification_service.dart';

/// A Find species run's lane in the queue (issue #4727), kept beside the
/// queue it runs in: the same library, so it shares the service's private
/// state.
extension RunLane on MediaIdentificationService {
  /// Queues [item] for a Find species run (issue #4727), behind every
  /// viewer request, with the run's own way to reach an original not on
  /// this device. Completes with what became of it. Applying confident
  /// matches is left to the run, which files a whole run as one History
  /// entry.
  Future<RunItemOutcome> requestFromRun(
    MediaItem item, {
    GeoPoint? location,
    required Future<IdentificationImage?> Function(MediaItem) resolveImage,
    required Future<VideoFileReader?> Function(MediaItem) resolveVideo,
  }) {
    if (_disposed) return Future.value(RunItemOutcome.skipped);
    final job = _Job(item, location, null, true, resolveImage, resolveVideo);
    final running = _running;
    if (running != null && running.item.id == item.id) {
      return running.done.future.then((_) => running.outcome);
    }
    _runWaiting.remove(item.id)?.done.complete();
    _runWaiting[item.id] = job;
    _changed();
    _pump();
    return job.done.future.then((_) => job.outcome);
  }

  /// Drops a run's request for [mediaId] that has not started, or stops a
  /// run's video scan after the chunk in progress. Returns whether there
  /// was one.
  bool cancelRun(String mediaId) {
    final job = _runWaiting.remove(mediaId);
    if (job != null) {
      job.outcome = RunItemOutcome.skipped;
      job.done.complete();
      _changed();
      return true;
    }
    final running = _running;
    if (running != null && running.fromRun && running.item.id == mediaId) {
      running.cancelled = true;
      return true;
    }
    return false;
  }
}

/// What a Find species run's request came to (issue #4727).
enum RunItemOutcome {
  /// Analysed, named again, or found to need nothing.
  done,

  /// No image or video file could be reached.
  unreadable,

  /// The device was too warm to go on.
  tooHot,

  /// The app went to the background, where the models may not run.
  notForeground,

  /// The engine failed on it.
  failed,

  /// Dropped before it ran, or not a photo or video.
  skipped,
}

/// The [RunItemOutcome] for a failure [e] from the engine.
RunItemOutcome runOutcomeOf(Object e) => switch (e) {
  VisionEngineException(code: VisionEngineException.tooHot) =>
    RunItemOutcome.tooHot,
  VisionEngineException(code: VisionEngineException.notForeground) =>
    RunItemOutcome.notForeground,
  _ => RunItemOutcome.failed,
};

/// One request in the queue: the viewer's, or a Find species run's.
class _Job {
  _Job(
    this.item,
    this.location, [
    Completer<void>? done,
    this.fromRun = false,
    this.resolveImage,
    this.resolveVideo,
  ]) : done = done ?? Completer<void>();

  final MediaItem item;
  final GeoPoint? location;
  final Completer<void> done;

  /// Asked for by a Find species run (issue #4727), with the run's own
  /// resolvers in place of the viewer's.
  final bool fromRun;
  final Future<IdentificationImage?> Function(MediaItem)? resolveImage;
  final Future<VideoFileReader?> Function(MediaItem)? resolveVideo;

  /// What became of it, for a run's summary.
  var outcome = RunItemOutcome.done;

  /// A video the diver left: its scan stops after the chunk in progress.
  var cancelled = false;

  _Job withLocation(GeoPoint? location) =>
      _Job(item, location, done, fromRun, resolveImage, resolveVideo);
}
