import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

/// Ids of the template parts that attaching an assembly would still write
/// ([isGearActive]: flagged active, neither retired nor lost), whoever owns
/// them. The dive gear tree reads it to tell a part missing from a dive
/// apart from one that was retired since (issue #1988).
///
/// Refreshes on an equipment write (a part retired or restored) and, through
/// the index, on an edge change (a part added to or removed from a template).
final activeComponentIdsProvider = FutureProvider<Set<String>>((ref) async {
  final equipment = ref.watch(equipmentRepositoryProvider);
  ref.invalidateSelfWhen(equipment.watchEquipmentChanges());
  final index = await ref.watch(equipmentComponentsIndexProvider.future);
  final ids = index.byComponent.keys.toList();
  if (ids.isEmpty) return const {};
  final items = await equipment.getEquipmentByIds(ids);
  return {
    for (final item in items)
      if (isGearActive(item)) item.id,
  };
});
