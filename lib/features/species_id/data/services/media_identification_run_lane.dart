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
    bool fresh = false,
  }) {
    if (_disposed) return Future.value(RunItemOutcome.skipped);
    final job = _Job(
      item,
      location,
      _databaseGeneration(),
      null,
      true,
      resolveImage,
      resolveVideo,
      false,
      fresh,
    );
    // Joins only a run's own job: a viewer's scan of the same video may be
    // stopped when the diver leaves it, so the run queues its own, which
    // carries on from wherever the viewer's stopped.
    // A fresh one (issue #4825) starts over after it instead.
    final running = _running;
    if (!fresh &&
        running != null &&
        running.fromRun &&
        running.item.id == item.id) {
      return running.done.future.then((_) => running.outcome);
    }
    final replaced = _runWaiting.remove(item.id);
    if (replaced != null) {
      replaced.outcome = RunItemOutcome.skipped;
      replaced.done.complete();
    }
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
    this.location,
    this.generation, [
    Completer<void>? done,
    this.fromRun = false,
    this.resolveImage,
    this.resolveVideo,
    this.byHand = false,
    this.fresh = false,
  ]) : done = done ?? Completer<void>();

  /// The viewer's request.
  _Job.byViewer(
    MediaItem item,
    GeoPoint? location,
    int generation, {
    required bool byHand,
    required bool fresh,
  }) : this(item, location, generation, null, false, null, null, byHand, fresh);

  final MediaItem item;
  final GeoPoint? location;

  /// The logbook it was asked for in (the database generation): one opened
  /// since drops it unprocessed, so the old logbook's media are never
  /// analysed into the new one.
  final int generation;
  final Completer<void> done;

  /// Asked for by a Find species run (issue #4727), with the run's own
  /// resolvers in place of the viewer's.
  final bool fromRun;
  final Future<IdentificationImage?> Function(MediaItem)? resolveImage;
  final Future<VideoFileReader?> Function(MediaItem)? resolveVideo;

  /// Asked for by the diver from the labels menu (issue #4825): it runs
  /// whether or not media are identified on opening. A by-hand request
  /// that joins it running sets it (issue #4872).
  bool byHand;

  /// Still to start over from the beginning: until its fresh start is
  /// stored ([freshStarted]), after which a job put back carries on.
  bool fresh;

  /// It started over: nothing is applied by the app when it settles.
  var wasFresh = false;

  /// The fresh start is stored.
  void freshStarted() {
    if (!fresh) return;
    fresh = false;
    wasFresh = true;
  }

  /// What became of it, for a run's summary.
  var outcome = RunItemOutcome.done;

  /// A video the diver left: its scan stops after the chunk in progress.
  var cancelled = false;

  /// The scan saw [cancelled] and is stopping for it (issue #4872). The
  /// diver coming back after that clears [cancelled] too late to keep the
  /// scan going, so the job goes back in the queue when it ends.
  var stopSeen = false;

  /// Whether the scan should stop because the diver left, noting that it
  /// saw it ([stopSeen]).
  bool stopForLeaving() {
    if (cancelled) stopSeen = true;
    return cancelled;
  }

  /// The diver came back after the scan saw them leave: it is to carry on
  /// in a fresh pass once this one ends.
  bool get revived => stopSeen && !cancelled;

  /// This request asked again, in the logbook of [generation], by hand or
  /// fresh if either asking was.
  _Job withLocation(
    GeoPoint? location,
    int generation, {
    bool byHand = false,
    bool fresh = false,
  }) => _Job(
    item,
    location,
    generation,
    done,
    fromRun,
    resolveImage,
    resolveVideo,
    this.byHand || byHand,
    this.fresh || fresh,
  )..wasFresh = wasFresh;
}
