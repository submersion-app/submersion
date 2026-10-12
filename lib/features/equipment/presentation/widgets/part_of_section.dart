import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_departed_status.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_labels_of.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A small caption that splits the Components card into its "Part of" and
/// "Contains" halves.
class ComponentsSectionLabel extends StatelessWidget {
  final String text;

  const ComponentsSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The upward half of the Components card (issue #1487): one row per
/// assembly this item is a part of, with the role it plays there and the
/// outermost rigs above that assembly. Rows only navigate; membership is
/// edited from the assembly's own card, where the past-dives question runs.
class PartOfSection extends ConsumerWidget {
  final List<PartOfEntry> entries;

  const PartOfSection({super.key, required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The parents labelled as one list, so two identical assemblies are
    // told apart by their identifiers (#2791).
    // The role and rig line is on the row too, so parents it already tells
    // apart gain no tie-break.
    final l10n = context.l10n;
    final roleLines = {
      for (final entry in entries)
        entry.edge.parentEquipmentId: _roleLine(entry, l10n),
    };
    final labels = equipmentRowLabelsOf(context, ref, [
      for (final entry in entries) ?entry.edge.parent,
    ], shownWith: (item) => roleLines[item.id] ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ComponentsSectionLabel(context.l10n.equipment_components_partOfSection),
        for (final entry in entries)
          _ParentTile(
            entry: entry,
            details:
                labels[entry.edge.parentEquipmentId]?.subtitleParts ?? const [],
          ),
      ],
    );
  }
}

/// The role this item plays in the parent (the parent's type when it has
/// none), with the rigs above that parent when there are any.
String _roleLine(PartOfEntry entry, AppLocalizations l10n) {
  final edge = entry.edge;
  final role = edge.role.isNotEmpty
      ? edge.role
      : (edge.parent?.type ?? EquipmentType.other).localizedName(l10n);
  return entry.rootNames.isEmpty
      ? role
      : l10n.equipment_components_partOfSubtitle(
          entry.rootNames.join(', '),
          role,
        );
}

class _ParentTile extends StatelessWidget {
  final PartOfEntry entry;

  /// Brand and model, identifier and any tie-break, after the role line.
  final List<String> details;

  const _ParentTile({required this.entry, required this.details});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final edge = entry.edge;
    final parent = edge.parent;
    final type = parent?.type ?? EquipmentType.other;
    final departed = parent == null ? null : departedStatusOf(parent);
    final subtitle = [_roleLine(entry, l10n), ...details].join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(equipmentTypeIcon(type)),
      title: Text(parent?.name ?? edge.parentEquipmentId),
      subtitle: Row(
        children: [
          Flexible(child: Text(subtitle)),
          if (departed != null) ...[
            const SizedBox(width: 8),
            Text(
              departed.localizedName(l10n),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ServiceStatusIndicatorFor(
            equipmentId: edge.parentEquipmentId,
            density: ServiceIndicatorDensity.dot,
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => context.push('/equipment/${edge.parentEquipmentId}'),
    );
  }
}
