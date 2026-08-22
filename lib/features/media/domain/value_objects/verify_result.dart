/// Result of a [MediaSourceResolver.verify] call — whether and why a media
/// item is currently reachable on this device.
///
/// Only [VerifyResult.notFound] and [VerifyResult.unauthenticated] are
/// considered persistent failure states that flip `MediaItem.isOrphaned` to
/// `true`. [VerifyResult.transientError], [VerifyResult.volumeOffline] and
/// [VerifyResult.accessDenied] update `lastVerifiedAt` but do not mark the
/// item as orphan.
enum VerifyResult {
  available,
  notFound,
  unauthenticated,
  transientError,
  fromOtherDevice,

  /// The volume holding the file is not mounted; the file may well still
  /// exist. Treated as transient by cleanup sweeps (never orphans).
  volumeOffline,

  /// The source refused to answer, so the check learned nothing. The gallery
  /// case is a revoked or not-yet-granted photo permission.
  ///
  /// Distinct from [notFound], which is a positive finding that the source
  /// was consulted and does not have the item. Collapsing the two would mark
  /// an entire photo library orphaned the moment permission lapses, and
  /// every flipped row replicates through sync.
  accessDenied,
}
