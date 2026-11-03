import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/compact_switch_row.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Installation-local: whether downloads from THIS device set each
/// computer's clock (issue #1216). Lives beside the computer lists rather
/// than in Settings so it sits near the per-computer override on the detail
/// page. Both the Dive Computers page and the Transfers computers section
/// render it (#1910). A single compact row rather than a two-line
/// `SwitchListTile` (issue #4005): this minor, device-local setting sat at
/// the top of both screens with as much visual weight as a primary action.
class ClockSyncGlobalSwitch extends ConsumerWidget {
  const ClockSyncGlobalSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      clockSyncSettingsNotifierProvider.select((s) => s.globalEnabled),
    );
    final l10n = context.l10n;
    return CompactSwitchRow(
      switchKey: const ValueKey('clock_sync_global_switch'),
      icon: Icons.schedule,
      title: l10n.diveComputer_clockSync_globalTitle,
      explanation: l10n.diveComputer_clockSync_globalSubtitle,
      value: enabled,
      onChanged: (value) => ref
          .read(clockSyncSettingsNotifierProvider.notifier)
          .setGlobalEnabled(value),
    );
  }
}
