import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Forward and reverse adjacency over every assembly edge, built once per
/// change tick so list tiles and pickers read by id instead of querying.
///
/// Lives in the domain layer so the dive repository can build one from
/// junction rows without depending on presentation providers.
class ComponentsIndex {
  /// Parts of each assembly, in sort order.
  final Map<String, List<EquipmentComponent>> byParent;

  /// The assemblies each part belongs to.
  final Map<String, List<EquipmentComponent>> byComponent;

  const ComponentsIndex({required this.byParent, required this.byComponent});

  static const empty = ComponentsIndex(byParent: {}, byComponent: {});

  factory ComponentsIndex.fromRows(Iterable<EquipmentComponent> rows) {
    final byParent = <String, List<EquipmentComponent>>{};
    final byComponent = <String, List<EquipmentComponent>>{};
    for (final row in rows) {
      byParent.putIfAbsent(row.parentEquipmentId, () => []).add(row);
      byComponent.putIfAbsent(row.componentEquipmentId, () => []).add(row);
    }
    for (final parts in byParent.values) {
      // The row id breaks sort_order ties: List.sort is not stable, and a
      // sync merge of concurrent reorders can leave two parts on one order.
      parts.sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    }
    return ComponentsIndex(byParent: byParent, byComponent: byComponent);
  }

  int componentCount(String id) => byParent[id]?.length ?? 0;

  bool isAssembly(String id) => componentCount(id) > 0;

  /// Each assembly's part names in template order, for the CSV and Excel
  /// exports. A part whose item is not in [itemsById] falls back to its id
  /// rather than vanishing from the row.
  Map<String, List<String>> namesByParent(
    Map<String, EquipmentItem> itemsById,
  ) => {
    for (final entry in byParent.entries)
      entry.key: [
        for (final edge in entry.value)
          itemsById[edge.componentEquipmentId]?.name ??
              edge.componentEquipmentId,
      ],
  };

  List<String> parentIdsOf(String id) => [
    for (final edge in byComponent[id] ?? const <EquipmentComponent>[])
      edge.parentEquipmentId,
  ];

  /// Every id reachable downward from [id], excluding [id] itself unless a
  /// corrupt loop leads back to it. A visited set guarantees termination.
  Set<String> descendantsOf(String id) => _walk(id, (current) sync* {
    for (final edge in byParent[current] ?? const <EquipmentComponent>[]) {
      yield edge.componentEquipmentId;
    }
  });

  /// Every id reachable upward from [id]; same termination guarantee.
  Set<String> ancestorsOf(String id) => _walk(id, (current) sync* {
    for (final edge in byComponent[current] ?? const <EquipmentComponent>[]) {
      yield edge.parentEquipmentId;
    }
  });

  Set<String> _walk(String start, Iterable<String> Function(String) next) {
    final seen = <String>{};
    final queue = <String>[start];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      for (final id in next(current)) {
        if (seen.add(id)) queue.add(id);
      }
    }
    return seen;
  }
}
