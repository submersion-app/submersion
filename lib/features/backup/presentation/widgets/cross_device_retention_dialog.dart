import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/byte_format.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/data/services/cross_device_retention.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks before a cross-device prune removes [plan]'s backups (issue #3503),
/// listing every one with its date, source and size. True to go ahead.
Future<bool> showCrossDeviceRetentionDialog(
  BuildContext context,
  CrossDeviceRetentionPlan plan,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _CrossDeviceRetentionDialog(plan),
    ) ??
    false;

class _CrossDeviceRetentionDialog extends ConsumerWidget {
  const _CrossDeviceRetentionDialog(this.plan);

  final CrossDeviceRetentionPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final count = plan.toDelete.length;
    return AlertDialog(
      title: Text(l10n.backup_retention_confirm_title(count)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.backup_retention_confirm_body(
                plan.keepCount,
                formatBytes(plan.totalBytes),
              ),
            ),
            if (plan.pinnedKept > 0) ...[
              const SizedBox(height: 8),
              Text(l10n.backup_retention_confirm_pinnedKept(plan.pinnedKept)),
            ],
            const SizedBox(height: 12),
            Flexible(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in plan.toDelete)
                      ListTile(
                        dense: true,
                        title: Text(
                          units.formatDateTime(c.timestamp, l10n: l10n),
                        ),
                        subtitle: Text(_source(context, c.ownership)),
                        // An unknown size is left blank, never "0 B".
                        trailing: switch (c.file.sizeBytes) {
                          final size? => Text(formatBytes(size)),
                          null => null,
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.backup_retention_confirm_action(count)),
        ),
      ],
    );
  }

  String _source(BuildContext context, BackupOwnership ownership) =>
      switch (ownership) {
        BackupOwnership.thisDevice =>
          context.l10n.backup_retention_source_thisDevice,
        BackupOwnership.otherDevice =>
          context.l10n.backup_retention_source_anotherDevice,
        BackupOwnership.unattributed =>
          context.l10n.backup_retention_source_unknown,
      };
}
