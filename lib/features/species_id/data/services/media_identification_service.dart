import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/pack/species_pack_store.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/region_grid.dart';
import 'package:submersion/features/species_id/domain/services/species_namer.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

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
    required Future<List<TaggedSpecies>> Function(String mediaId) taggedSpecies,
    required bool Function() enabled,
    int Function()? databaseGeneration,
    DateTime Function()? now,
    String Function()? newId,
    Duration idleUnload = const Duration(seconds: 60),
  }) : _engine = engine,
       _loadPack = loadPack,
       _identifications = identifications,
       _embeddings = embeddings,
       _crops = crops,
       _resolveImage = resolveImage,
       _taggedSpecies = taggedSpecies,
       _enabled = enabled,
       _databaseGeneration =
           databaseGeneration ?? (() => DatabaseService.instance.generation),
       _now = now ?? DateTime.now,
       _newId = newId ?? const Uuid().v4,
       _idleUnload = idleUnload;

  final VisionEngine _engine;
  final Future<LoadedPack?> Function() _loadPack;
  final MediaIdentificationRepository _identifications;
  final IdentificationEmbeddingRepository _embeddings;
  final IdentificationCropStore _crops;
  final Future<IdentificationImage?> Function(MediaItem) _resolveImage;
  final Future<List<TaggedSpecies>> Function(String) _taggedSpecies;
  final bool Function() _enabled;

  /// Moves when another logbook is opened: what an analysis found for the
  /// one it started in is then dropped, not stored in the new one.
  final int Function() _databaseGeneration;
  final DateTime Function() _now;
  final String Function() _newId;
  final Duration _idleUnload;
  final _log = LoggerService.forClass(MediaIdentificationService);

  /// Insertion-ordered (a map literal is a LinkedHashMap): the newest
  /// request is last.
  final _waiting = <String, _Job>{};
  _Job? _running;
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
  bool cancelPending(String mediaId) {
    final job = _waiting.remove(mediaId);
    if (job == null) return false;
    job.done.complete();
    _changed();
    return true;
  }

  bool isBusy(String mediaId) =>
      _running?.item.id == mediaId || _waiting.containsKey(mediaId);

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
        await _identifications.updateIdentifications(changed);
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
        await _identifications.updateIdentifications(changed);
      }
    } on Object catch (e) {
      _log.debug('Could not dismiss suggestions of $mediaId', error: e);
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
      await _running!.done.future;
    }
  }

  /// Runs [change] (installing, updating or removing the pack) with no
  /// analysis under way: waits for the one running, holds queued requests,
  /// frees the models, runs [change], then forgets the cached pack and lets
  /// the queue go on. An analysis is never left using files [change]
  /// deletes, nor started on a pack half replaced.
  Future<T> changePack<T>(Future<T> Function() change) async {
    _paused++;
    try {
      while (_running != null) {
        await _running!.done.future;
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
    await _running?.done.future;
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
    unawaited(
      _process(job).whenComplete(() {
        _running = null;
        job.done.complete();
        _changed();
        _pump();
      }),
    );
  }

  void _changed() {
    if (!_activity.isClosed) _activity.add(null);
  }

  Future<void> _process(_Job job) async {
    final item = job.item;
    final generation = _databaseGeneration();
    try {
      if (!_enabled() || item.mediaType != MediaType.photo) return;
      if (await _engine.availability() != VisionAvailability.available) return;
      final pack = _pack ??= await _loadPack();
      if (pack == null) return;
      final manifest = pack.pack.manifest;
      final location = job.location;
      final cell = location == null
          ? null
          : RegionGrid(
              cellDegrees: manifest.region.cellDegrees,
            ).cellOf(location.latitude, location.longitude);

      final run = await _identifications.runFor(item.id);
      final stored = await _identifications.forMedia(item.id);
      final undecided = [
        for (final i in stored)
          if (i.decision == IdentificationDecision.undecided) i,
      ];
      // A suggestion's crop must be here. A decided identification's crop
      // is restored by analysing once on this device (after a restore onto
      // a new one); if that analysis could not bring it back, it stays
      // without one rather than the photo being analysed at every opening.
      final cropsPresent =
          await _crops.allPresent(item.id, [for (final i in undecided) i.id]) &&
          (undecided.length == stored.length ||
              await _crops.wasAnalysedHere(item.id));
      final storedEmbeddings = run == null
          ? const <String, Float32List>{}
          : await _embeddings.get([
              for (final i in undecided) i.id,
            ], classifierId: manifest.classifier.id);
      final action = decideRefresh(
        run: run,
        packVersion: manifest.packVersion,
        detectorId: manifest.detector.id,
        classifierId: manifest.classifier.id,
        cell: cell,
        cropsPresent: cropsPresent,
        embeddingsPresent: storedEmbeddings.length == undecided.length,
      );
      switch (action) {
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
      if (_databaseGeneration() != generation) return;
      await reconcile(item.id);
    } on Object catch (e) {
      _log.debug('Could not identify marine life in ${item.id}', error: e);
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
    final results = await _name(pack, [
      for (final i in undecided)
        (embedding: embeddings[i.id]!, shorterSide: i.boxShorterSide),
    ], cell);
    final changed = [
      for (var k = 0; k < undecided.length; k++)
        undecided[k].copyWith(
          openScore: results[k].openScore,
          candidates: results[k].candidates,
          locationLimited: results[k].locationLimited,
          suggestable: results[k].suggestable,
        ),
    ];
    if (_databaseGeneration() != generation) return;
    await _identifications.updateIdentifications(
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
    final results = await _name(pack, [
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
          openScore: results[k].openScore,
          candidates: results[k].candidates,
          locationLimited: results[k].locationLimited,
          suggestable: results[k].suggestable,
          decision: IdentificationDecision.undecided,
          createdAt: now,
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
        detectorId: manifest.detector.id,
        classifierId: manifest.classifier.id,
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
    }, classifierId: manifest.classifier.id);
    for (final i in carried.insert) {
      await _crops.write(item.id, i.id, byId[i.id]!.cropJpeg);
    }
    await _crops.markAnalysed(item.id);
  }

  /// Runs the models over [image]. Models the system unloaded behind the
  /// service's back (an iOS memory warning) are loaded again, once.
  Future<VisionAnalysis> _analyseImage(
    LoadedPack pack,
    IdentificationImage image,
  ) async {
    Future<VisionAnalysis> attempt() async {
      await _ensureLoaded(pack);
      return image.path != null
          ? _engine.analyze(path: image.path)
          : _engine.analyze(bytes: image.bytes);
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
        detectorPath: pack.pack.detectorPath,
        classifierPath: pack.pack.classifierPath,
      ),
    );
    _loadedModels = key;
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
    } on Object catch (e) {
      _log.debug('Could not unload the marine life models', error: e);
    }
  }

  /// Names crops off the UI isolate: with thousands of candidates it is
  /// millions of multiplications a crop.
  static Future<List<NamingResult>> _name(
    LoadedPack pack,
    List<({Float32List embedding, int shorterSide})> crops,
    int? cell,
  ) async {
    if (crops.isEmpty) return const [];
    final manifest = pack.pack.manifest;
    return compute(
      _nameAll,
      _NamingJob(
        candidates: pack.candidates,
        textEmbeddings: pack.textEmbeddings,
        embeddingSize: manifest.classifier.embeddingSize,
        logitScale: manifest.classifier.logitScale,
        naming: manifest.naming,
        regions: pack.regions,
        neighbourCells: manifest.region.neighbourCells,
        crops: crops,
        cell: cell,
      ),
    );
  }
}

class _Job {
  _Job(this.item, this.location, [Completer<void>? done])
    : done = done ?? Completer<void>();

  final MediaItem item;
  final GeoPoint? location;
  final Completer<void> done;

  _Job withLocation(GeoPoint? location) => _Job(item, location, done);
}

class _NamingJob {
  const _NamingJob({
    required this.candidates,
    required this.textEmbeddings,
    required this.embeddingSize,
    required this.logitScale,
    required this.naming,
    required this.regions,
    required this.neighbourCells,
    required this.crops,
    required this.cell,
  });

  final List<PackCandidate> candidates;
  final Float32List textEmbeddings;
  final int embeddingSize;
  final double logitScale;
  final NamingConfig naming;
  final RegionTable regions;
  final int neighbourCells;
  final List<({Float32List embedding, int shorterSide})> crops;
  final int? cell;
}

List<NamingResult> _nameAll(_NamingJob job) {
  final namer = SpeciesNamer(
    candidates: job.candidates,
    textEmbeddings: job.textEmbeddings,
    embeddingSize: job.embeddingSize,
    logitScale: job.logitScale,
    config: job.naming,
    regions: job.regions,
    neighbourCells: job.neighbourCells,
  );
  return [
    for (final crop in job.crops)
      namer.name(
        embedding: crop.embedding,
        boxShorterSide: crop.shorterSide,
        cell: job.cell,
      ),
  ];
}
