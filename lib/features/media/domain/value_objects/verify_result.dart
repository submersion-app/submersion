/// Result of a [MediaSourceResolver.verify] call — whether and why a media
/// item is currently reachable on this device.
///
/// Only [VerifyResult.notFound] and [VerifyResult.unauthenticated] are
/// considered persistent failure states that flip `MediaItem.isOrphaned` to
/// `true`. [VerifyResult.transientError] updates `lastVerifiedAt` but does
/// not mark the item as orphan.
enum VerifyResult {
  available,
  notFound,
  unauthenticated,
  transientError,
  fromOtherDevice,
}
