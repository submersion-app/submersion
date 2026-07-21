import 'dart:async';
import 'dart:io';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/media_store_policies.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/image_compressor.dart';
import 'package:submersion/features/media_store/data/media_compressor.dart';
import 'package:submersion/features/media_store/data/thumbnail_generator.dart';
import 'package:submersion/features/media_store/data/video_transcoder.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';

enum UploadOutcome { uploaded, deduplicated, skippedIneligible, failed }

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

  static const Set<MediaSourceType> _eligibleSources = {
    MediaSourceType.platformGallery,
    MediaSourceType.localFile,
    MediaSourceType.serviceConnector,
  };

  /// Connector videos never download their original in v1 (Lightroom spec:
  /// match + thumbnail only). The store carries just the thumb, derived
  /// from the poster rendition the resolver materializes, and
  /// remoteUploadedAt stays null so a future playback phase can tell a
  /// poster frame from a playable original.
  bool _isThumbOnly(MediaItem item) =>
      item.sourceType == MediaSourceType.serviceConnector &&
      item.mediaType == MediaType.video;

  Future<UploadOutcome> process(MediaTransferQueueEntry entry) async {
    await _queue.markTransferring(entry.id);
    final item = await _mediaRepository.getMediaById(entry.mediaId);
    if (item == null || !_isEligible(item)) {
      await _queue.markDone(entry.id);
      return UploadOutcome.skippedIneligible;
    }
    final alreadyUploaded =
        item.remoteUploadedAt != null ||
        item.remoteCompressedUploadedAt != null;
    if (_isThumbOnly(item)
        ? item.remoteThumbUploadedAt != null
        : alreadyUploaded) {
      await _queue.markDone(entry.id);
      return UploadOutcome.deduplicated;
    }

    File? staged;
    try {
      staged = await _materialize(item);
      if (staged == null) {
        await _queue.markFailed(entry.id, 'source unavailable on this device');
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
      final level = await _policies.qualityFor(item.mediaType);
      final rendition = await _renditionFor(item, staged, level);
      if (rendition != null) {
        final renditionKey = StoreKeys.renditionKey(
          digest.hash,
          ext: rendition.ext,
        );
        if (await _store.head(renditionKey) == null) {
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
          sizeBytes: rendition.sizeBytes,
        );
        await _cleanupRendition(rendition.file);
        await _queue.markDone(entry.id);
        return UploadOutcome.uploaded;
      }

      final extension = StoreKeys.extensionFor(item.originalFilename);
      final key = StoreKeys.objectKey(digest.hash, extension: extension);
      final existing = await _store.head(key);
      if (existing == null) {
        // Resume state survives failures on the queue row; content
        // addressing makes replaying it against a re-materialized staging
        // copy safe (identical bytes, identical part boundaries).
        await _store.putFile(
          key,
          staged,
          contentType: StoreKeys.contentTypeFor(extension),
          resumeStateJson: entry.resumeStateJson,
          onResumeStateChanged: (json) =>
              unawaited(_queue.updateResumeState(entry.id, json)),
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
      await _queue.markDone(entry.id);
      return existing == null
          ? UploadOutcome.uploaded
          : UploadOutcome.deduplicated;
    } on Exception catch (e, stackTrace) {
      _log.error(
        'Upload failed for media ${entry.mediaId}',
        error: e,
        stackTrace: stackTrace,
      );
      await _queue.markFailed(entry.id, e.toString());
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
    if (!_eligibleSources.contains(item.sourceType)) return false;
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
  /// video has no transcoder registered (Phase A -> upload the original).
  Future<CompressionResult?> _renditionFor(
    MediaItem item,
    File source,
    MediaUploadQuality level,
  ) async {
    if (level == MediaUploadQuality.original) return null;
    if (item.mediaType == MediaType.video) {
      return _videoTranscoder?.transcode(item, source, level);
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
}
