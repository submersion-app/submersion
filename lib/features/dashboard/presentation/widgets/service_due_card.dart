import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dashboard card listing service clocks that are overdue or due soon,
/// overdue first. Hidden when nothing is due.
class ServiceDueCard extends ConsumerWidget {
  const ServiceDueCard({super.key});

  static const _maxRows = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueAsync = ref.watch(dueClocksProvider);
    final l10n = context.l10n;

    return dueAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (due) {
        if (due.isEmpty) return const SizedBox.shrink();
        final visible = due.take(_maxRows).toList();
        final truncated = due.length - visible.length;
        final scheme = Theme.of(context).colorScheme;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.build, color: scheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.dashboard_serviceDue_title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final clock in visible)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.circle,
                      size: 12,
                      color:
                          clock.status.severity == ServiceClockSeverity.overdue
                          ? scheme.error
                          : scheme.tertiary,
                    ),
                    title: Text(clock.item.name),
                    subtitle: Text(_subtitle(context, clock.status)),
                    trailing: const Icon(Icons.chevron_right, size: 16),
                    onTap: () => context.push('/equipment/${clock.item.id}'),
                  ),
                if (truncated > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.dashboard_serviceDue_more(truncated),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _subtitle(BuildContext context, ServiceClockStatus status) {
    final l10n = context.l10n;
    final kind = status.kind.name;
    final dueDate = status.dueDate;

    // Severity is the engine's verdict across all triggers (date, dives,
    // hours); dueDate only reflects the date trigger. Key the label off
    // severity so a clock that is overdue on dives/hours -- but whose date
    // trigger is null or still in the future -- never renders as merely "due".
    if (status.severity == ServiceClockSeverity.overdue) {
      // Strict isAfter: "overdue since {date}" only when a *past* date drove
      // the overdue state. At the exact due instant (now == dueDate) the engine
      // is not yet date-overdue, and a clock overdue purely on dives/hours has
      // a null/future date trigger -- both fall through to the generic label.
      if (dueDate != null && status.now.isAfter(dueDate)) {
        final formatted = MaterialLocalizations.of(
          context,
        ).formatShortDate(dueDate);
        return '$kind · ${l10n.equipment_serviceClocks_overdueSince(formatted)}';
      }
      return '$kind · ${l10n.equipment_serviceClocks_overdue}';
    }

    if (dueDate != null) {
      final formatted = MaterialLocalizations.of(
        context,
      ).formatShortDate(dueDate);
      return '$kind · ${l10n.equipment_serviceClocks_dueOn(formatted)}';
    }
    return kind;
  }
}
