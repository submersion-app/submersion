import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/database/database_image.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/platform/file_saver.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
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
  static String fileNameFor(DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'submersion-backup-${at.year}${two(at.month)}${two(at.day)}-'
        '${two(at.hour)}${two(at.minute)}.db';
  }

  @override
  ConsumerState<BackupDownloadTile> createState() => _BackupDownloadTileState();
}

class _BackupDownloadTileState extends ConsumerState<BackupDownloadTile> {
  static const _log = LoggerService('BackupDownload');
  bool _busy = false;

  Future<Uint8List> _readLive() => SyncCoordinator.join(
    () => readDatabaseImage(DatabaseService.instance.database),
  );

  Future<void> _saveDownload(Uint8List bytes, String fileName) =>
      FileSaver.saveBytes(
        bytes,
        fileName: fileName,
        mimeType: 'application/vnd.sqlite3',
      );

  Future<void> _download() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = context.l10n.settings_cloudSync_message_syncFailed;
    setState(() => _busy = true);
    try {
      final bytes = await (widget.readImage ?? _readLive)();
      final name = BackupDownloadTile.fileNameFor(
        (widget.clock ?? DateTime.now)(),
      );
      await (widget.save ?? _saveDownload)(bytes, name);
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
