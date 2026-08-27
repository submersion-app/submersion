import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Outcome of a [SafetyReviewSweep.run].
class SafetyReviewSweepResult {
  /// Dives visited, including those that failed analysis. Mirrors the progress
  /// bar's position rather than a success count.
  final int swept;

  /// Dives whose analysis threw. They stay unanalyzed and recompute lazily.
  final int failed;

  /// True when the caller's isCancelled callback stopped the sweep early.
  final bool cancelled;

  const SafetyReviewSweepResult({
    required this.swept,
    required this.failed,
    required this.cancelled,
  });

  static const empty = SafetyReviewSweepResult(
    swept: 0,
    failed: 0,
    cancelled: false,
  );
}

/// Runs the post-dive safety review over a logbook, persisting each result.
///
/// Shared by the manual Settings sweep and the post-restore sweep so the
/// invalidate-before-read invariant below lives in exactly one place.
class SafetyReviewSweep {
  final Ref _ref;

  const SafetyReviewSweep(this._ref);

  /// Profile analysis carries residual tissue, CNS, and OTU state forward
  /// from earlier dives. Sweeping in that same order primes the provider cache
  /// one dive at a time instead of making the first newest dive recursively
  /// analyze much of the logbook before progress can advance.
  static const oldestFirstSort = SortState<DiveSortField>(
    field: DiveSortField.date,
    direction: SortDirection.ascending,
  );

  /// Analyzes every dive matching [diverId] (null means every diver), or
  /// exactly [diveIds] when supplied.
  ///
  /// Pass [diveIds] when the caller has already resolved the set and the
  /// container is scoped to match it — the post-restore sweep runs one pass per
  /// diver, each in a container pinned to that diver's settings, so it supplies
  /// the ids rather than re-deriving them here. [diverId] is ignored then.
  ///
  /// [onProgress] fires once with (0, total) to size a progress bar, then after
  /// each dive. [isCancelled] is polled before each dive; returning true stops
  /// the sweep and yields a result with `cancelled: true`. Cancelling is
  /// lossless -- unswept dives still compute lazily on first view.
  Future<SafetyReviewSweepResult> run({
    String? diverId,
    List<String>? diveIds,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    // Master toggle off: safetyReviewProvider would refuse to compute anyway,
    // so skip the whole pass rather than issuing a marker read per dive.
    if (!_ref.read(safetyReviewEnabledProvider)) {
      return SafetyReviewSweepResult.empty;
    }

    final ids =
        diveIds ??
        await _ref
            .read(diveRepositoryProvider)
            .getOrderedDiveIds(diverId: diverId, sort: oldestFirstSort);

    final total = ids.length;
    onProgress?.call(0, total);

    var swept = 0;
    var failed = 0;

    for (final diveId in ids) {
      if (isCancelled?.call() ?? false) {
        return SafetyReviewSweepResult(
          swept: swept,
          failed: failed,
          cancelled: true,
        );
      }
      try {
        // Invalidate first. safetyReviewProvider is not autoDispose, so any
        // dive whose detail page was opened this session holds a cached
        // AsyncValue -- including a cached null from a dive opened mid-sync
        // before its profile arrived. A bare read would return that cached
        // value and never run the compute-through-cache, leaving the review
        // missing until an app restart.
        _ref.invalidate(safetyReviewProvider(diveId));
        await _ref.read(safetyReviewProvider(diveId).future);
      } catch (_) {
        // A dive that fails analysis (corrupt profile) must not abort the
        // sweep; it stays unanalyzed. Counted so callers can report honestly
        // rather than implying every dive was analyzed.
        failed++;
      }
      swept++;
      onProgress?.call(swept, total);
    }

    return SafetyReviewSweepResult(
      swept: swept,
      failed: failed,
      cancelled: false,
    );
  }
}

final safetyReviewSweepProvider = Provider<SafetyReviewSweep>(
  (ref) => SafetyReviewSweep(ref),
);
