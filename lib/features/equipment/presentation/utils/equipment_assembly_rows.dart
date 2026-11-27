import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_fold_keys.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/domain/services/equipment_part_tree.dart';

/// Which items of one placement unit (a place's section, or the whole list
/// when the page does not group by location) stand at the top level in the
/// assembly view (issue #5071), and walks the rest under them.
///
/// An item is top level when none of its assemblies is in the unit. A part
/// of a corrupt loop that nothing top level reaches is made top level too,
/// so a loop never hides its members.
class AssemblyUnit {
  AssemblyUnit(List<EquipmentGroup> groups, this.parts)
    : itemsById = {
        for (final group in groups)
          for (final item in group.items) item.id: item,
      } {
    final topLevel = <String>{};
    final placed = <String>{};
    // Reachability only: an item reached once is placed, which also ends a
    // walk around a loop.
    void walk(String id, Set<String> path) {
      if (!placed.add(id)) return;
      final below = {...path, id};
      for (final child in childrenOf(id, below)) {
        walk(child, below);
      }
    }

    for (final group in groups) {
      for (final item in group.items) {
        final inUnit = parts.parentsOf(item.id).any(itemsById.containsKey);
        if (!inUnit) {
          topLevel.add(item.id);
          walk(item.id, const {});
        }
      }
    }
    for (final group in groups) {
      for (final item in group.items) {
        if (placed.contains(item.id)) continue;
        topLevel.add(item.id);
        walk(item.id, const {});
      }
    }
    _topLevel = topLevel;
  }

  final EquipmentPartTree parts;
  final Map<String, EquipmentItem> itemsById;
  late final Set<String> _topLevel;

  /// [group]'s items that stand at the top level, in the group's order.
  List<EquipmentItem> topLevelOf(EquipmentGroup group) => [
    for (final item in group.items)
      if (_topLevel.contains(item.id)) item,
  ];

  /// The parts of [id] in this unit, in display order, leaving out any item
  /// on [path] (the assemblies above it), which only a corrupt loop reaches.
  List<String> childrenOf(String id, Set<String> path) => [
    for (final child in parts.childrenOf(id))
      if (itemsById.containsKey(child) && !path.contains(child)) child,
  ];
}

/// The key of a part's row after its first on screen: a part in several open
/// assemblies is drawn under each, and every row needs its own stop.
String repeatedPartNavKey(String parentNavKey, String id) =>
    'part:$parentNavKey/$id';

/// The data an assembly row needs, beyond the item.
typedef AssemblyRowInfo = ({
  int depth,
  String navKey,
  String? parentId,
  String? parentNavKey,
  String? foldKey,
  bool isExpanded,
  int partCount,
});

/// Walks [item] and the parts under it within [unit], depth first, calling
/// [onRow] for each row on screen and [onItem] for every item reached,
/// shown or folded away, with the fold keys on the way to it (outermost
/// first, starting with [outerKeys]).
///
/// An assembly's parts are on screen only when the assembly is and its key
/// is not in [collapsed]. [isShown] says whether an item already has a row
/// on screen, so a repeated part gets [repeatedPartNavKey] and the first
/// one keeps the item id.
///
/// [walkedInRoot] holds the items whose parts this top-level walk has
/// already listed. An item met again within it gets its row but no parts
/// below it and no fold, so each item's parts are walked once per top-level
/// rig: a part shared by two rigs still shows its parts under both, and a
/// corrupt dense cycle costs one visit per item and edge instead of one per
/// path.
void walkAssembly(
  EquipmentItem item, {
  required AssemblyUnit unit,
  required Set<String> collapsed,
  required List<String> outerKeys,
  required bool visible,
  required bool Function(String id) isShown,
  required Set<String> walkedInRoot,
  required void Function(EquipmentItem item, AssemblyRowInfo info) onRow,
  required void Function(EquipmentItem item, List<String> foldKeys) onItem,
  required void Function(String assemblyId) onAssembly,
  int depth = 0,
  String? parentId,
  String? parentNavKey,
  Set<String> path = const {},
}) {
  final firstInRoot = walkedInRoot.add(item.id);
  final below = {...path, item.id};
  final children = firstInRoot
      ? unit.childrenOf(item.id, below)
      : const <String>[];
  final foldKey = children.isEmpty ? null : assemblyFoldKey(item.id);
  final isExpanded = foldKey != null && !collapsed.contains(foldKey);
  onItem(item, outerKeys);
  if (foldKey != null) onAssembly(item.id);
  String? navKey;
  if (visible) {
    navKey = parentNavKey != null && isShown(item.id)
        ? repeatedPartNavKey(parentNavKey, item.id)
        : item.id;
    onRow(item, (
      depth: depth,
      navKey: navKey,
      parentId: parentId,
      parentNavKey: parentNavKey,
      foldKey: foldKey,
      isExpanded: isExpanded,
      partCount: children.length,
    ));
  }
  if (foldKey == null) return;
  for (final child in children) {
    walkAssembly(
      unit.itemsById[child]!,
      unit: unit,
      collapsed: collapsed,
      outerKeys: [...outerKeys, foldKey],
      visible: visible && isExpanded,
      isShown: isShown,
      walkedInRoot: walkedInRoot,
      onRow: onRow,
      onItem: onItem,
      onAssembly: onAssembly,
      depth: depth + 1,
      parentId: item.id,
      parentNavKey: navKey,
      path: below,
    );
  }
}
