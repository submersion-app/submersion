import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/equipment_lead.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Total a weights editor shows: its [rows] plus the lead [leadGear]
/// carries, as `Dive.recordedWeightKg` adds them (issue #4442), or null when
/// there is neither and the editor shows no total. [leadGear] is what
/// [EquipmentLead.carriers] picks from the dive's gear.
double? editorWeightTotalKg(
  List<DiveWeight> rows,
  List<EquipmentItem> leadGear,
) => rows.isEmpty && leadGear.isEmpty
    ? null
    : rows.fold(0.0, (sum, w) => sum + w.amountKg) +
          EquipmentLead.totalKg(leadGear);

/// A line under a weights editor naming the lead the dive already carries
/// as weights gear, and how much (issue #4442).
///
/// Gear-carried lead and the Weights rows add up (a belt beside a weighted
/// backplate), so a diver who logs the same lead in both places counts it
/// twice. This makes the gear share visible where the rows are typed.
/// Draws nothing when no gear carries lead.
class GearLeadNote extends StatelessWidget {
  const GearLeadNote({super.key, required this.items, required this.units});

  /// The weights gear that carries lead, as [EquipmentLead.carriers] picks
  /// it from the dive's gear.
  final List<EquipmentItem> items;

  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final names = [
      for (final item in items) item.name,
    ].join(context.l10n.diveLog_edit_weightGearNote_listSeparator);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.backpack_outlined, size: 16, color: muted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.diveLog_edit_weightGearNote(
                names,
                units.formatWeight(EquipmentLead.totalKg(items)),
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
