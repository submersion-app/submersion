import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/domain/services/gear_tree.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_group_header.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The gear on a dive, rendered the same way on the detail and edit pages
/// (issue #1487): rows bucketed by the set they came from (loose gear
/// last), each bucket's top-level rows ordered and optionally type-grouped
/// by the diver's arrangement, an assembly as one collapsed row that
/// expands in place to its parts in template order.
///
/// A row-removal callback puts the rows in edit mode. A top-level row,
/// loose or assembly, is removed through [onRemoveSubtree] (a loose row is
/// a one-row subtree); a part beneath an assembly through [onRemovePart];
/// a whole band through [onRemoveSet], which only affects the band header.
class DiveGearTreeView extends ConsumerStatefulWidget {
  final List<GearLink> links;
  final void Function(EquipmentItem item)? onTap;
  final void Function(String setId)? onRemoveSet;
  final void Function(String equipmentId)? onRemoveSubtree;
  final void Function(String equipmentId)? onRemovePart;

  const DiveGearTreeView({
    super.key,
    required this.links,
    this.onTap,
    this.onRemoveSet,
    this.onRemoveSubtree,
    this.onRemovePart,
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
    final buckets = GearTree.build(widget.links);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final bucket in buckets) ...[
          if (bucket.setId != null)
            _SetHeader(
              name:
                  setsById[bucket.setId]?.name ?? l10n.diveLog_gear_unknownSet,
              onRemove: widget.onRemoveSet == null
                  ? null
                  : () => widget.onRemoveSet!(bucket.setId!),
            ),
          // The arrangement sees only the top-level items of this bucket;
          // parts keep template order underneath their assembly.
          ..._bucketRows(context, bucket, arrangement),
        ],
      ],
    );
  }

  List<Widget> _bucketRows(
    BuildContext context,
    GearBucket bucket,
    EquipmentArrangement arrangement,
  ) {
    final l10n = context.l10n;
    final rootsById = {for (final n in bucket.roots) n.link.item.id: n};
    return [
      for (final group in arrangeEquipment(
        [for (final n in bucket.roots) n.link.item],
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
          ),
      ],
    ];
  }

  List<Widget> _rows(
    BuildContext context,
    GearNode node, {
    required int depth,
    required bool showType,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final item = node.link.item;
    final hasParts = node.children.isNotEmpty;
    final open = _expanded.contains(item.id);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final subtitleParts = <String>[
      if (item.fullName != item.name) item.fullName,
      if (hasParts) l10n.equipment_components_count(node.children.length),
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
              // Redundant under a group heading, which already names the
              // type, and for a part, whose parent row says what it is.
              if (depth == 0 && showType)
                Text(item.type.localizedName(l10n), style: muted),
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
          ..._rows(context, child, depth: depth + 1, showType: false),
    ];
  }
}

class _SetHeader extends StatelessWidget {
  final String name;
  final VoidCallback? onRemove;

  const _SetHeader({required this.name, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: context.l10n.diveLog_gear_removeSet,
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
