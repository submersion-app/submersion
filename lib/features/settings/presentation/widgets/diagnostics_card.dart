import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/debug_mode_provider.dart';
import 'package:submersion/features/settings/presentation/providers/diagnostics_actions.dart';
import 'package:submersion/l10n/l10n_extension.dart';

export 'package:submersion/features/settings/presentation/providers/diagnostics_actions.dart'
    show FolderLauncher;

const _logger = LoggerService('DiagnosticsCard');

/// Settings > About card that makes the always-on log reachable without the
/// hidden five-tap debug gesture (#1826): view it, copy a bug-report summary,
/// and on desktop open the folder holding it.
class DiagnosticsCard extends ConsumerWidget {
  /// Whether to offer "Open log folder"; null follows [canOpenLogFolder].
  final bool? canOpenFolder;

  /// Seam for the folder hand-off; null uses `launchUrl`.
  final FolderLauncher? folderLauncher;

  const DiagnosticsCard({super.key, this.canOpenFolder, this.folderLauncher});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: Text(l10n.settings_diagnostics_viewLog),
            subtitle: Text(l10n.settings_diagnostics_viewLogSubtitle),
            onTap: () => context.push('/settings/debug-logs'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.content_copy),
            title: Text(l10n.settings_diagnostics_copy),
            subtitle: Text(l10n.settings_diagnostics_copySubtitle),
            onTap: () => _copyDiagnostics(context, ref),
          ),
          if (canOpenFolder ?? canOpenLogFolder) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: Text(l10n.settings_diagnostics_openFolder),
              onTap: () => _openFolder(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _copyDiagnostics(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(logFileServiceProvider);
    final verbose = ref.read(debugModeNotifierProvider);
    try {
      await copyDiagnostics(service, verboseLogging: verbose);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.settings_diagnostics_copiedSnack),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _logger.warning('Copy diagnostics failed', error: e);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settings_diagnostics_copyFailed(e))),
      );
    }
  }

  Future<void> _openFolder(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(logFileServiceProvider);
    final opened = await openLogFolder(service, launcher: folderLauncher);
    if (opened) return;
    // The path is the fallback: the diver can paste it into a file manager.
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.settings_diagnostics_openFolderFailed(service.logDirectory),
        ),
      ),
    );
  }
}
