import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_suggestion_providers.dart';

/// The write side of a site suggestion, for the dive page's sitting, which
/// holds the dive's link until Save (issue #4527). Each goes through the
/// SiteMatchingService that computed the suggestion, so the banner and the
/// batch review page share bundled-site materialisation. UI concerns
/// (dialogs, snackbars, the sitting) live in SiteSuggestionCard.
class SiteSuggestionActions {
  SiteSuggestionActions({required this.diveId, required this.suggestion});

  final String diveId;
  final SiteSuggestion suggestion;

  /// The site [candidateId] stands for, without linking the dive: a
  /// catalogue site is adopted as the diver's at once.
  Future<({DiveSite site, List<String> createdSiteIds})> resolve(
    String candidateId,
  ) => suggestion.service.resolveCandidate(diveId, candidateId);

  /// Creates [site] at the point with no link.
  Future<DiveSite> createUnlinked(DiveSite site) =>
      suggestion.service.createSite(site);
}
