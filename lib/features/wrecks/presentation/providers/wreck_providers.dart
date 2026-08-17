import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/wrecks/data/repositories/wreck_repository.dart';
import 'package:submersion/features/wrecks/domain/entities/wreck.dart';

final wreckRepositoryProvider = Provider<WreckRepository>((ref) {
  return WreckRepository();
});

/// The whole catalogue, name-ordered, refreshed on any wrecks write
/// (local edit or sync merge).
final wrecksProvider = FutureProvider<List<Wreck>>((ref) async {
  final repository = ref.watch(wreckRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchWreckChanges());
  return repository.getAllWrecks();
});

final wreckProvider = FutureProvider.family<Wreck?, String>((ref, id) async {
  final repository = ref.watch(wreckRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchWreckChanges());
  return repository.getWreckById(id);
});

/// Catalogue wrecks the diver linked to this site.
final wrecksForSiteProvider = FutureProvider.family<List<Wreck>, String>((
  ref,
  siteId,
) async {
  final repository = ref.watch(wreckRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchWreckChanges());
  return repository.getWrecksForSite(siteId);
});
