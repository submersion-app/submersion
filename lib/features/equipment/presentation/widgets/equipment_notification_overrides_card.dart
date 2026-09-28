import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The equipment edit page's Notifications card: per-item reminder
/// overrides. [customReminderEnabled] is tri-state: true uses the custom
/// [customReminderDays], false turns reminders off for this item, and null
/// follows the global settings.
class EquipmentNotificationOverridesCard extends StatelessWidget {
  final bool? customReminderEnabled;
  final List<int> customReminderDays;
  final ValueChanged<bool?> onEnabledChanged;

  /// Called on every chip tap, with the list unchanged when the tap would
  /// have cleared the last selected day.
  final ValueChanged<List<int>> onDaysChanged;

  const EquipmentNotificationOverridesCard({
    super.key,
    required this.customReminderEnabled,
    required this.customReminderDays,
    required this.onEnabledChanged,
    required this.onDaysChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.equipment_edit_notificationsTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.equipment_edit_notificationsSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(context.l10n.equipment_edit_useCustomReminders),
              subtitle: Text(
                context.l10n.equipment_edit_useCustomRemindersSubtitle,
              ),
              value: customReminderEnabled == true,
              onChanged: (value) => onEnabledChanged(value ? true : null),
              contentPadding: EdgeInsets.zero,
            ),
            if (customReminderEnabled == true) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.equipment_edit_remindMeBeforeServiceDue,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [7, 14, 30].map((days) {
                  final isSelected = customReminderDays.contains(days);
                  return FilterChip(
                    label: Text(context.l10n.equipment_edit_reminderDays(days)),
                    selected: isSelected,
                    onSelected: (_) {
                      if (isSelected) {
                        onDaysChanged(
                          customReminderDays.length > 1
                              ? customReminderDays
                                    .where((d) => d != days)
                                    .toList()
                              : customReminderDays,
                        );
                      } else {
                        onDaysChanged([...customReminderDays, days]);
                      }
                    },
                  );
                }).toList(),
              ),
            ],
            const Divider(height: 24),
            SwitchListTile(
              title: Text(context.l10n.equipment_edit_disableReminders),
              subtitle: Text(
                context.l10n.equipment_edit_disableRemindersSubtitle,
              ),
              value: customReminderEnabled == false,
              onChanged: (value) => onEnabledChanged(value ? false : null),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
