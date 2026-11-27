import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The firmware switches in the notification settings (issue #5104), kept on
/// this device: whether it reads the public firmware list, and whether it
/// notifies. The second is hidden while checks are off rather than shown
/// disabled, since it would do nothing.
class FirmwareSettingsSwitches extends ConsumerWidget {
  const FirmwareSettingsSwitches({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final checks = ref.watch(firmwareChecksEnabledProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.system_update_alt),
            title: Text(l10n.settings_notifications_firmwareChecks),
            subtitle: Text(l10n.settings_notifications_firmwareChecks_subtitle),
            value: checks,
            onChanged: (on) =>
                ref.read(firmwareChecksEnabledProvider.notifier).set(on),
          ),
        ),
        if (checks) ...[
          const SizedBox(height: 16),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: Text(l10n.settings_notifications_firmwareNotices),
              subtitle: Text(
                l10n.settings_notifications_firmwareNotices_subtitle,
              ),
              value: ref.watch(firmwareNotificationsEnabledProvider),
              onChanged: (on) => ref
                  .read(firmwareNotificationsEnabledProvider.notifier)
                  .set(on),
            ),
          ),
        ],
      ],
    );
  }
}
