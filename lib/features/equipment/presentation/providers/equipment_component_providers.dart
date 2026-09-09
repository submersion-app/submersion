import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

final equipmentComponentRepositoryProvider =
    Provider<EquipmentComponentRepository>((ref) {
      return EquipmentComponentRepository();
    });

/// Forward and reverse adjacency over every assembly edge, built once per
/// change tick so list tiles and pickers read by id instead of querying.
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

/// The whole template, refreshed only when an edge changes: it holds ids,
/// so a rename of a part is nothing to it. Names come from the item
/// providers, which follow the equipment table on their own.
final equipmentComponentsIndexProvider = FutureProvider<ComponentsIndex>((
  ref,
) async {
  final repository = ref.watch(equipmentComponentRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchComponentEdgeChanges());
  return ComponentsIndex.fromRows(await repository.getAllComponents());
});

/// The hydrated parts of one assembly, in sort order (Components card).
final equipmentComponentsProvider =
    FutureProvider.family<List<EquipmentComponent>, String>((
      ref,
      parentId,
    ) async {
      final repository = ref.watch(equipmentComponentRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchComponentChanges());
      return repository.getComponents(parentId);
    });

/// The single most urgent clock in an item's subtree and who owns it, so a
/// badge can say "Necklace hose: Regulator service overdue".
typedef RollupClock = ({
  String ownerId,
  String ownerName,
  ServiceClockStatus status,
});

/// True when [a] should be surfaced ahead of [b]: higher severity first,
/// then the earlier due date, with a missing date sorting last.
bool isMoreUrgentClock(ServiceClockStatus a, ServiceClockStatus b) {
  if (a.severity != b.severity) return a.severity.index > b.severity.index;
  final ad = a.dueDate, bd = b.dueDate;
  if (ad == null) return false;
  if (bd == null) return true;
  return ad.isBefore(bd);
}

/// Worst clock across every active item and its active descendants, keyed
/// by item id. Absent means nothing in the subtree has a clock at all.
///
/// Derives from [activeEquipmentClocksProvider], which keeps ok clocks, and
/// not from the due-only map: a rollup that dropped ok clocks could not
/// answer "when is this rig next due". A retired descendant is absent from
/// the active evaluation and contributes no clock of its own, though its
/// own active parts still count through it, the same rule the dive expander
/// applies (issue #1487).
///
/// One memoised post-order pass: each node's rollup is the worst of its own
/// clocks and its children's rollups, computed once and reused by every
/// parent, so a thousand-item list costs one visit per node and edge rather
/// than a subtree walk per item.
final equipmentRollupClockProvider = FutureProvider<Map<String, RollupClock>>((
  ref,
) async {
  final evaluated = await ref.watch(activeEquipmentClocksProvider.future);
  final index = await ref.watch(equipmentComponentsIndexProvider.future);
  final byId = {for (final e in evaluated) e.item.id: e};
  final memo = <String, RollupClock?>{};
  final visiting = <String>{};

  RollupClock? rollupFor(String id) {
    if (memo.containsKey(id)) return memo[id];
    // A corrupt loop would otherwise recurse forever; the repeated node
    // contributes nothing on its second visit.
    if (!visiting.add(id)) return null;
    RollupClock? worst;
    void consider(RollupClock? candidate) {
      if (candidate == null) return;
      if (worst == null || isMoreUrgentClock(candidate.status, worst!.status)) {
        worst = candidate;
      }
    }

    final own = byId[id];
    if (own != null) {
      for (final status in own.statuses) {
        consider((ownerId: id, ownerName: own.item.name, status: status));
      }
    }
    for (final edge in index.byParent[id] ?? const <EquipmentComponent>[]) {
      consider(rollupFor(edge.componentEquipmentId));
    }
    visiting.remove(id);
    return memo[id] = worst;
  }

  return {for (final e in evaluated) e.item.id: ?rollupFor(e.item.id)};
});
