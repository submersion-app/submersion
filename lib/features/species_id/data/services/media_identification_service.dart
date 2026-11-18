import 'dart:async';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/crop_naming.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/services/memory_readout.dart';
import 'package:submersion/features/species_id/data/services/video_identification_scan.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/region_grid.dart';
import 'package:submersion/features/species_id/domain/services/species_namer.dart';
import 'package:submersion/features/species_id/domain/services/video_identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

part 'media_identification_video.dart';

/// The image to analyse: a readable file, or its bytes.
class IdentificationImage {
  const IdentificationImage.path(String this.path) : bytes = null;
  const IdentificationImage.bytes(Uint8List this.bytes) : path = null;

  final String? path;
  final Uint8List? bytes;
}

/// Finds the animals in photos as they are opened, names them, and keeps
/// what it found (issue #4668).
///
/// One analysis at a time, newest request first: the photo the diver is
/// looking at now matters more than the one they swiped past. Never throws:
/// a photo that cannot be read or analysed simply has no suggestions, and is
/// tried again the next time it is opened.
class MediaIdentificationService {
  MediaIdentificationService({
    required VisionEngine engine,
    required Future<LoadedPack?> Function() loadPack,
    required MediaIdentificationRepository identifications,
    required IdentificationEmbeddingRepository embeddings,
    required IdentificationCropStore crops,
    required Future<IdentificationImage?> Function(MediaItem item) resolveImage,
    Future<VideoFileReader?> Function(MediaItem item)? resolveVideo,
    required Future<List<TaggedSpecies>> Function(String mediaId) taggedSpecies,
    required bool Function() enabled,
    int Function()? databaseGeneration,
    DateTime Function()? now,
    String Function()? newId,
    Duration idleUnload = const Duration(seconds: 60),
    MemoryReadout? memoryReadout,
  }) : _engine = engine,
       _loadPack = loadPack,
       _identifications = identifications,
       _embeddings = embeddings,
       _crops = crops,
       _resolveImage = resolveImage,
       _resolveVideo = resolveVideo ?? ((_) async => null),
       _taggedSpecies = taggedSpecies,
       _enabled = enabled,
       _databaseGeneration =
           databaseGeneration ?? (() => DatabaseService.instance.generation),
       _now = now ?? DateTime.now,
       _newId = newId ?? const Uuid().v4,
       _idleUnload = idleUnload,
       _memoryReadout = memoryReadout;

  final VisionEngine _engine;
  final Future<LoadedPack?> Function() _loadPack;
  final MediaIdentificationRepository _identifications;
  final IdentificationEmbeddingRepository _embeddings;
  final IdentificationCropStore _crops;
  final Future<IdentificationImage?> Function(MediaItem) _resolveImage;

  /// The file the player opened for a video, or null (issue #4675).
  final Future<VideoFileReader?> Function(MediaItem) _resolveVideo;
  final Future<List<TaggedSpecies>> Function(String) _taggedSpecies;
  final bool Function() _enabled;

  /// Moves when another logbook is opened: what an analysis found for the
  /// one it started in is then dropped, not stored in the new one.
  final int Function() _databaseGeneration;
  final DateTime Function() _now;
  final String Function() _newId;
  final Duration _idleUnload;

  /// Logs memory after each stage, while debug mode is on; null logs
  /// nothing (the iPhone memory test, docs/developer/species-identification.md).
  final MemoryReadout? _memoryReadout;
  final _log = LoggerService.forClass(MediaIdentificationService);

  /// Insertion-ordered (a map literal is a LinkedHashMap): the newest
  /// request is last.
  var _waiting = <String, _Job>{};
  _Job? _running;

  /// Completes when the running job's work is over, whether or not its
  /// callers are answered yet: a video put back in the queue is not.
  Future<void>? _runningEnded;

  /// How far the running video's scan is, 0 to 1.
  double? _videoProgress;
  final _activity = StreamController<void>.broadcast();

  LoadedPack? _pack;
  String? _loadedModels;
  Timer? _idleTimer;
  var _disposed = false;

  /// While above zero a pack change is under way: queued requests wait.
  var _paused = 0;

  /// Queues [item]. Completes when it has been analysed, named again, found
  /// to need nothing, or dropped.
  ///
  /// A [location] that arrives after the first request (the dive was still
  /// loading) is not lost: a queued request takes it, and one already
  /// running is followed by another that names the photo again.
  Future<void> request(MediaItem item, {GeoPoint? location}) {
    if (_disposed) return Future<void>.value();
    final running = _running;
    if (running != null &&
        running.item.id == item.id &&
        (location == null || location == running.location)) {
      // Back on a video whose scan was told to stop: it carries on.
      running.cancelled = false;
      return running.done.future;
    }
    final queued = _waiting.remove(item.id);
    // A later location replaces a queued one; the callers' future stays.
    final job = queued == null
        ? _Job(item, location)
        : queued.withLocation(location ?? queued.location);
    // Re-inserting moves it to the newest end.
    _waiting[item.id] = job;
    _changed();
    _pump();
    return job.done.future;
  }

  /// Drops a queued request that has not started. Returns whether there
  /// was one, so a caller knows the photo was never looked at.
  ///
  /// A video being scanned stops after the chunk in progress (issue
  /// #4675); what was scanned is kept, so this also returns true for it:
  /// it is asked for again, and resumes, when the diver comes back.
  bool cancelPending(String mediaId) {
    final job = _waiting.remove(mediaId);
    if (job != null) {
      job.done.complete();
      _changed();
      return true;
    }
    final running = _running;
    if (running != null &&
        running.item.id == mediaId &&
        running.item.mediaType == MediaType.video &&
        !running.cancelled) {
      running.cancelled = true;
      return true;
    }
    return false;
  }

  bool isBusy(String mediaId) =>
      _running?.item.id == mediaId || _waiting.containsKey(mediaId);

  /// How far the scan of the video [mediaId] has got, 0 to 1, while it is
  /// being scanned; null otherwise.
  double? progressOf(String mediaId) =>
      _running?.item.id == mediaId ? _videoProgress : null;

  /// Ticks whenever a request starts, finishes or is dropped.
  Stream<void> watchActivity() => _activity.stream;

  /// Records accepted and rejected decisions against the photo's current
  /// species tags. Nothing is written if another logbook opened while the
  /// rows and tags were being read.
  Future<void> reconcile(String mediaId) async {
    final generation = _databaseGeneration();
    try {
      final all = await _identifications.forMedia(mediaId);
      if (all.isEmpty) return;
      final changed = reconcileDecisions(
        all,
        await _taggedSpecies(mediaId),
        now: _now().toUtc(),
      );
      if (changed.isNotEmpty && _databaseGeneration() == generation) {
        await _identifications.updateDecisions(changed);
      }
    } on Object catch (e) {
      _log.debug('Could not reconcile identifications of $mediaId', error: e);
    }
  }

  /// The diver dismissed these suggestions; they do not come back. Never
  /// throws, and writes nothing if another logbook opened while it read.
  Future<void> reject(String mediaId, List<String> identificationIds) async {
    final ids = identificationIds.toSet();
    final now = _now().toUtc();
    final generation = _databaseGeneration();
    try {
      final changed = [
        for (final i in await _identifications.forMedia(mediaId))
          if (ids.contains(i.id) &&
              i.decision != IdentificationDecision.rejected)
            i.copyWith(
              decision: IdentificationDecision.rejected,
              decidedAt: now,
            ),
      ];
      if (changed.isNotEmpty && _databaseGeneration() == generation) {
        await _identifications.updateDecisions(changed);
      }
    } on Object catch (e) {
      _log.debug('Could not dismiss suggestions of $mediaId', error: e);
    }
  }

  /// The diver gave the animal [identificationId] on [mediaId] the species
  /// [speciesId] from the frame (issue #4675): held until its tag is
  /// written, when it is accepted as that species whatever the app's
  /// guess. Written at once, in both editing modes; never throws. In a
  /// logbook opened meanwhile the row is not there, so nothing is written.
  Future<void> claim(
    String mediaId,
    String identificationId,
    String speciesId,
  ) async {
    try {
      await _identifications.claim(identificationId, speciesId);
    } on Object catch (e) {
      _log.debug('Could not record the fish named on $mediaId', error: e);
    }
  }

  /// For media deleted for good: drops their queued requests and waits for
  /// the one running, if it is one of them, so that what it found is
  /// written before the caller purges it rather than after.
  Future<void> settle(Iterable<String> mediaIds) async {
    final ids = mediaIds.toSet();
    for (final id in ids) {
      cancelPending(id);
    }
    while (_running != null && ids.contains(_running!.item.id)) {
      await _runningEnded;
    }
  }

  /// Before every identification is cleared: drops every queued request
  /// and waits for the one running, stopping a video's scan after its
  /// chunk, so nothing is written back after the clear.
  Future<void> settleAll() => settle({..._waiting.keys, ?_running?.item.id});

  /// Runs [change] (installing, updating or removing the pack) with no
  /// analysis under way: waits for the one running, holds queued requests,
  /// frees the models, runs [change], then forgets the cached pack and lets
  /// the queue go on. An analysis is never left using files [change]
  /// deletes, nor started on a pack half replaced.
  Future<T> changePack<T>(Future<T> Function() change) async {
    _paused++;
    try {
      while (_running != null) {
        await _runningEnded;
      }
      _pack = null;
      await _unloadModels();
      return await change();
    } finally {
      _pack = null;
      _paused--;
      _pump();
    }
  }

  /// The installed pack changed or was removed.
  Future<void> packChanged() => changePack(() async {});

  Future<void> dispose() async {
    _disposed = true;
    _idleTimer?.cancel();
    for (final job in _waiting.values) {
      job.done.complete();
    }
    _waiting.clear();
    await _runningEnded;
    await _unloadModels();
    await _activity.close();
  }

  void _pump() {
    if (_running != null || _waiting.isEmpty || _disposed || _paused > 0) {
      return;
    }
    final id = _waiting.keys.last;
    final job = _waiting.remove(id)!;
    _running = job;
    _changed();
    final ended = _process(job).then((putBack) {
      _running = null;
      _videoProgress = null;
      // A video stopped for a newer request or a pack change goes to the
      // oldest end, to carry on once the rest is done.
      if (putBack && !_disposed && !_waiting.containsKey(job.item.id)) {
        _waiting = {job.item.id: job, ..._waiting};
      } else {
        job.done.complete();
      }
      _changed();
      _pump();
    });
    _runningEnded = ended;
    unawaited(ended);
  }

  void _changed() {
    if (!_activity.isClosed) _activity.add(null);
  }

  /// Returns whether [job] should go back in the queue: a video stopped
  /// between chunks for other work.
  Future<bool> _process(_Job job) async {
    final item = job.item;
    final generation = _databaseGeneration();
    try {
      final video = item.mediaType == MediaType.video;
      if (!_enabled() || (!video && item.mediaType != MediaType.photo)) {
        return false;
      }
      if (await _engine.availability() != VisionAvailability.available) {
        return false;
      }
      final pack = _pack ??= await _loadPack();
      if (pack == null) return false;
      final manifest = pack.pack.manifest;
      final location = job.location;
      // A position that is not a number (a bad EXIF read) is no position:
      // the photo is named without a region rather than not at all.
      final cell =
          location == null ||
              !location.latitude.isFinite ||
              !location.longitude.isFinite
          ? null
          : RegionGrid(
              cellDegrees: manifest.region.cellDegrees,
            ).cellOf(location.latitude, location.longitude);

      final run = await _identifications.runFor(item.id);
      final stored = await _identifications.forMedia(item.id);
      // A video's fish kept unnamed at a stop have no crop or embedding
      // yet: the resumed scan names them.
      final named = [
        for (final i in stored)
          if (!i.isPending) i,
      ];
      final undecided = [
        for (final i in named)
          if (i.decision == IdentificationDecision.undecided) i,
      ];
      // A suggestion's crop must be here. A decided identification's crop
      // is restored by analysing once on this device (after a restore onto
      // a new one); if that analysis could not bring it back, it stays
      // without one rather than the photo being analysed at every opening.
      final cropsPresent =
          await _crops.allPresent(item.id, [for (final i in undecided) i.id]) &&
          (undecided.length == named.length ||
              await _crops.wasAnalysedHere(item.id));
      // A video's tracks are named again only when their pack or place
      // changed: its embeddings are not read otherwise.
      final namesCurrent =
          video &&
          run != null &&
          run.packVersion == manifest.packVersion &&
          run.locationCell == cell;
      final storedEmbeddings = run == null || namesCurrent
          ? const <String, Float32List>{}
          : await _embeddings.get([
              for (final i in undecided) i.id,
            ], classifierId: manifest.classifier.embeddingId);
      final embeddingsPresent =
          namesCurrent || storedEmbeddings.length == undecided.length;
      var putBack = false;
      if (video) {
        putBack = await _refreshVideo(
          job,
          pack,
          run,
          stored,
          undecided,
          storedEmbeddings,
          cell: cell,
          cropsPresent: cropsPresent,
          embeddingsPresent: embeddingsPresent,
          generation: generation,
        );
      } else {
        switch (decideRefresh(
          run: run,
          packVersion: manifest.packVersion,
          detectorId: manifest.detectorSetId,
          classifierId: manifest.classifier.embeddingId,
          cell: cell,
          cropsPresent: cropsPresent,
          embeddingsPresent: embeddingsPresent,
        )) {
          case RefreshAction.none:
            break;
          case RefreshAction.rename:
            await _rename(
              pack,
              run!,
              undecided,
              storedEmbeddings,
              cell,
              generation,
            );
          case RefreshAction.analyse:
            await _analyse(pack, item, stored, cell, generation);
        }
      }
      if (_databaseGeneration() != generation) return false;
      await reconcile(item.id);
      return putBack;
    } on Object catch (e) {
      _log.debug('Could not identify marine life in ${item.id}', error: e);
      return false;
    }
  }

  Future<void> _rename(
    LoadedPack pack,
    MediaIdentificationRun run,
    List<MediaIdentification> undecided,
    Map<String, Float32List> embeddings,
    int? cell,
    int generation,
  ) async {
    final results = await nameCrops(pack, [
      for (final i in undecided)
        (embedding: embeddings[i.id]!, shorterSide: i.boxShorterSide),
    ], cell);
    final naming = pack.pack.manifest.naming;
    final changed = [
      for (var k = 0; k < undecided.length; k++)
        _named(undecided[k], results[k], naming),
    ];
    if (_databaseGeneration() != generation) return;
    await _identifications.updateNames(
      changed,
      run: run.copyWith(
        packVersion: pack.pack.manifest.packVersion,
        locationCell: () => cell,
      ),
    );
  }

  Future<void> _analyse(
    LoadedPack pack,
    MediaItem item,
    List<MediaIdentification> stored,
    int? cell,
    int generation,
  ) async {
    final image = await _resolveImage(item);
    if (image == null) return;
    final VisionAnalysis analysis;
    try {
      analysis = await _analyseImage(pack, image);
    } finally {
      _armIdleUnload();
    }
    final results = await nameCrops(pack, [
      for (final d in analysis.detections)
        (
          embedding: d.embedding,
          shorterSide: d.pixelWidth < d.pixelHeight
              ? d.pixelWidth
              : d.pixelHeight,
        ),
    ], cell);
    final now = _now().toUtc();
    final fresh = <MediaIdentification>[];
    final byId = <String, VisionDetection>{};
    for (var k = 0; k < analysis.detections.length; k++) {
      final d = analysis.detections[k];
      final id = _newId();
      byId[id] = d;
      fresh.add(
        _named(
          MediaIdentification(
            id: id,
            mediaId: item.id,
            box: IdentificationBox(
              x: d.x,
              y: d.y,
              width: d.width,
              height: d.height,
            ),
            boxPixelWidth: d.pixelWidth,
            boxPixelHeight: d.pixelHeight,
            detectorScore: d.score,
            openScore: 0,
            candidates: const [],
            locationLimited: false,
            suggestable: false,
            decision: IdentificationDecision.undecided,
            createdAt: now,
          ),
          results[k],
          pack.pack.manifest.naming,
        ),
      );
    }
    final carried = carryDecisions(previous: stored, fresh: fresh);
    final manifest = pack.pack.manifest;
    if (_databaseGeneration() != generation) return;
    await _identifications.storeRun(
      MediaIdentificationRun(
        mediaId: item.id,
        packVersion: manifest.packVersion,
        detectorId: manifest.detectorSetId,
        classifierId: manifest.classifier.embeddingId,
        locationCell: cell,
        analysedAt: now,
        imageWidth: analysis.imageWidth,
        imageHeight: analysis.imageHeight,
        detectionCount: carried.keep.length + carried.insert.length,
      ),
      insert: carried.insert,
      deleteIds: carried.deleteIds,
    );
    // Rows first: a crop or embedding that fails to write leaves a row the
    // next opening sees as incomplete, and analyses again.
    await _embeddings.delete(carried.deleteIds);
    await _crops.delete(item.id, carried.deleteIds);
    await _embeddings.put({
      for (final i in carried.insert) i.id: byId[i.id]!.embedding,
    }, classifierId: manifest.classifier.embeddingId);
    for (final i in carried.insert) {
      await _crops.write(item.id, i.id, byId[i.id]!.cropJpeg);
    }
    await _crops.markAnalysed(item.id);
  }

  /// [identification] with what naming found, including the label flags.
  static MediaIdentification _named(
    MediaIdentification identification,
    NamingResult result,
    NamingConfig naming,
  ) {
    final flags = namingFlags(result, naming);
    return identification.copyWith(
      openScore: result.openScore,
      candidates: result.candidates,
      locationLimited: result.locationLimited,
      suggestable: result.suggestable,
      confident: flags.confident,
      specific: flags.specific,
    );
  }

  /// Runs the models over [image]. Models the system unloaded behind the
  /// service's back (an iOS memory warning) are loaded again, once.
  Future<VisionAnalysis> _analyseImage(
    LoadedPack pack,
    IdentificationImage image,
  ) async {
    Future<VisionAnalysis> attempt() async {
      await _ensureLoaded(pack);
      final analysis = image.path != null
          ? await _engine.analyze(path: image.path)
          : await _engine.analyze(bytes: image.bytes);
      _memoryReadout?.recordLater(() => 'photo');
      return analysis;
    }

    try {
      return await attempt();
    } on VisionEngineException catch (e) {
      if (e.code != VisionEngineException.notLoaded) rethrow;
      _loadedModels = null;
      return attempt();
    }
  }

  Future<void> _ensureLoaded(LoadedPack pack) async {
    final key = '${pack.pack.directory}|${pack.pack.manifest.packVersion}';
    if (_loadedModels == key) return;
    await _engine.load(
      VisionModels.fromManifest(
        pack.pack.manifest,
        detectorPaths: pack.pack.detectorPaths,
        classifierPath: pack.pack.classifierPath,
      ),
    );
    _loadedModels = key;
    _memoryReadout?.recordLater(() => 'load');
  }

  /// After a quiet spell the models and the pack's tables are freed. A
  /// spell that ends while a photo is being looked at waits for another.
  void _armIdleUnload() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleUnload, () {
      if (_disposed) return;
      if (_running != null || _waiting.isNotEmpty) {
        _armIdleUnload();
        return;
      }
      _pack = null;
      unawaited(_unloadModels());
    });
  }

  Future<void> _unloadModels() async {
    _idleTimer?.cancel();
    if (_loadedModels == null) return;
    _loadedModels = null;
    try {
      await _engine.unload();
      _memoryReadout?.recordLater(() => 'unload');
    } on Object catch (e) {
      _log.debug('Could not unload the marine life models', error: e);
    }
  }
}

class _Job {
  _Job(this.item, this.location, [Completer<void>? done])
    : done = done ?? Completer<void>();

  final MediaItem item;
  final GeoPoint? location;
  final Completer<void> done;

  /// A video the diver left: its scan stops after the chunk in progress.
  var cancelled = false;

  _Job withLocation(GeoPoint? location) => _Job(item, location, done);
}
