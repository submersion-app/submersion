import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_sweep.dart';
import 'package:submersion/features/equipment/data/services/equipment_findings_pass.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/dive_sensor_summary_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/exposure_thresholds_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Outcome of an [EquipmentConditionSweep.run].
class EquipmentConditionSweepResult {
  /// Dives visited, including those that failed. Mirrors the progress bar.
  final int swept;

  /// Dives whose summary threw. They stay stale and recompute lazily.
  final int failed;

  /// Active items visited by the findings pass, including failures.
  final int items;

  /// Items whose findings refresh threw; they recompute lazily on view.
  final int itemsFailed;

  /// True when the caller's isCancelled callback stopped the sweep early.
  final bool cancelled;

  const EquipmentConditionSweepResult({
    required this.swept,
    required this.failed,
    this.items = 0,
    this.itemsFailed = 0,
    required this.cancelled,
  });

  static const empty = EquipmentConditionSweepResult(
    swept: 0,
    failed: 0,
    cancelled: false,
  );
}

/// Brings `dive_sensor_summaries` up to date over a logbook, one dive at a
/// time, oldest first, then runs the condition engine over the diver's
/// active gear through the review marker. Shared by the settings action,
/// the post-restore pass and the startup scheduler so the visit order and
/// the cancel contract live in one place. Same shape as [SafetyReviewSweep].
class EquipmentConditionSweep {
  final Ref _ref;

  const EquipmentConditionSweep(this._ref);

  /// Visits exactly [diveIds] when supplied; otherwise the stale dives of
  /// [diverId] (null means every diver), or every dive when [force] is
  /// true. [force] also recomputes rows that are current.
  ///
  /// With [findings] set (the default) and the engine's master toggle on,
  /// the active items follow the dives in the same progress count. Each
  /// item's inputs are read to build its fingerprint; one that matches the
  /// marker skips the engine and writes nothing.
  ///
  /// [onProgress] fires once with (0, total), then after each dive and
  /// each item. [isCancelled] is polled before each; cancelling is
  /// lossless, an unvisited dive or item computes lazily on first view.
  Future<EquipmentConditionSweepResult> run({
    String? diverId,
    List<String>? diveIds,
    bool force = false,
    bool findings = true,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final repo = _ref.read(diveSensorSummaryRepositoryProvider);
    final runFindings = findings && _ref.read(conditionEngineEnabledProvider);
    final pass = EquipmentFindingsPass(
      equipment: _ref.read(equipmentRepositoryProvider),
      refresher: _ref.read(equipmentConditionRefresherProvider),
    );
    final items = runFindings
        ? await pass.activeItems(diverId: diverId)
        : const <EquipmentItem>[];
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

    final total = ids.length + items.length;
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
    final passResult = items.isEmpty
        ? EquipmentFindingsPassResult.empty
        : await pass.run(
            items: items,
            thresholds: _ref.read(exposureThresholdsProvider),
            onProgress: (done, _) {
              if (done > 0) onProgress?.call(swept + done, total);
            },
            isCancelled: isCancelled,
          );
    return EquipmentConditionSweepResult(
      swept: swept,
      failed: failed,
      items: passResult.items,
      itemsFailed: passResult.failed,
      cancelled: passResult.cancelled,
    );
  }
}

final equipmentConditionSweepProvider = Provider<EquipmentConditionSweep>(
  (ref) => EquipmentConditionSweep(ref),
);
