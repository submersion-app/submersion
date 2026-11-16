import 'package:submersion/features/agent_access/data/documents/plan_documents.dart';
import 'package:submersion/features/agent_access/data/records/record_entity.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';

/// A saved plan with the entry in the log its link names, if any.
typedef LoggedPlan = ({DivePlan plan, Map<String, Dive> logged});

/// A saved series with the entries in the log its dives link.
typedef LoggedSeries = ({StoredSeries series, Map<String, Dive> logged});

/// The plans [ids] name, each with its entry in the log, read in one batch
/// for them all: a dive's state is a flag on its row, so no samples are
/// decoded.
Future<Map<String, LoggedPlan>> loadLoggedPlans(
  RecordRepositories r,
  List<String> ids,
) async {
  final plans = await loadEach(ids, r.divePlans.getPlan);
  final logged = await _entries(r, linkedDiveIds(plans.values));
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
  final logged = await _entries(
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

Future<Map<String, Dive>> _entries(
  RecordRepositories r,
  Set<String> diveIds,
) async => byId(
  await r.dives.getDivesByIdsWithoutSamples(diveIds.toList()),
  (d) => d.id,
);
