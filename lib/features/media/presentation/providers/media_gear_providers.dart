import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/media/data/repositories/media_gear_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

/// Gear linked to photos and videos (issue #5046).
final mediaGearRepositoryProvider = Provider<MediaGearRepository>(
  (ref) => MediaGearRepository(),
);

/// Every gear id linked to one photo. Unscoped: the card hides gear the
/// diver cannot see.
final gearIdsForMediaProvider = FutureProvider.family<List<String>, String>((
  ref,
  mediaId,
) async {
  final repository = ref.watch(mediaGearRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchChanges());
  return repository.gearIdsFor(mediaId);
});

/// The photos linked to one gear item that the active diver can see, newest
/// first.
final linkedMediaForEquipmentProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, equipmentId) async {
      final repository = ref.watch(mediaGearRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      ref.invalidateSelfWhen(
        ref.read(mediaRepositoryProvider).watchMediaChanges(),
      );
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      return repository.linkedMediaFor(equipmentId, diverId: diverId);
    });

/// The gear used on one dive, every way gear reaches a dive.
final gearOnDiveProvider = FutureProvider.family<Set<String>, String>((
  ref,
  diveId,
) async {
  ref.invalidateSelfWhen(
    ref.read(diveRepositoryProvider).watchTables(_diveGearTables),
  );
  return ref.watch(mediaGearRepositoryProvider).gearOnDive(diveId);
});

/// The ids of the dives the item page's Dives row counts, newest first.
final equipmentDiveIdsProvider = FutureProvider.family<List<String>, String>((
  ref,
  equipmentId,
) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  ref.invalidateSelfWhen(
    ref.read(diveRepositoryProvider).watchTables(_diveGearTables),
  );
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.getDiveIdsForEquipment(equipmentId, diverId: diverId);
});

const _diveGearTables = {'dives', 'dive_equipment', 'dive_tanks'};
