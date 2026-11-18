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
    required int generation,
  }) async {
    final manifest = pack.pack.manifest;
    final action = decideVideoRefresh(
      run: run,
      packVersion: manifest.packVersion,
      detectorId: manifest.detectorSetId,
      classifierId: manifest.classifier.embeddingId,
      cell: cell,
      cropsPresent: cropsPresent,
      embeddingsPresent: embeddingsPresent,
    );
    switch (action) {
      case VideoRefreshAction.none:
        return false;
      case VideoRefreshAction.rename:
        await _rename(pack, run!, undecided, embeddings, cell, generation);
        return false;
      case VideoRefreshAction.resume:
        final reader = await _resolveVideo(job.item);
        if (reader == null) return false;
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
        // scan stored end at or before where it got to).
        final scanned = from.scannedMs ?? 0;
        final ahead = [
          for (final i in now)
            if (_saidByDiver(i) && (i.endMs ?? 0) > scanned) i,
        ];
        return _scanVideo(
          job,
          pack,
          cell,
          reader,
          from,
          generation,
          ahead,
          stored: now,
        );
      case VideoRefreshAction.rescan:
        final reader = await _resolveVideo(job.item);
        if (reader == null) return false;
        // What the diver said about a fish (a decision, or a claim from
        // the frame) is carried to the fresh track of the same fish; the
        // app's own guesses are found again.
        final carry = [
          for (final i in stored)
            if (_saidByDiver(i)) i,
        ];
        final dropped = [
          for (final i in stored)
            if (!carry.contains(i)) i.id,
        ];
        final start = MediaIdentificationRun(
          mediaId: job.item.id,
          packVersion: manifest.packVersion,
          detectorId: manifest.detectorSetId,
          classifierId: manifest.classifier.embeddingId,
          locationCell: cell,
          analysedAt: _now().toUtc(),
          imageWidth: run?.imageWidth ?? 0,
          imageHeight: run?.imageHeight ?? 0,
          detectionCount: carry.length,
          scannedMs: 0,
        );
        if (_databaseGeneration() != generation) return false;
        await _identifications.storeRun(
          start,
          insert: const [],
          deleteIds: dropped,
        );
        await _embeddings.delete(dropped);
        await _crops.delete(job.item.id, dropped);
        return _scanVideo(job, pack, cell, reader, start, generation, carry);
    }
  }

  /// Whether a request for other media is waiting. One for this same video
  /// (its location arrived late) waits for the scan to end, then names
  /// what was found for the new place, rather than stopping the scan.
  bool _otherWaiting(_Job job) => _waiting.keys.any((id) => id != job.item.id);

  /// Whether the diver decided on [i], or named it from the frame.
  static bool _saidByDiver(MediaIdentification i) =>
      i.decision != IdentificationDecision.undecided ||
      i.claimedSpeciesId != null;

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
    List<MediaIdentification> carry, {
    List<MediaIdentification> stored = const [],
  }) async {
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
      stored: stored,
      reload: () async {
        _loadedModels = null;
        await _ensureLoaded(pack);
      },
      memoryReadout: _memoryReadout,
      keepGoing: () =>
          !job.cancelled &&
          !_disposed &&
          _paused == 0 &&
          !_otherWaiting(job) &&
          _databaseGeneration() == generation,
    );
    _videoProgress = scan.progress;
    _changed();
    try {
      while (true) {
        if (job.cancelled || _disposed || _databaseGeneration() != generation) {
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
