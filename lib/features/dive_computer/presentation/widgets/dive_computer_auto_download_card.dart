import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Per-computer opt-out from the passive auto-connect scan (issue #3361):
/// excludes this one computer from auto-download even while the global
/// switch on the Transfer tab's Dive Computers section is on. Synced like
/// the rest of the computer record, unlike the clock sync override above it
/// on this page, which lives in SharedPreferences.
class DiveComputerAutoDownloadCard extends ConsumerWidget {
  const DiveComputerAutoDownloadCard({super.key, required this.computer});

  final DiveComputer computer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Card(
      child: SwitchListTile(
        key: const ValueKey('dive_computer_auto_download_disabled'),
        title: Text(
          l10n.diveComputer_autoDownload_disableTitle,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(l10n.diveComputer_autoDownload_disableSubtitle),
        // Inverted: the switch reads as "skip this computer", the field
        // stores "is disabled" - same polarity, so no extra negation here.
        value: computer.autoDownloadDisabled,
        onChanged: (value) => ref
            .read(diveComputerNotifierProvider.notifier)
            .update(computer.copyWith(autoDownloadDisabled: value)),
      ),
    );
  }
}
