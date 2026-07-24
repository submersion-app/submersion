import 'dart:async';
import 'dart:io';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/media_store_policies.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/image_compressor.dart';
import 'package:submersion/features/media_store/data/media_compressor.dart';
import 'package:submersion/features/media_store/data/thumbnail_generator.dart';
import 'package:submersion/features/media_store/data/video_transcoder.dart';
import 'package:submersion/features/media_store/domain/media_backup_status.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

enum UploadOutcome { uploaded, deduplicated, skippedIneligible, failed }

/// Retry delay for an item whose bytes could not be materialized. Chosen to
/// outlast the shortest asset-resolution lockout (24h) so each queue attempt
/// gets a genuine re-resolution rather than a cached refusal.
const Duration _sourceUnavailableRetryAfter = Duration(hours: 25);

/// The six-step upload pipeline (design spec section 9), photos and
/// single-shot transfers in Phase 1. Every step is idempotent: a crash
/// mid-item replays harmlessly because the content key derives from the
/// bytes and the head() dedup check short-circuits completed work.
class MediaUploadPipeline {
  MediaUploadPipeline({
    required MediaRepository mediaRepository,
    required MediaTransferQueueRepository queue,
    required MediaObjectStore store,
    required MediaSourceResolverRegistry registry,
    required MediaCacheStore cache,
    ThumbnailGenerator? thumbnails,
    MediaStorePolicies? policies,
    MediaCompressor? imageCompressor,
    VideoTranscoder? videoTranscoder,
    DateTime Function()? now,
  }) : _mediaRepository = mediaRepository,
       _queue = queue,
       _store = store,
       _registry = registry,
       _cache = cache,
       _thumbnails =
           thumbnails ?? ThumbnailGenerator(registry: registry, cache: cache),
       _policies = policies ?? MediaStorePolicies(),
       _imageCompressor =
           imageCompressor ?? ImageCompressor(registry: registry, cache: cache),
       _videoTranscoder = videoTranscoder,
       _now = now ?? DateTime.now;

  final MediaRepository _mediaRepository;
  final MediaTransferQueueRepository _queue;
  final MediaObjectStore _store;
  final MediaSourceResolverRegistry _registry;
  final MediaCacheStore _cache;
  final ThumbnailGenerator _thumbnails;
  final MediaStorePolicies _policies;
  final MediaCompressor _imageCompressor;
  final VideoTranscoder? _videoTranscoder;
  final DateTime Function() _now;
  final _log = LoggerService.forClass(MediaUploadPipeline);

  /// Connector videos never download their original in v1 (Lightroom spec:
  /// match + thumbnail only). The store carries just the thumb, derived
  /// from the poster rendition the resolver materializes, and
  /// remoteUploadedAt stays null so a future playback phase can tell a
  /// poster frame from a playable original.
  bool _isThumbOnly(MediaItem item) => isThumbOnlyMedia(item);

  Future<UploadOutcome> process(MediaTransferQueueEntry entry) async {
    await _queue.markTransferring(entry.id);
    final item = await _mediaRepository.getMediaById(entry.mediaId);
    if (item == null || !_isEligible(item)) {
      await _queue.markDone(entry.id);
      return UploadOutcome.skippedIneligible;
    }
    final isOverride = entry.overrideLevel != null;
    if (!isOverride) {
      final alreadyUploaded =
          item.remoteUploadedAt != null ||
          item.remoteCompressedUploadedAt != null;
      if (_isThumbOnly(item)
          ? item.remoteThumbUploadedAt != null
          : alreadyUploaded) {
        await _queue.markDone(entry.id);
        return UploadOutcome.deduplicated;
      }
    }

    File? staged;
    CompressionResult? rendition;
    // Freshest resume state and its key, for terminal-failure session
    // abandonment (orphan-prevention spec 5.5): the queue row's copy can
    // lag when this very attempt created the session.
    var latestResumeJson = entry.resumeStateJson;
    String? resumableUploadKey;
    try {
      staged = await _materialize(item);
      if (staged == null) {
        // Resolution failure is rate-limited on a 24h/3d/7d clock of its own,
        // so retrying on the queue's minute-scale ladder would consume the
        // attempt budget without ever re-reaching the gallery.
        await _queue.markFailed(
          entry.id,
          'source unavailable on this device',
          retryAfter: _sourceUnavailableRetryAfter,
        );
        return UploadOutcome.failed;
      }

      final digest = await sha256OfFile(staged);
      // Size can lag the hash: a row synced from another device arrives
      // with contentHash set but contentSizeBytes never stamped locally.
      if (item.contentHash != digest.hash ||
          item.contentSizeBytes != digest.sizeBytes) {
        await _mediaRepository.stampContentIdentity(
          item.id,
          contentHash: digest.hash,
          sizeBytes: digest.sizeBytes,
        );
      }

      // Thumb first (spec section 9 step 5): tiny, so remote devices get
      // something renderable while the original uploads. Best-effort - a
      // thumb failure must never block the original.
      if (item.remoteThumbUploadedAt == null) {
        File? thumb;
        try {
          thumb = await _thumbnails.generateFor(item);
          if (thumb != null) {
            final thumbKey = StoreKeys.thumbKey(digest.hash);
            if (await _store.head(thumbKey) == null) {
              await _store.putFile(thumbKey, thumb, contentType: 'image/jpeg');
            }
            await _mediaRepository.stampRemoteThumbUploaded(
              item.id,
              uploadedAt: _now(),
            );
          }
        } on Exception catch (e) {
          _log.warning('Thumb upload failed for ${item.id}: $e');
        } finally {
          if (thumb != null && await thumb.exists()) {
            await thumb.delete();
          }
        }
      }

      if (_isThumbOnly(item)) {
        await _queue.markDone(entry.id);
        return UploadOutcome.uploaded;
      }

      // Quality branch: a non-Original level uploads a compressed rendition
      // instead of the original. A null rendition (Original level, already
      // under the ceiling, undecodable, or a video with no transcoder in
      // Phase A) falls through to the untouched-original upload below.
      // An override entry forces its chosen level and replaces whatever the
      // store currently holds for this item.
      final hadOriginal = item.remoteUploadedAt != null;
      final hadCompressed = item.remoteCompressedUploadedAt != null;
      // A corrupt or future-enum override string must not fail the upload:
      // fall back to the device's configured level so the item still uploads.
      final level =
          (isOverride ? _tryParseQuality(entry.overrideLevel!) : null) ??
          await _policies.qualityFor(item.mediaType);
      rendition = await _renditionFor(item, staged, level, digest.hash);
      if (rendition != null) {
        final renditionKey = StoreKeys.renditionKey(
          digest.hash,
          ext: rendition.ext,
        );
        // Override forces a rewrite (the key ignores quality, so a level
        // change lands at the same key); otherwise head() dedups.
        final existingRendition = isOverride
            ? null
            : await _store.head(renditionKey);
        if (existingRendition == null) {
          await _store.putFile(
            renditionKey,
            rendition.file,
            contentType: StoreKeys.contentTypeFor(rendition.ext),
          );
        }
        await _mediaRepository.stampRemoteCompressedUploaded(
          item.id,
          uploadedAt: _now(),
          level: level.name,
          // First-writer-wins: on the dedup path the stored object was written
          // by the first uploader and may differ from this device's local
          // rendition (renditions are not hash-verified and can vary by level),
          // so record the authoritative stored size, not our local bytes. The
          // stored object's level is not recoverable, so it stays this device's
          // best signal (the design keeps one rendition per hash, not one per
          // level).
          sizeBytes: existingRendition?.sizeBytes ?? rendition.sizeBytes,
        );
        if (item.mediaType != MediaType.video) {
          // Photos re-compress cheaply, so drop the temp rendition now.
          await _cleanupRendition(rendition.file);
        }
        // Namespace switch (override original -> compressed): drop the now
        // unreferenced original object.
        if (hadOriginal) {
          await _mediaRepository.clearRemoteUploaded(item.id);
          if (await _mediaRepository.countRowsWithOriginal(digest.hash) == 0) {
            await _bestEffortDelete(
              StoreKeys.objectKey(
                digest.hash,
                extension: StoreKeys.extensionFor(item.originalFilename),
              ),
              'abandoned original',
            );
          }
        }
        await _queue.markDone(entry.id);
        // Spec section 8: delete the deterministic transcode (and any stale
        // same-hash siblings from a level change) only AFTER markDone. It is
        // expensive to recreate, so removing it before the upload is committed
        // would force a re-transcode on retry if any step above threw. The
        // helper is best-effort and never throws.
        if (item.mediaType == MediaType.video) {
          await _cache.deleteTranscodeArtifacts(digest.hash);
        }
        return UploadOutcome.uploaded;
      }

      final extension = StoreKeys.extensionFor(item.originalFilename);
      final key = StoreKeys.objectKey(digest.hash, extension: extension);
      final existing = await _store.head(key);
      if (isOverride || existing == null) {
        // Resume state survives failures on the queue row; content
        // addressing makes replaying it against a re-materialized staging
        // copy safe (identical bytes, identical part boundaries).
        resumableUploadKey = key;
        await _store.putFile(
          key,
          staged,
          contentType: StoreKeys.contentTypeFor(extension),
          resumeStateJson: entry.resumeStateJson,
          onResumeStateChanged: (json) {
            latestResumeJson = json;
            unawaited(_queue.updateResumeState(entry.id, json));
          },
          onProgress: (sent, total) => unawaited(
            _queue.updateProgress(
              entry.id,
              transferredBytes: sent,
              totalBytes: total ?? digest.sizeBytes,
            ),
          ),
        );
      }

      await _mediaRepository.stampRemoteUploaded(item.id, uploadedAt: _now());
      // Namespace switch (override compressed -> original): drop the now
      // unreferenced rendition object.
      if (hadCompressed) {
        await _mediaRepository.clearRemoteCompressed(item.id);
        if (await _mediaRepository.countRowsWithRendition(digest.hash) == 0) {
          await _bestEffortDelete(
            StoreKeys.renditionKey(
              digest.hash,
              ext: item.mediaType == MediaType.video ? 'mp4' : 'jpg',
            ),
            'abandoned rendition',
          );
        }
      }
      await _queue.markDone(entry.id);
      // Transcode-once cleanup (spec section 8): a video that uploads its
      // original still clears any deterministic transcode left for this hash
      // (e.g. a prior attempt's rendition, then a switch to Original or a lost
      // engine) so it can't be stranded. Mirrors the rendition branch above;
      // best-effort and never throws.
      if (item.mediaType == MediaType.video) {
        await _cache.deleteTranscodeArtifacts(digest.hash);
      }
      return (isOverride || existing == null)
          ? UploadOutcome.uploaded
          : UploadOutcome.deduplicated;
    } on Exception catch (e, stackTrace) {
      _log.error(
        'Upload failed for media ${entry.mediaId}',
        error: e,
        stackTrace: stackTrace,
      );
      final terminal = await _queue.markFailed(entry.id, e.toString());
      // Terminal failure means the resume state will never be replayed:
      // abandon any provider-side session so its parts cannot strand
      // (orphan-prevention spec 5.5). retry() re-arms with the preserved
      // resume state; _validateResume then finds the session gone and
      // starts fresh - graceful either way.
      final abandonKey = resumableUploadKey;
      if (terminal && abandonKey != null && latestResumeJson != null) {
        try {
          await _store.abandonResume(abandonKey, latestResumeJson);
        } on Exception catch (abortError) {
          _log.warning(
            'Abandoning upload session failed for $abandonKey',
            error: abortError,
          );
        }
      }
      // Photos re-compress cheaply, so their rendition staging file is
      // discarded on failure (Phase A leaked it). Video renditions are
      // deterministic and PRESERVED for the retry (spec section 8).
      final failedRendition = rendition;
      if (failedRendition != null && item.mediaType != MediaType.video) {
        await _cleanupRendition(failedRendition.file);
      }
      return UploadOutcome.failed;
    } finally {
      // Best-effort cleanup of the staging temp file. Delete atomically and
      // tolerate a missing file rather than racing a separate exists() check:
      // the file may already be gone (a concurrent drain, a temp-dir teardown,
      // or OS reaping), and cleanup must never turn a successful upload into an
      // uncaught error.
      if (staged != null) {
        try {
          await staged.delete();
        } on PathNotFoundException {
          // Already removed -- nothing to clean up.
        }
      }
    }
  }

  bool _isEligible(MediaItem item) {
    if (!kUploadableSources.contains(item.sourceType)) return false;
    if (item.mediaType == MediaType.instructorSignature) return false;
    final resolver = _registry.resolverFor(item.sourceType);
    return resolver.canResolveOnThisDevice(item);
  }

  /// Resolves the item's bytes to a private temp file the pipeline owns.
  Future<File?> _materialize(MediaItem item) async {
    final resolver = _registry.resolverFor(item.sourceType);
    final data = await resolver.resolve(item);
    switch (data) {
      case FileData(file: final f):
        final staged = await _cache.stagingFile();
        await f.copy(staged.path);
        return staged;
      case BytesData(bytes: final b):
        final staged = await _cache.stagingFile();
        await staged.writeAsBytes(b, flush: true);
        return staged;
      case NetworkData():
      case UnavailableData():
        return null;
    }
  }

  /// Chooses the compressor by media type; returns null for the Original
  /// level, when the compressor declines (ceiling/undecodable), or when a
  /// video has no transcoder registered (upload the original).
  Future<CompressionResult?> _renditionFor(
    MediaItem item,
    File source,
    MediaUploadQuality level,
    String contentHash,
  ) async {
    if (level == MediaUploadQuality.original) return null;
    if (item.mediaType == MediaType.video) {
      final transcoder = _videoTranscoder;
      if (transcoder == null) return null;
      final output = await _cache.transcodeFile(contentHash, level.name);
      if (await output.exists()) {
        // Transcode-once: a completed rendition survives retries and app
        // restarts; only markDone deletes it.
        return CompressionResult(
          file: output,
          ext: 'mp4',
          sizeBytes: await output.length(),
        );
      }
      return transcoder.transcode(item, source, level, output: output);
    }
    return _imageCompressor.compress(item, source, level);
  }

  Future<void> _cleanupRendition(File file) async {
    try {
      await file.delete();
    } on PathNotFoundException {
      // Already gone -- best-effort.
    }
  }

  /// Parses a persisted override level name, tolerating a corrupt or
  /// future-enum string (returns null so the caller can fall back) rather
  /// than throwing ArgumentError and failing the whole upload.
  MediaUploadQuality? _tryParseQuality(String name) {
    for (final quality in MediaUploadQuality.values) {
      if (quality.name == name) return quality;
    }
    _log.warning('Ignoring unrecognized override upload level "$name"');
    return null;
  }

  /// Deletes a now-unreferenced store object as best-effort cleanup after a
  /// namespace switch. The primary upload has already succeeded, so a
  /// transient/auth failure here must not turn the outcome into a failure
  /// (which would endlessly retry an upload whose bytes are already stored).
  Future<void> _bestEffortDelete(String key, String label) async {
    try {
      await _store.delete(key);
    } on Exception catch (e, stackTrace) {
      _log.warning(
        'Best-effort cleanup of $label object failed for $key '
        '(upload already succeeded)',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
