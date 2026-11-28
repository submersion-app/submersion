import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_grouping_controls.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Equipment page's assembly view switch (issue #5071): each assembly's
/// parts listed under it rather than in their own type groups. Stored in the
/// shared gear arrangement so it syncs, but offered on this page alone,
/// since no other gear surface nests parts.
class NestPartsSwitch extends ConsumerWidget {
  const NestPartsSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final on = ref.watch(equipmentArrangementProvider).nestParts;
    return SwitchListTile(
      key: const ValueKey('equipment_nest_parts'),
      value: on,
      // Flips the stored value, not the rendered one: a second tap before
      // the first has saved still sees the switch on, and must undo it.
      onChanged: (_) => applyEquipmentArrangement(
        context,
        ref,
        (current) => current.copyWith(nestParts: !current.nestParts),
      ),
      title: Text(l10n.equipment_arrange_nestParts),
      subtitle: Text(l10n.equipment_arrange_nestPartsSubtitle),
    );
  }
}
