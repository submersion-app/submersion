import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_schedule_dialogs.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_trigger_text.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
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

  String _triggerText(
    BuildContext context,
    UnitFormatter units,
    ServiceClockStatus status,
  ) => formatServiceTriggerText(
    context,
    units: units,
    now: status.now,
    dueDate: status.dueDate,
    divesSinceAnchor: status.divesSinceAnchor,
    divesRemaining: status.divesRemaining,
    hoursSinceAnchor: status.hoursSinceAnchor,
    hoursRemaining: status.hoursRemaining,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusesAsync = ref.watch(serviceClockStatusesProvider(equipmentId));
    final schedulesAsync = ref.watch(
      serviceSchedulesForEquipmentProvider(equipmentId),
    );
    final kindsAsync = ref.watch(serviceKindsProvider);
    final units = UnitFormatter(ref.watch(settingsProvider));
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
                final schedules = schedulesAsync.value ?? const [];
                final paused = schedules.where((s) => !s.enabled).toList();
                final kindsById = {
                  for (final k in kindsAsync.value ?? []) k.id: k,
                };
                // Enabled schedules the engine emitted no status for have no
                // effective interval (no override, no kind default). They are
                // invisible otherwise; surface them so the user can configure.
                final evaluatedIds = {for (final s in statuses) s.schedule.id};
                final unconfigured = schedules
                    .where((s) => s.enabled && !evaluatedIds.contains(s.id))
                    .toList();
                if (statuses.isEmpty &&
                    paused.isEmpty &&
                    unconfigured.isEmpty) {
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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_triggerText(context, units, status)),
                            // An hours clock accrues from logged dive
                            // duration, which approximates but is not
                            // identical to rebreather loop time. Say so
                            // rather than leaving a diver to infer it from a
                            // scrubber budget.
                            if (status.hoursRemaining != null)
                              Text(
                                l10n.equipment_serviceClocks_hoursSource,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                          ],
                        ),
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
                    for (final schedule in unconfigured)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.circle_outlined,
                          size: 14,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        title: Text(
                          kindsById[schedule.serviceKindId]?.name ??
                              schedule.serviceKindId,
                        ),
                        subtitle: Text(
                          l10n.equipment_serviceClocks_unconfigured,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final kind = kindsById[schedule.serviceKindId];
                          if (kind == null) return;
                          // The dialog invalidates the clock providers itself on
                          // Save (and on Cancel nothing changed), so no extra
                          // invalidation here -- matches the 'edit' action.
                          await showScheduleOverrideDialog(
                            context,
                            ref,
                            schedule: schedule,
                            kind: kind,
                          );
                        },
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
        await showScheduleOverrideDialog(
          context,
          ref,
          schedule: status.schedule,
          kind: status.kind,
        );
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
