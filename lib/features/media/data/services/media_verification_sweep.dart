import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_item_verifier.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// What one sweep pass found.
///
/// [inconclusive] is counted separately on purpose. A pass that could not
/// read the photo library checked nothing, and folding those rows into a
/// success count would hand the user a clean bill of health for a library
/// nobody actually looked at.
class SweepOutcome {
  const SweepOutcome({
    required this.processed,
    required this.flipped,
    required this.inconclusive,
    required this.failed,
  });

  /// Rows the sweep attempted, including the inconclusive and failed ones.
  final int processed;

  /// Rows whose orphan flag actually changed.
  final int flipped;

  /// Rows whose source could not be REACHED, so nothing was learned about
  /// whether their bytes still exist and their orphan flag was left alone.
  ///
  /// Every [VerifyResult] other than `available` and `notFound`: no photo
  /// permission, an unmounted volume, a transient error, a disconnected
  /// connector account, and a row whose bytes live on another machine.
  /// Deliberately defined as "not a positive finding" rather than as a list,
  /// so it stays in step with the verifier when the enum grows.
  ///
  /// Callers must not attribute a CAUSE to this count: it aggregates several,
  /// and a message naming one of them would be wrong for the others.
  final int inconclusive;

  /// Rows whose verification threw.
  final int failed;
}

/// Verifies media rows of any source type, dispatching through the resolver
/// registry that [MediaItemVerifier] already owns.
///
/// Reuses [MediaItemVerifier] per item rather than reimplementing the
/// persistence contract. Two implementations of "what does this result mean
/// for isOrphaned" would eventually disagree about the same row, which is the
/// divergence MediaItemVerifier's own doc comment exists to warn about.
///
/// Exists because the only bulk sweep before it,
/// `LocalFilesDiagnosticsService.reverifyAll`, was filtered to
/// `MediaSourceType.localFile`. A library of gallery rows therefore had its
/// orphan flag written at link time and never again.
class MediaVerificationSweep {
  MediaVerificationSweep({
    required MediaRepository repository,
    required MediaItemVerifier verifier,
  }) : _repository = repository,
       _verifier = verifier;

  final MediaRepository _repository;
  final MediaItemVerifier _verifier;
  final _log = LoggerService.forClass(MediaVerificationSweep);

  /// Verifies every row of [sourceTypes], or every row in the library when it
  /// is null.
  ///
  /// Per-item failures are logged and counted, never rethrown: one bad row
  /// must not abort a pass over thousands.
  Future<SweepOutcome> run({
    Set<MediaSourceType>? sourceTypes,
    void Function(int done, int total)? onProgress,
  }) async {
    final items = await _repository.getAllBySourceTypes(sourceTypes);
    _log.info('Verification sweep starting over ${items.length} rows');
    var flipped = 0;
    var inconclusive = 0;
    var failed = 0;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      try {
        final result = await _verifier.verify(item);
        // Mirrors MediaItemVerifier's own predicate rather than restating its
        // exclusion list. The two drifting apart is exactly how the sweep
        // would start reporting updates for rows the verifier declined to
        // touch, so both are written as "notFound is the only positive
        // finding".
        if (result != VerifyResult.available &&
            result != VerifyResult.notFound) {
          // Nothing was learned, and MediaItemVerifier left the flag alone.
          inconclusive++;
        } else if ((result == VerifyResult.notFound) != item.isOrphaned) {
          flipped++;
        }
      } catch (e, st) {
        failed++;
        _log.error(
          'Verification failed for ${item.id}',
          error: e,
          stackTrace: st,
        );
      }
      onProgress?.call(i + 1, items.length);
    }

    _log.info(
      'Verification sweep complete: ${items.length} processed, '
      '$flipped flipped, $inconclusive inconclusive, $failed failed',
    );
    return SweepOutcome(
      processed: items.length,
      flipped: flipped,
      inconclusive: inconclusive,
      failed: failed,
    );
  }
}
