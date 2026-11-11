import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/services/assembly_totals.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';

/// What an assembly's parts add up to, for the Components card (issue
/// #4443). Reloads when a part's buoyancy or dry weight is edited (an
/// attribute write), when a part is retired or lost (an equipment write),
/// when a part is shared or unshared, when the active diver changes, and
/// when the template changes (through the index).
final assemblyTotalsProvider = FutureProvider.family<AssemblyTotals, String>((
  ref,
  assemblyId,
) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchEquipmentChanges());
  ref.invalidateSelfWhen(repository.watchAttributeChanges());
  ref.invalidateSelfWhen(
    ref.watch(equipmentShareRepositoryProvider).watchChanges(),
  );
  final diverFuture = ref.watch(validatedCurrentDiverIdProvider.future);
  final index = await ref.watch(equipmentComponentsIndexProvider.future);

  final ids = index.descendantsOf(assemblyId)..remove(assemblyId);
  if (ids.isEmpty) return AssemblyTotals.empty;
  final parts = await repository.getEquipmentByIds(ids.toList());

  // A part another profile owns and has not shared with the active diver is
  // not brought along when the assembly is attached (expandGearOnPage,
  // issue #2046), so it is not in the total either.
  final diverId = await diverFuture;
  final usable = diverId == null
      ? null
      : (await repository.usableSetMemberIds([
          for (final p in parts) p.id,
        ], diverId)).toSet();
  final items = {
    for (final item in parts)
      if (usable == null || usable.contains(item.id)) item.id: item,
  };
  return AssemblyTotals.of(
    assemblyId,
    index: index,
    itemFor: (id) => items[id],
    // The rule attaching the assembly to a dive uses, so the total is the
    // figure the assembly adds to a dive.
    isActive: (id) {
      final item = items[id];
      return item != null && isGearActive(item);
    },
  );
});
