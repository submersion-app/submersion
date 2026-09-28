import 'package:flutter/material.dart';

import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/utils/service_severity_colors.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_tag_chips.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The equipment detail page's header card: the type avatar, name, type,
/// retired chip and tags, then the service banner when a clock is due.
class EquipmentDetailHeaderCard extends StatelessWidget {
  final EquipmentItem equipment;

  /// Reddens the avatar; only an overdue clock does, as on the list tiles.
  final bool isServiceOverdue;

  /// The most urgent due clock, or null when nothing is due (no banner).
  final RollupClock? headerClock;

  const EquipmentDetailHeaderCard({
    super.key,
    required this.equipment,
    required this.isServiceOverdue,
    required this.headerClock,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: isServiceOverdue
                      ? StatusColors.of(context).alert.container
                      : Theme.of(context).colorScheme.tertiaryContainer,
                  child: Icon(
                    equipmentTypeIcon(equipment.type),
                    size: 32,
                    color: isServiceOverdue
                        ? StatusColors.of(context).alert.onContainer
                        : Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equipment.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        equipment.type.localizedName(context.l10n),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (!equipment.isActive)
                        Chip(
                          label: Text(
                            context.l10n.equipment_detail_retiredChip,
                          ),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      // Tags (issue #1942), under the name and type.
                      EquipmentTagChips(equipmentId: equipment.id),
                    ],
                  ),
                ),
              ],
            ),
            if (headerClock case final clock?) ...[
              const SizedBox(height: 16),
              _ServiceBanner(clock: clock, subjectId: equipment.id),
            ],
          ],
        ),
      ),
    );
  }
}

/// The header's service banner: which service is due, on which part, and
/// when, in the swatch of its own severity (red overdue, amber due soon).
/// It used to say only "Service is overdue!", which named neither (#2260).
///
/// The text takes the swatch's onContainer rather than the indicator's
/// accent: the banner fills itself with the container colour, and an accent
/// laid on its own container does not read.
class _ServiceBanner extends StatelessWidget {
  final RollupClock clock;
  final String subjectId;

  const _ServiceBanner({required this.clock, required this.subjectId});

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);
    final swatch =
        serviceSeveritySwatch(colors, clock.status.severity) ?? colors.alert;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: swatch.container,
        border: Border.all(color: swatch.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: swatch.onContainer),
          const SizedBox(width: 8),
          Expanded(
            child: ServiceStatusIndicator(
              clock: clock,
              subjectId: subjectId,
              density: ServiceIndicatorDensity.full,
              color: swatch.onContainer,
            ),
          ),
        ],
      ),
    );
  }
}
