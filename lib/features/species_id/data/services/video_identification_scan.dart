import 'dart:math' as math;
import 'dart:typed_data';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/services/memory_readout.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/species_namer.dart';
import 'package:submersion/features/species_id/domain/services/video_identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/video_tracker.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

/// Opens the video file for one call: through its bookmark where it has
/// one, held only while [read] runs. Null when the file cannot be opened.
typedef VideoFileReader =
    Future<T?> Function<T>(Future<T> Function(String path) read);

/// Names crops by their embeddings and the size of their boxes.
typedef CropNamer =
    Future<List<NamingResult>> Function(
      List<({Float32List embedding, int shorterSide})> crops,
    );

/// A track as it is stored: named, with the embedding and crop it was
/// named from, or kept without them as the scan stopped.
typedef _Stored = ({
  MediaIdentification identification,
  Float32List? embedding,
  Uint8List? cropJpeg,
});

/// Thrown by [VideoIdentificationScan.runChunk] when told to stop between
/// two batches of pass 2. Nothing of that chunk is stored.
class VideoScanStopped implements Exception {
  const VideoScanStopped();
}

/// One video's scan, a chunk at a time (issue #4675).
///
/// Each chunk runs the detector over [chunkMs] of video (pass 1), links
/// the boxes into tracks, crops and embeds the best moments of the tracks
/// that chunk closed (pass 2), names each track once, and stores it with
/// how far the scan got. A scan stopped between chunks loses nothing: the
/// next one resumes from the stored progress.
class VideoIdentificationScan {
  VideoIdentificationScan({
    required VisionEngine engine,
    required LoadedPack pack,
    required MediaIdentificationRepository identifications,
    required IdentificationEmbeddingRepository embeddings,
    required IdentificationCropStore crops,
    required MediaItem item,
    required int? cell,
    required VideoFileReader reader,
    required CropNamer name,
    required DateTime Function() now,
    required String Function() newId,
    required int Function() databaseGeneration,
    int? generation,
    MediaIdentificationRun? resumeFrom,
    List<MediaIdentification> carry = const [],
    List<MediaIdentification> stored = const [],
    Future<void> Function()? reload,
    bool Function()? keepGoing,
    MemoryReadout? memoryReadout,
    this.chunkMs = 10000,
    this.sampleIntervalMs = 250,
  }) : _engine = engine,
       _pack = pack,
       _identifications = identifications,
       _embeddings = embeddings,
       _crops = crops,
       _item = item,
       _cell = cell,
       _reader = reader,
       _name = name,
       _now = now,
       _newId = newId,
       _databaseGeneration = databaseGeneration,
       _reload = reload,
       _keepGoing = keepGoing ?? _always,
       _memoryReadout = memoryReadout,
       _generation = generation ?? databaseGeneration(),
       _scannedMs = resumeFrom?.scannedMs ?? 0,
       _durationMs = resumeFrom?.videoDurationMs,
       _width = resumeFrom?.imageWidth ?? 0,
       _height = resumeFrom?.imageHeight ?? 0,
       _detectionCount = resumeFrom?.detectionCount ?? 0,
       _carry = [...carry] {
    // The animals in view when an earlier scan stopped were stored with
    // the progress at that point: they carry on as the same tracks, and
    // their rows (with what the diver said) are updated, not duplicated.
    // One kept without a name is always taken up, so that it is named.
    for (final row in stored) {
      final end = row.endMs;
      if (!row.isTrack || row.path.isEmpty || end == null) continue;
      if (end > _scannedMs) continue;
      final missed = ((_scannedMs - end) / sampleIntervalMs).round() - 1;
      if (missed > _tracker.maxGapSamples && !row.isPending) continue;
      _continuing[row.id] = row;
      _tracker.resume(
        TrackedAnimal(
          [
            for (final s in row.path)
              (
                ms: s.ms,
                detection: DetectedBox(box: s.box, score: row.detectorScore),
              ),
          ],
          storedId: row.id,
          pending: row.isPending,
        ),
        missed: math.max(0, math.min(missed, _tracker.maxGapSamples)),
      );
    }
  }

  final int chunkMs;
  final int sampleIntervalMs;

  /// Moments cropped and embedded per engine call. A stop waits for at
  /// most one batch: about a second on a Mac, longer on a phone.
  static const int embedBatch = 12;

  static bool _always() => true;

  final VisionEngine _engine;

  /// Logs memory after each pass, while debug mode is on; null logs nothing.
  final MemoryReadout? _memoryReadout;
  final LoadedPack _pack;
  final MediaIdentificationRepository _identifications;
  final IdentificationEmbeddingRepository _embeddings;
  final IdentificationCropStore _crops;
  final MediaItem _item;
  final int? _cell;
  final VideoFileReader _reader;
  final CropNamer _name;
  final DateTime Function() _now;
  final String Function() _newId;
  final int Function() _databaseGeneration;

  /// Loads the models again after the system freed them (an iOS memory
  /// warning); the call that found them gone is then made once more.
  final Future<void> Function()? _reload;

  /// Asked between batches of pass 2: false stops the chunk there.
  final bool Function() _keepGoing;

  /// Engine calls made by pass 2, so a chunk that embedded nothing logs no
  /// pass 2 reading.
  var _embedCalls = 0;

  /// A chunk failed part-way: what the tracker holds may include frames
  /// that were never stored, so nothing more is stored from it.
  var _broken = false;

  /// The logbook the scan belongs to (by default the one open when it was
  /// made): nothing is stored once another one has opened.
  final int _generation;
  final _tracker = VideoTracker();

  /// Stored rows the tracker is continuing, by id.
  final _continuing = <String, MediaIdentification>{};

  /// Decided or claimed tracks of a previous scan, waiting to be carried
  /// to the fresh tracks that follow the same animal.
  List<MediaIdentification> _carry;

  int _scannedMs;
  int? _durationMs;
  int _width;
  int _height;
  int _detectionCount;

  int get scannedMs => _scannedMs;

  /// 0 to 1: how much of the video is scanned.
  double get progress {
    final duration = _durationMs;
    if (duration == null) return 0;
    if (duration <= 0) return 1;
    return math.min(1, _scannedMs / duration);
  }

  /// Scans the next chunk and stores what it closed. Returns whether more
  /// of the video remains. Returns false having stored nothing when the
  /// file cannot be opened or another logbook opened meanwhile. Engine
  /// failures are thrown to the caller.
  Future<bool> runChunk() async {
    if (_broken) return false;
    final from = _scannedMs;
    final detections = await _call(
      (path) => _engine.detectVideo(
        path: path,
        startMs: from,
        endMs: from + chunkMs,
        sampleIntervalMs: sampleIntervalMs,
      ),
    );
    if (detections == null || _databaseGeneration() != _generation) {
      return false;
    }
    final duration = math.max(0, detections.durationMs);
    String range() =>
        '(${_clock(from)} to ${_clock(math.min(from + chunkMs, duration))})';
    _memoryReadout?.recordLater(() => 'pass 1 ${range()}');
    final embedsBefore = _embedCalls;
    // Nothing of a chunk is stored until its pass 2 is done: a stop or a
    // failure there puts the tracks back as they were where it began, so
    // the next chunk, or [finish], starts from what is stored.
    final before = _tracker.save();
    final closed = [
      for (final frame in detections.frames) ..._tracker.add(frame),
    ];
    final scanned = math.min(from + chunkMs, duration);
    final more = scanned < duration;
    if (!more) closed.addAll(_tracker.closeAll());
    // A continued track not seen again is already stored as it is.
    closed.removeWhere((t) => !t.hasNewPoints);
    final List<_Stored>? named;
    try {
      named = await _nameTracks(closed, stopping: false);
    } on Object {
      _tracker.restore(before);
      rethrow;
    }
    if (named == null) {
      _tracker.restore(before);
      return false;
    }
    if (_embedCalls > embedsBefore) {
      _memoryReadout?.recordLater(() => 'pass 2 ${range()}');
    }
    final bool stored;
    try {
      stored = await _store(
        named,
        scanned: scanned,
        duration: duration,
        width: detections.width,
        height: detections.height,
      );
    } on Object {
      // Part of it may be written: nothing more is stored from this scan.
      _broken = true;
      rethrow;
    }
    return stored && more;
  }

  /// Closes the tracks still open (the scan is stopping) and stores them,
  /// without moving the progress on. With [naming], as many are named as
  /// one batch of moments takes, so stopping is never slow. The rest, and
  /// all of them without [naming] or when naming fails, are stored unnamed
  /// and named when the scan resumes.
  Future<void> finish({bool naming = true}) async {
    if (_broken || _databaseGeneration() != _generation) return;
    final closed = [
      for (final t in _tracker.closeAll())
        if (t.hasNewPoints) t,
    ];
    final duration = _durationMs;
    if (closed.isEmpty || duration == null) return;
    List<_Stored>? named;
    if (naming) {
      try {
        named = await _nameTracks(closed, stopping: true);
      } on Object {
        // Out of the foreground, too hot, or the file gone: the tracks are
        // still kept, unnamed.
      }
    }
    final now = _now().toUtc();
    await _store(
      named ?? [for (final t in closed) _unnamed(t, now)],
      scanned: _scannedMs,
      duration: duration,
      width: _width,
      height: _height,
    );
  }

  /// Stores [named] and the run's progress. False when nothing was stored.
  Future<bool> _store(
    List<_Stored> named, {
    required int scanned,
    required int duration,
    required int width,
    required int height,
  }) async {
    if (_databaseGeneration() != _generation) return false;
    final continuing = [
      for (final n in named)
        if (_continuing.containsKey(n.identification.id)) n.identification,
    ];
    var continued = continuing;
    if (named.isNotEmpty && (_carry.isNotEmpty || continuing.isNotEmpty)) {
      // As stored now: the diver may have decided or named a fish since
      // the scan read the rows, or cleared them.
      final current = {
        for (final i in await _identifications.forMedia(_item.id)) i.id: i,
      };
      _carry = [for (final c in _carry) ?current[c.id]];
      continued = [
        for (final c in continuing)
          if (current[c.id] case final now?)
            c.copyWith(
              decision: now.decision,
              decidedSpeciesId: now.decidedSpeciesId,
              decidedAt: now.decidedAt,
              claimedSpeciesId: () => now.claimedSpeciesId,
            ),
      ];
    }
    // A continued track keeps its own row and decision; only the new ones
    // can take over a decision from a previous scan.
    final found = carryTrackDecisions(
      decided: _carry,
      fresh: [
        for (final n in named)
          if (!_continuing.containsKey(n.identification.id)) n.identification,
      ],
    );
    final carried = (
      insert: [...found.insert, ...continued],
      deleteIds: found.deleteIds,
    );
    _carry = [
      for (final c in _carry)
        if (!carried.deleteIds.contains(c.id)) c,
    ];
    // The rows were read above: another logbook may have opened since.
    if (_databaseGeneration() != _generation) return false;
    final manifest = _pack.pack.manifest;
    final run = MediaIdentificationRun(
      mediaId: _item.id,
      packVersion: manifest.packVersion,
      detectorId: manifest.detectorSetId,
      classifierId: manifest.classifier.embeddingId,
      locationCell: _cell,
      analysedAt: _now().toUtc(),
      imageWidth: width,
      imageHeight: height,
      detectionCount:
          _detectionCount + found.insert.length - found.deleteIds.length,
      scannedMs: scanned,
      videoDurationMs: duration,
    );
    await _identifications.storeRun(
      run,
      insert: carried.insert,
      deleteIds: carried.deleteIds,
    );
    _scannedMs = scanned;
    _durationMs = duration;
    _width = width;
    _height = height;
    _detectionCount = run.detectionCount;
    // Rows first: a crop or embedding that fails to write leaves a row the
    // next opening sees as incomplete, and scans again.
    final byId = {for (final n in named) n.identification.id: n};
    await _embeddings.delete(carried.deleteIds);
    await _crops.delete(_item.id, carried.deleteIds);
    await _embeddings.put({
      for (final i in carried.insert) i.id: ?byId[i.id]!.embedding,
    }, classifierId: manifest.classifier.embeddingId);
    for (final i in carried.insert) {
      if (byId[i.id]!.cropJpeg case final jpeg?) {
        await _crops.write(_item.id, i.id, jpeg);
      }
    }
    await _crops.markAnalysed(_item.id);
    return true;
  }

  /// Crops and embeds each track's best moments in batches, and names each
  /// track from the average of its moments' embeddings. A track none of
  /// whose moments could be cropped is left out. When [stopping], only one
  /// batch is named, the tracks with no name yet and then the longest
  /// first; the others are kept without naming them. Null when the file
  /// cannot be opened.
  Future<List<_Stored>?> _nameTracks(
    List<TrackedAnimal> all, {
    required bool stopping,
  }) async {
    if (all.isEmpty) return const [];
    var closed = all;
    var picks = [for (final track in all) bestMoments(track)];
    final left = <_Stored>[];
    if (stopping) {
      bool named(TrackedAnimal t) =>
          !(_continuing[t.storedId]?.isPending ?? true);
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
        if (moments + picks[k].length > embedBatch) break;
        moments += picks[k].length;
        chosen.add(k);
      }
      final now = _now().toUtc();
      left.addAll([
        for (final k in order.skip(chosen.length)) _unnamed(all[k], now),
      ]);
      closed = [for (final k in chosen) all[k]];
      picks = [for (final k in chosen) picks[k]];
    }
    final moments = [
      for (final chosen in picks)
        for (final p in chosen) VisionMoment(ms: p.ms, box: p.detection.box),
    ];
    final crops = <VisionMomentCrop?>[];
    for (var at = 0; at < moments.length; at += embedBatch) {
      if (!stopping && !_keepGoing()) throw const VideoScanStopped();
      _embedCalls++;
      final batch = await _call(
        (path) => _engine.embedMoments(
          path: path,
          moments: moments.sublist(
            at,
            math.min(at + embedBatch, moments.length),
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
      if (usable.isEmpty) continue;
      final embedding = _averaged([for (final u in usable) u.crop.embedding]);
      if (embedding == null) continue;
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
        ),
      ...left,
    ];
  }

  /// [track], stored without naming it as the scan stops. A fish already
  /// named keeps its name and gains the path it swam since; any other is
  /// kept to be named when the scan resumes ([MediaIdentification.isPending]).
  _Stored _unnamed(TrackedAnimal track, DateTime now) {
    final row = _continuing[track.storedId];
    if (row != null && !row.isPending) {
      return (
        identification: row.copyWith(
          endMs: () => track.endMs,
          path: track.samples,
        ),
        embedding: null,
        cropJpeg: null,
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
  ) {
    final flags = namingFlags(result, naming);
    final storedId = track.storedId;
    final row = storedId == null ? null : _continuing[storedId];
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
    );
  }

  /// [call] on the file, loading the models again once if the system freed
  /// them. Null when the file cannot be opened.
  Future<T?> _call<T>(Future<T> Function(String path) call) async {
    try {
      return await _reader(call);
    } on VisionEngineException catch (e) {
      final reload = _reload;
      if (e.code != VisionEngineException.notLoaded || reload == null) {
        rethrow;
      }
      await reload();
      return _reader(call);
    }
  }

  /// The mean of [embeddings], each first scaled to unit length, itself
  /// scaled to unit length. Null when they disagree in length or sum to
  /// nothing.
  static Float32List? _averaged(List<Float32List> embeddings) {
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

  /// [ms] of video as m:ss, for the memory readout's stage names.
  static String _clock(int ms) =>
      '${ms ~/ 60000}:${(ms % 60000 ~/ 1000).toString().padLeft(2, '0')}';
}
