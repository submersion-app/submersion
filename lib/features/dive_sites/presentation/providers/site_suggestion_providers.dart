import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';

/// Builds a [SiteMatchingService] for [diverId] from the app's providers.
/// The review notifier and the per-dive suggestion share it, so a widget
/// test can override one provider to fake the whole matching pipeline.
final siteMatchingServiceFactoryProvider =
    Provider<SiteMatchingService Function(String? diverId)>((ref) {
      return (diverId) => SiteMatchingService(
        siteRepository: ref.read(siteRepositoryProvider),
        apiService: ref.read(diveSiteApiServiceProvider),
        diveRepository: ref.read(diveRepositoryProvider),
        mediaRepository: ref.read(mediaRepositoryProvider),
        diverId: diverId,
        thresholds: ref.read(settingsProvider).siteMatchSensitivity.thresholds,
        fetchElevation: (point) => ref
            .read(elevationServiceProvider)
            .fetchElevation(
              latitude: point.latitude,
              longitude: point.longitude,
            ),
      );
    });

/// One dive's site suggestion, with the service instance that computed it
/// (its apply methods rely on refs cached during computeProposals).
class SiteSuggestion {
  const SiteSuggestion({required this.proposal, required this.service});
  final MatchProposal proposal;
  final SiteMatchingService service;
  GeoPoint get point => proposal.point!;
  PointSource get pointSource => proposal.pointSource;
}

/// The suggestion for [diveId], or null when the dive needs none: it has a
/// located site, the diver dismissed it, or there is no point to match.
/// Eligibility is the same repository predicate the batch review uses.
final siteSuggestionForDiveProvider = FutureProvider.autoDispose
    .family<SiteSuggestion?, String>((ref, diveId) async {
      final diveRepo = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(diveRepo.watchDivesChanges());
      ref.invalidateSelfWhen(
        ref.watch(siteRepositoryProvider).watchSitesChanges(),
      );
      ref.invalidateSelfWhen(
        ref.watch(mediaRepositoryProvider).watchMediaChanges(),
      );
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      final dives = await diveRepo.getDivesNeedingSiteMatch(
        diverId: diverId,
        limitToIds: [diveId],
      );
      if (dives.isEmpty) return null;
      final service = ref.read(siteMatchingServiceFactoryProvider)(diverId);
      final proposals = await service.computeProposals(dives);
      if (proposals.isEmpty || proposals.single.point == null) return null;
      return SiteSuggestion(proposal: proposals.single, service: service);
    });
