import 'package:submersion/features/dive_computer/domain/services/fill_target_matcher.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// What to do with one Apple Health workout (issue #637).
sealed class HealthDiveRoute {
  const HealthDiveRoute();
}

/// The workout fills the draft [diveId]: the watch's readings become its
/// profile.
class FillDraft extends HealthDiveRoute {
  const FillDraft(this.diveId);
  final String diveId;
}

/// The workout falls on the day of the plan [diveId]. The review and the
/// wizard default to filling it; the automatic import holds it for the
/// diver, since a plan's day is weak evidence.
class FillPlan extends HealthDiveRoute {
  const FillPlan(this.diveId);
  final String diveId;
}

/// The workout joins the logged dive [diveId] as a second set of readings.
class Consolidate extends HealthDiveRoute {
  const Consolidate(this.diveId);
  final String diveId;
}

/// Nothing to join: a new dive.
class ImportNew extends HealthDiveRoute {
  const ImportNew();
}

/// More than one candidate, or too weak a match: nothing is merged and the
/// diver decides.
class NeedsReview extends HealthDiveRoute {
  const NeedsReview(this.candidateIds);
  final List<String> candidateIds;
}

/// A match with a logged dive at or above this joins it.
const double kHealthConsolidateScore = 0.85;

/// A match with a logged dive at or above this, and below
/// [kHealthConsolidateScore], waits for the diver.
const double kHealthReviewScore = 0.5;

/// One route per workout, in order. Three passes, each taking only the
/// workouts the one before left, in order of evidence:
///
/// 1. Drafts, by [FillTargetMatcher]'s tap-window rule. A pair fills it; a
///    workout that fits two drafts waits for the diver.
/// 2. Logged dives in [loggedNear], by [DiveMatcher.calculateMatchScore]:
///    [kHealthConsolidateScore] or more joins the best, [kHealthReviewScore]
///    or more waits for the diver.
/// 3. Plans, by [FillTargetMatcher]'s same-day rule over the whole batch, so
///    several workouts of one day pair with plans as a download batch does.
///
/// Anything left imports as new. The classifier only names the route; the
/// caller decides whether a [FillPlan] is written or held.
List<HealthDiveRoute> classifyHealthDives(
  List<ImportedDive> workouts, {
  required List<Dive> unfilled,
  required List<Dive> loggedNear,
  DiveMatcher matcher = const DiveMatcher(),
  FillTargetMatcher fillMatcher = const FillTargetMatcher(),
}) {
  final routes = List<HealthDiveRoute?>.filled(workouts.length, null);
  final windows = [
    for (final w in workouts) (start: w.startTime, end: w.endTime),
  ];

  // 1. Drafts.
  final drafts = [
    for (final d in unfilled)
      if (d.isDraft) d,
  ];
  final draftPairing = fillMatcher.match(incoming: windows, targets: drafts);
  draftPairing.pairs.forEach((i, id) => routes[i] = FillDraft(id));
  draftPairing.ambiguous.forEach((i, ids) => routes[i] = NeedsReview(ids));

  // 2. Logged dives.
  for (var i = 0; i < workouts.length; i++) {
    if (routes[i] != null) continue;
    final w = workouts[i];
    String? bestId;
    var bestScore = 0.0;
    for (final dive in loggedNear) {
      final score = matcher.calculateMatchScore(
        wearableStartTime: w.startTime,
        wearableMaxDepth: w.maxDepth,
        wearableDurationSeconds: w.duration.inSeconds,
        existingStartTime: dive.entryTime ?? dive.dateTime,
        existingMaxDepth: dive.maxDepth ?? 0,
        existingDurationSeconds: dive.effectiveRuntime?.inSeconds ?? 0,
      );
      if (score > bestScore) {
        bestScore = score;
        bestId = dive.id;
      }
    }
    if (bestId == null) continue;
    if (bestScore >= kHealthConsolidateScore) {
      routes[i] = Consolidate(bestId);
    } else if (bestScore >= kHealthReviewScore) {
      routes[i] = NeedsReview([bestId]);
    }
  }

  // 3. Plans, over the workouts still open.
  final rest = [
    for (var i = 0; i < workouts.length; i++)
      if (routes[i] == null) i,
  ];
  final plans = [
    for (final d in unfilled)
      if (d.isPlanned && !d.isDraft) d,
  ];
  final planPairs = fillMatcher.pair(
    incoming: [for (final i in rest) windows[i]],
    targets: plans,
  );
  planPairs.forEach((k, id) => routes[rest[k]] = FillPlan(id));

  return [for (final r in routes) r ?? const ImportNew()];
}
