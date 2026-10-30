import 'package:flutter/material.dart';

import 'package:submersion/features/backup/presentation/widgets/backup_actions.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_advanced_section.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_auto_row.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_copy_row.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_history_section.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_status_line.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Backups (spec section 8.2): what is true first, then how backups run,
/// where the copy goes, the two actions, History, and Advanced. Restore
/// completion (RestoreCompletePage + restartApp) is handled app-wide in
/// SubmersionApp, so it fires even if this page is disposed mid-restore.
class BackupSettingsPage extends StatelessWidget {
  const BackupSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings_backups_title)),
      body: ListView(
        children: const [
          SizedBox(height: 8),
          BackupOperationMessage(),
          BackupStatusLine(),
          BackupAutoRow(),
          BackupCopyRow(),
          BackupNowTile(),
          RestoreFromFileTile(),
          Divider(),
          BackupHistorySection(),
          Divider(),
          BackupAdvancedSection(),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}
