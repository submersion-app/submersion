import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_ownership_event.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_share.dart';

final equipmentShareRepositoryProvider = Provider<EquipmentShareRepository>(
  (ref) => EquipmentShareRepository(),
);

/// The profiles [equipmentId] is shared with, oldest share first.
final equipmentSharesProvider =
    FutureProvider.family<List<EquipmentShare>, String>((
      ref,
      equipmentId,
    ) async {
      final repository = ref.watch(equipmentShareRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      return repository.getSharesFor(equipmentId);
    });

/// [equipmentId]'s share and ownership events, oldest first.
final equipmentOwnershipEventsProvider =
    FutureProvider.family<List<EquipmentOwnershipEvent>, String>((
      ref,
      equipmentId,
    ) async {
      final repository = ref.watch(equipmentShareRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      return repository.getEventsFor(equipmentId);
    });

/// Every profile's name by id, for owner chips and history rows.
final diverNamesByIdProvider = FutureProvider<Map<String, String>>((ref) async {
  final divers = await ref.watch(allDiversProvider.future);
  return {for (final d in divers) d.id: d.name};
});

/// Sharing UI shows only when two or more profiles exist, as for sites and
/// trips.
final hasMultipleDiversProvider = Provider<bool>(
  (ref) => ref
      .watch(allDiversProvider)
      .maybeWhen(data: (divers) => divers.length >= 2, orElse: () => false),
);
