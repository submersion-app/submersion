import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/gallery_asset_reader.dart';
import 'package:submersion/features/media/data/services/gallery_thumbnail_cache.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// Resolves [MediaSourceType.platformGallery] items via [photo_manager].
///
/// Gallery photos are universally addressable on the device that owns the
/// platform library, but on a synced second device the [platformAssetId]
/// stored in the database is device-specific and will not load directly.
/// This resolver delegates to [AssetResolutionService] for a 3-step fallback:
///   1. Check [LocalAssetCacheRepository] for a previously resolved local ID.
///   2. Try [platformAssetId] directly (works on the originating device).
///   3. Search the gallery by filename + timestamp, then timestamp + dimensions.
class PlatformGalleryResolver implements MediaSourceResolver {
  final AssetResolutionService _resolutionService;

  /// Memoizes thumbnail bytes across tile recycling and caps concurrent
  /// PhotoKit traffic. Must be shared process-wide to be worth anything -- a
  /// per-resolver instance would be discarded on every provider rebuild -- so
  /// production injects the singleton from [galleryThumbnailCacheProvider].
  final GalleryThumbnailCache _thumbnailCache;

  /// False on Windows and Linux, which have no photo library for
  /// photo_manager to read (it has no backend there). Every gallery row on
  /// such a device was linked on another one, so this resolver answers
  /// [UnavailableKind.fromOtherDevice] for all of them without consulting
  /// [AssetResolutionService], whose gallery search is an interactive file
  /// dialog on those platforms.
  ///
  /// [UnavailableKind.notFound] is the one verdict that orphans a row, and
  /// the write syncs, so it is origin-qualified. A host without a library
  /// never gives it for a row that carries an asset id: a Linux device would
  /// otherwise mark photos still safe in a Mac's or phone's library missing
  /// everywhere. A host with a library gives it only when the search fails
  /// for a row whose origin is this device ([_linkedHere], via [_missing]);
  /// a row linked elsewhere, or with no origin yet, is
  /// [UnavailableKind.fromOtherDevice]. A row with no asset id at all has
  /// nothing to search for and is notFound on every host.
  final bool _hasPhotoLibrary;

  /// Names the device a row was linked on, for the "From {device}"
  /// placeholder. Consulted only when this host has no photo library.
  final Future<String?> Function(String deviceId)? _deviceLabel;

  Future<UnavailableData> _elsewhereFor(MediaItem item) async =>
      UnavailableData(
        kind: UnavailableKind.fromOtherDevice,
        originDeviceLabel: await _labelFor(item.originDeviceId),
      );

  /// The published name of [deviceId], or null when unknown or unset. Never
  /// throws: a label is decoration on a placeholder, not a verdict.
  Future<String?> _labelFor(String? deviceId) async {
    final lookup = _deviceLabel;
    if (deviceId == null || lookup == null) return null;
    try {
      return await lookup(deviceId);
    } catch (_) {
      return null;
    }
  }

  /// [assetReader] performs the byte and metadata reads once an id is
  /// resolved. Production uses photo_manager; tests inject a fake library.
  ///
  /// [localDeviceId] names this device, so a miss can be judged by where the
  /// row was linked. Fetched lazily, only when a search fails, and memoized
  /// once it succeeds.
  PlatformGalleryResolver({
    required AssetResolutionService resolutionService,
    GalleryThumbnailCache? thumbnailCache,
    bool hasPhotoLibrary = true,
    GalleryAssetReader? assetReader,
    Future<String?> Function(String deviceId)? deviceLabel,
    Future<String?> Function()? localDeviceId,
  }) : _resolutionService = resolutionService,
       _thumbnailCache = thumbnailCache ?? GalleryThumbnailCache(),
       _hasPhotoLibrary = hasPhotoLibrary,
       _reader = assetReader ?? const PhotoManagerAssetReader(),
       _deviceLabel = deviceLabel,
       _localDeviceId = localDeviceId;

  final GalleryAssetReader _reader;
  final Future<String?> Function()? _localDeviceId;

  /// [_localDeviceId]'s answer, memoized once it succeeds. A failed fetch is
  /// not cached, so the next miss asks again.
  String? _knownDeviceId;
  final _log = LoggerService.forClass(
    PlatformGalleryResolver,
    category: LogCategory.media,
  );

  Future<String?> _thisDeviceId() async {
    if (_knownDeviceId != null) return _knownDeviceId;
    final source = _localDeviceId;
    if (source == null) return null;
    try {
      return _knownDeviceId = await source();
    } on Object catch (e) {
      // "Unknown" is not "linked here": a miss then says nothing about the
      // bytes, which is the safe answer when the answer syncs.
      _log.debug('Local device id unavailable', error: e);
      return null;
    }
  }

  /// Whether [item] was provably linked on this device.
  ///
  /// Only then is a failed search evidence the photo is gone. A row linked
  /// elsewhere is one this device never had; a row with no origin was linked
  /// before gallery rows recorded one, and until the gallery origin backfill
  /// stamps it no device can prove it is the one (media sync program spec
  /// 6.1). Either way the verdict must not orphan a row on every device.
  Future<bool> _linkedHere(MediaItem item) async {
    final origin = item.originDeviceId;
    if (origin == null) return false;
    final local = await _thisDeviceId();
    return local != null && origin == local;
  }

  /// The verdict for a gallery search that came back empty.
  Future<UnavailableData> _missing(MediaItem item) async =>
      await _linkedHere(item)
      ? const UnavailableData(kind: UnavailableKind.notFound)
      : _elsewhereFor(item);

  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;

  @override
  bool canResolveOnThisDevice(MediaItem item) => _hasPhotoLibrary;

  @override
  Future<MediaSourceData> resolve(MediaItem item) async {
    final assetId = item.platformAssetId;
    if (assetId == null || assetId.isEmpty) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    if (!_hasPhotoLibrary) return _elsewhereFor(item);
    final resolution = await _resolutionService.resolveAssetId(item);
    // Checked before the id, because accessDenied always carries a null id
    // and collapsing the two would report "your photo is gone" for what is
    // really "let me look at your photos".
    if (resolution.status == ResolutionStatus.accessDenied) {
      return UnavailableData(
        kind: UnavailableKind.accessDenied,
        limitedAccess: resolution.limitedAccess,
      );
    }
    final resolvedId = resolution.localAssetId;
    if (resolvedId == null) return _missing(item);
    final bytes = await _reader.originBytes(resolvedId);
    if (bytes != null) {
      return BytesData(bytes: bytes, servedFrom: ServedFrom.platformGallery);
    }
    // A cached mapping is trusted without re-proving it, so the photo can
    // stop reading under it: dropped from a limited selection, or
    // re-indexed. Search again before calling it gone (spec 6.3), and keep
    // an inconclusive answer, which would otherwise read as notFound here.
    final again = await _resolutionService.reresolve(item);
    if (again.status == ResolutionStatus.accessDenied) {
      return UnavailableData(
        kind: UnavailableKind.accessDenied,
        limitedAccess: again.limitedAccess,
      );
    }
    final newId = again.localAssetId;
    if (newId != null && newId != resolvedId) {
      final found = await _reader.originBytes(newId);
      if (found != null) {
        return BytesData(bytes: found, servedFrom: ServedFrom.platformGallery);
      }
    }
    return _missing(item);
  }

  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) async {
    final assetId = item.platformAssetId;
    if (assetId == null || assetId.isEmpty) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    if (!_hasPhotoLibrary) return _elsewhereFor(item);
    final width = target.width.toInt();
    final height = target.height.toInt();
    // Keyed by size as well as item: the grid and the viewer ask for different
    // targets and must not serve each other's bytes.
    final bytes = await _thumbnailCache.getOrFetch(
      '${item.id}@${width}x$height',
      () => _fetchThumbnail(item, width, height),
    );
    if (bytes == null) {
      // _fetchThumbnail returns Uint8List? and has already discarded WHY, so
      // re-derive it. Failure path only, and getOrFetch never caches a null
      // (gallery_thumbnail_cache.dart:99-103), so this costs nothing in the
      // common case. resolveAssetId short-circuits at the permission check
      // before it queries the gallery.
      //
      // Load-bearing: grid tiles call resolveThumbnail, so without this every
      // tile on a permission-revoked device reports notFound and the
      // reconciler would orphan the whole library.
      final again = await _resolutionService.resolveAssetId(item);
      if (again.status == ResolutionStatus.accessDenied) {
        return UnavailableData(
          kind: UnavailableKind.accessDenied,
          limitedAccess: again.limitedAccess,
        );
      }
      return _missing(item);
    }
    return BytesData(
      bytes: bytes,
      servedFrom: ServedFrom.platformGallery,
      servedTier: ServedTier.thumbnail,
    );
  }

  /// Runs only on a cache miss.
  Future<Uint8List?> _fetchThumbnail(
    MediaItem item,
    int width,
    int height,
  ) async {
    final resolvedId = await _resolveId(item);
    if (resolvedId == null) return null;
    final bytes = await _thumbBytes(resolvedId, width, height);
    if (bytes != null) return bytes;
    // The mapping produced no bytes. That is now the ONLY staleness signal:
    // resolveAssetId no longer pre-checks with a throwaway fetch. Drop the
    // mapping, search the gallery again, and retry once against a genuinely
    // different id.
    final retry = await _resolutionService.reresolve(item);
    final retryId = retry.localAssetId;
    if (retryId == null || retryId == resolvedId) return null;
    return _thumbBytes(retryId, width, height);
  }

  Future<Uint8List?> _thumbBytes(String id, int width, int height) =>
      _reader.thumbnailBytes(id, width, height);

  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async {
    final assetId = item.platformAssetId;
    if (assetId == null || assetId.isEmpty || !_hasPhotoLibrary) return null;
    final resolvedId = await _resolveId(item);
    if (resolvedId == null) return null;
    return _reader.metadata(resolvedId);
  }

  @override
  Future<VerifyResult> verify(MediaItem item) async {
    final assetId = item.platformAssetId;
    if (assetId == null || assetId.isEmpty) return VerifyResult.notFound;
    if (!_hasPhotoLibrary) return VerifyResult.fromOtherDevice;
    final resolution = await _resolutionService.resolveAssetId(item);
    // Before the id check: accessDenied always carries a null id, and
    // returning notFound here is what used to let a revoked permission mark
    // every row in the library orphaned.
    if (resolution.status == ResolutionStatus.accessDenied) {
      return VerifyResult.accessDenied;
    }
    final resolvedId = resolution.localAssetId;
    if (resolvedId != null && await _reader.exists(resolvedId)) {
      return VerifyResult.available;
    }
    // A cached mapping whose asset no longer exists is searched again, as
    // in resolve: an inconclusive search must not become the orphaning
    // verdict (spec 6.3).
    if (resolvedId != null) {
      final again = await _resolutionService.reresolve(item);
      if (again.status == ResolutionStatus.accessDenied) {
        return VerifyResult.accessDenied;
      }
      final newId = again.localAssetId;
      if (newId != null && newId != resolvedId && await _reader.exists(newId)) {
        return VerifyResult.available;
      }
    }
    return await _linkedHere(item)
        ? VerifyResult.notFound
        : VerifyResult.fromOtherDevice;
  }

  /// Delegates to [AssetResolutionService] to obtain the local asset ID.
  /// Returns null when resolution fails or no match is found.
  Future<String?> _resolveId(MediaItem item) async {
    final result = await _resolutionService.resolveAssetId(item);
    if (result.status == ResolutionStatus.unavailable ||
        result.localAssetId == null) {
      return null;
    }
    return result.localAssetId;
  }
}
