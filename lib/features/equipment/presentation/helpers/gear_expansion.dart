import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/equipment/domain/services/gear_expander.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

/// True for gear the expander may attach as a part.
bool isGearActive(EquipmentItem item) =>
    item.isActive &&
    item.status != EquipmentStatus.retired &&
    item.status != EquipmentStatus.lost;

/// What a page gets back from [expandGearOnPage]: the new provenance list
/// and the items (parts) that were not in the page's list before, so the
/// page can append them to its flat item list.
typedef GearExpansion = ({
  List<GearProvenance> provenance,
  List<EquipmentItem> newItems,
});

/// Expands [additions] on a page's in-memory gear list, fetching the parts'
/// items so the page can show them (issue #1487). [existingItems] must
/// already contain the items being added. Best-effort on the template: if
/// the index or the parts cannot be read, the additions are attached flat,
/// which is what the app did before assemblies existed, rather than
/// failing the add.
Future<GearExpansion> expandGearOnPage(
  WidgetRef ref, {
  required List<GearAddition> additions,
  required List<GearProvenance> existing,
  required List<EquipmentItem> existingItems,
}) async {
  ComponentsIndex index;
  try {
    index = await ref.read(equipmentComponentsIndexProvider.future);
  } catch (_) {
    index = ComponentsIndex.empty;
  }
  final candidateIds = {
    for (final a in additions) ...index.descendantsOf(a.equipmentId),
  }..removeAll(existingItems.map((e) => e.id));
  var fetched = const <EquipmentItem>[];
  if (candidateIds.isNotEmpty) {
    try {
      fetched = await ref
          .read(equipmentRepositoryProvider)
          .getEquipmentByIds(candidateIds.toList());
    } catch (_) {
      // The repository has logged it; an unknown part is simply not
      // attached, and the expander skips ids it cannot see.
    }
  }
  final itemsById = {
    for (final e in existingItems) e.id: e,
    for (final e in fetched) e.id: e,
  };
  final provenance = GearExpander.expand(
    additions: additions,
    index: index,
    existing: existing,
    isActive: (id) {
      final item = itemsById[id];
      return item != null && isGearActive(item);
    },
  );
  final known = {for (final e in existingItems) e.id};
  final newItems = [
    for (final p in provenance)
      if (!known.contains(p.equipmentId) && itemsById[p.equipmentId] != null)
        itemsById[p.equipmentId]!,
  ];
  return (provenance: provenance, newItems: newItems);
}
