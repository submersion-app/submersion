part of 'media_identification_service.dart';

/// Scanning videos (issue #4675), kept beside the queue it runs in: the
/// same library, so it shares the service's private state.
extension _VideoScanning on MediaIdentificationService {
  /// A video (issue #4675): resumed, scanned from the start, or named
  /// again, as [decideVideoRefresh] says. Returns whether it stopped
  /// between chunks for other work and should go back in the queue.
  Future<bool> _refreshVideo(
    _Job job,
    LoadedPack pack,
    MediaIdentificationRun? run,
    List<MediaIdentification> stored,
    List<MediaIdentification> undecided,
    Map<String, Float32List> embeddings, {
    required int? cell,
    required bool cropsPresent,
    required bool embeddingsPresent,
    required bool madeHere,
    required int generation,
  }) async {
    final manifest = pack.pack.manifest;
    // A fresh request scans from the start whatever the video needs.
    final action = job.fresh
        ? VideoRefreshAction.rescan
        : decideVideoRefresh(
            run: run,
            packVersion: manifest.packVersion,
            detectorId: _runDetectorId(manifest, video: true),
            classifierId: manifest.classifier.embeddingId,
            cell: cell,
            cropsPresent: cropsPresent,
            embeddingsPresent: embeddingsPresent,
            madeHere: madeHere,
          );
    switch (action) {
      case VideoRefreshAction.none:
        return false;
      case VideoRefreshAction.rename:
        await _rename(pack, run!, undecided, embeddings, cell, generation);
        return false;
      case VideoRefreshAction.resume:
        final reader = await (job.resolveVideo ?? _resolveVideo)(job.item);
        if (reader == null) {
          job.outcome = RunItemOutcome.unreadable;
          return false;
        }
        var from = run!;
        final moved =
            from.packVersion != manifest.packVersion ||
            from.locationCell != cell;
        var now = stored;
        if (moved && embeddingsPresent) {
          await _rename(pack, from, undecided, embeddings, cell, generation);
          from = await _identifications.runFor(job.item.id) ?? from;
          now = await _identifications.forMedia(job.item.id);
        }
        // A rescan stopped part-way: what the diver said about a fish not
        // yet reached is still to be carried to its fresh track (rows this
        // scan stored lie inside the stretches it scanned).
        final scanned = from.scanned;
        final ahead = [
          for (final i in now)
            if (i.saidByDiver &&
                !scanned.coversRange(i.startMs ?? 0, i.endMs ?? 0))
              i,
        ];
        return _scanVideo(job, pack, cell, reader, from, generation, ahead);
      case VideoRefreshAction.rescan:
        final reader = await (job.resolveVideo ?? _resolveVideo)(job.item);
        if (reader == null) {
          job.outcome = RunItemOutcome.unreadable;
          return false;
        }
        // Dismissals come back only for a video that is looked at again.
        var rows = stored;
        if (job.fresh) {
          final reopened = await _reopen(job, stored);
          if (reopened == null) return false;
          rows = reopened;
        }
        // What the diver said about a fish (a decision, or a claim from
        // the frame) is carried to the fresh track of the same fish; the
        // app's own guesses are found again.
        final carry = [
          for (final i in rows)
            if (i.saidByDiver) i,
        ];
        final dropped = [
          for (final i in rows)
            if (!carry.contains(i)) i.id,
        ];
        final start = MediaIdentificationRun(
          mediaId: job.item.id,
          packVersion: manifest.packVersion,
          detectorId: videoRunDetectorId(manifest.detectorSetId),
          classifierId: manifest.classifier.embeddingId,
          locationCell: cell,
          analysedAt: _now().toUtc(),
          imageWidth: run?.imageWidth ?? 0,
          imageHeight: run?.imageHeight ?? 0,
          detectionCount: carry.length,
          scannedMs: 0,
          // Known already: the analysed stretches show from the start.
          videoDurationMs: run?.videoDurationMs,
          // A scan from the start is a new run here (issue #4876); its
          // later chunks keep this id.
          analysedBy: await _deviceId(),
          runId: _newRunId(),
          namingBars: NamingBars.fromNaming(manifest.naming),
        );
        if (_databaseGeneration() != generation) return false;
        await _identifications.storeRun(
          start,
          insert: const [],
          deleteIds: dropped,
        );
        await _embeddings.delete(dropped);
        await _crops.delete(job.item.id, dropped);
        // From here a job put back carries on rather than starting over.
        job.freshStarted();
        return _scanVideo(job, pack, cell, reader, start, generation, carry);
    }
  }

  /// Whether a request for other media is waiting. One for this same video
  /// (its location arrived late) waits for the scan to end, then names
  /// what was found for the new place, rather than stopping the scan.
  bool _otherWaiting(_Job job) => _waiting.keys.any((id) => id != job.item.id);

  /// Whether the diver asked for this same video again from the start
  /// (issue #4825): the scan under way gives way to it.
  bool _freshWaiting(_Job job) =>
      (job.fromRun ? _runWaiting : _waiting)[job.item.id]?.fresh ?? false;

  /// Scans [job]'s video a chunk at a time from [from]. Between chunks it
  /// stops when the video was left, another logbook opened, a pack change
  /// or a newer request is waiting (then it returns true, to be put back),
  /// or the service is closing. Never throws.
  Future<bool> _scanVideo(
    _Job job,
    LoadedPack pack,
    int? cell,
    VideoFileReader reader,
    MediaIdentificationRun from,
    int generation,
    List<MediaIdentification> carry,
  ) async {
    // One worker holds the candidate table for the whole scan; without it
    // each chunk's naming copies the table into a new isolate.
    CropNamingWorker? worker;
    try {
      worker = await CropNamingWorker.start(pack, cell);
    } on Object catch (e) {
      _log.debug('Naming without a worker isolate', error: e);
    }
    final scan = VideoIdentificationScan(
      engine: _engine,
      pack: pack,
      identifications: _identifications,
      embeddings: _embeddings,
      crops: _crops,
      item: job.item,
      cell: cell,
      reader: reader,
      name: worker?.name ?? (crops) => nameCrops(pack, crops, cell),
      now: _now,
      newId: _newId,
      databaseGeneration: _databaseGeneration,
      generation: generation,
      resumeFrom: from,
      carry: carry,
      playhead: () => _playheads[job.item.id],
      onFollowed: (sequence) => _followedPlayheads[job.item.id] = sequence,
      firstChunkMs: _firstVideoChunkMs,
      reload: () async {
        _loadedModels = null;
        await _ensureLoaded(pack);
      },
      memoryReadout: _memoryReadout,
      keepGoing: () =>
          !job.stopForLeaving() &&
          !_disposed &&
          _paused == 0 &&
          !_otherWaiting(job) &&
          !_freshWaiting(job) &&
          _databaseGeneration() == generation,
    );
    _videoProgress = scan.progress;
    _changed();
    try {
      while (true) {
        if (job.stopForLeaving() ||
            _disposed ||
            _freshWaiting(job) ||
            _databaseGeneration() != generation) {
          await scan.finish();
          return false;
        }
        if (_paused > 0 || _otherWaiting(job)) {
          await scan.finish();
          return true;
        }
        await _ensureLoaded(pack);
        // Models the system freed mid-chunk are loaded again inside the
        // scan, which retries only the call that found them gone.
        final bool more;
        try {
          more = await scan.runChunk();
        } on VideoScanStopped {
          // Stopped between batches: that chunk is scanned again next
          // time, and the tracks open where it began are kept, unnamed
          // (the stop has waited for a batch already). Put back only for a
          // pack change or a newer request.
          await scan.finish(naming: false);
          return !job.cancelled &&
              !_disposed &&
              _databaseGeneration() == generation &&
              (_paused > 0 || _otherWaiting(job));
        }
        // The chip row and sheet agree with the labels, which reconcile in
        // memory, while the scan is still running (issue #4709).
        await reconcile(job.item.id);
        _videoProgress = scan.progress;
        _changed();
        if (!more) {
          // The end, another logbook, or a file that cannot be opened any
          // more: in the last, the tracks open where it stopped are kept.
          await scan.finish(naming: false);
          return false;
        }
      }
    } on Object catch (e) {
      // In the background, too hot, or a failure: what was stored stays,
      // and the next opening carries on from it.
      _log.debug('Video scan of ${job.item.id} stopped', error: e);
      job.outcome = runOutcomeOf(e);
      try {
        await scan.finish();
      } on Object {
        // The open tracks are lost; the stored progress is not.
      }
      return false;
    } finally {
      _armIdleUnload();
      await worker?.close();
    }
  }
}
