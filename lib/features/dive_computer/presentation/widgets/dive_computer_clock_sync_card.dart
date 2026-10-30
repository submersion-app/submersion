import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Per-computer clock sync choice (issue #1216). Installation-local like
/// the switch on the computers list: the values live in SharedPreferences,
/// never on the synced computer record.
class DiveComputerClockSyncCard extends ConsumerWidget {
  const DiveComputerClockSyncCard({super.key, required this.computer});

  final DiveComputer computer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final settings = ref.watch(clockSyncSettingsNotifierProvider);
    final notifier = ref.read(clockSyncSettingsNotifierProvider.notifier);
    final support = settings.supportFor(computer.id);
    final captionStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.diveComputer_clockSync_cardTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (support == ClockSyncSupport.unsupported) ...[
              // A control that could never do anything would mislead; say
              // why instead, and let the diver ask the device again after a
              // libdivecomputer update.
              Text(
                l10n.diveComputer_clockSync_unsupported,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const ValueKey('clock_sync_check_again'),
                  onPressed: () => notifier.clearSupport(computer.id),
                  child: Text(l10n.diveComputer_clockSync_checkAgain),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ClockSyncOverride>(
                  key: const ValueKey('clock_sync_override'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: ClockSyncOverride.inherit,
                      label: Text(l10n.diveComputer_clockSync_overrideInherit),
                    ),
                    ButtonSegment(
                      value: ClockSyncOverride.always,
                      label: Text(l10n.diveComputer_clockSync_overrideAlways),
                    ),
                    ButtonSegment(
                      value: ClockSyncOverride.never,
                      label: Text(l10n.diveComputer_clockSync_overrideNever),
                    ),
                  ],
                  selected: {settings.overrideFor(computer.id)},
                  onSelectionChanged: (selection) =>
                      notifier.setOverride(computer.id, selection.first),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                settings.globalEnabled
                    ? l10n.diveComputer_clockSync_appSettingOn
                    : l10n.diveComputer_clockSync_appSettingOff,
                style: captionStyle,
              ),
              if (support == ClockSyncSupport.supported) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.diveComputer_clockSync_supported,
                  style: captionStyle,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
