import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// The equipment tag junction (issue #1942).
final equipmentTagRepositoryProvider = Provider<EquipmentTagRepository>((ref) {
  return EquipmentTagRepository();
});

/// One item's tags, by name. Refreshes on any link or tag change, including
/// one a sync or an import applies without a notifier.
final tagsForEquipmentProvider = FutureProvider.family<List<Tag>, String>((
  ref,
  equipmentId,
) async {
  final repository = ref.watch(equipmentTagRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchChanges());
  return repository.getTagsForEquipment(equipmentId);
});

/// Every item's tags in one query, for the list tiles, the Tags column and
/// the tag filter.
final tagsByEquipmentProvider = FutureProvider<Map<String, List<Tag>>>((
  ref,
) async {
  final repository = ref.watch(equipmentTagRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchChanges());
  return repository.getTagsByEquipment();
});
