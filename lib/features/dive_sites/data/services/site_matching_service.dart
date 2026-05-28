import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/matching/match_candidate.dart';
import 'package:submersion/features/dive_sites/domain/matching/match_thresholds.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_outcome.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_matcher.dart';

enum ProposalStatus { clear, review, none }

/// A display candidate for the review screen + map (resolved from a user site
/// or a bundled site; fields are null when the source lacks them).
class MatchCandidateView {
  final String id; // existing site id or bundled externalId
  final String name;
  final bool isExisting;
  final double distanceMeters;
  final GeoPoint location;
  final double? minDepth;
  final double? maxDepth;
  final String? country;
  final String? region;
  final double? rating;
  final String? difficulty; // SiteDifficulty.displayName
  final List<String> features; // bundled: wreck/reef/shore...
  final String? description;

  const MatchCandidateView({
    required this.id,
    required this.name,
    required this.isExisting,
    required this.distanceMeters,
    required this.location,
    this.minDepth,
    this.maxDepth,
    this.country,
    this.region,
    this.rating,
    this.difficulty,
    this.features = const [],
    this.description,
  });
}

/// One dive's matching proposal (no write state — selection lives in the
/// notifier).
class MatchProposal {
  final Dive dive;
  final ProposalStatus status;
  final List<MatchCandidateView> candidates; // distance-sorted
  final String? recommendedCandidateId; // matcher's pick (clear only)

  const MatchProposal({
    required this.dive,
    required this.status,
    this.candidates = const [],
    this.recommendedCandidateId,
  });
}

/// A user-confirmed (diveId -> chosen candidate) pair to apply.
class ConfirmedMatch {
  final String diveId;
  final String candidateId; // existing site id or bundled externalId
  const ConfirmedMatch(this.diveId, this.candidateId);
}

/// Outcome counts from applyConfirmed, for the result message.
class ApplyResult {
  final int divesLinked;
  final int sitesCreated;
  const ApplyResult({required this.divesLinked, required this.sitesCreated});
}

/// Runs a body inside a DB transaction. Injectable so unit tests can pass a
/// pass-through that doesn't require a real database.
typedef TransactionRunner = Future<void> Function(Future<void> Function() body);

/// Resolved candidate objects retained per dive so apply can act on a chosen id.
class _CandidateRef {
  final DiveSite? existing; // non-null when existing
  final ExternalDiveSite? bundled; // non-null when bundled
  const _CandidateRef.existing(this.existing) : bundled = null;
  const _CandidateRef.bundled(this.bundled) : existing = null;
}

/// Gathers candidates and computes proposals (no writes); applies confirmed
/// selections in a single transaction on demand.
class SiteMatchingService {
  SiteMatchingService({
    required SiteRepository siteRepository,
    required DiveSiteApiService apiService,
    required DiveRepository diveRepository,
    required this.diverId,
    required this.thresholds,
    TransactionRunner? runInTransaction,
  }) : _siteRepository = siteRepository,
       _apiService = apiService,
       _diveRepository = diveRepository,
       _runInTransaction =
           runInTransaction ??
           ((body) => DatabaseService.instance.database.transaction(body));

  final SiteRepository _siteRepository;
  final DiveSiteApiService _apiService;
  final DiveRepository _diveRepository;
  final String? diverId;
  final MatchThresholds thresholds;
  final TransactionRunner _runInTransaction;

  static const double _coincidenceMeters = 100;

  // Per-session state (no rollback bookkeeping — nothing is written until apply).
  List<DiveSite> _userSites = const [];
  final Map<String, Map<String, _CandidateRef>> _refsByDive = {};
  // Reset at the start of each applyConfirmed pass (batch dedup).
  final Map<String, String> _createdByExternalId = {};

  GeoPoint? _pointFor(Dive dive) => dive.entryLocation ?? dive.exitLocation;

  /// Computes proposals for [dives]. Performs NO database writes.
  Future<List<MatchProposal>> computeProposals(List<Dive> dives) async {
    _userSites = (await _siteRepository.getAllSites(
      diverId: diverId,
    )).where((s) => s.location != null).toList();

    final proposals = <MatchProposal>[];
    for (final dive in dives) {
      final point = _pointFor(dive);
      if (point == null) continue;

      final bundled = await _apiService.searchNearby(
        latitude: point.latitude,
        longitude: point.longitude,
        radiusKm: thresholds.outerRadiusMeters / 1000.0,
      );

      final refs = <String, _CandidateRef>{};
      final candidates = <MatchCandidate>[];
      for (final s in _userSites) {
        refs[s.id] = _CandidateRef.existing(s);
        candidates.add(
          MatchCandidate(id: s.id, location: s.location!, isExisting: true),
        );
      }
      for (final b in bundled.sites) {
        if (!b.hasCoordinates) continue;
        refs[b.externalId] = _CandidateRef.bundled(b);
        candidates.add(
          MatchCandidate(
            id: b.externalId,
            location: GeoPoint(b.latitude!, b.longitude!),
            isExisting: false,
          ),
        );
      }
      _refsByDive[dive.id] = refs;

      // Rank once; reuse for both the UI candidate list and the matcher
      // decision so distances are computed a single time per dive/site pair.
      final ranked = rankCandidates(point, candidates);
      final views = ranked
          .where((r) => r.distanceMeters <= thresholds.outerRadiusMeters)
          .map(
            (r) =>
                _viewFor(r.candidate, refs[r.candidate.id]!, r.distanceMeters),
          )
          .toList();

      final outcome = matchRanked(ranked, thresholds);

      proposals.add(switch (outcome) {
        NoMatch() => MatchProposal(dive: dive, status: ProposalStatus.none),
        Suggested() => MatchProposal(
          dive: dive,
          status: ProposalStatus.review,
          candidates: views,
        ),
        AutoMatch(:final siteId) => MatchProposal(
          dive: dive,
          status: ProposalStatus.clear,
          candidates: views,
          recommendedCandidateId: siteId,
        ),
      });
    }
    return proposals;
  }

  MatchCandidateView _viewFor(
    MatchCandidate c,
    _CandidateRef ref,
    double distance,
  ) {
    if (ref.existing != null) {
      final s = ref.existing!;
      return MatchCandidateView(
        id: s.id,
        name: s.name,
        isExisting: true,
        distanceMeters: distance,
        location: s.location!,
        minDepth: s.minDepth,
        maxDepth: s.maxDepth,
        country: s.country,
        region: s.region,
        rating: s.rating,
        difficulty: s.difficulty?.displayName,
        description: s.description.isEmpty ? null : s.description,
      );
    }
    final b = ref.bundled!;
    return MatchCandidateView(
      id: b.externalId,
      name: b.name,
      isExisting: false,
      distanceMeters: distance,
      location: GeoPoint(b.latitude!, b.longitude!),
      maxDepth: b.maxDepth,
      country: b.country,
      region: b.region ?? b.ocean,
      features: b.features,
      description: (b.description == null || b.description!.isEmpty)
          ? null
          : b.description,
    );
  }

  /// Applies confirmed selections in a single transaction. Returns counts.
  Future<ApplyResult> applyConfirmed(List<ConfirmedMatch> confirmed) async {
    _createdByExternalId.clear();
    var linked = 0;
    var created = 0;
    await _runInTransaction(() async {
      for (final c in confirmed) {
        final ref = _refsByDive[c.diveId]?[c.candidateId];
        if (ref == null) continue;
        final didCreate = await _applyOne(c.diveId, ref);
        linked++;
        if (didCreate) created++;
      }
    });
    return ApplyResult(divesLinked: linked, sitesCreated: created);
  }

  /// Links one dive to its chosen candidate. Returns true if a new bundled site
  /// row was created. Mirrors the original apply logic (dedup + coincidence
  /// guard) minus the rollback bookkeeping.
  Future<bool> _applyOne(String diveId, _CandidateRef ref) async {
    if (ref.existing != null) {
      await _diveRepository.setSite(diveId, ref.existing!.id);
      return false;
    }

    final bundled = ref.bundled!;
    final point = GeoPoint(bundled.latitude!, bundled.longitude!);

    // Batch dedup: this bundled site already materialised in this pass?
    final dedupId = _createdByExternalId[bundled.externalId];
    if (dedupId != null) {
      await _diveRepository.setSite(diveId, dedupId);
      return false;
    }

    // Coincidence guard: an existing user site essentially here?
    for (final s in _userSites) {
      if (distanceMeters(point, s.location!) <= _coincidenceMeters) {
        await _diveRepository.setSite(diveId, s.id);
        return false;
      }
    }

    // Materialise the bundled site, then link.
    final createdSite = await _siteRepository.createSite(
      bundled.toDiveSite(diverId: diverId),
    );
    _createdByExternalId[bundled.externalId] = createdSite.id;
    await _diveRepository.setSite(diveId, createdSite.id);
    return true;
  }
}
