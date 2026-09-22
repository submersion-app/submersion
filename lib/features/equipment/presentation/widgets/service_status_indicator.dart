import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/service_severity_colors.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_trigger_text.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// How much room the host surface has for the service signal.
enum ServiceIndicatorDensity {
  /// Kind label plus the full trigger line. For detail headers and cards.
  full,

  /// One line naming the kind and its urgency. For list and picker rows.
  compact,

  /// A coloured dot; the compact wording moves into the tooltip and the
  /// semantics label. For chips, dense rows and tree rows.
  dot,
}

/// The one place the app decides how a service clock looks.
///
/// Renders nothing at all for a null or ok clock, so a caller can pass the
/// raw map lookup without filtering first. Service state only: arbitration
/// against a competing condition finding stays with `pickBadgeSource`, and a
/// caller whose badge slot is contested decides which of the two to pass.
class ServiceStatusIndicator extends ConsumerWidget {
  const ServiceStatusIndicator({
    super.key,
    required this.clock,
    required this.subjectId,
    this.density = ServiceIndicatorDensity.compact,
  });

  final RollupClock? clock;

  /// The item being rendered. When the clock's owner is someone else, the
  /// label names that part, matching the equipment list's rollup badge.
  final String subjectId;

  final ServiceIndicatorDensity density;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = clock;
    if (c == null || c.status.severity == ServiceClockSeverity.ok) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final swatch = serviceSeveritySwatch(
      StatusColors.of(context),
      c.status.severity,
    );

    final kindLabel = c.ownerId == subjectId
        ? c.status.kind.name
        : l10n.equipment_components_rollupClock(
            c.ownerName,
            c.status.kind.name,
          );

    final line = c.status.severity == ServiceClockSeverity.overdue
        ? l10n.equipment_service_overdue(kindLabel)
        : l10n.equipment_service_dueRelative(
            kindLabel,
            formatServiceTriggerShort(
              context,
              units: units,
              now: c.status.now,
              status: c.status,
            ),
          );

    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: swatch?.accent,
      fontWeight: FontWeight.w600,
    );

    switch (density) {
      case ServiceIndicatorDensity.full:
        return Semantics(
          label: line,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line, style: labelStyle),
              Text(
                formatServiceTriggerText(
                  context,
                  units: units,
                  now: c.status.now,
                  dueDate: c.status.dueDate,
                  usageByUnit: c.status.usageByUnit,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );

      case ServiceIndicatorDensity.compact:
        return Semantics(
          label: line,
          child: Text(line, style: labelStyle, overflow: TextOverflow.ellipsis),
        );

      case ServiceIndicatorDensity.dot:
        return Tooltip(
          message: line,
          child: Semantics(
            label: line,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: serviceSeverityDotColor(context, c.status.severity),
              ),
            ),
          ),
        );
    }
  }
}

/// [ServiceStatusIndicator] for a surface that holds an equipment id rather
/// than a clock. Watches the batch rollup map, so a list of a thousand rows
/// still costs one provider rather than one per row.
///
/// [enabled] is how a surface expresses the current-facing rule: a logged
/// past dive passes false, so its gear tree stays a faithful record of that
/// dive rather than a statement about today's service state.
class ServiceStatusIndicatorFor extends ConsumerWidget {
  const ServiceStatusIndicatorFor({
    super.key,
    required this.equipmentId,
    this.density = ServiceIndicatorDensity.compact,
    this.enabled = true,
  });

  final String equipmentId;
  final ServiceIndicatorDensity density;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) return const SizedBox.shrink();
    final clock = ref.watch(equipmentRollupClockProvider).value?[equipmentId];
    return ServiceStatusIndicator(
      clock: clock,
      subjectId: equipmentId,
      density: density,
    );
  }
}
