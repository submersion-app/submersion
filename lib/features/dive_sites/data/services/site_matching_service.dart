import 'dart:async';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_adoption_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/matching/match_candidate.dart';
import 'package:submersion/features/dive_sites/domain/matching/match_thresholds.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_outcome.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_matcher.dart';
import 'package:submersion/features/dive_sites/domain/repositories/site_catalogue.dart';
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
  /// A built-in candidate's site types, as built-in type ids. The review
  /// card translates them: this service has no language to name them in.
  final List<String> typeIds;
  final List<String> features; // bundled: the source's tags (drift, sharks)
  final String? description;

  /// A built-in record gathered by research, shown "Not verified".
  final bool isResearched;

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
    this.typeIds = const [],
    this.features = const [],
    this.description,
    this.isResearched = false,
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

  /// The sites this apply created, for the logbook rules (#3513).
  final List<String> createdSiteIds;
  const ApplyResult({
    required this.divesLinked,
    required this.sitesCreated,
    this.sitesLocated = 0,
    this.createdSiteIds = const [],
  });
}

/// Runs a body inside a DB transaction. Injectable so unit tests can pass a
/// pass-through that doesn't require a real database.
typedef TransactionRunner = Future<void> Function(Future<void> Function() body);

typedef _ResolvedPoint = ({GeoPoint point, PointSource source});

/// Resolved candidate objects retained per dive so apply can act on a chosen id.
class _CandidateRef {
  final DiveSite? existing; // link the dive to this site
  final CatalogueSite? bundled; // adopt, then link
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
    required SiteCatalogue catalogue,
    required CatalogueAdoptionService adoption,
    required DiveRepository diveRepository,
    required MediaRepository mediaRepository,
    required this.diverId,
    required this.thresholds,
    TransactionRunner? runInTransaction,
    this.fetchElevation,
  }) : _siteRepository = siteRepository,
       _catalogue = catalogue,
       _adoption = adoption,
       _diveRepository = diveRepository,
       _mediaRepository = mediaRepository,
       _runInTransaction =
           runInTransaction ??
           ((body) => DatabaseService.instance.database.transaction(body));

  final SiteRepository _siteRepository;
  final SiteCatalogue _catalogue;
  final CatalogueAdoptionService _adoption;
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
  final Map<String, DiveSite> _createdByExternalId = {};
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

      // Map-placed records are offered from further out than the rest,
      // and are always read on their own: in a shared read, the records
      // nearer the dive could fill its limit first, even when the outer
      // radius is already as wide as the map-placed reach.
      final inRadius = await _catalogue.near(
        point,
        radiusMeters: thresholds.outerRadiusMeters,
      );
      final mapPlaced = await _catalogue.near(
        point,
        radiusMeters: mapPlacedReachMeters(thresholds),
        mapPlacedOnly: true,
      );
      final inRadiusIds = {for (final b in inRadius) b.id};
      final bundled = [
        ...inRadius,
        for (final b in mapPlaced)
          if (!inRadiusIds.contains(b.id)) b,
      ];

      final refs = <String, _CandidateRef>{};
      final candidates = <MatchCandidate>[];
      for (final s in _userSites) {
        refs[s.id] = _CandidateRef.existing(s);
        candidates.add(
          MatchCandidate(id: s.id, location: s.location!, isExisting: true),
        );
      }
      // A catalogue site the diver already adopted is among their own
      // sites above: offering its record too would show the site twice.
      final adopted = {for (final site in _userSites) ?site.catalogueId};
      // A record a site stands for since a merge may lie well away from
      // that site. It is left out only when the site itself is in range
      // to be chosen; otherwise it stays a candidate, and choosing it
      // links the dive to that site.
      final standingFor = {
        for (final site in _userSites)
          for (final id in site.catalogueAnswers.also) id: site,
      };
      for (final b in bundled) {
        final location = b.location;
        if (location == null || adopted.contains(b.id)) continue;
        final stands = standingFor[b.id];
        if (stands != null &&
            distanceMeters(point, stands.location!) <=
                thresholds.outerRadiusMeters) {
          continue;
        }
        refs[b.id] = _CandidateRef.bundled(b);
        candidates.add(
          MatchCandidate(
            id: b.id,
            location: location,
            isExisting: false,
            isRegister: b.kind == CatalogueKind.register,
            isResearched: b.isResearched,
            isMapPlaced: b.isResearched && b.positionFromMap,
          ),
        );
      }
      _refsByDive[dive.id] = refs;

      // Rank once; reuse for both the UI candidate list and the matcher
      // decision so distances are computed a single time per dive/site pair.
      final ranked = rankCandidates(point, candidates);
      final views = ranked
          .where(
            (r) => r.distanceMeters <= reachMeters(r.candidate, thresholds),
          )
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
      id: b.id,
      name: b.name,
      isExisting: false,
      distanceMeters: distance,
      // Only located catalogue sites become candidates.
      location: b.location!,
      minDepth: b.minDepth,
      maxDepth: b.maxDepth,
      country: b.country,
      region: b.region,
      // As an existing site's card shows it.
      difficulty: b.difficulty?.displayName,
      // What the review card lists: the site's types, which it names in
      // the diver's language, then the source's other tags (drift, sharks).
      typeIds: b.typeIds,
      features: b.features,
      description: b.description,
      isResearched: b.isResearched,
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
      createdSiteIds: [for (final site in _createdByExternalId.values) site.id],
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
  /// hold a DB lock, and never throws. The sites are read before the first
  /// lookup, so a call left running is not disturbed by the next pass.
  Future<void> _fillAltitudes() async {
    final fetch = fetchElevation;
    if (fetch == null) return;
    for (final entry in Map.of(_locatedThisPass).entries) {
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

  /// The site [candidateId] stands for, for [diveId], without linking the
  /// dive (issue #4527): an existing site, or a catalogue site adopted as
  /// the diver's, through the same dedup, adoption lookup and coincidence
  /// guard as [applyConfirmed]. An adopted site is created at once, in a
  /// transaction, and its altitude filled best effort once this has
  /// answered, so the answer never waits on the network. Creating a
  /// record is outside an editing sitting; only the dive's link waits for
  /// its Save.
  ///
  /// Throws [ArgumentError] for the dive's own site (giving it coordinates
  /// is a write to that site, held by the sitting instead), and
  /// [StateError] for a candidate the last proposals did not offer.
  Future<({DiveSite site, List<String> createdSiteIds})> resolveCandidate(
    String diveId,
    String candidateId,
  ) async {
    final ref = _refsByDive[diveId]?[candidateId];
    if (ref == null) {
      throw StateError('No candidate $candidateId for dive $diveId');
    }
    if (ref.currentSite != null) {
      throw ArgumentError.value(
        candidateId,
        'candidateId',
        'the dive\'s own site is not a site to resolve',
      );
    }
    _createdByExternalId.clear();
    _locatedThisPass.clear();
    late ({DiveSite site, _ApplyOutcome outcome}) chosen;
    await _runInTransaction(() async {
      chosen = await _siteFor(ref);
    });
    // The site exists now: a sitting waiting for it does not also wait on
    // the network for its altitude.
    unawaited(_fillAltitudes());
    return (
      site: chosen.site,
      createdSiteIds: [
        if (chosen.outcome == _ApplyOutcome.created) chosen.site.id,
      ],
    );
  }

  /// Creates [site] for this diver, with no link, and fills its altitude
  /// best effort once this has answered. What the site suggestion's "Create site" does during an
  /// editing sitting, which holds the dive's link until its Save.
  Future<DiveSite> createSite(DiveSite site) async {
    final created = await _siteRepository.createSite(
      site.copyWith(diverId: diverId),
    );
    _locatedThisPass.clear();
    final point = created.location;
    if (point != null && created.altitude == null) {
      _locatedThisPass[created.id] = point;
    }
    // As in [resolveCandidate]: the altitude lands after the answer.
    unawaited(_fillAltitudes());
    return created;
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
    final chosen = await _siteFor(ref);
    await _diveRepository.setSite(diveId, chosen.site.id);
    return chosen.outcome;
  }

  /// The site an existing or catalogue candidate stands for, adopting the
  /// catalogue site when no site of the diver's already is it. Links
  /// nothing.
  Future<({DiveSite site, _ApplyOutcome outcome})> _siteFor(
    _CandidateRef ref,
  ) async {
    final existing = ref.existing;
    if (existing != null) {
      return (site: existing, outcome: _ApplyOutcome.linked);
    }

    final bundled = ref.bundled!;
    final point = bundled.location!;

    // Batch dedup: this bundled site already materialised in this pass?
    final dedup = _createdByExternalId[bundled.id];
    if (dedup != null) return (site: dedup, outcome: _ApplyOutcome.linked);

    // Already adopted, wherever the diver has since moved it? The link is a
    // surer sign of the same site than the distance guard below.
    final adopted = await _siteRepository.getSiteByCatalogueId(
      bundled.id,
      diverId: diverId,
    );
    if (adopted != null) {
      return (site: adopted, outcome: _ApplyOutcome.linked);
    }

    // Coincidence guard: an existing user site essentially here?
    for (final s in _userSites) {
      if (distanceMeters(point, s.location!) <= _coincidenceMeters) {
        return (site: s, outcome: _ApplyOutcome.linked);
      }
    }

    // Adopt the catalogue site through the one adoption path, so it gets
    // the same details and link as a site picked anywhere else. Altitude is
    // filled by [_fillAltitudes] once the transaction commits.
    final adoption = await _adoption.adopt(
      bundled,
      diverId: diverId,
      fillAltitude: false,
    );
    final site = adoption.site;
    // Another screen adopted this record after the lookup above: the site
    // is the diver's already, and whoever made it sees to its altitude and
    // its rules. Reporting it as created would run those rules again, over
    // whatever the diver has changed since.
    if (!adoption.created) return (site: site, outcome: _ApplyOutcome.linked);
    _createdByExternalId[bundled.id] = site;
    if (site.altitude == null) _locatedThisPass[site.id] = point;
    return (site: site, outcome: _ApplyOutcome.created);
  }
}
