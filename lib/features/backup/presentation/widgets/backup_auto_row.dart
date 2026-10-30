import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_choice_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// "Back up automatically", with how often in its subtitle; tapping the
/// frequency changes it (spec section 8.2).
class BackupAutoRow extends ConsumerWidget {
  const BackupAutoRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(backupSettingsProvider);
    final notifier = ref.read(backupSettingsProvider.notifier);
    return SwitchListTile(
      secondary: const Icon(Icons.schedule),
      title: Text(l10n.settings_backups_auto),
      value: settings.enabled,
      onChanged: notifier.setEnabled,
      subtitle: settings.enabled
          ? TileSubtitleAction(
              label: backupFrequencyLabel(l10n, settings.frequency),
              // The value is the label; the name only adds context.
              semanticsLabel:
                  '${l10n.backup_schedule_frequency}: '
                  '${backupFrequencyLabel(l10n, settings.frequency)}',
              onPressed: () async {
                final picked = await showBackupChoiceDialog(
                  context,
                  title: l10n.backup_schedule_frequency,
                  values: BackupFrequency.values,
                  selected: settings.frequency,
                  label: (f) => backupFrequencyLabel(l10n, f),
                );
                if (picked != null) await notifier.setFrequency(picked);
              },
            )
          : null,
    );
  }
}

String backupFrequencyLabel(AppLocalizations l10n, BackupFrequency f) =>
    switch (f) {
      BackupFrequency.daily => l10n.backup_frequency_daily,
      BackupFrequency.weekly => l10n.backup_frequency_weekly,
      BackupFrequency.monthly => l10n.backup_frequency_monthly,
    };
