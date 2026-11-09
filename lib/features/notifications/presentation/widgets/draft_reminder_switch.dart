import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/notifications/presentation/providers/draft_reminder_settings_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The switch for reminders about drafts left waiting for a download (issue
/// #637), in the notification settings.
class DraftReminderSwitch extends ConsumerWidget {
  const DraftReminderSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.hourglass_top_outlined),
        title: Text(l10n.settings_notifications_draftReminder),
        subtitle: Text(l10n.settings_notifications_draftReminder_subtitle),
        value: ref.watch(draftReminderSettingProvider),
        onChanged: (on) =>
            ref.read(draftReminderSettingProvider.notifier).set(on),
      ),
    );
  }
}
