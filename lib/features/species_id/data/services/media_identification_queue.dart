part of 'media_identification_service.dart';

/// Running the queue one job at a time, kept beside the service it runs
/// in: the same library, so it shares the service's private state.
extension _Queue on MediaIdentificationService {
  void _pump() {
    if (_running != null ||
        (_waiting.isEmpty && _runWaiting.isEmpty) ||
        _disposed ||
        _paused > 0) {
      return;
    }
    // The viewer's newest request first; a run's oldest only when none
    // waits (issue #4727).
    final job = _waiting.isNotEmpty
        ? _waiting.remove(_waiting.keys.last)!
        : _runWaiting.remove(_runWaiting.keys.first)!;
    _running = job;
    job.stopSeen = false;
    _changed();
    final ended = _process(job).then((putBack) {
      _running = null;
      _videoProgress = null;
      // A video stopped for a newer request or a pack change goes to the
      // oldest end, to carry on once the rest is done.
      if (putBack && !_disposed && job.fromRun) {
        _runWaiting = {job.item.id: job, ..._runWaiting};
      } else if (putBack && !_disposed && !_waiting.containsKey(job.item.id)) {
        _waiting = {job.item.id: job, ..._waiting};
      } else if (job.revived &&
          !_disposed &&
          !_waiting.containsKey(job.item.id)) {
        // The diver came back to a video whose scan had already seen them
        // leave and stopped: it carries on, as the newest request, so the
        // caller who came back is answered by a scan (issue #4872).
        _waiting[job.item.id] = job;
      } else {
        job.done.complete();
      }
      _changed();
      _pump();
    });
    _runningEnded = ended;
    unawaited(ended);
  }
}
