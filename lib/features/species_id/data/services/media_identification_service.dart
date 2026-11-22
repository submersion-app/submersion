import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart' show visibleForTesting;
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
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
import 'package:submersion/features/species_id/domain/entities/naming_bars.dart';
import 'package:submersion/features/species_id/domain/entities/naming_level.dart';
import 'package:submersion/features/species_id/domain/entities/species_pack_manifest.dart';
import 'package:submersion/features/species_id/domain/entities/vision_analysis.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/naming_levels.dart';
import 'package:submersion/features/species_id/domain/services/region_grid.dart';
import 'package:submersion/features/species_id/domain/services/species_namer.dart';
import 'package:submersion/features/species_id/domain/services/video_identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/video_scan_order.dart';
import 'package:submersion/features/species_id/domain/services/video_tracker.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

part 'media_identification_fresh.dart';
part 'media_identification_queue.dart';
part 'media_identification_readiness.dart';
part 'media_identification_reads.dart';
part 'media_identification_run_lane.dart';
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
    bool Function()? runEnabled,
    bool Function()? videoRuns,
    int Function()? databaseGeneration,
    DateTime Function()? now,
    String Function()? newId,
    Duration idleUnload = const Duration(seconds: 60),
    MemoryReadout? memoryReadout,
    int firstVideoChunkMs = 2000,
    Future<void> Function(MediaItem item, int generation)? onItemSettled,
    Future<LevelInForce?> Function()? namingLevel,
    NamingLevel Function()? chosenLevel,
    Future<String?> Function()? deviceId,
    String Function()? newRunId,
  }) : _engine = engine,
       _loadPack = loadPack,
       _identifications = identifications,
       _embeddings = embeddings,
       _crops = crops,
       _resolveImage = resolveImage,
       _resolveVideo = resolveVideo ?? ((_) async => null),
       _taggedSpecies = taggedSpecies,
       _enabled = enabled,
       _runEnabled = runEnabled ?? enabled,
       _videoRuns = videoRuns ?? (() => true),
       _databaseGeneration =
           databaseGeneration ?? (() => DatabaseService.instance.generation),
       _now = now ?? DateTime.now,
       _newId = newId ?? const Uuid().v4,
       _idleUnload = idleUnload,
       _memoryReadout = memoryReadout,
       _firstVideoChunkMs = firstVideoChunkMs,
       _onItemSettled = onItemSettled ?? ((_, _) async {}),
       _namingLevel = namingLevel ?? (() async => null),
       _chosenLevel = chosenLevel,
       _deviceId = deviceId ?? syncDeviceIdOrNull,
       _newRunId = newRunId ?? const Uuid().v4;

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

  /// Whether a Find species run is served (issue #4727): the feature, not
  /// the identify-on-open toggle, since the diver asked for the run.
  final bool Function() _runEnabled;

  /// Whether videos are scanned here: not on Linux, which has no video
  /// player, so neither the viewer nor a Find species run reads a video.
  final bool Function() _videoRuns;

  /// Moves when another logbook is opened: what an analysis found for the
  /// one it started in is then dropped, not stored in the new one.
  final int Function() _databaseGeneration;
  final DateTime Function() _now;
  final String Function() _newId;
  final Duration _idleUnload;

  /// Logs memory after each stage, while debug mode is on; null logs
  /// nothing (the iPhone memory test, docs/developer/species-identification.md).
  final MemoryReadout? _memoryReadout;

  /// Called once an item is settled and its decisions reconciled: analysed,
  /// renamed, found to need nothing, or looked at with no model installed.
  /// Auto-apply hangs here (issue #4727), told the logbook the item was
  /// looked at in so it writes nothing once another is open. Its failure
  /// never fails the item.
  final Future<void> Function(MediaItem item, int generation) _onItemSettled;

  /// The naming level the diver chose, as the installed pack names at it,
  /// or null for the pack's own bars (issue #4721).
  final Future<LevelInForce?> Function() _namingLevel;

  /// The level the diver chose (issue #4876), so a run that kept its
  /// pack's naming bars reconciles at it with no pack installed. Null reads
  /// the level from [_namingLevel] alone.
  final NamingLevel Function()? _chosenLevel;

  /// This device's sync id, which a run records as its maker (issue #4876),
  /// or null when it cannot be read: the run then counts as this device's
  /// and is stamped before it first publishes.
  final Future<String?> Function() _deviceId;

  /// A run id, minted when an analysis of a media starts (issue #4876).
  final String Function() _newRunId;

  final _log = LoggerService.forClass(MediaIdentificationService);

  /// Insertion-ordered (a map literal is a LinkedHashMap): the newest
  /// request is last.
  var _waiting = <String, _Job>{};

  /// A Find species run's requests (issue #4727), oldest first: served only
  /// when no viewer request waits, and never dropped by the viewer.
  var _runWaiting = <String, _Job>{};
  _Job? _running;

  /// Completes when the running job's work is over, whether or not its
  /// callers are answered yet: a video put back in the queue is not.
  Future<void>? _runningEnded;

  /// How far the running video's scan is, 0 to 1.
  double? _videoProgress;

  /// Video in a scan's first chunk after opening or a move (issue #4709).
  final int _firstVideoChunkMs;

  /// Where the diver last moved the playhead in each video being watched,
  /// by media id (issue #4709); dropped when the diver leaves the video.
  final _playheads = <String, PlayheadReport>{};
  var _playheadSequence = 0;

  /// The [PlayheadReport.sequence] a scan of each video last followed.
  final _followedPlayheads = <String, int>{};
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
  ///
  /// [byHand] is the diver asking (issue #4825): it runs whether or not
  /// photos are identified on opening. [fresh] is the diver asking for it
  /// again from the start: analysed whatever it needs, dismissals brought
  /// back ([reopenDismissed]), and nothing tagged by the app after it.
  Future<void> request(
    MediaItem item, {
    GeoPoint? location,
    bool byHand = false,
    bool fresh = false,
  }) {
    if (_disposed) return Future<void>.value();
    final running = _running;
    // A fresh request never joins the one running: it starts over after it.
    if (!fresh &&
        running != null &&
        running.item.id == item.id &&
        (location == null || location == running.location)) {
      // Back on a video whose scan was told to stop: it carries on, in a
      // fresh pass if it has already stopped (issue #4872).
      running.cancelled = false;
      // Asked by hand, it runs whether or not media are identified on
      // opening, revived or not.
      if (byHand) running.byHand = true;
      return running.done.future;
    }
    final queued = _waiting.remove(item.id);
    // A later location replaces a queued one; the callers' future stays.
    final job = queued == null
        ? _Job.byViewer(
            item,
            location,
            _databaseGeneration(),
            byHand: byHand || fresh,
            fresh: fresh,
          )
        : queued.withLocation(
            location ?? queued.location,
            _databaseGeneration(),
            byHand: byHand || fresh,
            fresh: fresh,
          );
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
    // A run's scan is the run's to stop (cancelRun), not the viewer's: a
    // diver swiping past a video the run is scanning must not cut it short
    // (issue #4727).
    if (running != null &&
        !running.fromRun &&
        running.item.id == mediaId &&
        running.item.mediaType == MediaType.video &&
        !running.cancelled) {
      running.cancelled = true;
      return true;
    }
    return false;
  }

  /// The diver moved the playhead of the video [mediaId] to [positionMs]:
  /// a seek once it settled, or a pause when [seek] is false (issue #4709).
  /// A scan of that video follows it, now or when it starts; a report for
  /// a video not being scanned waits until it is, or until the diver
  /// leaves it ([forgetPlayhead]).
  ///
  /// A pause after a seek the scan has not followed yet keeps it a seek, so
  /// the move the seek asked for is not lost.
  void followPlayhead(String mediaId, int positionMs, {required bool seek}) {
    if (_disposed) return;
    final previous = _playheads[mediaId];
    final unfollowedSeek =
        previous != null &&
        previous.seek &&
        previous.sequence > (_followedPlayheads[mediaId] ?? 0);
    _playheads[mediaId] = PlayheadReport(
      ms: math.max(0, positionMs),
      seek: seek || unfollowedSeek,
      sequence: ++_playheadSequence,
    );
  }

  /// The diver left the video [mediaId]: its playhead report is dropped, so
  /// a later opening starts from the beginning. A page covering the viewer
  /// stops the scan ([cancelPending]) but keeps the report.
  void forgetPlayhead(String mediaId) {
    _playheads.remove(mediaId);
    _followedPlayheads.remove(mediaId);
  }

  /// The latest playhead report for the video [mediaId], or null.
  @visibleForTesting
  PlayheadReport? playheadOf(String mediaId) => _playheads[mediaId];

  bool isBusy(String mediaId) =>
      _running?.item.id == mediaId ||
      _waiting.containsKey(mediaId) ||
      _runWaiting.containsKey(mediaId);

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
      // Which animals a tag may accept follows the naming level. Only
      // decisions are written, so the level-applied flags stay in memory.
      final all = await identificationsAtLevel(
        _identifications,
        mediaId,
        await _namingLevel(),
        chosen: _chosenLevel?.call(),
      );
      if (all.isEmpty) return;
      final changed = reconcileDecisions(
        all,
        await _taggedSpecies(mediaId),
        now: _now().toUtc(),
      );
      if (changed.isNotEmpty && _databaseGeneration() == generation) {
        await _identifications.updateDecisions(changed);
        await _promoteNamed(mediaId, changed);
      }
    } on Object catch (e) {
      _log.debug('Could not reconcile identifications of $mediaId', error: e);
    }
  }

  /// The diver dismissed these suggestions; they come back only when the
  /// diver asks for the item to be analysed again (issue #4825). Never
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
        await _promoteNamed(mediaId, changed);
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
      // Named now: its crop syncs (issue #4876).
      await _crops.promote(mediaId, [identificationId]);
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
      cancelRun(id);
    }
    while (_running != null && ids.contains(_running!.item.id)) {
      await _runningEnded;
    }
  }

  /// Before every identification is cleared: drops every queued request
  /// and waits for the one running, stopping a video's scan after its
  /// chunk, so nothing is written back after the clear.
  Future<void> settleAll() =>
      settle({..._waiting.keys, ..._runWaiting.keys, ?_running?.item.id});

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
    for (final job in [..._waiting.values, ..._runWaiting.values]) {
      job.outcome = RunItemOutcome.skipped;
      job.done.complete();
    }
    _waiting.clear();
    _runWaiting.clear();
    await _runningEnded;
    await _unloadModels();
    await _activity.close();
  }

  void _changed() {
    if (!_activity.isClosed) _activity.add(null);
  }

  /// Returns whether [job] should go back in the queue: a video stopped
  /// between chunks for other work.
  Future<bool> _process(_Job job) async {
    final item = job.item;
    final generation = job.generation;
    // Asked for in a logbook since closed: the item is not this one's.
    if (_databaseGeneration() != generation) {
      job.outcome = RunItemOutcome.skipped;
      return false;
    }
    try {
      final video = item.mediaType == MediaType.video;
      if (!video && item.mediaType != MediaType.photo) {
        job.outcome = RunItemOutcome.skipped;
        return false;
      }
      if (video && !_videoRuns()) {
        job.outcome = RunItemOutcome.skipped;
        return false;
      }
      if (!(job.fromRun || job.byHand ? _runEnabled() : _enabled())) {
        job.outcome = RunItemOutcome.skipped;
        return false;
      }
      if (await _engine.availability() != VisionAvailability.available) {
        job.outcome = RunItemOutcome.failed;
        return false;
      }
      final pack = _pack ??= await _loadPack();
      if (pack == null) {
        // Stored names still count with no model installed (issue #4727).
        if (_databaseGeneration() != generation) return false;
        await reconcile(item.id);
        await _settled(job);
        return false;
      }
      final manifest = pack.pack.manifest;
      final cell = _regionCell(manifest, job.location);

      final run = await _identifications.runFor(item.id);
      final madeHere = await _madeHere(run);
      final stored = await _withoutLeftovers(
        item.id,
        run,
        await _identifications.forMedia(item.id),
        madeHere: madeHere,
        generation: generation,
      );
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
      final cropsPresent = await _cropsPresent(_crops, item.id, named);
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
          madeHere: madeHere,
          generation: generation,
        );
      } else {
        final action = job.fresh
            ? RefreshAction.analyse
            : decideRefresh(
                run: run,
                packVersion: manifest.packVersion,
                detectorId: _runDetectorId(manifest, video: false),
                classifierId: manifest.classifier.embeddingId,
                cell: cell,
                cropsPresent: cropsPresent,
                embeddingsPresent: embeddingsPresent,
                madeHere: madeHere,
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
            await _analyse(pack, job, stored, cell, generation);
            job.freshStarted();
        }
      }
      if (_databaseGeneration() != generation) return false;
      await reconcile(item.id);
      await _settled(job);
      return putBack;
    } on Object catch (e) {
      _log.debug('Could not identify marine life in ${item.id}', error: e);
      job.outcome = runOutcomeOf(e);
      return false;
    }
  }

  Future<void> _analyse(
    LoadedPack pack,
    _Job job,
    List<MediaIdentification> storedBefore,
    int? cell,
    int generation,
  ) async {
    var stored = storedBefore;
    final item = job.item;
    final image = await (job.resolveImage ?? _resolveImage)(item);
    if (image == null) {
      job.outcome = RunItemOutcome.unreadable;
      return;
    }
    // Another logbook opened while the photo was read: not worth analysing.
    if (_databaseGeneration() != generation) {
      job.outcome = RunItemOutcome.skipped;
      return;
    }
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
    // Dismissals come back only for a photo that was looked at again: an
    // analysis or naming that failed leaves them as they were.
    if (job.fresh) {
      final reopened = await _reopen(job, stored);
      if (reopened == null) return;
      stored = reopened;
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
        analysedBy: await _deviceId(),
        runId: _newRunId(),
        namingBars: NamingBars.fromNaming(manifest.naming),
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
      await _crops.write(
        item.id,
        i.id,
        byId[i.id]!.cropJpeg,
        named: isNamed(i),
      );
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
