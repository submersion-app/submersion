import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

final customCertificationRepositoryProvider =
    Provider<CustomCertificationRepository>(
      (ref) => CustomCertificationRepository(),
    );

/// Built-ins plus every custom row, with pickers filtered for the active
/// diver (issue #690). Rebuilds on any write to either custom table,
/// including sync applies.
final certificationCatalogProvider = FutureProvider<CertificationCatalog>((
  ref,
) async {
  final repository = ref.watch(customCertificationRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchChanges());
  final agencies = await repository.getAllAgencies();
  final levels = await repository.getAllLevels();
  return CertificationCatalog(
    agencies: agencies,
    levels: levels,
    viewerDiverId: diverId,
  );
});

/// Every custom row with no viewer, for imports and exports (issue #690):
/// they resolve stored ids by name and never filter a picker, so they do
/// not depend on which profile is active.
final allCustomCertificationsCatalogProvider =
    FutureProvider<CertificationCatalog>((ref) async {
      final repository = ref.watch(customCertificationRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      final agencies = await repository.getAllAgencies();
      final levels = await repository.getAllLevels();
      return CertificationCatalog(agencies: agencies, levels: levels);
    });

/// The loaded catalog for synchronous build methods; built-ins only while
/// loading, so built-in names and colours never flicker.
final certificationCatalogSyncProvider = Provider<CertificationCatalog>(
  (ref) =>
      ref.watch(certificationCatalogProvider).value ??
      CertificationCatalog.builtInOnly,
);
