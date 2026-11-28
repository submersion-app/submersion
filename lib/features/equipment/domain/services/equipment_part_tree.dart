import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';

/// The order a host lists the parts installed in it: O2 cells, then
/// batteries, then other types by name, each by cell slot and then name.
/// Shared by the condition card's installed parts and the Equipment list's
/// assembly view (issue #5071), so the two never disagree.
int compareInstalledParts(EquipmentItem a, EquipmentItem b) {
  int slotOf(EquipmentItem e) => e.cellSlot ?? 1 << 20;
  int rankOf(EquipmentType t) => switch (t) {
    EquipmentType.o2Cell => 0,
    EquipmentType.battery => 1,
    _ => 2,
  };
  final byRank = rankOf(a.type).compareTo(rankOf(b.type));
  if (byRank != 0) return byRank;
  final byType = a.type.name.compareTo(b.type.name);
  if (byType != 0) return byType;
  final bySlot = slotOf(a).compareTo(slotOf(b));
  if (bySlot != 0) return bySlot;
  return compareTextForSort(a.name, b.name);
}

/// Every "part of" link the Equipment list folds by (issue #5071): an
/// assembly's components (#1487) and the parts installed in a host
/// (`parentEquipmentId`, v202), as one graph.
///
/// Built once per build of the list from the components index and the items
/// on it, so rows read children by id instead of querying.
class EquipmentPartTree {
  final Map<String, List<String>> _children;
  final Map<String, List<String>> _parents;

  const EquipmentPartTree._(this._children, this._parents);

  static const empty = EquipmentPartTree._({}, {});

  /// A host's components come first, in template order, then the parts
  /// installed in it, in [compareInstalledParts] order. Only fitted items
  /// count as installed, as on the condition card. An item linked to one
  /// host both ways is one child, listed once.
  factory EquipmentPartTree.build({
    required ComponentsIndex components,
    required Iterable<EquipmentItem> items,
  }) {
    final installed = <String, List<EquipmentItem>>{};
    for (final item in items) {
      final host = item.parentEquipmentId;
      if (host == null || !item.isFitted) continue;
      installed.putIfAbsent(host, () => []).add(item);
    }
    final children = <String, List<String>>{};
    final parents = <String, List<String>>{};
    void link(String parent, String child) {
      final kids = children.putIfAbsent(parent, () => []);
      if (kids.contains(child)) return;
      kids.add(child);
      parents.putIfAbsent(child, () => []).add(parent);
    }

    for (final entry in components.byParent.entries) {
      for (final EquipmentComponent edge in entry.value) {
        link(entry.key, edge.componentEquipmentId);
      }
    }
    for (final entry in installed.entries) {
      final sorted = [...entry.value]..sort(compareInstalledParts);
      for (final item in sorted) {
        link(entry.key, item.id);
      }
    }
    return EquipmentPartTree._(
      {for (final e in children.entries) e.key: List.unmodifiable(e.value)},
      {for (final e in parents.entries) e.key: List.unmodifiable(e.value)},
    );
  }

  /// The parts of [id], in display order; empty for an item with none.
  List<String> childrenOf(String id) => _children[id] ?? const [];

  /// The items [id] is a part of, by either link.
  List<String> parentsOf(String id) => _parents[id] ?? const [];

  bool hasParts(String id) => _children.containsKey(id);

  /// Every id with at least one part.
  Set<String> get assemblyIds => _children.keys.toSet();
}
