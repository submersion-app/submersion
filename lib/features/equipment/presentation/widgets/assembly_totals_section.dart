import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/services/assembly_totals.dart';
import 'package:submersion/features/equipment/presentation/providers/assembly_totals_provider.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_units.dart';
import 'package:submersion/features/equipment/presentation/widgets/part_of_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row_group.dart';

/// The foot of the Components card (issue #4443): the buoyancy and dry
/// weight the assembly's parts add up to, in the diver's weight unit. A
/// measure no part declares is left out, and the section hides itself when
/// there is nothing to sum, so an assembly of parts with no figures shows
/// no empty block. A sum some parts are missing from says how many it is
/// from, so it never reads as the whole assembly's figure.
class AssemblyTotalsSection extends ConsumerWidget {
  final String assemblyId;

  const AssemblyTotalsSection({super.key, required this.assemblyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(assemblyTotalsProvider(assemblyId)).value;
    if (totals == null || !totals.hasAny) return const SizedBox.shrink();
    final units = ref.watch(unitFormatterProvider);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        ComponentsSectionLabel(l10n.equipment_components_totalsSection),
        DetailRowGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (totals.buoyancy case final sum?)
                _TotalRow(
                  label: attributeLabel(l10n, EquipmentAttrKeys.buoyancyKg),
                  sum: sum,
                  partCount: totals.partCount,
                  units: units,
                ),
              if (totals.dryWeight case final sum?)
                _TotalRow(
                  label: attributeLabel(l10n, EquipmentAttrKeys.dryWeightKg),
                  sum: sum,
                  partCount: totals.partCount,
                  units: units,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final PartsSum sum;
  final int partCount;
  final UnitFormatter units;

  const _TotalRow({
    required this.label,
    required this.sum,
    required this.partCount,
    required this.units,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Formatted as a part's own figure reads on its detail page, so the
    // total and the figures it sums agree to the digit.
    final value =
        '${formatAttributeNumberForEditing(AttributeDimension.massKg, units, sum.kg)} '
        '${attributeUnitSymbol(AttributeDimension.massKg, units)}';
    final partial = sum.parts < partCount;
    return DetailRow(
      label: label,
      padding: const EdgeInsets.symmetric(vertical: 4),
      value: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value),
          if (partial)
            Text(
              context.l10n.equipment_components_totalFromParts(
                sum.parts,
                partCount,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
