import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_byte_retention.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

const _log = LoggerService('mediaBytesProvider');

/// Full-resolution bytes for any [MediaItem], read from the source the row
/// actually points at and falling back to the media store.
///
/// This is the byte-level companion to `MediaItemView`: same registry, same
/// store fallback, so a document, a local-file photo and a gallery photo all
/// resolve here. [resolvedFullResolutionProvider] answers a narrower
/// question — "where did this row's `platformAssetId` end up in the photo
/// library on THIS device" — and returns unavailable for every row that has
/// no asset id at all. Document attachments never have one: they are
/// reference-linked by path, bookmark or SAF URI. Routing the PDF viewer
/// through the gallery provider therefore made every attachment read as
/// "not available on this device" (issue #1019).
///
/// Callers get [ResolvedAssetResult] rather than [MediaSourceData] because
/// they all want the same thing — bytes to render or to write into a share
/// temp file — and a resolution they cannot use (a bare URL) is, for that
/// purpose, indistinguishable from an absent one.
final mediaBytesProvider =
    FutureProvider.family<ResolvedAssetResult, MediaItem>((ref, item) async {
      // A full-resolution buffer per item. Riverpod 3 keeps a family entry
      // forever unless told otherwise, so before #1175 every document and
      // photo opened stayed on the heap for the process lifetime.
      retainFor(ref, fullResolutionRetention);
      // Always thumbnail: false. This provider resolves full-resolution
      // bytes only; grid thumbnails go through MediaItemView.
      final recorder = ref.read(mediaServingRecorderProvider);

      final native = await _resolveNative(ref, item);
      final bytes = await _bytesOf(native, item);
      if (bytes != null) {
        recorder.record(
          item.id,
          thumbnail: false,
          servedFrom: native.servedFrom,
          servedTier: native.servedTier,
        );
        return ResolvedAssetResult(
          bytes: bytes,
          status: ResolutionStatus.resolved,
        );
      }

      // The store is the cross-device path for reference-linked media: the
      // originating device holds the file, everyone else holds the row. Its
      // resolver self-gates on the upload stamps, so an item that was never
      // uploaded costs one null return rather than a fetch.
      final remote = await _resolveRemote(ref, item);
      final remoteBytes = await _bytesOf(remote, item);
      if (remoteBytes != null) {
        recorder.record(
          item.id,
          thumbnail: false,
          servedFrom: remote?.servedFrom,
          servedTier: remote?.servedTier ?? ServedTier.original,
          storeFallbackUsed: true,
        );
        return ResolvedAssetResult(
          bytes: remoteBytes,
          status: ResolutionStatus.resolved,
        );
      }

      // A native NetworkData yields no bytes without being an
      // UnavailableData: this provider deliberately does not fetch URLs (see
      // [_bytesOf]). For a byte consumer that is indistinguishable from an
      // absent source, so it collapses to notFound.
      //
      // storeFallbackUsed is true because the store WAS asked and could not
      // help. It records that the fallback ran, not that it succeeded.
      recorder.record(
        item.id,
        thumbnail: false,
        failure: native is UnavailableData
            ? native.kind
            : UnavailableKind.notFound,
        storeFallbackUsed: true,
      );
      return const ResolvedAssetResult(status: ResolutionStatus.unavailable);
    }, isAutoDispose: true);

/// Resolves [item] through its registered source resolver.
///
/// An unregistered source type makes the registry throw [UnsupportedError] —
/// a programmer error, but one whose blast radius here is a single
/// attachment. Swallowed to the unavailable placeholder so a mis-registered
/// row cannot turn the viewer into an error screen.
Future<MediaSourceData> _resolveNative(Ref ref, MediaItem item) async {
  try {
    final registry = ref.read(mediaSourceResolverRegistryProvider);
    return await registry.resolverFor(item.sourceType).resolve(item);
  } on Object catch (e, st) {
    _log.warning(
      'Source resolution failed for media ${item.id}',
      error: e,
      stackTrace: st,
    );
    return const UnavailableData(kind: UnavailableKind.notFound);
  }
}

Future<MediaSourceData?> _resolveRemote(Ref ref, MediaItem item) async {
  try {
    final runtime = await ref.read(mediaStoreRuntimeProvider.future);
    return await runtime?.resolver.tryResolveRemote(item, thumbnail: false);
  } on Object catch (e, st) {
    _log.warning(
      'Media store fallback failed for media ${item.id}',
      error: e,
      stackTrace: st,
    );
    return null;
  }
}

/// Bytes for the resolutions that carry any, null for the ones that do not.
///
/// [NetworkData] is deliberately not fetched: it is `cached_network_image`'s
/// contract, and the rows that produce it (URL imports, manifest entries)
/// have their own display path.
Future<Uint8List?> _bytesOf(MediaSourceData? data, MediaItem item) async {
  switch (data) {
    case BytesData(bytes: final b):
      return b;
    case FileData(file: final f):
      try {
        return await f.readAsBytes();
      } on FileSystemException catch (e) {
        _log.warning('Resolved file unreadable for media ${item.id}: $e');
        return null;
      }
    case NetworkData():
    case UnavailableData():
    case null:
      return null;
  }
}
