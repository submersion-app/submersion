import 'package:flutter/material.dart' show Size;

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media_store/domain/media_backup_status.dart';

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
  MediaStoreSourceResolver({required this.remote, this.storeId});

  final RemoteResolve? Function() remote;

  /// The attached store's id, read per call like [remote]. [verify] reads a
  /// row's stamp through it (issue #3482): a stamp made in another store
  /// says nothing about this one. Null, or a null answer, reads every stamp
  /// as it stands.
  final String? Function()? storeId;

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
    final thumb = await fn(item, thumbnail: true);
    if (thumb != null) return thumb;
    // A video's original and its rendition are both video, so degrading to
    // either renders the same movie placeholder the caller already has, at the
    // cost of a full download per grid tile.
    // `MediaStoreResolver.tryResolveRemote` returns null for exactly this
    // reason and says so; falling through to [resolve] asked it again with
    // `thumbnail: false` and undid the whole decision.
    if (item.isVideo) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    return resolve(item);
  }

  @override
  Future<VerifyResult> verify(MediaItem item) async {
    // Store unreachable/unconfigured is transient: cloud-backed rows must
    // never orphan for a reason that is not about the store's contents.
    if (remote() == null) return VerifyResult.transientError;
    final attached = storeId?.call();
    // Stamped in another store (issue #3569): the bytes are there, out of
    // this device's reach while it stays on this one. notFound would set the
    // sticky, synced missing flag on every device, so it reads as a reach
    // problem, which the verifier never writes.
    if (stampedElsewhere(item, attached)) return VerifyResult.fromOtherDevice;
    final seen = stampsInStore(item, attached);
    return (seen.contentHash != null && seen.remoteUploadedAt != null)
        ? VerifyResult.available
        : VerifyResult.notFound;
  }
}
