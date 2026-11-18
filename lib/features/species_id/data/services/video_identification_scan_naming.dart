part of 'video_identification_scan.dart';

/// Naming a scan's tracks: pass 2 and the rows it makes, kept beside the
/// scan in the same library so it shares the scan's private state.
extension _Naming on VideoIdentificationScan {
  /// Crops and embeds each track's best moments in batches, and names each
  /// track from the average of its moments' embeddings. A track none of
  /// whose moments could be cropped is left out, unless it continues a
  /// stored row: that is kept as named before, with its path grown
  /// ([_unnamed]). When [stopping], only one
  /// batch is named, the tracks with no name yet and then the longest
  /// first; the others are kept without naming them. [rows] are the stored
  /// rows the tracks continue, by id. Between batches (not when stopping)
  /// it stops on [VideoIdentificationScan._keepGoing], and drops the chunk
  /// when [dropped] says the diver moved the scan elsewhere. Null when the
  /// file cannot be opened.
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
            ({int ms, DetectedBox detection}) moment,
            VisionMomentCrop crop,
          })
        >[];
    final averaged = <Float32List>[];
    // Tracks that could not be named now but continue a stored row.
    final unnameable = <TrackedAnimal>[];
    var at = 0;
    for (var t = 0; t < closed.length; t++) {
      final own = [
        for (var k = 0; k < picks[t].length; k++)
          (index: k, crop: crops[at + k]),
      ];
      at += picks[t].length;
      final usable = [
        for (final o in own)
          if (o.crop != null) (index: o.index, crop: o.crop!),
      ];
      final embedding = usable.isEmpty
          ? null
          : _averaged([for (final u in usable) u.crop.embedding]);
      if (embedding == null) {
        if (rows.containsKey(closed[t].storedId)) unnameable.add(closed[t]);
        continue;
      }
      kept.add((
        track: closed[t],
        moment: picks[t][usable.first.index],
        crop: usable.first.crop,
      ));
      averaged.add(embedding);
    }
    final results = await _name([
      for (var k = 0; k < kept.length; k++)
        (
          embedding: averaged[k],
          shorterSide: math.min(
            kept[k].crop.pixelWidth,
            kept[k].crop.pixelHeight,
          ),
        ),
    ]);
    final now = _now().toUtc();
    final naming = _pack.pack.manifest.naming;
    return [
      for (var k = 0; k < kept.length; k++)
        _identification(
          kept[k].track,
          kept[k].moment,
          kept[k].crop,
          averaged[k],
          results[k],
          naming,
          now,
          rows,
        ),
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

  _Stored _identification(
    TrackedAnimal track,
    ({int ms, DetectedBox detection}) best,
    VisionMomentCrop crop,
    Float32List embedding,
    NamingResult result,
    NamingConfig naming,
    DateTime now,
    Map<String, MediaIdentification> rows,
  ) {
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
      embedding: embedding,
      cropJpeg: crop.cropJpeg,
      track: track,
      worth: momentWorth(best.detection),
    );
  }
}

/// The mean of [embeddings], each first scaled to unit length, itself
/// scaled to unit length. Null when they disagree in length or sum to
/// nothing.
Float32List? _averaged(List<Float32List> embeddings) {
  final width = embeddings.first.length;
  if (width == 0 || embeddings.any((e) => e.length != width)) return null;
  final sum = Float64List(width);
  for (final e in embeddings) {
    var norm = 0.0;
    for (final v in e) {
      norm += v * v;
    }
    norm = math.sqrt(norm);
    if (norm == 0 || !norm.isFinite) continue;
    for (var k = 0; k < width; k++) {
      sum[k] += e[k] / norm;
    }
  }
  var total = 0.0;
  for (final v in sum) {
    total += v * v;
  }
  total = math.sqrt(total);
  if (total == 0 || !total.isFinite) return null;
  return Float32List.fromList([for (final v in sum) v / total]);
}
