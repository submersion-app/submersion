import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_suggestion_providers.dart';

/// The write side of a site suggestion. Every action goes through the
/// [SiteMatchingService] that computed the suggestion, so the banner and the
/// batch review page share the coincidence guard, bundled-site
/// materialisation, and the post-commit altitude pass. UI concerns (dialogs,
/// snackbars, navigation, provider refreshes) live in SiteSuggestionCard.
class SiteSuggestionActions {
  SiteSuggestionActions({
    required this.diveId,
    required this.suggestion,
    required this.diveRepository,
  });

  final String diveId;
  final SiteSuggestion suggestion;
  final DiveRepository diveRepository;

  /// Links the dive to [candidateId] (an existing site id or a bundled
  /// site's external id).
  Future<ApplyResult> assign(String candidateId) =>
      suggestion.service.applyConfirmed([ConfirmedMatch(diveId, candidateId)]);

  /// Writes the point onto the dive's coordinate-less current site.
  Future<ApplyResult> addLocation() {
    final site = suggestion.proposal.dive.site;
    if (site == null) {
      throw StateError('addLocation needs a dive with a current site');
    }
    return suggestion.service.applyConfirmed([
      ConfirmedMatch(
        diveId,
        SiteMatchingService.currentSiteCandidateId(site.id),
      ),
    ]);
  }

  /// Creates [site] at the point and links the dive to it.
  Future<DiveSite> create(DiveSite site) =>
      suggestion.service.createAndLink(diveId, site);

  /// The site the dive is linked to right now, re-read after a write.
  ///
  /// The chosen candidate id is not the answer: a bundled candidate
  /// materialises a new row and the coincidence guard can link an existing
  /// site instead. Goes through the repository captured at build time, so it
  /// is safe to call after an await even if the caller's widget is gone.
  Future<DiveSite?> linkedSite() async =>
      (await diveRepository.getDiveById(diveId))?.site;

  /// Hides the suggestion for this dive on every device.
  Future<void> dismiss() =>
      diveRepository.setSiteSuggestionDismissed(diveId, true);
}
