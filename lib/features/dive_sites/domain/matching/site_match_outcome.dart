import 'package:submersion/features/dive_sites/domain/matching/match_candidate.dart';

/// A candidate paired with its computed distance to the dive's GPS point.
class RankedCandidate {
  final MatchCandidate candidate;
  final double distanceMeters;

  const RankedCandidate(this.candidate, this.distanceMeters);
}

/// Result of matching one dive's GPS against candidate sites.
sealed class SiteMatchOutcome {
  const SiteMatchOutcome();
}

/// High-confidence single match to auto-apply.
class AutoMatch extends SiteMatchOutcome {
  final String siteId; // existing site id or bundled externalId
  final bool isExisting;
  final double distanceMeters;

  const AutoMatch({
    required this.siteId,
    required this.isExisting,
    required this.distanceMeters,
  });
}

/// One or more candidates worth showing, needing user confirmation/choice.
class Suggested extends SiteMatchOutcome {
  final List<RankedCandidate> candidates; // distance-sorted, length >= 1

  const Suggested(this.candidates);
}

/// Nothing within the outer radius.
class NoMatch extends SiteMatchOutcome {
  const NoMatch();
}
