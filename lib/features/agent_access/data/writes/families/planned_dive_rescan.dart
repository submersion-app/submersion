import 'package:meta/meta.dart';

import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';

/// For an entity whose writes rewrite planned dives inside the apply's
/// transaction (issue #4283), so a revert takes the rewrite back with the
/// template. Sync hears of the apply from the applier itself; the rescan a
/// save would queue (issue #2853) waits for [afterApply], once the rows are
/// committed and a scan can read them.
///
/// An apply that rolls back never reaches [afterApply]. What it held is
/// rescanned with a later apply on the same catalog, if one comes, which is
/// harmless for a dive that did not change.
mixin PlannedDiveRescan on WritableEntry {
  final _rewrittenDives = <String>{};

  /// Holds [dives], which a write of this apply rewrote, for [afterApply].
  void holdForRescan(Iterable<String> dives) => _rewrittenDives.addAll(dives);

  @override
  Future<void> afterApply(List<AppliedChange> changes, ApplyRun run) async {
    if (_rewrittenDives.isEmpty) return;
    final dives = Set.of(_rewrittenDives);
    _rewrittenDives.clear();
    scheduleQualityScan(dives);
  }

  @visibleForTesting
  Set<String> get pendingRescan => Set.unmodifiable(_rewrittenDives);
}
