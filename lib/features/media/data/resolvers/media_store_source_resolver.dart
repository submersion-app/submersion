import 'package:flutter/material.dart' show Size;

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// The remote fetch shape of MediaStoreResolver.tryResolveRemote, taken as a
/// tear-off so this resolver composes the existing store fallback instead of
/// duplicating it.
typedef RemoteResolve =
    Future<MediaSourceData?> Function(
      MediaItem item, {
      required bool thumbnail,
    });

/// First-class resolver for [MediaSourceType.mediaStore] rows (Media section
/// Phase 3): the cloud store IS the source of truth, unlike the fallback
/// path where it merely papers over a temporarily unavailable native source.
///
/// [remote] is read per call so connecting or disconnecting a store takes
/// effect without rebuilding the resolver registry's consumers.
class MediaStoreSourceResolver implements MediaSourceResolver {
  MediaStoreSourceResolver({required this.remote});

  final RemoteResolve? Function() remote;

  @override
  MediaSourceType get sourceType => MediaSourceType.mediaStore;

  @override
  bool canResolveOnThisDevice(MediaItem item) => true;

  @override
  Future<MediaSourceData> resolve(MediaItem item) async {
    final fn = remote();
    if (fn == null) {
      // No store configured: the bytes exist, this device just cannot reach
      // them. Renders as needs-setup, never as missing.
      return const UnavailableData(kind: UnavailableKind.unauthenticated);
    }
    return await fn(item, thumbnail: false) ??
        const UnavailableData(kind: UnavailableKind.notFound);
  }

  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) async {
    final fn = remote();
    if (fn == null) {
      return const UnavailableData(kind: UnavailableKind.unauthenticated);
    }
    return await fn(item, thumbnail: true) ?? resolve(item);
  }

  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async => null;

  @override
  Future<VerifyResult> verify(MediaItem item) async {
    // Store unreachable/unconfigured is transient: cloud-backed rows must
    // never orphan for a reason that is not about the store's contents.
    if (remote() == null) return VerifyResult.transientError;
    return (item.contentHash != null && item.remoteUploadedAt != null)
        ? VerifyResult.available
        : VerifyResult.notFound;
  }
}
