import 'dart:convert';

import 'package:clock/clock.dart';

import 'package:submersion/features/agent_access/data/planning/plan_request.dart';
import 'package:submersion/features/agent_access/data/planning/plan_request_series.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/planner/data/services/stored_series_results.dart';
import 'package:submersion/features/planner/domain/entities/stored_series.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// The dives of a series created from scratch, each as `compute_plan` takes
/// one, so a dive's `resolved_inputs` save unchanged. Only its shape is
/// checked here; [seriesFromDives] reads each dive as `compute_plan` does,
/// with the owner's settings, which a codec does not have.
///
/// The parsed value is the list as JSON.
class PlanSeriesDivesCodec extends FieldCodec {
  const PlanSeriesDivesCodec();

  @override
  String get describe =>
      'a list of 2 to $maxPlanRequestDives dives, each as compute_plan\'s '
      'dives take one (its resolved_inputs save unchanged)';

  @override
  Object parseValue(Object raw) {
    if (raw is! List || raw.any((dive) => dive is! Map)) {
      throw const FieldRefusal('This field takes a list of dive objects.');
    }
    return jsonEncode(raw);
  }

  @override
  Object? wire(Object? value) => value is String ? jsonDecode(value) : value;

  /// [value], parsed by this codec, as `compute_plan`'s `dives` argument.
  static List<Object?> dives(Object? value) =>
      jsonDecode(value! as String) as List<Object?>;
}

/// Why [dives] cannot be a series, or null when they can: a series has two
/// dives at least, one dive being a plan of its own.
String? seriesDiveCountProblem(Object? dives) {
  final n = PlanSeriesDivesCodec.dives(dives).length;
  if (n >= 2 && n <= maxPlanRequestDives) return null;
  return n < 2
      ? 'A series has at least two dives; save one dive as a dive_plans '
            'record.'
      : 'dives: a series created here has at most $maxPlanRequestDives '
            'dives.';
}

/// The series [dives] describe, as the planner would save it: each dive's
/// plan named [name], where its tanks carry from, how it is timed, and the
/// summary [config] computes for it (issue #4203). [followedDiveId] is the
/// logged dive it follows, read through [followOf].
///
/// Throws an [AgentToolException] naming the field at fault, as
/// `compute_plan` refuses the same dives.
Future<StoredSeries> seriesFromDives({
  required Object? dives,
  required String name,
  required String diverId,
  required String? followedDiveId,
  required PlanEngineConfig config,
  required SeriesFollowReader? followOf,
}) async {
  final request = parsePlanRequest({
    'dives': PlanSeriesDivesCodec.dives(dives),
    'follow_dive_id': ?followedDiveId,
  }, settings: config);
  final follow = followedDiveId == null
      ? null
      : await followOf?.call(followedDiveId);
  if (followedDiveId != null && follow == null) {
    throw AgentToolException(
      AgentToolErrorCode.invalidArgument,
      '$followedDiveId is not a logged dive.',
      details: {'field': 'followed_dive_id'},
    );
  }
  final built = storedSeriesFor(request, follow: follow, now: clock.now());
  final computed = computeSeriesFromStored(
    built.stored,
    follow: follow,
    config: config,
  );
  return StoredSeries(
    id: built.stored.id,
    name: name,
    diverId: diverId,
    followedDiveId: followedDiveId,
    dives: [
      for (final (i, dive) in built.stored.dives.indexed)
        dive.copyWith(
          plan: dive.plan.copyWith(name: name),
          summaryMaxDepth: computed.results[i].outcome.maxDepth,
          summaryRuntimeSeconds: computed.results[i].outcome.runtimeSeconds,
          summaryTtsSeconds: computed.results[i].outcome.ttsAtBottom,
        ),
    ],
  );
}
