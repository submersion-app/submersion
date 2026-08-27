/// Result of a [MediaSourceResolver.verify] call — whether and why a media
/// item is currently reachable on this device.
///
/// [VerifyResult.notFound] is the ONLY result that flips
/// `MediaItem.isOrphaned` to `true`, because it is the only positive finding
/// of absence: the source was consulted and does not have the item.
///
/// Every other non-available result describes a failure to REACH the source
/// and says nothing about whether the bytes still exist, so all of them
/// update `lastVerifiedAt` and leave the orphan flag untouched in both
/// directions. That includes [VerifyResult.unauthenticated], which this
/// comment previously listed as a persistent failure: it fires for every
/// Lightroom row when the account is disconnected
/// (`ConnectorMediaResolver.verify`) and on a 401, so orphaning it would
/// empty a connector library because a token expired.
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
