import 'dart:ui' show Size;

import 'package:submersion/core/services/lightroom/lightroom_api_client.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';

/// Resolver for `serviceConnector` media rows. Dispatches by the row's
/// connector type; v1 knows only Lightroom.
///
/// This is the single source of connector bytes for BOTH display (via
/// MediaItemView) and store upload (MediaUploadPipeline materializes
/// through the registry). On devices without the connector account it
/// declines via [canResolveOnThisDevice]; those devices display through
/// the media store fallback instead.
///
/// Rendition bytes are cached in the media store cache pools once the
/// row's contentHash is stamped by the upload pipeline: the rendition IS
/// this row's store content, so the hash of freshly-downloaded bytes can
/// be verified against it before entering the content-addressed cache.
class ConnectorMediaResolver implements MediaSourceResolver {
  ConnectorMediaResolver({
    required bool hasLightroomAccount,
    required Future<LightroomApiClient?> Function() apiClient,
    required Future<String?> Function() catalogId,
    required Future<MediaCacheStore?> Function() cache,
  }) : _hasLightroomAccount = hasLightroomAccount,
       _apiClient = apiClient,
       _catalogId = catalogId,
       _cache = cache;

  final bool _hasLightroomAccount;
  final Future<LightroomApiClient?> Function() _apiClient;
  final Future<String?> Function() _catalogId;
  final Future<MediaCacheStore?> Function() _cache;
  final _log = LoggerService.forClass(ConnectorMediaResolver);

  @override
  MediaSourceType get sourceType => MediaSourceType.serviceConnector;

  @override
  bool canResolveOnThisDevice(MediaItem item) =>
      _hasLightroomAccount && item.remoteAssetId != null;

  @override
  Future<MediaSourceData> resolve(MediaItem item) =>
      _resolveRendition(item, size: '2048', kind: MediaCacheKind.original);

  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) =>
      _resolveRendition(item, size: 'thumbnail2x', kind: MediaCacheKind.thumb);

  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async => null;

  @override
  Future<VerifyResult> verify(MediaItem item) async {
    if (!_hasLightroomAccount) return VerifyResult.unauthenticated;
    if (item.remoteAssetId == null) return VerifyResult.notFound;
    return VerifyResult.available;
  }

  Future<MediaSourceData> _resolveRendition(
    MediaItem item, {
    required String size,
    required MediaCacheKind kind,
  }) async {
    final remoteAssetId = item.remoteAssetId;
    if (remoteAssetId == null) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    if (!_hasLightroomAccount) {
      return const UnavailableData(kind: UnavailableKind.signInRequired);
    }

    try {
      final cache = await _cache();
      final contentHash = item.contentHash;

      if (cache != null && contentHash != null) {
        final cached = await cache.get(contentHash, kind);
        if (cached != null) return FileData(file: cached);
      }

      final api = await _apiClient();
      final catalogId = await _catalogId();
      if (api == null || catalogId == null) {
        return const UnavailableData(kind: UnavailableKind.signInRequired);
      }
      final bytes = await api.getRendition(
        catalogId: catalogId,
        assetId: remoteAssetId,
        size: size,
      );

      // Enter the content-addressed cache only when the bytes provably ARE
      // the row's content: full renditions verify against contentHash;
      // thumbs are derived and keyed by the original's hash unverified,
      // mirroring the store pipeline's thumb semantics.
      if (cache != null && contentHash != null) {
        final staging = await cache.stagingFile();
        try {
          await staging.writeAsBytes(bytes, flush: true);
          if (kind == MediaCacheKind.thumb) {
            final file = await cache.put(contentHash, kind, staging);
            return FileData(file: file);
          }
          final digest = await sha256OfFile(staging);
          if (digest.hash == contentHash) {
            final file = await cache.put(contentHash, kind, staging);
            return FileData(file: file);
          }
        } finally {
          if (await staging.exists()) {
            await staging.delete();
          }
        }
      }
      return BytesData(bytes: bytes);
    } on LightroomApiException catch (e) {
      _log.warning('Lightroom rendition $size failed for ${item.id}: $e');
      return UnavailableData(
        kind: e.statusCode == 401
            ? UnavailableKind.unauthenticated
            : UnavailableKind.networkError,
        userMessage: e.message,
      );
    } on Exception catch (e) {
      _log.warning('Lightroom resolve failed for ${item.id}: $e');
      return const UnavailableData(kind: UnavailableKind.networkError);
    }
  }
}
