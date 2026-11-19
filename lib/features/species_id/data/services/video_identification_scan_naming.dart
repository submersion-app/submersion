part of 'video_identification_scan.dart';

/// Naming a scan's tracks: pass 2 and the rows it makes, kept beside the
/// scan in the same library so it shares the scan's private state.
extension _Naming on VideoIdentificationScan {
  /// Crops and embeds each track's best moments in batches, names each
  /// moment on its own, and names each track from the view
  /// [chooseNamingView] picks (issue #4736). A track none of whose moments
  /// could be cropped, or named, is left out, unless it continues a stored
  /// row: that is kept as named before, with its path grown ([_unnamed]).
  /// When [stopping], only one batch is named, the tracks with no name yet
  /// and then the longest first; the others are kept without naming them.
  /// [rows] are the stored rows the tracks continue, by id. Between batches
  /// (not when stopping) it stops on [VideoIdentificationScan._keepGoing],
  /// and drops the chunk when [dropped] says the diver moved the scan
  /// elsewhere. Null when the file cannot be opened.
  Future<List<_Stored>?> _nameTracks(
    List<TrackedAnimal> all, {
    required bool stopping,
    required Map<String, MediaIdentification> rows,
    bool Function()? dropped,
  }) async {
    if (all.isEmpty) return const [];
    var closed = all;
    var picks = [for (final track in all) bestMoments(track)];
    final left = <_Stored>[];
    if (stopping) {
      bool named(TrackedAnimal t) => !(rows[t.storedId]?.isPending ?? true);
      int length(TrackedAnimal t) => t.endMs - t.startMs;
      final order = [for (var k = 0; k < all.length; k++) k]
        ..sort((a, b) {
          if (named(all[a]) != named(all[b])) return named(all[a]) ? 1 : -1;
          return length(all[b]).compareTo(length(all[a]));
        });
      // Filled in [order], so it is in that order too.
      final chosen = <int>[];
      var moments = 0;
      for (final k in order) {
        if (moments + picks[k].length > VideoIdentificationScan.embedBatch) {
          break;
        }
        moments += picks[k].length;
        chosen.add(k);
      }
      final now = _now().toUtc();
      left.addAll([
        for (final k in order.skip(chosen.length)) _unnamed(all[k], now, rows),
      ]);
      closed = [for (final k in chosen) all[k]];
      picks = [for (final k in chosen) picks[k]];
    }
    final moments = [
      for (final chosen in picks)
        for (final p in chosen) VisionMoment(ms: p.ms, box: p.detection.box),
    ];
    final crops = <VisionMomentCrop?>[];
    const batchSize = VideoIdentificationScan.embedBatch;
    for (var at = 0; at < moments.length; at += batchSize) {
      if (!stopping && !_keepGoing()) throw const VideoScanStopped();
      if (!stopping && (dropped?.call() ?? false)) throw const _ChunkDropped();
      _embedCalls++;
      final batch = await _call(
        (path) => _engine.embedMoments(
          path: path,
          moments: moments.sublist(
            at,
            math.min(at + batchSize, moments.length),
          ),
        ),
      );
      if (batch == null) return null;
      crops.addAll(batch);
    }

    final kept =
        <
          ({
            TrackedAnimal track,
            List<
              ({
                ({int ms, DetectedBox detection}) moment,
                VisionMomentCrop crop,
              })
            >
            views,
          })
        >[];
    // Tracks that could not be named now but continue a stored row.
    final unnameable = <TrackedAnimal>[];
    var at = 0;
    for (var t = 0; t < closed.length; t++) {
      final usable = [
        for (var k = 0; k < picks[t].length; k++)
          if (crops[at + k] case final crop?) (moment: picks[t][k], crop: crop),
      ];
      at += picks[t].length;
      if (usable.isEmpty) {
        if (rows.containsKey(closed[t].storedId)) unnameable.add(closed[t]);
        continue;
      }
      kept.add((track: closed[t], views: usable));
    }
    final results = await _name([
      for (final k in kept)
        for (final v in k.views)
          (
            embedding: v.crop.embedding,
            shorterSide: math.min(v.crop.pixelWidth, v.crop.pixelHeight),
          ),
    ]);
    final now = _now().toUtc();
    final naming = _pack.pack.manifest.naming;
    final named = <_Stored>[];
    var from = 0;
    for (final k in kept) {
      final own = results.sublist(from, from + k.views.length);
      from += k.views.length;
      final pick = chooseNamingView([
        for (var v = 0; v < own.length; v++)
          (naming: own[v], ms: k.views[v].moment.ms),
      ]);
      // No view could be named: as when none could be cropped.
      if (pick == null) {
        if (rows.containsKey(k.track.storedId)) unnameable.add(k.track);
        continue;
      }
      final result = own[pick.index];
      final chosen = k.views[pick.index];
      named.add(
        _identification(
          k.track,
          chosen.moment,
          chosen.crop,
          NamingResult(
            openScore: result.openScore,
            candidates: result.candidates,
            locationLimited: result.locationLimited,
            suggestable: pick.suggestable,
          ),
          naming,
          now,
          rows,
          // The detector's best view among those cropped: a later view
          // worth clearly more names the track again ([namesNow]).
          worth: momentWorth(k.views.first.moment.detection),
        ),
      );
    }
    return [
      ...named,
      for (final t in unnameable) _unnamed(t, now, rows),
      ...left,
    ];
  }

  /// [track], stored without naming it now. A fish already named keeps its
  /// name and gains the path it swam since; any other is kept to be named
  /// later ([MediaIdentification.isPending]).
  _Stored _unnamed(
    TrackedAnimal track,
    DateTime now,
    Map<String, MediaIdentification> rows,
  ) {
    final row = rows[track.storedId];
    if (row != null && !row.isPending) {
      return (
        identification: row.copyWith(
          startMs: () => track.startMs,
          endMs: () => track.endMs,
          path: track.samples,
        ),
        embedding: null,
        cropJpeg: null,
        track: track,
        worth: track.namedWorth,
      );
    }
    final first = track.points.first.detection;
    return (
      identification: MediaIdentification(
        id: track.storedId ?? _newId(),
        mediaId: _item.id,
        box: first.box,
        boxPixelWidth: 0,
        boxPixelHeight: 0,
        detectorScore: first.score,
        openScore: 0,
        candidates: const [],
        locationLimited: false,
        suggestable: false,
        decision: row?.decision ?? IdentificationDecision.undecided,
        decidedSpeciesId: row?.decidedSpeciesId,
        decidedAt: row?.decidedAt,
        claimedSpeciesId: row?.claimedSpeciesId,
        createdAt: row?.createdAt ?? now,
        startMs: track.startMs,
        endMs: track.endMs,
        path: track.samples,
      ),
      embedding: null,
      cropJpeg: null,
      track: track,
      worth: null,
    );
  }

  /// [track] named from its view at [best], whose [crop] is shown and
  /// whose embedding is stored for renaming.
  _Stored _identification(
    TrackedAnimal track,
    ({int ms, DetectedBox detection}) best,
    VisionMomentCrop crop,
    NamingResult result,
    NamingConfig naming,
    DateTime now,
    Map<String, MediaIdentification> rows, {
    required double worth,
  }) {
    final flags = namingFlags(result, naming);
    final storedId = track.storedId;
    final row = storedId == null ? null : rows[storedId];
    final identification = MediaIdentification(
      id: storedId ?? _newId(),
      mediaId: _item.id,
      box: best.detection.box,
      boxPixelWidth: crop.pixelWidth,
      boxPixelHeight: crop.pixelHeight,
      detectorScore: best.detection.score,
      openScore: result.openScore,
      candidates: result.candidates,
      locationLimited: result.locationLimited,
      suggestable: result.suggestable,
      decision: row?.decision ?? IdentificationDecision.undecided,
      decidedSpeciesId: row?.decidedSpeciesId,
      decidedAt: row?.decidedAt,
      claimedSpeciesId: row?.claimedSpeciesId,
      createdAt: row?.createdAt ?? now,
      startMs: track.startMs,
      endMs: track.endMs,
      bestMs: best.ms,
      path: track.samples,
      confident: flags.confident,
      specific: flags.specific,
    );
    return (
      identification: identification,
      embedding: crop.embedding,
      cropJpeg: crop.cropJpeg,
      track: track,
      worth: worth,
    );
  }
}
