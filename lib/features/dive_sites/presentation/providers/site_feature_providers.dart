import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';

final siteFeatureRepositoryProvider = Provider<SiteFeatureRepository>((ref) {
  return SiteFeatureRepository();
});

/// Diver-placed features for one site, refreshed on any site_features
/// write (local edit or sync merge).
final siteFeaturesProvider = FutureProvider.family<List<SiteFeature>, String>((
  ref,
  siteId,
) async {
  final repository = ref.watch(siteFeatureRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchFeatureChanges());
  return repository.getFeaturesForSite(siteId);
});
