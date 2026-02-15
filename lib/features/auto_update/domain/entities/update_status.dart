import 'package:equatable/equatable.dart';

/// Represents the current state of the auto-update lifecycle.
sealed class UpdateStatus extends Equatable {
  const UpdateStatus();
}

/// The application is running the latest available version.
class UpToDate extends UpdateStatus {
  const UpToDate();

  @override
  List<Object?> get props => [];
}

/// A check for updates is currently in progress.
class Checking extends UpdateStatus {
  const Checking();

  @override
  List<Object?> get props => [];
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

  UpdateAvailable copyWith({
    String? version,
    String? releaseNotes,
    String? downloadUrl,
  }) {
    return UpdateAvailable(
      version: version ?? this.version,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      downloadUrl: downloadUrl ?? this.downloadUrl,
    );
  }

  @override
  List<Object?> get props => [version, releaseNotes, downloadUrl];
}

/// An update is being downloaded.
class Downloading extends UpdateStatus {
  /// Download progress from 0.0 to 1.0.
  final double progress;

  const Downloading({required this.progress})
    : assert(
        progress >= 0.0 && progress <= 1.0,
        'progress must be between 0.0 and 1.0',
      );

  Downloading copyWith({double? progress}) {
    return Downloading(progress: progress ?? this.progress);
  }

  @override
  List<Object?> get props => [progress];
}

/// An update has been downloaded and is ready to install.
class ReadyToInstall extends UpdateStatus {
  final String version;
  final String localPath;

  const ReadyToInstall({required this.version, required this.localPath});

  ReadyToInstall copyWith({String? version, String? localPath}) {
    return ReadyToInstall(
      version: version ?? this.version,
      localPath: localPath ?? this.localPath,
    );
  }

  @override
  List<Object?> get props => [version, localPath];
}

/// An error occurred during the update process.
class UpdateError extends UpdateStatus {
  final String message;

  const UpdateError({required this.message});

  UpdateError copyWith({String? message}) {
    return UpdateError(message: message ?? this.message);
  }

  @override
  List<Object?> get props => [message];
}
