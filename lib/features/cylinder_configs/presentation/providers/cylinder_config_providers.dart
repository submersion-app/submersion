import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/cylinder_configs/data/repositories/cylinder_config_repository.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// Repository provider
final cylinderConfigRepositoryProvider = Provider<CylinderConfigRepository>((
  ref,
) {
  return CylinderConfigRepository();
});

/// Every configuration belonging to the active diver, items hydrated.
///
/// Items are included eagerly because every surface that lists configurations
/// shows a cylinder count or the roles, so a lazy variant would just mean an
/// extra round trip on each row.
final cylinderConfigsProvider = FutureProvider<List<CylinderConfig>>((
  ref,
) async {
  final repository = ref.watch(cylinderConfigRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  ref.invalidateSelfWhen(repository.watchConfigsChanges());
  return repository.getAllConfigs(
    diverId: validatedDiverId,
    includeItems: true,
  );
});

/// Configurations owned by one rebreather.
final cylinderConfigsForEquipmentProvider =
    FutureProvider.family<List<CylinderConfig>, String>((
      ref,
      equipmentId,
    ) async {
      final repository = ref.watch(cylinderConfigRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchConfigsChanges());
      return repository.getConfigsForEquipment(equipmentId);
    });

/// A single configuration with its cylinders.
final cylinderConfigProvider = FutureProvider.family<CylinderConfig?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(cylinderConfigRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchConfigsChanges());
  return repository.getConfigById(id);
});

/// Invalidates every configuration view. Call after a create, update, delete,
/// or item save so the list, the owning unit's card, and any open detail all
/// refetch together.
void invalidateCylinderConfigs(WidgetRef ref, {String? configId}) {
  ref.invalidate(cylinderConfigsProvider);
  ref.invalidate(cylinderConfigsForEquipmentProvider);
  if (configId != null) {
    ref.invalidate(cylinderConfigProvider(configId));
  } else {
    ref.invalidate(cylinderConfigProvider);
  }
}
