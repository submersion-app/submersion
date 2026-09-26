import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// Checks one media item's source and persists what it finds.
///
/// `MediaVerificationSweep` runs this over many rows for the Settings
/// "Check all media" action, so the two must agree about what a result
/// means: the sweep counts a row inconclusive under exactly the predicate
/// this method declines to write under.
class MediaItemVerifier {
  MediaItemVerifier({
    required MediaSourceResolverRegistry registry,
    required MediaRepository repository,
    DateTime Function()? now,
  }) : _registry = registry,
       _repository = repository,
       _now = now ?? DateTime.now;

  final MediaSourceResolverRegistry _registry;
  final MediaRepository _repository;
  final DateTime Function() _now;

  Future<VerifyResult> verify(MediaItem item) async {
    final MediaSourceResolver resolver;
    try {
      resolver = _registry.resolverFor(item.sourceType);
    } on UnsupportedError {
      // A row whose source type has no registered resolver is a programmer
      // error, but the blast radius here must stay one item. Reporting a
      // transient failure and writing nothing is the honest outcome:
      // nothing was checked, so no verification date is owed either.
      return VerifyResult.transientError;
    }

    final VerifyResult result;
    try {
      result = await resolver.verify(item);
    } on Object {
      // reverifyAll catches per item so one bad row cannot abort the sweep;
      // a single-item check invoked from a button needs the same guarantee,
      // and nothing was learned, so no verification date is owed either.
      return VerifyResult.transientError;
    }
    final stamp = _now();

    // An unmounted volume, a momentarily unreadable file, a photo library
    // this app may not read, a disconnected connector account, and a row
    // whose bytes live on another machine are all reachability problems
    // rather than dead pointers. The orphan flag is sticky and syncs, so
    // setting it for any of them would leave the row marked missing after
    // the share came back, permission was granted, or the account was
    // reconnected, and would push that claim to every other device.
    // A write failure must not surface as a crash either. The check itself
    // succeeded, but its outcome was not persisted, so reporting a transient
    // failure is the honest answer rather than claiming a durable result.
    try {
      // Inverted deliberately: match the results that MAY move the flag
      // rather than the ones that may not. Written the other way round, a new
      // VerifyResult defaults to orphaning, and this method's blast radius is
      // a sticky flag that syncs to every other device.
      //
      // notFound is the only positive finding of absence. unauthenticated and
      // fromOtherDevice both mean "this device cannot reach it": the first
      // fires for every Lightroom row when the account is disconnected, the
      // second for a row whose bytes live on another machine. Orphaning
      // either would report a reachability problem as data loss.
      //
      // Narrow writes, never `updateMedia`: [item] is the caller's snapshot,
      // and an upload finishing after it was taken has stamped the row since.
      // Writing the snapshot back would roll those stamps to null and sync
      // the rollback, which is how a second device ends up believing a
      // backed-up photo has no backup. Inconclusive outcomes now return
      // before any write.
      // An inconclusive outcome writes NOTHING, not even the date. The date
      // is a synced column, so stamping it queued a pending record for every
      // row a Check all pass could not reach, and on a device that holds a
      // peer's library that is every row (media sync program spec 5.2). The
      // check did not learn whether the bytes exist, so there is nothing to
      // record: the resolver verdict in the media health report is where a
      // support thread reads what this device could see.
      if (result != VerifyResult.available && result != VerifyResult.notFound) {
        return result;
      }
      await _repository.stampVerification(
        item.id,
        verifiedAt: stamp,
        isOrphaned: result == VerifyResult.notFound,
      );
    } on Object {
      return VerifyResult.transientError;
    }
    return result;
  }
}
