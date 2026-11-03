import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/providers/auto_connect_settings_provider.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/compact_switch_row.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Device-local: whether this device passively scans for known dive
/// computers while the Transfer tab's Dive Computers section is visible
/// (issue #3361).
class AutoConnectGlobalSwitch extends ConsumerWidget {
  const AutoConnectGlobalSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return CompactSwitchRow(
      switchKey: const ValueKey('auto_connect_known_computers_switch'),
      icon: Icons.bluetooth_connected,
      title: l10n.transfer_computers_autoConnect_switchTitle,
      explanation: l10n.transfer_computers_autoConnect_switchSubtitle,
      value: ref.watch(autoConnectKnownComputersProvider),
      onChanged: (value) => ref
          .read(autoConnectKnownComputersProvider.notifier)
          .setEnabled(value),
    );
  }
}
