import 'dart:io';

import 'package:auto_updater/auto_updater.dart';

import 'package:submersion/features/auto_update/data/services/update_service.dart';
import 'package:submersion/features/auto_update/domain/entities/update_status.dart';

class SparkleUpdateService implements UpdateService {
  final String feedUrl;
  bool _initialized = false;

  SparkleUpdateService({required this.feedUrl});

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    // Only initialize on macOS or Windows
    if (!Platform.isMacOS && !Platform.isWindows) return;

    await autoUpdater.setFeedURL(feedUrl);
    // Check every 4 hours (in seconds)
    await autoUpdater.setScheduledCheckInterval(4 * 60 * 60);
    _initialized = true;
  }

  @override
  Future<UpdateStatus> checkForUpdate() async {
    if (!Platform.isMacOS && !Platform.isWindows) {
      return const UpToDate();
    }

    try {
      await _ensureInitialized();
      await autoUpdater.checkForUpdates(inBackground: true);
      // Sparkle handles the entire UI flow natively. We return UpToDate here
      // because Sparkle manages its own dialogs and download progress.
      // The native framework will show update UI if an update is available.
      return const UpToDate();
    } catch (e) {
      return UpdateError(message: e.toString());
    }
  }

  /// Trigger a user-initiated (foreground) update check.
  /// Shows Sparkle's native "checking for updates" dialog.
  Future<void> checkForUpdatesInteractively() async {
    if (!Platform.isMacOS && !Platform.isWindows) return;

    await _ensureInitialized();
    await autoUpdater.checkForUpdates(inBackground: false);
  }
}
