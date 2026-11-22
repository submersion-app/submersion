import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_clocks_editor.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/service_severity_colors.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_trigger_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';

/// The Service clocks card on the equipment detail page: one row per
/// schedule with severity dot and binding trigger text. It offers no action:
/// the clocks are edited in the open card's editor (issue #4527, phase 3).
class ServiceClocksCard extends ConsumerWidget {
  final String equipmentId;

  /// The item's own reminder days, shown as a row when set: they are edited
  /// on this card, so they are shown on it.
  final ({bool? enabled, List<int>? days})? customReminder;

  const ServiceClocksCard({
    super.key,
    required this.equipmentId,
    this.customReminder,
  });

  List<String> _triggerLines(
    BuildContext context,
    UnitFormatter units,
    ServiceClockStatus status,
  ) => formatServiceTriggerLines(
    context,
    units: units,
    now: status.now,
    dueDate: status.dueDate,
    usageByUnit: status.usageByUnit,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusesAsync = ref.watch(serviceClockStatusesProvider(equipmentId));
    final schedulesAsync = ref.watch(
      serviceSchedulesForEquipmentProvider(equipmentId),
    );
    final kindsAsync = ref.watch(serviceKindsProvider);
    final allKindsAsync = ref.watch(allServiceKindsByIdProvider);
    final units = ref.watch(unitFormatterProvider);
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
                Expanded(
                  child: Text(
                    l10n.equipment_serviceClocks_title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                RecordCardPencil(cardTitle: l10n.equipment_serviceClocks_title),
              ],
            ),
            const Divider(),
            if (customReminder case final reminder?)
              if (gearCustomReminderText(context, reminder) case final text?)
                Padding(
                  key: const ValueKey('service-clocks-reminders'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
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
                // Every kind, so a shared item's schedule on its owner's
                // custom kind keeps its name (issue #2046).
                final kindsById = {
                  ...?allKindsAsync.value,
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
                          color: serviceSeverityDotColor(
                            context,
                            status.severity,
                          ),
                        ),
                        title: Text(status.kind.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Due date and each usage count get their own
                            // line: joined into one line they read as a
                            // single crowded sentence (issue #3267).
                            for (final line in _triggerLines(
                              context,
                              units,
                              status,
                            ))
                              Text(line),
                            // A baseline date, a service record, the
                            // purchase date or the date the item was added
                            // can each start a clock; say which date did.
                            Text(
                              l10n.equipment_serviceClocks_countingSince(
                                units.formatDate(status.anchor),
                              ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            // An hours clock accrues from logged dive
                            // duration, which approximates but is not
                            // identical to rebreather loop time. Say so
                            // rather than leaving a diver to infer it from a
                            // scrubber budget.
                            if (status.usageByUnit.keys.any(
                              (u) => u.isFractional,
                            ))
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
}
