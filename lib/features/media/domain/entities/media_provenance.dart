import 'package:flutter/foundation.dart';

import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/domain/media_backup_status.dart';

/// Whether the row's own source can still produce this item's bytes here.
///
/// Derived from [MediaItem.isOrphaned], which in this codebase means the FILE
/// is missing. That is a different axis from the orphan sweep's notion of an
/// unlinked row, and [MediaItem.retainInLibrary] belongs to that other axis.
enum OriginHealth {
  /// Verified present at [OriginFacts.lastVerifiedAt].
  healthy,

  /// A verification found the source pointer dead.
  missing,

  /// Never checked, so nothing is known either way.
  neverVerified,
}

/// How much of an item the cloud store holds.
///
/// Finer grained than [isBackedUp], which it must never contradict: the
/// upload pipeline gates on that predicate, so a tier claiming more than
/// [isBackedUp] does would put the panel and the pipeline at odds.
enum BackupTier {
  /// No upload stamp of any kind.
  none,

  /// Only the derived thumbnail was uploaded. The original is not in the
  /// store, which for most rows means it is not really backed up.
  thumbOnly,

  /// A compressed rendition stands in for the original, which happens when
  /// the upload quality setting is anything other than "original".
  renditionOnly,

  /// The item's own bytes are in the store.
  full,
}

/// The transfer-queue row for one item, reduced to what a reader needs.
///
/// Deliberately not the Drift row type: this entity lives in the domain layer
/// and must not depend on the local cache database. The provider maps.
@immutable
class QueueFacts {
  const QueueFacts({required this.state, this.error});

  /// One of 'pending', 'transferring', 'done', 'failed'. The queue stores
  /// these as raw strings rather than an enum.
  final String state;
  final String? error;
}

/// Where an item was linked from, and whether that source still resolves.
@immutable
class OriginFacts {
  const OriginFacts({
    required this.sourceType,
    required this.pointer,
    required this.originDeviceId,
    required this.health,
    required this.lastVerifiedAt,
  });

  final MediaSourceType sourceType;

  /// The human-meaningful reference for this source type: an asset id, a
  /// path, a URL, a content hash. Null when the type has no useful pointer.
  final String? pointer;

  /// The device that created the link, or null when this source type does
  /// not track one. Null is NOT "this device": `MediaRepository`
  /// `_effectiveOriginDeviceId` stamps an id only for localFile and
  /// serviceConnector rows and leaves the other five types null, so treating
  /// null as local would claim a fact the app never recorded.
  final String? originDeviceId;

  final OriginHealth health;
  final DateTime? lastVerifiedAt;

  factory OriginFacts.from(MediaItem item) => OriginFacts(
    sourceType: item.sourceType,
    pointer: _pointerFor(item),
    originDeviceId: item.originDeviceId,
    health: item.isOrphaned
        ? OriginHealth.missing
        : item.lastVerifiedAt == null
        ? OriginHealth.neverVerified
        : OriginHealth.healthy,
    lastVerifiedAt: item.lastVerifiedAt,
  );

  /// Exhaustive on purpose: a new source type must decide what it points at
  /// rather than silently falling through to null.
  static String? _pointerFor(MediaItem item) {
    switch (item.sourceType) {
      case MediaSourceType.platformGallery:
        return item.platformAssetId;
      case MediaSourceType.localFile:
        return item.localPath ?? item.filePath ?? item.bookmarkRef;
      case MediaSourceType.networkUrl:
      case MediaSourceType.manifestEntry:
        return item.url;
      case MediaSourceType.serviceConnector:
        return item.remoteAssetId;
      case MediaSourceType.mediaStore:
        return item.contentHash;
      case MediaSourceType.signature:
        // Stored inline on the row or beside the database; neither is a
        // reference a reader could act on.
        return null;
    }
  }
}

/// What the cloud store holds for an item, and what the queue is doing.
@immutable
class BackupFacts {
  const BackupFacts({
    required this.storeAttached,
    required this.eligible,
    required this.tier,
    required this.backedUp,
    required this.originalUploadedAt,
    required this.thumbUploadedAt,
    required this.renditionUploadedAt,
    required this.queueState,
    required this.queueError,
  });

  final bool storeAttached;

  /// Whether the upload pipeline would ever carry this row. A URL row is not
  /// eligible, which is a different statement from "not backed up".
  final bool eligible;

  final BackupTier tier;

  /// The upload pipeline's own definition of "the store has this".
  ///
  /// NOT derivable from [tier] being non-none: a thumb-only stamp yields
  /// [BackupTier.thumbOnly] while [isBackedUp] stays false for ordinary
  /// media, because a thumbnail cannot stand in for the original. Callers
  /// deciding whether the store can cover for a missing local file must use
  /// this, not the tier, or they will promise bytes that are not there.
  final bool backedUp;

  final DateTime? originalUploadedAt;
  final DateTime? thumbUploadedAt;
  final DateTime? renditionUploadedAt;
  final String? queueState;
  final String? queueError;

  factory BackupFacts.from(
    MediaItem item, {
    required bool storeAttached,
    required QueueFacts? queue,
  }) {
    final eligible = kUploadableSources.contains(item.sourceType);
    return BackupFacts(
      storeAttached: storeAttached,
      eligible: eligible,
      tier: eligible ? _tierFor(item) : BackupTier.none,
      backedUp: eligible && isBackedUp(item),
      originalUploadedAt: item.remoteUploadedAt,
      thumbUploadedAt: item.remoteThumbUploadedAt,
      renditionUploadedAt: item.remoteCompressedUploadedAt,
      queueState: queue?.state,
      queueError: queue?.error,
    );
  }

  /// Ordered strongest first, so a row carrying several stamps reports the
  /// most complete thing the store holds.
  static BackupTier _tierFor(MediaItem item) {
    if (item.remoteUploadedAt != null) return BackupTier.full;
    if (item.remoteCompressedUploadedAt != null) {
      return BackupTier.renditionOnly;
    }
    if (item.remoteThumbUploadedAt != null) return BackupTier.thumbOnly;
    return BackupTier.none;
  }
}

/// What actually produced the bytes on screen, from [MediaServingRecorder].
///
/// Not a member of [MediaProvenance]: it comes from a [ChangeNotifier] the
/// widget listens to directly, and folding it into a Riverpod-computed object
/// would make that object reactive to something the framework cannot see.
@immutable
class ServingFacts {
  const ServingFacts({
    required this.servedFrom,
    required this.servedTier,
    required this.storeFallbackUsed,
    required this.failure,
    required this.observedAt,
  });

  final ServedFrom? servedFrom;
  final ServedTier servedTier;
  final bool storeFallbackUsed;
  final UnavailableKind? failure;

  /// Null when this item has not been resolved yet in this session.
  final DateTime? observedAt;

  /// Whether anything is known at all. Distinguishes "not loaded yet" from
  /// "loaded and failed", which read very differently to a user.
  bool get observed => observedAt != null;

  static const ServingFacts unobserved = ServingFacts(
    servedFrom: null,
    servedTier: ServedTier.original,
    storeFallbackUsed: false,
    failure: null,
    observedAt: null,
  );

  factory ServingFacts.from(ServingObservation? observation) {
    if (observation == null) return unobserved;
    return ServingFacts(
      servedFrom: observation.servedFrom,
      servedTier: observation.servedTier,
      storeFallbackUsed: observation.storeFallbackUsed,
      failure: observation.failure,
      observedAt: observation.observedAt,
    );
  }
}

/// Origin and backup facts for one media item.
///
/// Cheap to build: every input is a row field, a queue row already being
/// watched, or a boolean. That matters because a grid badge derives from this
/// on every visible tile, so nothing here may reach for the media store
/// runtime (see `mediaStoreIdentityProvider` for the part that does).
@immutable
class MediaProvenance {
  const MediaProvenance({required this.origin, required this.backup});

  final OriginFacts origin;
  final BackupFacts backup;

  factory MediaProvenance.from(
    MediaItem item, {
    required bool storeAttached,
    required QueueFacts? queue,
  }) => MediaProvenance(
    origin: OriginFacts.from(item),
    backup: BackupFacts.from(item, storeAttached: storeAttached, queue: queue),
  );
}
