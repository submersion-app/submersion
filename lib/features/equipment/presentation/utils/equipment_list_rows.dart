import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/models/equipment_fold_keys.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/domain/services/equipment_location_arranger.dart';
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
  const EquipmentItemRow({required this.item, required this.headerKey});

  final EquipmentItem item;

  /// The fold key of the innermost heading this row sits under, null when
  /// it sits under none.
  final String? headerKey;
}

/// The rows of one build, plus what the page needs to fold, reveal and
/// navigate them.
class EquipmentRowLayout {
  const EquipmentRowLayout({
    required this.rows,
    required this.foldKeysByItem,
    required this.outerKeys,
    required this.navStops,
  });

  final List<EquipmentListRow> rows;

  /// Every fold key that can hide an item, outermost first, whether folded
  /// now or not: what a reveal has to open to show it.
  final Map<String, List<String>> foldKeysByItem;

  /// The outermost headings' fold keys, in order: what Collapse all folds.
  final List<String> outerKeys;

  /// The keyboard stops: each visible heading as [equipmentGroupNavKey],
  /// each visible item by its id.
  final KeyboardNavStops navStops;
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
EquipmentRowLayout layoutEquipmentRows({
  required List<EquipmentGroup> groups,
  List<EquipmentLocationSection>? sections,
  required Set<String> collapsed,
}) {
  final rows = <EquipmentListRow>[];
  final foldKeysByItem = <String, List<String>>{};
  final outerKeys = <String>[];
  final navStops = KeyboardNavStops();

  void addGroup(EquipmentGroup group, {String? locationKey}) {
    final type = group.type;
    if (type == null) {
      for (final item in group.items) {
        foldKeysByItem[item.id] = [?locationKey];
        rows.add(EquipmentItemRow(item: item, headerKey: locationKey));
        navStops.addRow(
          item.id,
          header: locationKey == null
              ? null
              : equipmentGroupNavKey(locationKey),
        );
      }
      return;
    }
    final key = typeFoldKey(type, parentKey: locationKey);
    if (locationKey == null) outerKeys.add(key);
    final isExpanded = !collapsed.contains(key);
    for (final item in group.items) {
      foldKeysByItem[item.id] = [?locationKey, key];
    }
    rows.add(
      EquipmentTypeHeadingRow(
        type: type,
        foldKey: key,
        parentKey: locationKey,
        items: group.items,
        isExpanded: isExpanded,
      ),
    );
    navStops.addHeader(
      equipmentGroupNavKey(key),
      key,
      parent: locationKey == null ? null : equipmentGroupNavKey(locationKey),
    );
    if (!isExpanded) return;
    for (final item in group.items) {
      rows.add(EquipmentItemRow(item: item, headerKey: key));
      navStops.addRow(item.id, header: equipmentGroupNavKey(key));
    }
  }

  if (sections == null) {
    for (final group in groups) {
      addGroup(group);
    }
  } else {
    for (final (index, section) in sections.indexed) {
      final key = locationFoldKey(section.location?.id);
      outerKeys.add(key);
      final isExpanded = !collapsed.contains(key);
      rows.add(
        EquipmentLocationHeadingRow(
          location: section.location,
          foldKey: key,
          typeCounts: [
            for (final group in section.groups)
              if (group.type case final type?) (type, group.items.length),
          ],
          items: [for (final group in section.groups) ...group.items],
          isExpanded: isExpanded,
          isFirst: index == 0,
        ),
      );
      navStops.addHeader(equipmentGroupNavKey(key), key);
      if (!isExpanded) {
        // Still record what the fold hides, for a reveal to open.
        for (final group in section.groups) {
          for (final item in group.items) {
            foldKeysByItem[item.id] = [
              key,
              if (group.type case final type?)
                typeFoldKey(type, parentKey: key),
            ];
          }
        }
        continue;
      }
      for (final group in section.groups) {
        addGroup(group, locationKey: key);
      }
    }
  }

  return EquipmentRowLayout(
    rows: List.unmodifiable(rows),
    foldKeysByItem: Map.unmodifiable(foldKeysByItem),
    outerKeys: List.unmodifiable(outerKeys),
    navStops: navStops,
  );
}
