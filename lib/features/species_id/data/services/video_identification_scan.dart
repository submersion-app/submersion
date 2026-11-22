import 'dart:math' as math;
import 'dart:typed_data';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/services/memory_readout.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/naming_bars.dart';
import 'package:submersion/features/species_id/domain/entities/scanned_ranges.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/track_sample.dart';
import 'package:submersion/features/species_id/domain/entities/video_detections.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/species_namer.dart';
import 'package:submersion/features/species_id/domain/services/video_identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/video_scan_order.dart';
import 'package:submersion/features/species_id/domain/services/video_tracker.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

part 'video_identification_scan_naming.dart';

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
/// named from, or kept without them; with the track it was stored from and
/// the worth of the moment it is named from (null while unnamed).
typedef _Stored = ({
  MediaIdentification identification,
  Float32List? embedding,
  Uint8List? cropJpeg,
  TrackedAnimal? track,
  double? worth,
});

/// Thrown by [VideoIdentificationScan.runChunk] when told to stop between
/// two batches of pass 2. Nothing of that chunk is stored.
class VideoScanStopped implements Exception {
  const VideoScanStopped();
}

/// The diver moved the scan elsewhere while a chunk ran: nothing of it is
/// stored, and it is scanned again later (issue #4709).
class _ChunkDropped implements Exception {
  const _ChunkDropped();
}

/// One video's scan, a chunk at a time (issues #4675 and #4709).
///
/// Each chunk runs the detector over a stretch of video (pass 1), links the
/// boxes into tracks, crops and embeds the best moments of the tracks to
/// name (pass 2), and stores them with the stretches scanned. The scan
/// follows where the diver is watching: [nextVideoChunk] picks each chunk
/// from the stretches already scanned and the latest [PlayheadReport], and
/// a report that moves the scan drops the running chunk. A fish still in
/// view at a chunk's end is named once seen for [earlyNamingMs], and named
/// again only on a clearly better view. A scan stopped between chunks loses
/// nothing: the next one resumes from the stored stretches.
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
    PlayheadReport? Function()? playhead,
    void Function(int sequence)? onFollowed,
    Future<void> Function()? reload,
    bool Function()? keepGoing,
    MemoryReadout? memoryReadout,
    this.chunkMs = 10000,
    this.firstChunkMs = 2000,
    this.sampleIntervalMs = videoSampleIntervalMs,
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
       _playhead = playhead ?? _nowhere,
       _onFollowed = onFollowed,
       _memoryReadout = memoryReadout,
       _generation = generation ?? databaseGeneration(),
       _scanned = resumeFrom?.scanned ?? const ScannedRanges(),
       _durationMs = resumeFrom?.videoDurationMs,
       _width = resumeFrom?.imageWidth ?? 0,
       _height = resumeFrom?.imageHeight ?? 0,
       _detectionCount = resumeFrom?.detectionCount ?? 0,
       _runId = resumeFrom?.runId,
       _analysedBy = resumeFrom?.analysedBy,
       _carry = [...carry];

  /// The run this scan continues and the device that made it (issue
  /// #4876), written on every chunk: a run another device stored meanwhile
  /// must not take over this scan's rows, so the last device to write wins
  /// the video, as it does a photo.
  final String? _runId;
  final String? _analysedBy;

  /// Video per chunk once the scan is under way.
  final int chunkMs;

  /// Video in the first chunk after opening or a move, so the first labels
  /// come soon (issue #4709).
  final int firstChunkMs;
  final int sampleIntervalMs;

  /// Moments cropped and embedded per engine call. A stop waits for at
  /// most one batch: about a second on a Mac, longer on a phone.
  static const int embedBatch = 12;

  static bool _always() => true;
  static PlayheadReport? _nowhere() => null;

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

  /// Where the diver last moved the playhead, if anywhere.
  final PlayheadReport? Function() _playhead;

  /// Told the [PlayheadReport.sequence] of each report the scan follows.
  final void Function(int sequence)? _onFollowed;

  /// The [PlayheadReport.sequence] of the last report followed.
  var _honoured = 0;

  /// Engine calls made by pass 2, so a chunk that embedded nothing logs no
  /// pass 2 reading.
  var _embedCalls = 0;

  /// A chunk failed part-way: what the tracker holds may include frames
  /// that were never stored, so nothing more is stored from it.
  var _broken = false;

  /// The logbook the scan belongs to (by default the one open when it was
  /// made): nothing is stored once another one has opened.
  final int _generation;

  /// Follows the animals through one run of consecutive chunks.
  var _tracker = VideoTracker();

  /// Where the current run of consecutive chunks has got; null before the
  /// first chunk of a run.
  int? _runEndMs;

  /// Stored rows the tracker is continuing, by id.
  final _continuing = <String, MediaIdentification>{};

  /// Decided or claimed tracks of a previous scan, waiting to be carried
  /// to the fresh tracks that follow the same animal.
  List<MediaIdentification> _carry;

  ScannedRanges _scanned;
  int? _durationMs;
  int _width;
  int _height;
  int _detectionCount;

  /// 0 to 1: how much of the video is scanned, in whatever order.
  double get progress {
    final duration = _durationMs;
    if (duration == null) return 0;
    if (duration <= 0) return 1;
    return math.min(1, _scanned.coveredMs(duration) / duration);
  }

  /// The latest report not yet followed, or null.
  PlayheadReport? _newReport() {
    final report = _playhead();
    return report != null && report.sequence > _honoured ? report : null;
  }

  /// Whether a report since the chunk began points the scan away from
  /// [running].
  bool _moved(VideoChunk running) {
    final report = _newReport();
    return report != null &&
        reportMovesScan(
          report,
          scanned: _scanned,
          durationMs: _durationMs,
          running: running,
        );
  }

  /// Scans the next chunk and stores what it found. Returns whether more of
  /// the video remains. A chunk the diver moved the scan away from stores
  /// nothing and returns true. Returns false having stored nothing when the
  /// file cannot be opened or another logbook opened meanwhile. Engine
  /// failures are thrown to the caller.
  Future<bool> runChunk() async {
    if (_broken) return false;
    final report = _newReport();
    final chunk = nextVideoChunk(
      scanned: _scanned,
      durationMs: _durationMs,
      runEndMs: _runEndMs,
      report: report,
      chunkMs: chunkMs,
      firstChunkMs: firstChunkMs,
    );
    if (report != null) {
      _honoured = report.sequence;
      _onFollowed?.call(report.sequence);
    }
    if (chunk == null) return false;
    if (chunk.startMs != _runEndMs && !await _startRun(chunk.startMs)) {
      return false;
    }
    final from = chunk.startMs;
    final detections = await _call(
      (path) => _engine.detectVideo(
        path: path,
        startMs: from,
        endMs: chunk.endMs,
        sampleIntervalMs: sampleIntervalMs,
      ),
    );
    if (detections == null || _databaseGeneration() != _generation) {
      return false;
    }
    final duration = math.max(0, detections.durationMs);
    final to = math.min(chunk.endMs, duration);
    String range() => '(${_clock(from)} to ${_clock(to)})';
    _memoryReadout?.recordLater(() => 'pass 1 ${range()}');
    _durationMs = duration;
    if (to <= from && duration > 0) {
      // Past the end (a report beyond a length not known yet): nothing
      // here, so the next chunk fills from the start.
      _runEndMs = null;
      return !_scanned.isComplete(duration);
    }
    final running = (startMs: from, endMs: to);
    if (_moved(running)) return true;
    final embedsBefore = _embedCalls;
    // Nothing of a chunk is stored until its pass 2 is done: a stop, a
    // move or a failure there puts the tracks back as they were where it
    // began, so the next chunk, or [finish], starts from what is stored.
    final before = _tracker.save();
    final _Chunk found;
    final List<_Stored>? named;
    try {
      found = await _feed(detections.frames, to: to, duration: duration);
      named = await _nameTracks(
        found.toName,
        stopping: false,
        rows: found.rows,
        dropped: () => _moved(running),
      );
    } on _ChunkDropped {
      _tracker.restore(before);
      return true;
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
    final now = _now().toUtc();
    final bool stored;
    try {
      stored = await _store(
        [...named, for (final t in found.toKeep) _unnamed(t, now, found.rows)],
        rows: found.rows,
        ranges: _scanned.add(from, to),
        duration: duration,
        width: detections.width,
        height: detections.height,
        joinedAway: found.joinedAway,
      );
    } on Object {
      // Part of it may be written: nothing more is stored from this scan.
      _broken = true;
      rethrow;
    }
    if (!stored) return false;
    _runEndMs = to;
    return !_scanned.isComplete(duration);
  }

  /// Feeds a chunk's [frames] to the tracker and works out what to store:
  /// the tracks it closed, those still in view for [earlyNamingMs], and at
  /// the end of the video or where it meets a stretch scanned earlier, all
  /// of them (joined across the seam).
  Future<_Chunk> _feed(
    List<FrameDetections> frames, {
    required int to,
    required int duration,
  }) async {
    final closed = [for (final frame in frames) ..._tracker.add(frame)];
    final rows = {..._continuing};
    final forced = <TrackedAnimal, bool>{};
    final joinedAway = <String, String>{};
    if (to >= duration) {
      closed.addAll(_tracker.closeAll());
    } else if (_scanned.stretchStartAfter(to - 1) == to) {
      final joins = await _joinSeam(to, rows, forced, joinedAway);
      closed.addAll([
        for (final t in _tracker.closeAll())
          if (!joins.containsKey(t)) t,
        ...joins.values,
      ]);
    }
    final early = [
      for (final t in _tracker.openTracks)
        if (t.endMs - t.startMs >= earlyNamingMs) t,
    ];
    final toName = <TrackedAnimal>[];
    final toKeep = <TrackedAnimal>[];
    for (final t in [...closed, ...early]) {
      if (!t.hasNewPoints) continue;
      (forced[t] ?? namesNow(t) ? toName : toKeep).add(t);
    }
    return (toName: toName, toKeep: toKeep, rows: rows, joinedAway: joinedAway);
  }

  /// Where the chunk ends at [seamMs], the start of a stretch scanned
  /// earlier: each open track that is the same animal as a stored track
  /// starting there becomes one track under the stored row's id, by open
  /// track. [rows] gains the stored rows joined; [forced] says whether each
  /// joined track is named again (a clearly better view, or not named
  /// yet); [joinedAway] maps each joined row to the earlier row it
  /// replaces.
  Future<Map<TrackedAnimal, TrackedAnimal>> _joinSeam(
    int seamMs,
    Map<String, MediaIdentification> rows,
    Map<TrackedAnimal, bool> forced,
    Map<String, String> joinedAway,
  ) async {
    final carried = {for (final c in _carry) c.id};
    final stored = [
      for (final row in await _identifications.forMedia(_item.id))
        if (!carried.contains(row.id)) row,
    ];
    final byId = {for (final row in stored) row.id: row};
    final pairs = seamJoins(
      open: _tracker.openTracks,
      openRows: byId,
      stored: stored,
      seamMs: seamMs,
      maxGapMs: (_tracker.maxGapSamples + 1) * sampleIntervalMs,
      link: _tracker.link,
    );
    final joins = <TrackedAnimal, TrackedAnimal>{};
    for (final (:open, :later) in pairs) {
      final laterWorth = later.isPending ? null : storedWorth(later);
      final joined = TrackedAnimal(
        [
          ...open.points,
          for (final s in later.path)
            (
              ms: s.ms,
              detection: DetectedBox(box: s.box, score: later.detectorScore),
            ),
        ],
        storedId: later.id,
        pending: true,
        namedWorth: laterWorth,
      );
      forced[joined] =
          laterWorth == null ||
          open.points.any(
            (p) => momentWorth(p.detection) >= betterViewMargin * laterWorth,
          );
      rows[later.id] = later;
      final earlier = open.storedId;
      if (earlier != null && earlier != later.id) {
        joinedAway[later.id] = earlier;
      }
      joins[open] = joined;
    }
    return joins;
  }

  /// Starts a run of consecutive chunks at [startMs]: the open tracks of
  /// the run before are stored as when the scan stops, and the stored
  /// tracks that end just before [startMs] are taken up again, so an animal
  /// in view there carries on as the same track. Only across scanned video:
  /// a track is never linked over a stretch not scanned yet. One kept
  /// without a name is taken up however long before [startMs] it ended, so
  /// that it is named. False when another logbook opened.
  Future<bool> _startRun(int startMs) async {
    await finish();
    _tracker = VideoTracker();
    _runEndMs = null;
    _continuing.clear();
    if (_broken) return false;
    final rows = await _identifications.forMedia(_item.id);
    if (_databaseGeneration() != _generation) return false;
    final carried = {for (final c in _carry) c.id};
    for (final row in rows) {
      final end = row.endMs;
      if (carried.contains(row.id)) continue;
      if (!row.isTrack || row.path.isEmpty || end == null || end > startMs) {
        continue;
      }
      if (!_scanned.coversRange(end, startMs)) continue;
      final missed = ((startMs - end) / sampleIntervalMs).round() - 1;
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
          namedWorth: row.isPending ? null : storedWorth(row),
        ),
        missed: math.max(0, math.min(missed, _tracker.maxGapSamples)),
      );
    }
    return true;
  }

  /// Closes the tracks still open (the scan is stopping, or moving) and
  /// stores them, without adding to the stretches scanned. With [naming],
  /// as many of those to name are named as one batch of moments takes, so
  /// stopping is never slow. The rest, and all of them without [naming] or
  /// when naming fails, are stored unnamed and named when the scan comes
  /// back; a fish already named keeps its name.
  Future<void> finish({bool naming = true}) async {
    if (_broken || _databaseGeneration() != _generation) return;
    final closed = [
      for (final t in _tracker.closeAll())
        if (t.hasNewPoints) t,
    ];
    final duration = _durationMs;
    if (closed.isEmpty || duration == null) return;
    final rows = {..._continuing};
    final toName = [
      for (final t in closed)
        if (namesNow(t)) t,
    ];
    List<_Stored>? named;
    if (naming) {
      try {
        named = await _nameTracks(toName, stopping: true, rows: rows);
      } on Object {
        // Out of the foreground, too hot, or the file gone: the tracks are
        // still kept, unnamed.
      }
    }
    final now = _now().toUtc();
    await _store(
      [
        ...named ?? [for (final t in toName) _unnamed(t, now, rows)],
        for (final t in closed)
          if (!toName.contains(t)) _unnamed(t, now, rows),
      ],
      rows: rows,
      ranges: _scanned,
      duration: duration,
      width: _width,
      height: _height,
    );
  }

  /// Stores [named] and the run with [ranges] scanned. Rows already stored
  /// ([rows]) keep what the diver said on them as it is stored now, under
  /// [keepDecisionOnRename], read in the same transaction as the write so a
  /// decision made meanwhile is never written over; [joinedAway] maps a row
  /// joined across a seam to the earlier row it replaces, which is deleted
  /// once the joined row is stored. False when nothing was stored.
  Future<bool> _store(
    List<_Stored> named, {
    required Map<String, MediaIdentification> rows,
    required ScannedRanges ranges,
    required int duration,
    required int width,
    required int height,
    Map<String, String> joinedAway = const {},
  }) async {
    if (_databaseGeneration() != _generation) return false;
    final continuing = [
      for (final n in named)
        if (rows.containsKey(n.identification.id)) n.identification,
    ];
    final manifest = _pack.pack.manifest;
    late List<MediaIdentification> inserted;
    late List<String> deleted;
    late List<String> away;
    late List<MediaIdentification> carryLeft;
    late MediaIdentificationRun run;
    final wrote = await _identifications.storeRunAfterReading(
      _item.id,
      read: named.isNotEmpty && (_carry.isNotEmpty || continuing.isNotEmpty),
      build: (stored) async {
        var carry = _carry;
        var continued = continuing;
        if (stored != null) {
          // As stored now: the diver may have decided or named a fish since
          // the scan read the rows, or cleared them.
          final current = {for (final i in stored) i.id: i};
          final tracks = {for (final n in named) n.identification.id: n.track};
          carry = [for (final c in carry) ?current[c.id]];
          continued = [
            for (final c in continuing)
              if (current[c.id] case final now?)
                if (_undoneJoin(now, current[joinedAway[c.id]], tracks[c.id])
                    case final earlier?)
                  earlier
                else
                  keepDecisionOnRename(
                    before: _sayOf(now, current[joinedAway[c.id]]),
                    renamed: c,
                  ),
          ];
        }
        // A continued track keeps its own row and what was said on it. One
        // with nothing said on it can still take over a decision from a
        // previous scan, as a new one can: named while still in view, it
        // may only now reach far enough to show it is that animal.
        final unsaid = [
          for (final c in continued)
            if (!c.saidByDiver) c,
        ];
        // One with something said on it takes up the parts of its fish
        // said the same on that this chunk reached (issue #4729).
        final found = carryTrackDecisions(
          decided: carry,
          fresh: [
            for (final n in named)
              if (!rows.containsKey(n.identification.id)) n.identification,
            ...unsaid,
          ],
          kept: [
            for (final c in continued)
              if (c.saidByDiver) c,
          ],
        );
        // An earlier part goes only when its joined row is stored.
        away = [for (final c in continued) ?joinedAway[c.id]];
        inserted = [
          ...found.insert,
          for (final c in continued)
            if (c.saidByDiver) c,
        ];
        deleted = [...found.deleteIds, ...away];
        carryLeft = [
          for (final c in carry)
            if (!found.deleteIds.contains(c.id)) c,
        ];
        // A dismissal brought back that the whole scan has not found again
        // is only an old guess (issue #4825): it goes. A name the diver gave
        // it stays theirs.
        final stale = ranges.isComplete(duration)
            ? [
                for (final c in carryLeft)
                  if (c.reopened && c.claimedSpeciesId == null) c.id,
              ]
            : const <String>[];
        if (stale.isNotEmpty) {
          deleted = [...deleted, ...stale];
          carryLeft = [
            for (final c in carryLeft)
              if (!stale.contains(c.id)) c,
          ];
        }
        // The rows were read above: another logbook may have opened since.
        if (_databaseGeneration() != _generation) return null;
        run = MediaIdentificationRun(
          mediaId: _item.id,
          packVersion: manifest.packVersion,
          detectorId: videoRunDetectorId(manifest.detectorSetId),
          classifierId: manifest.classifier.embeddingId,
          locationCell: _cell,
          analysedAt: _now().toUtc(),
          imageWidth: width,
          imageHeight: height,
          // The continued rows in found.insert are counted already.
          detectionCount: math.max(
            0,
            _detectionCount +
                found.insert.length -
                unsaid.length -
                found.deleteIds.length -
                away.length -
                stale.length,
          ),
          scannedMs: ranges.prefixEndMs,
          videoDurationMs: duration,
          scannedRanges: ranges,
          analysedBy: _analysedBy,
          runId: _runId,
          namingBars: NamingBars.fromNaming(manifest.naming),
        );
        return (run: run, insert: inserted, deleteIds: deleted);
      },
    );
    if (!wrote) return false;
    _carry = carryLeft;
    _scanned = ranges;
    _durationMs = duration;
    _width = width;
    _height = height;
    _detectionCount = run.detectionCount;
    _settle(named, inserted, away);
    // Rows first: a crop or embedding that fails to write leaves a row the
    // next opening sees as incomplete, and scans again.
    // An earlier part kept by an undone join is not among [named]: its
    // embedding and crop stay as they are.
    final byId = {for (final n in named) n.identification.id: n};
    await _embeddings.delete(deleted);
    await _crops.delete(_item.id, deleted);
    await _embeddings.put({
      for (final i in inserted) i.id: ?byId[i.id]?.embedding,
    }, classifierId: manifest.classifier.embeddingId);
    for (final i in inserted) {
      if (byId[i.id]?.cropJpeg case final jpeg?) {
        await _crops.write(_item.id, i.id, jpeg, named: isNamed(i));
      }
    }
    await _crops.markAnalysed(_item.id);
    return true;
  }

  /// A join across a seam undone because the diver, while the chunk was
  /// named, said something on [later] or [earlier] (both as stored now)
  /// that differs from the other: [earlier] with the path [joined] followed
  /// before [later] starts, to be written in place of the joined row, which
  /// leaves [later] as it is. Null when the join stands.
  static MediaIdentification? _undoneJoin(
    MediaIdentification later,
    MediaIdentification? earlier,
    TrackedAnimal? joined,
  ) {
    final from = later.startMs;
    if (earlier == null || joined == null || from == null) return null;
    if (!saidDifferently(later, earlier)) return null;
    final path = [
      for (final p in joined.points)
        if (p.ms < from) TrackSample(ms: p.ms, box: p.detection.box),
    ];
    if (path.isEmpty) return earlier;
    return earlier.copyWith(
      startMs: () => path.first.ms,
      endMs: () => path.last.ms,
      path: path,
    );
  }

  /// What the diver said on [row] or, when nothing was said on it, on the
  /// [earlier] part it was joined to across a seam.
  static MediaIdentification _sayOf(
    MediaIdentification row,
    MediaIdentification? earlier,
  ) {
    if (earlier == null || row.saidByDiver || !earlier.saidByDiver) {
      return row;
    }
    return earlier;
  }

  /// After a store: the tracks still open that were stored count their
  /// points as stored, under their rows' ids, and those rows are what they
  /// continue from now on. Rows of tracks that closed are not kept.
  void _settle(
    List<_Stored> named,
    List<MediaIdentification> inserted,
    List<String> away,
  ) {
    final rows = {for (final i in inserted) i.id: i};
    for (final id in away) {
      _continuing.remove(id);
    }
    final open = _tracker.openTracks;
    for (final n in named) {
      final track = n.track;
      final id = n.identification.id;
      final row = rows[id];
      if (track == null || row == null) continue;
      if (!open.any((t) => identical(t, track))) {
        _continuing.remove(id);
        continue;
      }
      _continuing[id] = row;
      _tracker.markStored(track, storedId: id, namedWorth: n.worth);
    }
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

  /// [ms] of video as m:ss, for the memory readout's stage names.
  static String _clock(int ms) =>
      '${ms ~/ 60000}:${(ms % 60000 ~/ 1000).toString().padLeft(2, '0')}';
}

/// What one chunk stores: the tracks to name now and those to keep as
/// they are named, the stored rows they continue, and the rows joined
/// across a seam to the earlier row each replaces.
typedef _Chunk = ({
  List<TrackedAnimal> toName,
  List<TrackedAnimal> toKeep,
  Map<String, MediaIdentification> rows,
  Map<String, String> joinedAway,
});
