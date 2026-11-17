import 'dart:math' as math;

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/matching/match_candidate.dart';
import 'package:submersion/features/dive_sites/domain/matching/match_thresholds.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_outcome.dart';

/// How far a map-placed researched record is offered from: its position is
/// only good enough to name the dive (wider sources design, section 5).
const double kMapPlacedReachMeters = 2000;

/// How far from the dive a map-placed record is in range:
/// [kMapPlacedReachMeters], or the outer radius when that is wider. The
/// matching service reads the catalogue out to it, so the two agree.
double mapPlacedReachMeters(MatchThresholds thresholds) =>
    math.max(thresholds.outerRadiusMeters, kMapPlacedReachMeters);

/// How far from the dive [candidate] is in range: the outer radius, or
/// [mapPlacedReachMeters] for a map-placed record.
double reachMeters(MatchCandidate candidate, MatchThresholds thresholds) =>
    candidate.isMapPlaced
    ? mapPlacedReachMeters(thresholds)
    : thresholds.outerRadiusMeters;

/// Ranks [candidates] by great-circle distance from [point], nearest first.
/// Computed once and shared by the matcher decision and the UI candidate list,
/// so distances are never recomputed for the same dive/site pair.
List<RankedCandidate> rankCandidates(
  GeoPoint point,
  List<MatchCandidate> candidates,
) {
  return candidates
      .map((c) => RankedCandidate(c, distanceMeters(point, c.location)))
      .toList()
    ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
}

/// The confidence rule over pre-ranked candidates, in order:
/// 1. Keep candidates within the outer radius ([reachMeters]: a map-placed
///    record reaches further). None -> [NoMatch].
/// 2. Pool selection: if any existing site is within the inner radius, the
///    auto-decision considers only those (existing-site precedence — never
///    auto-create a bundled duplicate when the user already has a site here);
///    otherwise, if any catalogue dive site is within the inner radius, only
///    those (a place known to be dived beats a charted wreck or a reef
///    deployment that happens to lie nearer); otherwise every candidate
///    within the inner radius, which are then register records only. A
///    register record is not picked on its own when a dive site lies
///    within the separation margin behind it, even outside the inner
///    radius: the diver chooses.
/// 3. The nearest in the pool is a clear [AutoMatch] when it has no in-pool
///    competitor, or the runner-up is farther by at least the separation
///    margin. Otherwise -> [Suggested] (all in-range candidates, both pools).
///    A researched record is never an [AutoMatch]: when it is the nearest
///    in the pool the diver chooses ([Suggested]). It still counts as a
///    competitor for the runner-up rule, unless it is map-placed: a
///    map-placed record is never in the pool and never a competitor, and
///    is listed whenever anything is [Suggested].
SiteMatchOutcome matchRanked(
  List<RankedCandidate> ranked,
  MatchThresholds thresholds,
) {
  final inRange = ranked
      .where((r) => r.distanceMeters <= reachMeters(r.candidate, thresholds))
      .toList();
  if (inRange.isEmpty) return const NoMatch();
  // A map-placed record is offered, and has no say in the automatic pick:
  // it is never in the pool and never a competitor.
  final contenders = inRange.where((r) => !r.candidate.isMapPlaced).toList();

  final innerExisting = contenders
      .where(
        (r) =>
            r.candidate.isExisting &&
            r.distanceMeters <= thresholds.innerRadiusMeters,
      )
      .toList();
  final innerAny = contenders
      .where((r) => r.distanceMeters <= thresholds.innerRadiusMeters)
      .toList();
  final innerSites = innerAny.where((r) => !r.candidate.isRegister).toList();

  final pool = innerExisting.isNotEmpty
      ? innerExisting
      : innerSites.isNotEmpty
      ? innerSites
      : innerAny;
  if (pool.isEmpty) return Suggested(inRange);

  final nearest = pool.first;
  if (nearest.candidate.isResearched) return Suggested(inRange);
  if (nearest.candidate.isRegister) {
    // The pool is register records only. A dive site just outside the
    // inner radius is still too near to say which of the two was dived.
    final siteCloseBehind = contenders.any(
      (r) =>
          !r.candidate.isRegister &&
          (r.distanceMeters - nearest.distanceMeters) <
              thresholds.separationMeters,
    );
    if (siteCloseBehind) return Suggested(inRange);
  }
  final clear =
      pool.length == 1 ||
      (pool[1].distanceMeters - nearest.distanceMeters) >=
          thresholds.separationMeters;

  if (clear) {
    return AutoMatch(
      siteId: nearest.candidate.id,
      isExisting: nearest.candidate.isExisting,
      distanceMeters: nearest.distanceMeters,
    );
  }
  return Suggested(inRange);
}

/// Matches one dive GPS [point] against [candidates] by ranking them and
/// applying [matchRanked]. Convenience entry point for callers that have raw
/// candidates; callers that also need the ranked list should rank once with
/// [rankCandidates] and call [matchRanked] directly.
SiteMatchOutcome matchDive({
  required GeoPoint point,
  required List<MatchCandidate> candidates,
  required MatchThresholds thresholds,
}) => matchRanked(rankCandidates(point, candidates), thresholds);
