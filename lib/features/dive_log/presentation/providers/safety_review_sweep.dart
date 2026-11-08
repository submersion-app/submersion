import 'dart:collection';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_analysis_release.dart';
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

  /// How many of the most recently swept dives keep their analysis loaded.
  ///
  /// Each dive's analysis reads the dive before it (residual tissue and CNS)
  /// and every earlier dive that day (residual OTU), so the trail has to
  /// cover a dive day or the next dive replays the chain behind it. Older
  /// dives are released as the sweep moves on: an analysis is otherwise held
  /// for `diveDataRetention`, and a library-wide pass would keep every dive
  /// analysed in that window (#4254).
  static const warmTrail = 8;

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
  ///
  /// [recompute] grades every dive again, even one whose stored review is
  /// current for this engine and these settings. The manual "Analyze all
  /// dives" sets it: a user runs that after correcting dive data, which the
  /// "is current" check cannot see (#1643). Without it the sweep only fills
  /// in reviews that are missing or out of date, which is all a restore needs.
  Future<SafetyReviewSweepResult> run({
    String? diverId,
    List<String>? diveIds,
    bool recompute = false,
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

    // A dive whose data was already loaded (an open page, a recent visit)
    // keeps it on its own terms; the sweep releases only what it loaded.
    final heldBefore = {
      for (final id in ids)
        if (isDiveAnalysisLoaded(_ref.container, id) ||
            _ref.container.exists(safetyReviewProvider(id)))
          id,
    };
    final trail = ListQueue<String>();

    try {
      for (final diveId in ids) {
        if (isCancelled?.call() ?? false) {
          return SafetyReviewSweepResult(
            swept: swept,
            failed: failed,
            cancelled: true,
          );
        }
        try {
          // Invalidate first. safetyReviewProvider keeps a dive's entry for
          // diveDataRetention after its detail page lets go, and for as long
          // as the page is open, so a dive viewed recently holds a cached
          // AsyncValue, including a cached null from a dive opened mid-sync
          // before its profile arrived. A bare read would return that cached
          // value and never run the compute-through-cache, leaving the review
          // missing until the entry was released.
          //
          // Recompute invalidates before computing, too, so a build already
          // under way for this dive (its detail page is open) stands down
          // instead of saving its result over the recompute's. The
          // invalidated provider then rebuilds from the saved review on its
          // next read, or at once through its change tick for an open page,
          // so it is not read here. The recompute provider is autoDispose:
          // the held listener keeps it for this one read, and closing it
          // disposes it.
          //
          // Nothing else need be listening to either provider, so a bare read
          // would never complete if the review were invalidated mid-load
          // (#3807).
          _ref.invalidate(safetyReviewProvider(diveId));
          await _ref.container.awaitFuture(
            recompute
                ? safetyReviewRecomputeProvider(diveId).future
                : safetyReviewProvider(diveId).future,
          );
        } catch (_) {
          // A dive that fails analysis (corrupt profile) must not abort the
          // sweep; it stays unanalyzed. Counted so callers can report
          // honestly rather than implying every dive was analyzed.
          failed++;
        }
        if (!heldBefore.contains(diveId)) {
          trail.addLast(diveId);
          if (trail.length > warmTrail) _release(trail.removeFirst());
        }
        swept++;
        onProgress?.call(swept, total);
      }

      return SafetyReviewSweepResult(
        swept: swept,
        failed: failed,
        cancelled: false,
      );
    } finally {
      // Finished or cancelled, nothing reads the trail any more.
      trail.forEach(_release);
    }
  }

  /// Frees what reviewing [diveId] loaded: its review entry, which watches
  /// the analysis and would otherwise keep it, then the analysis itself.
  void _release(String diveId) {
    _ref.invalidate(safetyReviewProvider(diveId));
    releaseDiveAnalysis(_ref, diveId);
  }
}

final safetyReviewSweepProvider = Provider<SafetyReviewSweep>(
  (ref) => SafetyReviewSweep(ref),
);
