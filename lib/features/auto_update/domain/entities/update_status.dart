/// Represents the current state of the auto-update lifecycle.
sealed class UpdateStatus {
  const UpdateStatus();
}

/// The application is running the latest available version.
class UpToDate extends UpdateStatus {
  const UpToDate();
}

/// A check for updates is currently in progress.
class Checking extends UpdateStatus {
  const Checking();
}

/// A newer version is available for download.
class UpdateAvailable extends UpdateStatus {
  final String version;
  final String? releaseNotes;
  final String downloadUrl;

  const UpdateAvailable({
    required this.version,
    this.releaseNotes,
    required this.downloadUrl,
  });
}

/// An update is being downloaded.
class Downloading extends UpdateStatus {
  /// Download progress from 0.0 to 1.0.
  final double progress;

  const Downloading({required this.progress});
}

/// An update has been downloaded and is ready to install.
class ReadyToInstall extends UpdateStatus {
  final String version;
  final String localPath;

  const ReadyToInstall({required this.version, required this.localPath});
}

/// An error occurred during the update process.
class UpdateError extends UpdateStatus {
  final String message;

  const UpdateError({required this.message});
}
