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
    this.color,
    this.textAlign,
  });

  final RollupClock? clock;

  /// The item being rendered. When the clock's owner is someone else, the
  /// label names that part, matching the equipment list's rollup badge.
  final String subjectId;

  final ServiceIndicatorDensity density;

  /// Foreground for a surface that has already filled itself with a status
  /// colour, where [StatusColors]'s accent would not read against its own
  /// container. Such a caller passes the `onContainer` its fill guarantees.
  /// Everything else leaves this null and takes the severity accent.
  final Color? color;

  /// Alignment of each line of the label, for a host column that aligns its
  /// other states one way (the dense list's right-aligned status column).
  /// Per line rather than an [Align] around the whole: a label wrapping in a
  /// narrow column would otherwise leave its lines ragged inside a box that
  /// merely sits at the edge. Ignored by the dot, which has no text.
  final TextAlign? textAlign;

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
      color: color ?? swatch?.accent,
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
              // The roomy density: body size and bold, since it stands in
              // for a whole banner rather than a chip.
              Text(
                line,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color ?? swatch?.accent,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: textAlign,
              ),
              Text(
                formatServiceTriggerText(
                  context,
                  units: units,
                  now: c.status.now,
                  dueDate: c.status.dueDate,
                  usageByUnit: c.status.usageByUnit,
                ),
                // The override reaches this line too: on a status fill the
                // default grey would not read against the container.
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color ?? theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: textAlign,
              ),
            ],
          ),
        );

      case ServiceIndicatorDensity.compact:
        return Semantics(
          label: line,
          child: Text(
            line,
            style: labelStyle,
            textAlign: textAlign,
            overflow: TextOverflow.ellipsis,
          ),
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
                color:
                    color ??
                    serviceSeverityDotColor(context, c.status.severity),
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

/// [ServiceStatusIndicator] for a surface whose subject is a group rather
/// than one item: an equipment set, a rig, a saved kit. Reports the most
/// urgent clock across [equipmentIds] and names the member that owns it,
/// because the group itself is not the thing needing service.
///
/// Ranking is [isMoreUrgentClock], the same order the equipment list uses,
/// so a set and its members never disagree about which clock matters most.
class ServiceStatusIndicatorForAny extends ConsumerWidget {
  const ServiceStatusIndicatorForAny({
    super.key,
    required this.equipmentIds,
    this.density = ServiceIndicatorDensity.compact,
    this.enabled = true,
  });

  final List<String> equipmentIds;
  final ServiceIndicatorDensity density;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) return const SizedBox.shrink();
    final map = ref.watch(equipmentRollupClockProvider).value;
    if (map == null) return const SizedBox.shrink();

    RollupClock? worst;
    for (final id in equipmentIds) {
      final candidate = map[id];
      if (candidate == null ||
          candidate.status.severity == ServiceClockSeverity.ok) {
        continue;
      }
      if (worst == null || isMoreUrgentClock(candidate.status, worst.status)) {
        worst = candidate;
      }
    }
    if (worst == null) return const SizedBox.shrink();

    // A subject id that matches nothing forces the owner-naming branch, so
    // the label always says which member is due rather than just the kind.
    return ServiceStatusIndicator(
      clock: worst,
      subjectId: '',
      density: density,
    );
  }
}
