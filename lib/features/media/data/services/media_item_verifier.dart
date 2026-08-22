import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// Checks one media item's source and persists what it finds.
///
/// The only other caller of `MediaSourceResolver.verify` that writes the
/// result is `LocalFilesDiagnosticsService.reverifyAll`, which is a bulk
/// sweep wired directly to `LocalFileResolver` rather than dispatching
/// through the registry. This exists so a user can check a single item of
/// any source type, and it mirrors that service's persistence contract
/// exactly: a divergence would let a one-off check and the bulk sweep
/// disagree about the same row.
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

    // A volume that is not mounted, a file that is present but momentarily
    // unreadable, or a photo library this app is not currently allowed to
    // read, are all recoverable conditions rather than dead pointers. The
    // orphan flag is sticky, so setting it here would leave the row marked
    // missing after the share came back or permission was granted.
    // A write failure must not surface as a crash either. The check itself
    // succeeded, but its outcome was not persisted, so reporting a transient
    // failure is the honest answer rather than claiming a durable result.
    try {
      if (result == VerifyResult.volumeOffline ||
          result == VerifyResult.accessDenied ||
          result == VerifyResult.transientError) {
        await _repository.updateMedia(item.copyWith(lastVerifiedAt: stamp));
        return result;
      }
      await _repository.updateMedia(
        item.copyWith(
          isOrphaned: result != VerifyResult.available,
          lastVerifiedAt: stamp,
        ),
      );
    } on Object {
      return VerifyResult.transientError;
    }
    return result;
  }
}
