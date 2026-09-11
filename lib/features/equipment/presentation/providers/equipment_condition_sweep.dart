import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_sweep.dart';
import 'package:submersion/features/equipment/presentation/providers/dive_sensor_summary_providers.dart';

/// Outcome of an [EquipmentConditionSweep.run].
class EquipmentConditionSweepResult {
  /// Dives visited, including those that failed. Mirrors the progress bar.
  final int swept;

  /// Dives whose summary threw. They stay stale and recompute lazily.
  final int failed;

  /// True when the caller's isCancelled callback stopped the sweep early.
  final bool cancelled;

  const EquipmentConditionSweepResult({
    required this.swept,
    required this.failed,
    required this.cancelled,
  });

  static const empty = EquipmentConditionSweepResult(
    swept: 0,
    failed: 0,
    cancelled: false,
  );
}

/// Brings `dive_sensor_summaries` up to date over a logbook, one dive at a
/// time, oldest first. Shared by the settings action, the post-restore
/// pass and the startup scheduler so the visit order and the cancel
/// contract live in one place. Same shape as [SafetyReviewSweep].
class EquipmentConditionSweep {
  final Ref _ref;

  const EquipmentConditionSweep(this._ref);

  /// Visits exactly [diveIds] when supplied; otherwise the stale dives of
  /// [diverId] (null means every diver), or every dive when [force] is
  /// true. [force] also recomputes rows that are current.
  ///
  /// [onProgress] fires once with (0, total), then after each dive.
  /// [isCancelled] is polled before each dive; cancelling is lossless, an
  /// unvisited dive computes lazily on first view.
  Future<EquipmentConditionSweepResult> run({
    String? diverId,
    List<String>? diveIds,
    bool force = false,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final repo = _ref.read(diveSensorSummaryRepositoryProvider);
    final ids =
        diveIds ??
        (force
            ? await _ref
                  .read(diveRepositoryProvider)
                  .getOrderedDiveIds(
                    diverId: diverId,
                    sort: SafetyReviewSweep.oldestFirstSort,
                  )
            : await repo.staleDiveIds(diverId: diverId));

    final total = ids.length;
    onProgress?.call(0, total);

    var swept = 0;
    var failed = 0;
    for (final diveId in ids) {
      if (isCancelled?.call() ?? false) {
        return EquipmentConditionSweepResult(
          swept: swept,
          failed: failed,
          cancelled: true,
        );
      }
      try {
        await repo.ensureCurrent(diveId, force: force);
      } catch (_) {
        // A corrupt series must not abort the pass; the dive stays stale
        // and is counted so the caller can say so.
        failed++;
      }
      swept++;
      onProgress?.call(swept, total);
    }
    return EquipmentConditionSweepResult(
      swept: swept,
      failed: failed,
      cancelled: false,
    );
  }
}

final equipmentConditionSweepProvider = Provider<EquipmentConditionSweep>(
  (ref) => EquipmentConditionSweep(ref),
);
