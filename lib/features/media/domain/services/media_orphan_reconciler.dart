import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

/// Decides whether a completed resolution should change a row's orphan flag.
///
/// Pure, and deliberately conservative: only a POSITIVE finding may write. A
/// resolution either consulted the source and learned something, or it did
/// not. Everything in the second category leaves the flag alone, because a
/// false orphan tells a diver a photo they still have is gone, and the write
/// that records it is sync-visible, so the claim reaches every other device.
///
/// Returns null when nothing should be written, which is the common case:
/// either the flag already agrees, or the resolution was inconclusive. That
/// is what makes calling this on every tile resolution affordable. A library
/// at rest performs no writes no matter how far it is scrolled, which matters
/// because every `MediaRepository` write calls `markRecordPending`.
bool? reconciledOrphanFlag({
  required bool currentlyOrphaned,
  required UnavailableKind? failure,
}) {
  final desired = _desiredFlag(failure);
  if (desired == null || desired == currentlyOrphaned) return null;
  return desired;
}

/// Exhaustive with no default arm, so a new [UnavailableKind] cannot ship
/// without someone deciding whether it is evidence of absence. The correct
/// answer for a new kind is almost always null: this function may only orphan
/// a row when the source was actually reached and actually said no.
bool? _desiredFlag(UnavailableKind? failure) {
  // Bytes arrived, so the source demonstrably still has it.
  if (failure == null) return false;
  return switch (failure) {
    // The ONLY positive finding: the source was consulted and does not have
    // this item. Every other kind below describes a failure to reach the
    // source, which teaches nothing about whether the bytes still exist.
    UnavailableKind.notFound => true,

    // "We lack the credentials or config to reach this", never "it is gone".
    // MediaStoreSourceResolver returns it for EVERY mediaStore row when no
    // store is configured, with the comment "the bytes exist, this device
    // just cannot reach them. Renders as needs-setup, never as missing".
    // ConnectorMediaResolver returns it for every Lightroom row when the
    // account is not connected, and on a 401. Orphaning here would empty a
    // library because a token expired.
    UnavailableKind.unauthenticated => null,

    // The source refused to answer. A revoked photo permission fails EVERY
    // gallery row at once, so getting this wrong is a whole-library event,
    // not a one-row event.
    UnavailableKind.accessDenied => null,

    // Recoverable by a user action; the item is probably still there.
    UnavailableKind.signInRequired => null,

    // Not a claim about this device's copy at all.
    UnavailableKind.fromOtherDevice => null,

    // Transient by construction. volumeOffline is documented as never
    // orphaning, and stillFetching explicitly means nothing is wrong: the
    // bytes exist and are on their way, they just outlived a time budget.
    UnavailableKind.networkError => null,
    UnavailableKind.volumeOffline => null,
    UnavailableKind.stillFetching => null,
  };
}
