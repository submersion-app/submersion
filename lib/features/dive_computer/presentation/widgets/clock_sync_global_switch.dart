import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Installation-local: whether downloads from THIS device set each
/// computer's clock (issue #1216). Lives beside the computer lists rather
/// than in Settings so it sits near the per-computer override on the detail
/// page. Both the Dive Computers page and the Transfers computers section
/// render it (#1910).
class ClockSyncGlobalSwitch extends ConsumerWidget {
  const ClockSyncGlobalSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      clockSyncSettingsNotifierProvider.select((s) => s.globalEnabled),
    );
    return SwitchListTile(
      key: const ValueKey('clock_sync_global_switch'),
      secondary: const Icon(Icons.schedule),
      title: Text(context.l10n.diveComputer_clockSync_globalTitle),
      subtitle: Text(context.l10n.diveComputer_clockSync_globalSubtitle),
      value: enabled,
      onChanged: (value) => ref
          .read(clockSyncSettingsNotifierProvider.notifier)
          .setGlobalEnabled(value),
    );
  }
}
