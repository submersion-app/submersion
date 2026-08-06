import 'package:flutter/material.dart';

/// Startup screen shown when the database on disk was written by a newer
/// version of the app than the one running (schema `user_version` exceeds
/// [appVersion]). The database has not been opened or modified at this point;
/// the only safe paths forward are updating the app or restoring an older
/// backup after updating.
class VersionMismatchView extends StatelessWidget {
  const VersionMismatchView({
    super.key,
    required this.databaseVersion,
    required this.appVersion,
    required this.textColor,
    required this.subtitleColor,
    required this.onDownloadLatest,
    required this.onClose,
  });

  /// Canonical download location, shown on screen and opened by the button.
  ///
  /// Deliberately owned here rather than passed in: the view renders this exact
  /// string as the manual fallback, and the caller launches the same constant,
  /// so the displayed address and the opened address cannot drift apart.
  static const String latestReleaseUrl =
      'https://github.com/submersion-app/submersion/releases/latest';

  final int databaseVersion;
  final int appVersion;
  final Color textColor;
  final Color subtitleColor;
  final VoidCallback onDownloadLatest;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.update, size: 64, color: Colors.orange),
          const SizedBox(height: 24),
          Text(
            'Update Required',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your dive data was saved by a newer version of '
            'Submersion (schema v$databaseVersion). This version '
            'only supports up to schema v$appVersion.',
            style: TextStyle(fontSize: 14, color: subtitleColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Please update Submersion to the latest version. '
            'Your data is safe and has not been modified. If a backup was '
            'taken before the upgrade, it is in your Backups folder and can '
            'be restored after updating.',
            style: TextStyle(fontSize: 14, color: subtitleColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onDownloadLatest,
            child: const Text('Download Latest Version'),
          ),
          const SizedBox(height: 12),
          Text(
            'If that does not open a browser, visit:',
            style: TextStyle(fontSize: 12, color: subtitleColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          SelectableText(
            latestReleaseUrl,
            style: TextStyle(fontSize: 12, color: subtitleColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onClose, child: const Text('Close')),
        ],
      ),
    );
  }
}
