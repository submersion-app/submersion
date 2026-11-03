import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/backup/data/services/browser_backup_download.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "Download a backup" (issue #4121): a browser has no backup files, so
/// its copy is an image of the live database, read page by page as a sync
/// turn (no merge runs across it) and handed to the download under a
/// dated name. Shown only in a browser.
class BackupDownloadTile extends ConsumerStatefulWidget {
  const BackupDownloadTile({
    super.key,
    @visibleForTesting this.readImage,
    @visibleForTesting this.save,
    @visibleForTesting this.clock,
  });

  final Future<Uint8List> Function()? readImage;
  final Future<void> Function(Uint8List bytes, String fileName)? save;
  final DateTime Function()? clock;

  /// `submersion-backup-<yyyyMMdd>-<HHmm>.db`.
  static String fileNameFor(DateTime at) => browserBackupFileName(at);

  @override
  ConsumerState<BackupDownloadTile> createState() => _BackupDownloadTileState();
}

class _BackupDownloadTileState extends ConsumerState<BackupDownloadTile> {
  static const _log = LoggerService('BackupDownload');
  bool _busy = false;

  Future<void> _download() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = context.l10n.web_downloadBackup_failed;
    setState(() => _busy = true);
    try {
      final bytes = await (widget.readImage ?? readLiveLibraryImage)();
      final name = BackupDownloadTile.fileNameFor(
        (widget.clock ?? DateTime.now)(),
      );
      await (widget.save ?? saveBrowserBackup)(bytes, name);
    } catch (e, stackTrace) {
      _log.error('Backup download failed', error: e, stackTrace: stackTrace);
      messenger?.showSnackBar(SnackBar(content: Text('$failed ($e)')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(deviceCapabilitiesProvider).isBrowser) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return ListTile(
      leading: const Icon(Icons.download),
      title: Text(l10n.web_downloadBackup_title),
      subtitle: Text(l10n.web_downloadBackup_subtitle),
      enabled: !_busy,
      onTap: _busy ? null : _download,
    );
  }
}
