import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_schedule_dialogs.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Service clocks card on the equipment detail page: one row per
/// schedule with severity dot, binding trigger text, and per-clock actions.
class ServiceClocksCard extends ConsumerWidget {
  final String equipmentId;
  final EquipmentType equipmentType;

  /// Opens the add-service dialog pre-filled with the clock's kind; provided
  /// by the detail page (which owns ServiceRecordDialog).
  final void Function(ServiceClockStatus status)? onLogService;

  const ServiceClocksCard({
    super.key,
    required this.equipmentId,
    required this.equipmentType,
    this.onLogService,
  });

  Color _dotColor(BuildContext context, ServiceClockSeverity severity) {
    final scheme = Theme.of(context).colorScheme;
    return switch (severity) {
      ServiceClockSeverity.overdue => scheme.error,
      ServiceClockSeverity.dueSoon => scheme.tertiary,
      ServiceClockSeverity.ok => scheme.surfaceContainerHighest,
    };
  }

  String _triggerText(BuildContext context, ServiceClockStatus status) {
    final l10n = context.l10n;
    final parts = <String>[];
    final dueDate = status.dueDate;
    if (dueDate != null) {
      final formatted = MaterialLocalizations.of(
        context,
      ).formatShortDate(dueDate);
      parts.add(
        // Strict isAfter: at the exact due instant (now == dueDate) the engine
        // treats the date trigger as due-soon, not overdue, so render "Due
        // {date}" until now is strictly past dueDate. Matches the engine's
        // now.isAfter(dueDate) boundary.
        status.now.isAfter(dueDate)
            ? l10n.equipment_serviceClocks_overdueSince(formatted)
            : l10n.equipment_serviceClocks_dueOn(formatted),
      );
    }
    final divesRemaining = status.divesRemaining;
    final divesSince = status.divesSinceAnchor;
    if (divesRemaining != null && divesSince != null) {
      parts.add(
        l10n.equipment_serviceClocks_divesLeft(
          divesRemaining < 0 ? 0 : divesRemaining,
          divesSince + divesRemaining,
        ),
      );
    }
    final hoursRemaining = status.hoursRemaining;
    final hoursSince = status.hoursSinceAnchor;
    if (hoursRemaining != null && hoursSince != null) {
      parts.add(
        l10n.equipment_serviceClocks_hoursLeft(
          (hoursRemaining < 0 ? 0.0 : hoursRemaining).toStringAsFixed(1),
          (hoursSince + hoursRemaining).toStringAsFixed(1),
        ),
      );
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusesAsync = ref.watch(serviceClockStatusesProvider(equipmentId));
    final schedulesAsync = ref.watch(
      serviceSchedulesForEquipmentProvider(equipmentId),
    );
    final kindsAsync = ref.watch(serviceKindsProvider);
    final l10n = context.l10n;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.av_timer,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.equipment_serviceClocks_title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => showServiceKindPicker(
                    context,
                    ref,
                    equipmentId: equipmentId,
                    equipmentType: equipmentType,
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.equipment_serviceClocks_addClock),
                ),
              ],
            ),
            const Divider(),
            statusesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) =>
                  Padding(padding: const EdgeInsets.all(8), child: Text('$e')),
              data: (statuses) {
                final paused =
                    schedulesAsync.value?.where((s) => !s.enabled).toList() ??
                    const [];
                final kindsById = {
                  for (final k in kindsAsync.value ?? []) k.id: k,
                };
                if (statuses.isEmpty && paused.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.equipment_serviceClocks_empty,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final status in statuses)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.circle,
                          size: 14,
                          color: _dotColor(context, status.severity),
                        ),
                        title: Text(status.kind.name),
                        subtitle: Text(_triggerText(context, status)),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) =>
                              _onAction(context, ref, action, status),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'log',
                              child: Text(
                                l10n.equipment_serviceClocks_logService,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'edit',
                              child: Text(l10n.equipment_serviceClocks_edit),
                            ),
                            PopupMenuItem(
                              value: 'pause',
                              child: Text(l10n.equipment_serviceClocks_pause),
                            ),
                            PopupMenuItem(
                              value: 'remove',
                              child: Text(l10n.equipment_serviceClocks_remove),
                            ),
                          ],
                        ),
                      ),
                    for (final schedule in paused)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.pause_circle_outline,
                          size: 18,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        title: Text(
                          (kindsById[schedule.serviceKindId]?.name ??
                              schedule.serviceKindId),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        subtitle: Text(l10n.equipment_serviceClocks_paused),
                        trailing: TextButton(
                          onPressed: () async {
                            await ref
                                .read(serviceScheduleRepositoryProvider)
                                .updateSchedule(
                                  schedule.copyWith(enabled: true),
                                );
                            invalidateServiceClockProviders(ref, equipmentId);
                          },
                          child: Text(l10n.equipment_serviceClocks_resume),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    ServiceClockStatus status,
  ) async {
    switch (action) {
      case 'log':
        onLogService?.call(status);
      case 'edit':
        await showScheduleOverrideDialog(context, ref, status: status);
      case 'pause':
        await ref
            .read(serviceScheduleRepositoryProvider)
            .updateSchedule(status.schedule.copyWith(enabled: false));
        invalidateServiceClockProviders(ref, equipmentId);
      case 'remove':
        await ref
            .read(serviceScheduleRepositoryProvider)
            .deleteSchedule(status.schedule.id);
        invalidateServiceClockProviders(ref, equipmentId);
    }
  }
}
