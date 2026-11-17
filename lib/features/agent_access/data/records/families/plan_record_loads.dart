import 'package:submersion/features/agent_access/data/documents/plan_documents.dart';
import 'package:submersion/features/agent_access/data/records/record_entity.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';

/// A saved plan with whether the entry in the log its link names is still
/// only planned, if there is one.
typedef LoggedPlan = ({DivePlan plan, Map<String, bool> logged});

/// A saved series with the same for the entries its dives link.
typedef LoggedSeries = ({StoredSeries series, Map<String, bool> logged});

/// The plans [ids] name, each with its entry in the log, read in one batch
/// for them all.
Future<Map<String, LoggedPlan>> loadLoggedPlans(
  RecordRepositories r,
  List<String> ids,
) async {
  final plans = await loadEach(ids, r.divePlans.getPlan);
  final logged = await loggedEntryFlags(r, linkedDiveIds(plans.values));
  return {
    for (final MapEntry(:key, :value) in plans.entries)
      key: (plan: value, logged: logged),
  };
}

/// The series [ids] name, each with its dives' entries in the log, read as
/// [loadLoggedPlans] reads them.
Future<Map<String, LoggedSeries>> loadLoggedSeries(
  RecordRepositories r,
  List<String> ids,
) async {
  final series = await loadEach(ids, r.divePlanSeries.getSeries);
  final logged = await loggedEntryFlags(
    r,
    linkedDiveIds([
      for (final s in series.values)
        for (final dive in s.dives) dive.plan,
    ]),
  );
  return {
    for (final MapEntry(:key, :value) in series.entries)
      key: (series: value, logged: logged),
  };
}

/// Whether each of [diveIds] still in the log is only planned, by dive id;
/// a dive no longer there has no entry. Where a dive stands is a flag on its
/// row, so only that column is read, never the dive itself.
Future<Map<String, bool>> loggedEntryFlags(
  RecordRepositories r,
  Iterable<String> diveIds,
) async {
  final ids = diveIds.toSet().toList();
  if (ids.isEmpty) return const {};
  final dives = r.db.dives;
  final flags = <String, bool>{};
  for (final chunk in seriesIdChunks(ids)) {
    final rows =
        await (r.db.selectOnly(dives)
              ..addColumns([dives.id, dives.isPlanned])
              ..where(dives.id.isIn(chunk)))
            .get();
    for (final row in rows) {
      flags[row.read(dives.id)!] = row.read(dives.isPlanned) ?? false;
    }
  }
  return flags;
}
