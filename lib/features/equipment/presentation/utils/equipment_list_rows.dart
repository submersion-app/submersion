import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/models/equipment_fold_keys.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/domain/services/equipment_location_arranger.dart';
import 'package:submersion/features/equipment/domain/services/equipment_part_tree.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_assembly_rows.dart';
import 'package:submersion/shared/widgets/master_detail/keyboard_nav_stops.dart';

/// One row of the lazily built Equipment list (issue #4184): a place's
/// heading, a type's heading, or an item. Plain data, so a long inventory
/// costs nothing until a row scrolls into view.
sealed class EquipmentListRow {
  const EquipmentListRow();
}

/// A place's heading when the page groups by location.
class EquipmentLocationHeadingRow extends EquipmentListRow {
  const EquipmentLocationHeadingRow({
    required this.location,
    required this.foldKey,
    required this.typeCounts,
    required this.items,
    required this.isExpanded,
    required this.isFirst,
  });

  /// Null is "No location".
  final EquipmentLocation? location;
  final String foldKey;

  /// The typed groups inside, in the order they are listed, with their item
  /// counts: what the folded heading summarises.
  final List<(EquipmentType, int)> typeCounts;

  /// Every item in the place, folded or not.
  final List<EquipmentItem> items;
  final bool isExpanded;

  /// The first place on the page, which draws no divider above it.
  final bool isFirst;
}

/// A type's heading, inside a place ([parentKey]) or at the top level.
class EquipmentTypeHeadingRow extends EquipmentListRow {
  const EquipmentTypeHeadingRow({
    required this.type,
    required this.foldKey,
    required this.parentKey,
    required this.items,
    required this.isExpanded,
  });

  final EquipmentType type;
  final String foldKey;

  /// The place heading's fold key when nested under one.
  final String? parentKey;
  final List<EquipmentItem> items;
  final bool isExpanded;
}

class EquipmentItemRow extends EquipmentListRow {
  const EquipmentItemRow({
    required this.item,
    this.depth = 0,
    String? navKey,
    this.parentId,
    this.foldKey,
    this.isExpanded = false,
    this.partCount = 0,
  }) : _navKey = navKey;

  final EquipmentItem item;

  /// How many assemblies deep the row sits (issue #5071); 0 at the top.
  final int depth;

  final String? _navKey;

  /// The row's keyboard stop: the item id, except for a part's second and
  /// later rows under other assemblies (see [repeatedPartNavKey]).
  String get navKey => _navKey ?? item.id;

  /// The assembly the row sits under, or null at the top level.
  final String? parentId;

  /// The row's own fold (`asm:<id>`) when it is an assembly with parts on
  /// the list; null for any other row.
  final String? foldKey;

  /// Whether the parts under [foldKey] show; false when there is no fold.
  final bool isExpanded;

  /// The parts listed under the row, folded or not.
  final int partCount;
}

/// The rows of one build, plus what the page needs to fold, reveal and
/// navigate them.
class EquipmentRowLayout {
  const EquipmentRowLayout({
    required this.rows,
    required this.foldKeysByItem,
    required this.outerKeys,
    required this.navStops,
    this.assemblyIds = const {},
    this.itemIdByNavKey = const {},
    this.assemblyFoldByNavKey = const {},
    this.parentNavKeyOf = const {},
    this.itemsByFoldKey = const {},
  });

  final List<EquipmentListRow> rows;

  /// Every fold key that can hide an item, outermost first, whether folded
  /// now or not: what a reveal has to open to show it.
  final Map<String, List<String>> foldKeysByItem;

  /// The outermost headings' fold keys, in order: what Collapse all folds.
  final List<String> outerKeys;

  /// The keyboard stops: each visible heading as [equipmentGroupNavKey],
  /// each visible item row by its [EquipmentItemRow.navKey].
  final KeyboardNavStops navStops;

  /// Every assembly that folds on the list (issue #5071), shown or folded
  /// away: what Expand all opens and Collapse all folds.
  final Set<String> assemblyIds;

  /// The item behind each visible item stop.
  final Map<String, String> itemIdByNavKey;

  /// Each visible assembly row's stop, to its fold key: Right opens it and
  /// Left folds it.
  final Map<String, String> assemblyFoldByNavKey;

  /// Each visible part row's stop, to the stop of the assembly row above it:
  /// where Left goes.
  final Map<String, String> parentNavKeyOf;

  /// Every item each fold hides, by every path that reaches it: a part in
  /// two rigs counts under both rigs' headings. What a folded heading's
  /// summaries count; [foldKeysByItem] keeps only the first path, for the
  /// reveal.
  final Map<String, Set<String>> itemsByFoldKey;
}

/// The keyboard stop of the heading whose fold key is [foldKey].
String equipmentGroupNavKey(String foldKey) => 'group:$foldKey';

/// Lays out the Equipment list's rows (issue #4184).
///
/// With [sections] (grouped by location), each place heads its type groups;
/// otherwise [groups] are the top level. A group whose type is null (type
/// grouping off) has no heading and cannot fold: its items sit directly
/// under the place, or at the top level. A key in [collapsed] that names no
/// group on the page (a deleted place) folds nothing.
///
/// With [parts] (the assembly view, issue #5071), each assembly's parts in
/// the same place sit under its row instead of in their own type groups,
/// and a type group left with nothing at the top level has no heading.
/// [collapsed] then also holds the `asm:` key of every folded assembly.
EquipmentRowLayout layoutEquipmentRows({
  required List<EquipmentGroup> groups,
  List<EquipmentLocationSection>? sections,
  required Set<String> collapsed,
  EquipmentPartTree? parts,
}) {
  final rows = <EquipmentListRow>[];
  final foldKeysByItem = <String, List<String>>{};
  final outerKeys = <String>[];
  final navStops = KeyboardNavStops();
  final assemblyIds = <String>{};
  final itemIdByNavKey = <String, String>{};
  final assemblyFoldByNavKey = <String, String>{};
  final parentNavKeyOf = <String, String>{};
  // Items with a row on screen already, so a repeated part gets its own stop.
  final shownIds = <String>{};
  final itemsByFoldKey = <String, Set<String>>{};
  void record(String id, List<String> keys) {
    foldKeysByItem.putIfAbsent(id, () => List.unmodifiable(keys));
    for (final key in keys) {
      itemsByFoldKey.putIfAbsent(key, () => <String>{}).add(id);
    }
  }

  final nest = parts != null && parts.assemblyIds.isNotEmpty ? parts : null;

  /// Adds [item] (and, in the assembly view, the parts under it) under the
  /// fold keys [keys], with its rows inside the heading [header].
  void addItem(
    EquipmentItem item, {
    required List<String> keys,
    required String? header,
    required bool visible,
    AssemblyUnit? unit,
  }) {
    if (unit == null) {
      record(item.id, keys);
      if (!visible) return;
      rows.add(EquipmentItemRow(item: item));
      navStops.addRow(item.id, header: header);
      itemIdByNavKey[item.id] = item.id;
      return;
    }
    walkAssembly(
      item,
      unit: unit,
      collapsed: collapsed,
      outerKeys: keys,
      visible: visible,
      isShown: shownIds.contains,
      walkedInRoot: <String>{},
      onItem: (item, foldKeys) => record(item.id, foldKeys),
      onAssembly: assemblyIds.add,
      onRow: (item, info) {
        rows.add(
          EquipmentItemRow(
            item: item,
            depth: info.depth,
            navKey: info.navKey,
            parentId: info.parentId,
            foldKey: info.foldKey,
            isExpanded: info.isExpanded,
            partCount: info.partCount,
          ),
        );
        navStops.addRow(info.navKey, header: header);
        itemIdByNavKey[info.navKey] = item.id;
        shownIds.add(item.id);
        if (info.foldKey case final key?) {
          assemblyFoldByNavKey[info.navKey] = key;
        }
        if (info.parentNavKey case final parent?) {
          parentNavKeyOf[info.navKey] = parent;
        }
      },
    );
  }

  /// [group]'s top-level items: all of them, or in the assembly view those
  /// none of whose assemblies are in the same place.
  List<EquipmentItem> topOf(EquipmentGroup group, AssemblyUnit? unit) =>
      unit == null ? group.items : unit.topLevelOf(group);

  void addGroup(
    EquipmentGroup group, {
    String? locationKey,
    AssemblyUnit? unit,
  }) {
    final top = topOf(group, unit);
    final type = group.type;
    if (type == null) {
      final header = locationKey == null
          ? null
          : equipmentGroupNavKey(locationKey);
      for (final item in top) {
        addItem(
          item,
          keys: [?locationKey],
          header: header,
          visible: true,
          unit: unit,
        );
      }
      return;
    }
    if (top.isEmpty) return;
    final key = typeFoldKey(type, parentKey: locationKey);
    if (locationKey == null) outerKeys.add(key);
    final isExpanded = !collapsed.contains(key);
    rows.add(
      EquipmentTypeHeadingRow(
        type: type,
        foldKey: key,
        parentKey: locationKey,
        items: top,
        isExpanded: isExpanded,
      ),
    );
    navStops.addHeader(
      equipmentGroupNavKey(key),
      key,
      parent: locationKey == null ? null : equipmentGroupNavKey(locationKey),
    );
    for (final item in top) {
      addItem(
        item,
        keys: [?locationKey, key],
        header: equipmentGroupNavKey(key),
        visible: isExpanded,
        unit: unit,
      );
    }
  }

  AssemblyUnit? unitOf(List<EquipmentGroup> groups) =>
      nest == null ? null : AssemblyUnit(groups, nest);

  if (sections == null) {
    final unit = unitOf(groups);
    for (final group in groups) {
      addGroup(group, unit: unit);
    }
  } else {
    for (final (index, section) in sections.indexed) {
      final unit = unitOf(section.groups);
      final key = locationFoldKey(section.location?.id);
      outerKeys.add(key);
      final isExpanded = !collapsed.contains(key);
      final tops = [
        for (final group in section.groups) (group, topOf(group, unit)),
      ];
      rows.add(
        EquipmentLocationHeadingRow(
          location: section.location,
          foldKey: key,
          typeCounts: [
            for (final (group, top) in tops)
              if (group.type case final type? when top.isNotEmpty)
                (type, top.length),
          ],
          items: [for (final (_, top) in tops) ...top],
          isExpanded: isExpanded,
          isFirst: index == 0,
        ),
      );
      navStops.addHeader(equipmentGroupNavKey(key), key);
      if (!isExpanded) {
        // Still record what the fold hides, for a reveal to open.
        for (final (group, top) in tops) {
          for (final item in top) {
            addItem(
              item,
              keys: [
                key,
                if (group.type case final type?)
                  typeFoldKey(type, parentKey: key),
              ],
              header: null,
              visible: false,
              unit: unit,
            );
          }
        }
        continue;
      }
      for (final group in section.groups) {
        addGroup(group, locationKey: key, unit: unit);
      }
    }
  }

  return EquipmentRowLayout(
    rows: List.unmodifiable(rows),
    foldKeysByItem: Map.unmodifiable(foldKeysByItem),
    outerKeys: List.unmodifiable(outerKeys),
    navStops: navStops,
    assemblyIds: Set.unmodifiable(assemblyIds),
    itemIdByNavKey: Map.unmodifiable(itemIdByNavKey),
    assemblyFoldByNavKey: Map.unmodifiable(assemblyFoldByNavKey),
    parentNavKeyOf: Map.unmodifiable(parentNavKeyOf),
    itemsByFoldKey: Map.unmodifiable(itemsByFoldKey),
  );
}
