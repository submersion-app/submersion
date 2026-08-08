import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/media_repair_log_repository.dart';
import 'package:submersion/features/media/presentation/providers/media_repair_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The repair audit trail (Media section Phase 5).
///
/// Automatic re-linking is only trustworthy if the user can see what it did,
/// so every applied repair -- manual or from the watcher -- lands here with
/// its new value, its timestamp, and where the candidate came from.
class MediaRepairHistoryView extends ConsumerWidget {
  const MediaRepairHistoryView({super.key});

  String _actionLabel(BuildContext context, RepairLogAction action) {
    return switch (action) {
      RepairLogAction.relink => context.l10n.media_repairHistory_action_relink,
      RepairLogAction.cloudBacked =>
        context.l10n.media_repairHistory_action_cloudBacked,
      RepairLogAction.autoRelink =>
        context.l10n.media_repairHistory_action_autoRelink,
    };
  }

  IconData _actionIcon(RepairLogAction action) {
    return switch (action) {
      RepairLogAction.relink => Icons.link,
      RepairLogAction.cloudBacked => Icons.cloud_done_outlined,
      RepairLogAction.autoRelink => Icons.auto_fix_high_outlined,
    };
  }

  String _sourceLabel(BuildContext context, RepairLogSource source) {
    return switch (source) {
      RepairLogSource.folder => context.l10n.media_repairHistory_sourceFolder,
      RepairLogSource.photoLibrary =>
        context.l10n.media_repairHistory_sourcePhotoLibrary,
      RepairLogSource.store => context.l10n.media_repairHistory_sourceStore,
      RepairLogSource.watcher => context.l10n.media_repairHistory_sourceWatcher,
      RepairLogSource.manual => context.l10n.media_repairHistory_sourceManual,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(repairHistoryProvider).value ?? const [];
    final format = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).add_jm();

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.media_repairHistory_title)),
      body: entries.isEmpty
          ? Center(child: Text(context.l10n.media_repairHistory_empty))
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final subtitleStyle = Theme.of(context).textTheme.bodySmall;
                return ListTile(
                  leading: Icon(_actionIcon(entry.action)),
                  title: Text(_actionLabel(context, entry.action)),
                  isThreeLine: true,
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.newValue ?? entry.mediaId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${format.format(entry.occurredAt)} '
                        '${context.l10n.media_repairHistory_source(_sourceLabel(context, entry.source))}',
                        style: subtitleStyle,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
