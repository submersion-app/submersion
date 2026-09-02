import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
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
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/services/photo_gps_point_selector.dart';

enum ProposalStatus { clear, review, none }

/// A display candidate for the review screen + map (resolved from a user site
/// or a bundled site; fields are null when the source lacks them).
class MatchCandidateView {
  final String id; // existing site id or bundled externalId
  final String name;
  final bool isExisting;

  /// The dive's own site, offered so it can be given these coordinates.
  final bool isCurrentSite;
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
    this.isCurrentSite = false,
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

/// Where a proposal's point came from. Dive-computer fixes are measured
/// entry/exit positions; photo fixes are the surface position of the photo
/// nearest the dive's entry time, so the review page labels them.
enum PointSource { diveComputer, photo }

/// One dive's matching proposal (no write state — selection lives in the
/// notifier).
class MatchProposal {
  final Dive dive;
  final ProposalStatus status;
  final List<MatchCandidateView> candidates; // distance-sorted
  final String? recommendedCandidateId; // matcher's pick (clear only)
  final GeoPoint? point;
  final PointSource pointSource;

  const MatchProposal({
    required this.dive,
    required this.status,
    this.candidates = const [],
    this.recommendedCandidateId,
    this.point,
    this.pointSource = PointSource.diveComputer,
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
  final int sitesLocated;
  const ApplyResult({
    required this.divesLinked,
    required this.sitesCreated,
    this.sitesLocated = 0,
  });
}

/// Runs a body inside a DB transaction. Injectable so unit tests can pass a
/// pass-through that doesn't require a real database.
typedef TransactionRunner = Future<void> Function(Future<void> Function() body);

typedef _ResolvedPoint = ({GeoPoint point, PointSource source});

/// Resolved candidate objects retained per dive so apply can act on a chosen id.
class _CandidateRef {
  final DiveSite? existing; // link the dive to this site
  final ExternalDiveSite? bundled; // materialise, then link
  final DiveSite? currentSite; // keep the dive's site, give it coordinates
  const _CandidateRef.existing(this.existing)
    : bundled = null,
      currentSite = null;
  const _CandidateRef.bundled(this.bundled)
    : existing = null,
      currentSite = null;
  const _CandidateRef.currentSite(this.currentSite)
    : existing = null,
      bundled = null;
}

/// What one confirmed apply did, for the result counts.
enum _ApplyOutcome { linked, created, located }

/// Gathers candidates and computes proposals (no writes); applies confirmed
/// selections in a single transaction on demand.
class SiteMatchingService {
  SiteMatchingService({
    required SiteRepository siteRepository,
    required DiveSiteApiService apiService,
    required DiveRepository diveRepository,
    required MediaRepository mediaRepository,
    required this.diverId,
    required this.thresholds,
    TransactionRunner? runInTransaction,
    this.fetchElevation,
  }) : _siteRepository = siteRepository,
       _apiService = apiService,
       _diveRepository = diveRepository,
       _mediaRepository = mediaRepository,
       _runInTransaction =
           runInTransaction ??
           ((body) => DatabaseService.instance.database.transaction(body));

  final SiteRepository _siteRepository;
  final DiveSiteApiService _apiService;
  final DiveRepository _diveRepository;
  final MediaRepository _mediaRepository;
  final String? diverId;
  final MatchThresholds thresholds;

  /// Best-effort ground elevation for a point; null disables the altitude
  /// pass. Runs only after the apply transaction commits.
  final Future<double?> Function(GeoPoint point)? fetchElevation;
  final TransactionRunner _runInTransaction;
  final _log = LoggerService.forClass(SiteMatchingService);

  static const double _coincidenceMeters = 100;

  // Per-session state (no rollback bookkeeping — nothing is written until apply).
  List<DiveSite> _userSites = const [];
  final Map<String, Map<String, _CandidateRef>> _refsByDive = {};
  // Reset at the start of each applyConfirmed pass (batch dedup).
  final Map<String, String> _createdByExternalId = {};
  // Point each proposal was computed against (the current-site apply needs it).
  final Map<String, GeoPoint> _pointByDive = {};
  // Sites that gained coordinates in this pass and still lack an altitude.
  final Map<String, GeoPoint> _locatedThisPass = {};

  /// Candidate id for "give the dive's current site these coordinates".
  static String currentSiteCandidateId(String siteId) => 'current:$siteId';

  /// Dive-computer fixes win; the photo fix is the fallback.
  _ResolvedPoint? _pointFor(Dive dive, Map<String, PhotoGpsPoint> photoFixes) {
    final measured = dive.entryLocation ?? dive.exitLocation;
    if (measured != null) {
      return (point: measured, source: PointSource.diveComputer);
    }
    final photo = photoFixes[dive.id];
    if (photo != null) {
      return (point: photo.location, source: PointSource.photo);
    }
    return null;
  }

  /// Computes proposals for [dives]. Performs NO database writes.
  Future<List<MatchProposal>> computeProposals(List<Dive> dives) async {
    _userSites = (await _siteRepository.getAllSites(
      diverId: diverId,
    )).where((s) => s.location != null).toList();

    Map<String, PhotoGpsPoint> photoFixes = const {};
    try {
      photoFixes = await _mediaRepository.getBestPhotoGpsForDives([
        for (final d in dives) d.id,
      ]);
    } catch (e, stackTrace) {
      // Dive-computer points still match; only photo-only dives drop out.
      _log.error('Photo GPS lookup failed', error: e, stackTrace: stackTrace);
    }

    final proposals = <MatchProposal>[];
    for (final dive in dives) {
      final resolved = _pointFor(dive, photoFixes);
      if (resolved == null) continue;
      final point = resolved.point;
      _pointByDive[dive.id] = point;

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

      final bareSite = dive.site;
      if (bareSite != null && !bareSite.hasCoordinates) {
        final currentId = currentSiteCandidateId(bareSite.id);
        refs[currentId] = _CandidateRef.currentSite(bareSite);
        final currentView = MatchCandidateView(
          id: currentId,
          name: bareSite.name,
          isExisting: true,
          isCurrentSite: true,
          distanceMeters: 0,
          location: point,
          country: bareSite.country,
          region: bareSite.region,
        );
        // A located user site within the inner radius is a probable
        // duplicate: let the diver choose between locating this site and
        // relinking the dive. Otherwise locating the current site is clear.
        final duplicateNearby = ranked.any(
          (r) =>
              r.candidate.isExisting &&
              r.distanceMeters <= thresholds.innerRadiusMeters,
        );
        proposals.add(
          MatchProposal(
            dive: dive,
            status: duplicateNearby
                ? ProposalStatus.review
                : ProposalStatus.clear,
            candidates: [currentView, ...views],
            recommendedCandidateId: duplicateNearby ? null : currentId,
            point: point,
            pointSource: resolved.source,
          ),
        );
        continue;
      }

      final outcome = matchRanked(ranked, thresholds);

      proposals.add(switch (outcome) {
        NoMatch() => MatchProposal(
          dive: dive,
          status: ProposalStatus.none,
          point: point,
          pointSource: resolved.source,
        ),
        Suggested() => MatchProposal(
          dive: dive,
          status: ProposalStatus.review,
          candidates: views,
          point: point,
          pointSource: resolved.source,
        ),
        AutoMatch(:final siteId) => MatchProposal(
          dive: dive,
          status: ProposalStatus.clear,
          candidates: views,
          recommendedCandidateId: siteId,
          point: point,
          pointSource: resolved.source,
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
    _locatedThisPass.clear();
    var linked = 0;
    var created = 0;
    var located = 0;
    await _runInTransaction(() async {
      for (final c in confirmed) {
        final ref = _refsByDive[c.diveId]?[c.candidateId];
        if (ref == null) continue;
        final outcome = await _applyOne(c.diveId, ref);
        linked++;
        if (outcome == _ApplyOutcome.created) created++;
        if (outcome == _ApplyOutcome.located) located++;
      }
    });
    await _fillAltitudes();
    return ApplyResult(
      divesLinked: linked,
      sitesCreated: created,
      sitesLocated: located,
    );
  }

  /// Creates [site] for this diver, links [diveId] to it, and fills the
  /// altitude best-effort. The single write path behind both the banner's
  /// "Create site" and the review page's "Create site here". A previous
  /// coordinate-less site on the dive is left as it was.
  Future<DiveSite> createAndLink(String diveId, DiveSite site) async {
    late DiveSite created;
    await _runInTransaction(() async {
      created = await _siteRepository.createSite(
        site.copyWith(diverId: diverId),
      );
      await _diveRepository.setSite(diveId, created.id);
    });
    _locatedThisPass.clear();
    final point = created.location;
    if (point != null && created.altitude == null) {
      _locatedThisPass[created.id] = point;
    }
    await _fillAltitudes();
    return created;
  }

  /// Best-effort altitude for every site that gained coordinates in this
  /// pass. Runs after the transaction commits so a network stall can never
  /// hold a DB lock, and never throws.
  Future<void> _fillAltitudes() async {
    final fetch = fetchElevation;
    if (fetch == null) return;
    for (final entry in _locatedThisPass.entries) {
      try {
        final meters = await fetch(entry.value);
        if (meters != null) {
          await _siteRepository.updateSiteAltitude(entry.key, meters);
        }
      } catch (e, stackTrace) {
        _log.warning(
          'Altitude lookup failed for site ${entry.key}',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Applies one dive's chosen candidate. Mirrors the original apply logic
  /// (dedup + coincidence guard) minus the rollback bookkeeping.
  Future<_ApplyOutcome> _applyOne(String diveId, _CandidateRef ref) async {
    if (ref.currentSite != null) {
      final site = ref.currentSite!;
      final point = _pointByDive[diveId];
      if (point == null) return _ApplyOutcome.linked;
      // Column patch, not a whole-entity update: the dive's site may be a
      // partially hydrated entity (issue #1187).
      await _siteRepository.updateSiteCoordinates(site.id, point);
      if (site.altitude == null) _locatedThisPass[site.id] = point;
      return _ApplyOutcome.located;
    }

    if (ref.existing != null) {
      await _diveRepository.setSite(diveId, ref.existing!.id);
      return _ApplyOutcome.linked;
    }

    final bundled = ref.bundled!;
    final point = GeoPoint(bundled.latitude!, bundled.longitude!);

    // Batch dedup: this bundled site already materialised in this pass?
    final dedupId = _createdByExternalId[bundled.externalId];
    if (dedupId != null) {
      await _diveRepository.setSite(diveId, dedupId);
      return _ApplyOutcome.linked;
    }

    // Coincidence guard: an existing user site essentially here?
    for (final s in _userSites) {
      if (distanceMeters(point, s.location!) <= _coincidenceMeters) {
        await _diveRepository.setSite(diveId, s.id);
        return _ApplyOutcome.linked;
      }
    }

    // Materialise the bundled site, then link.
    final createdSite = await _siteRepository.createSite(
      bundled.toDiveSite(diverId: diverId),
    );
    _createdByExternalId[bundled.externalId] = createdSite.id;
    if (createdSite.altitude == null) _locatedThisPass[createdSite.id] = point;
    await _diveRepository.setSite(diveId, createdSite.id);
    return _ApplyOutcome.created;
  }
}
