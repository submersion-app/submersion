import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/services/equipment_clone_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

/// Copies a clone's clocks, sets and documents (issue #3184).
final equipmentCloneServiceProvider = Provider<EquipmentCloneService>((ref) {
  return EquipmentCloneService(
    schedules: ref.watch(serviceScheduleRepositoryProvider),
    sets: ref.watch(equipmentSetRepositoryProvider),
    media: ref.watch(mediaRepositoryProvider),
  );
});

/// The item a clone starts from, or null when the active diver can neither
/// own nor share it (#2046). The `cloneFrom` id arrives in the route, so a
/// known id alone must not open another profile's gear for copying, as the
/// form already checks a deep-linked `parent`. With no active diver every
/// item counts, as everywhere else.
final cloneSourceProvider = FutureProvider.family<EquipmentItem?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  // Visibility reads the item's owner and its shares: a share granted or
  // revoked while the form is open must re-decide it.
  ref.invalidateSelfWhen(repository.watchEquipmentChanges());
  ref.invalidateSelfWhen(
    ref.watch(equipmentShareRepositoryProvider).watchChanges(),
  );
  final item = await ref.watch(equipmentItemProvider(id).future);
  if (item == null) return null;
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  if (diverId == null) return item;
  return await repository.isVisibleTo(id, diverId) ? item : null;
});
