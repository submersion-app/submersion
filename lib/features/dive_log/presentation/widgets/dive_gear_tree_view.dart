import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/services/assembly_snapshot.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/domain/services/gear_tree.dart';
import 'package:submersion/features/equipment/presentation/providers/assembly_snapshot_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_label.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_labels_of.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_group_header.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The gear on a dive, rendered the same way on the detail and edit pages
/// (issue #1487): the sets applied to the dive as a row of chips, then
/// every top-level row, set and hand-added alike, ordered and optionally
/// type-grouped by the diver's arrangement as one list (#2031), an
/// assembly as one collapsed row that expands in place to its parts in
/// template order.
///
/// A row-removal callback puts the rows in edit mode. A top-level row,
/// loose or assembly, is removed through [onRemoveSubtree] (a loose row is
/// a one-row subtree); a part beneath an assembly through [onRemovePart];
/// a whole set through [onRemoveSet], which only affects the set chips.
///
/// [rowTrailing] adds a widget at the start of every row's trailing edge,
/// parts included; the detail page uses it for the check-in chip.
///
/// An assembly whose template has gained parts since this dive was logged
/// reads "4 of 9 components" (issue #1988), and [onUpdateAssembly] puts an
/// "Add missing parts" control on that row. Until the template and the
/// part statuses load, rows show the plain count.
class DiveGearTreeView extends ConsumerStatefulWidget {
  final List<GearLink> links;
  final void Function(EquipmentItem item)? onTap;
  final void Function(String setId)? onRemoveSet;
  final void Function(String equipmentId)? onRemoveSubtree;
  final void Function(String equipmentId)? onRemovePart;
  final Widget Function(EquipmentItem item)? rowTrailing;
  final void Function(GearLink link)? onUpdateAssembly;

  /// Whether this tree is a present-tense view of the gear. Dive edit and a
  /// planned dive pass true; a logged past dive passes false, so its record
  /// does not gain a mark about today's service state.
  final bool showServiceStatus;

  const DiveGearTreeView({
    super.key,
    required this.links,
    this.onTap,
    this.onRemoveSet,
    this.onRemoveSubtree,
    this.onRemovePart,
    this.rowTrailing,
    this.onUpdateAssembly,
    this.showServiceStatus = false,
  });

  @override
  ConsumerState<DiveGearTreeView> createState() => _DiveGearTreeViewState();
}

class _DiveGearTreeViewState extends ConsumerState<DiveGearTreeView> {
  final _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final arrangement = ref.watch(equipmentArrangementProvider);
    final setsById = {
      for (final s in ref.watch(equipmentSetsProvider).valueOrNull ?? const [])
        s.id: s,
    };
    final roots = GearTree.build(widget.links);
    final rootsById = {for (final n in roots) n.link.item.id: n};
    final setIds = GearTree.setIds(widget.links);
    final index = ref.watch(equipmentComponentsIndexProvider).value;
    final activeParts = ref.watch(activeComponentIdsProvider).value;
    final shortfalls = index == null || activeParts == null
        ? const <String, AssemblyShortfall>{}
        : AssemblySnapshot.shortfalls(
            [for (final l in widget.links) l.provenance],
            index: index,
            isActive: activeParts.contains,
          );
    // Every item on the dive, parts included, labelled as one list: telling
    // identical items apart means comparing them with their neighbours
    // (#1549).
    final labels = equipmentRowLabelsOf(context, ref, [
      for (final link in widget.links) link.item,
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (setIds.isNotEmpty)
          _SetChips(
            // A deleted set, or one whose name the editor trimmed to empty,
            // takes the fallback so no chip renders without a label.
            names: {
              for (final id in setIds)
                id: switch (setsById[id]?.name.trim()) {
                  final name? when name.isNotEmpty => name,
                  _ => l10n.diveLog_gear_unknownSet,
                },
            },
            onRemove: widget.onRemoveSet,
          ),
        // The arrangement sees every top-level item on the dive at once;
        // parts keep template order underneath their assembly.
        for (final group in arrangeEquipment(
          [for (final n in roots) n.link.item],
          arrangement,
          typeLabel: (type) => type.localizedName(l10n),
        )) ...[
          if (group.type != null) EquipmentGroupHeader(type: group.type!),
          for (final item in group.items)
            ..._rows(
              context,
              rootsById[item.id]!,
              depth: 0,
              showType: group.type == null,
              shortfalls: shortfalls,
              labels: labels,
            ),
        ],
      ],
    );
  }

  List<Widget> _rows(
    BuildContext context,
    GearNode node, {
    required int depth,
    required bool showType,
    required Map<String, AssemblyShortfall> shortfalls,
    required Map<String, EquipmentRowLabel> labels,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final item = node.link.item;
    final hasParts = node.children.isNotEmpty;
    final open = _expanded.contains(item.id);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final shortfall = shortfalls[item.id];
    // An outer assembly behind only through a nested one keeps the plain
    // count: its own parts are all there.
    final fewerParts =
        shortfall != null && shortfall.partsAvailable > shortfall.partsOnDive;
    final subtitleParts = <String>[
      ...?labels[item.id]?.subtitleParts,
      if (fewerParts)
        l10n.equipment_components_countOfTotal(
          shortfall.partsOnDive,
          shortfall.partsAvailable,
        )
      else if (hasParts)
        l10n.equipment_components_count(node.children.length),
    ];
    final removeTooltip = hasParts
        ? l10n.diveLog_gear_removeAssembly
        : depth == 0
        ? l10n.diveLog_edit_tooltip_removeEquipment
        : l10n.diveLog_gear_removePart;
    // A row gets a control only when the callback it would call is there:
    // top-level rows and assemblies remove through onRemoveSubtree, a part
    // through onRemovePart. The set header owns its own button, so no row
    // ever shows a dead icon.
    final remove = hasParts || depth == 0
        ? widget.onRemoveSubtree
        : widget.onRemovePart;

    return [
      Padding(
        padding: EdgeInsets.only(left: 24.0 * depth),
        child: ListTile(
          key: ValueKey('gear-row-${item.id}'),
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.tertiaryContainer,
            child: Icon(
              equipmentTypeIcon(item.type),
              color: theme.colorScheme.onTertiaryContainer,
              size: 20,
            ),
          ),
          title: Text(item.name),
          subtitle: subtitleParts.isEmpty
              ? null
              : Text(subtitleParts.join(' · '), style: muted),
          onTap: widget.onTap == null ? null : () => widget.onTap!(item),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ServiceStatusIndicatorFor(
                equipmentId: item.id,
                density: ServiceIndicatorDensity.dot,
                enabled: widget.showServiceStatus,
              ),
              if (widget.rowTrailing case final trailing?) trailing(item),
              // Redundant under a group heading, which already names the
              // type, and for a part, whose parent row says what it is.
              if (depth == 0 && showType)
                Text(item.type.localizedName(l10n), style: muted),
              if (shortfall != null && widget.onUpdateAssembly != null)
                IconButton(
                  icon: const Icon(Icons.playlist_add, size: 20),
                  tooltip: l10n.diveLog_gear_addMissingParts,
                  onPressed: () => widget.onUpdateAssembly!(node.link),
                ),
              if (hasParts)
                IconButton(
                  icon: Icon(open ? Icons.expand_less : Icons.expand_more),
                  tooltip: open
                      ? l10n.diveLog_gear_collapse
                      : l10n.diveLog_gear_expand,
                  onPressed: () => setState(() {
                    if (!_expanded.remove(item.id)) _expanded.add(item.id);
                  }),
                ),
              if (remove != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: removeTooltip,
                  onPressed: () => remove(item.id),
                )
              else if (widget.onTap != null)
                const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
      if (hasParts && open)
        for (final child in node.children)
          ..._rows(
            context,
            child,
            depth: depth + 1,
            showType: false,
            shortfalls: shortfalls,
            labels: labels,
          ),
    ];
  }
}

/// The sets applied to the dive, one chip each. With [onRemove] the chip
/// carries the delete control that drops the set's gear from the dive.
class _SetChips extends StatelessWidget {
  /// Set id to the name shown, in the order the sets were applied.
  final Map<String, String> names;
  final void Function(String setId)? onRemove;

  const _SetChips({required this.names, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remove = onRemove;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final MapEntry(key: id, value: name) in names.entries)
            Chip(
              key: ValueKey('gear-set-$id'),
              avatar: Icon(
                Icons.inventory_2_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              label: Text(name),
              deleteIcon: const Icon(Icons.close, size: 18),
              deleteButtonTooltipMessage: context.l10n.diveLog_gear_removeSet,
              onDeleted: remove == null ? null : () => remove(id),
            ),
        ],
      ),
    );
  }
}
