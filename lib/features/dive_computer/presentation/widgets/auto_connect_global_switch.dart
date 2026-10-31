import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/auto_connect_settings_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Device-local: whether this device passively scans for known dive
/// computers while the Transfer tab's Dive Computers section is visible
/// (issue #3361). Same compact single-line row as [ClockSyncGlobalSwitch]
/// (issue #4005): icon, title, an info icon that opens the explanation as a
/// tap-triggered tooltip, and the switch.
class AutoConnectGlobalSwitch extends ConsumerWidget {
  const AutoConnectGlobalSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(autoConnectKnownComputersProvider);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.bluetooth_connected, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.transfer_computers_autoConnect_switchTitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Tooltip(
            message: l10n.transfer_computers_autoConnect_switchSubtitle,
            triggerMode: TooltipTriggerMode.tap,
            child: IconButton(
              icon: const Icon(Icons.info_outline),
              // The Tooltip above handles the tap; this button has nothing
              // of its own to do.
              onPressed: () {},
            ),
          ),
          Switch(
            key: const ValueKey('auto_connect_known_computers_switch'),
            value: enabled,
            onChanged: (value) => ref
                .read(autoConnectKnownComputersProvider.notifier)
                .setEnabled(value),
          ),
        ],
      ),
    );
  }
}
