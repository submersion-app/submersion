import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/matching/site_match_sensitivity.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_suggestion_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';

/// Records apply calls instead of touching a database. The base constructor
/// only stores its dependencies, so zero-arg repositories are safe here.
class FakeMatchingService extends SiteMatchingService {
  FakeMatchingService()
    : super(
        siteRepository: SiteRepository(),
        apiService: DiveSiteApiService(),
        diveRepository: DiveRepository(),
        mediaRepository: MediaRepository(),
        diverId: 'diver-1',
        thresholds: SiteMatchSensitivity.balanced.thresholds,
        runInTransaction: (body) => body(),
      );

  final applied = <ConfirmedMatch>[];
  final created = <DiveSite>[];

  @override
  Future<ApplyResult> applyConfirmed(List<ConfirmedMatch> confirmed) async {
    applied.addAll(confirmed);
    return const ApplyResult(divesLinked: 1, sitesCreated: 0);
  }

  @override
  Future<DiveSite> createAndLink(String diveId, DiveSite site) async {
    created.add(site);
    return site.copyWith(id: 'created');
  }
}

/// A suggestion for dive `d1` at a fixed photo point.
SiteSuggestion suggestionFor(
  FakeMatchingService service, {
  DiveSite? site,
  ProposalStatus status = ProposalStatus.clear,
  String? recommended,
  List<MatchCandidateView> candidates = const [],
}) => SiteSuggestion(
  proposal: MatchProposal(
    dive: Dive(
      id: 'd1',
      diveNumber: 1,
      dateTime: DateTime(2026, 1, 1),
      maxDepth: 18,
      site: site,
    ),
    status: status,
    candidates: candidates,
    recommendedCandidateId: recommended,
    point: const GeoPoint(20.5, -87.25),
    pointSource: PointSource.photo,
  ),
  service: service,
);
