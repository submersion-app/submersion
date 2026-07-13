import 'dart:io';

/// Classifies whether the VOLUME a path lives on is currently mounted, so
/// "file on an unmounted network share" can be told apart from "file
/// deleted" (program spec section 8).
///
/// Mount-root heuristics per platform:
/// - macOS: `/Volumes/<name>/...` (external and network mounts); anything
///   else is the always-mounted system volume.
/// - Windows: `X:\...` drive roots and `\\server\share\...` UNC roots.
/// - Linux: `/mnt/<name>`, `/media/<name>` (legacy single-segment mounts),
///   `/media/<user>/<name>`, `/run/media/<user>/<name>`.
///
/// The existence probe is injectable so tests never touch the real
/// filesystem. Only the volume ROOT is probed - a missing file on a
/// mounted volume stays "deleted".
class VolumeStatus {
  VolumeStatus({Future<bool> Function(String path)? directoryExists})
    : _directoryExists =
          directoryExists ?? ((path) => Directory(path).exists());

  /// Async so an offline network mount cannot block the UI isolate while
  /// the probe waits on the filesystem.
  final Future<bool> Function(String path) _directoryExists;

  /// The mount root governing [path], or null when the path lives on the
  /// system volume (always considered mounted).
  String? volumeRootOf(String path, {String? platformOverride}) {
    final platform =
        platformOverride ??
        (Platform.isMacOS
            ? 'macos'
            : Platform.isWindows
            ? 'windows'
            : Platform.isLinux
            ? 'linux'
            : 'other');
    switch (platform) {
      case 'macos':
        final match = RegExp(r'^(/Volumes/[^/]+)(/|$)').firstMatch(path);
        return match?.group(1);
      case 'windows':
        final unc = RegExp(r'^(\\\\[^\\]+\\[^\\]+)(\\|$)').firstMatch(path);
        if (unc != null) return unc.group(1);
        final drive = RegExp(r'^([A-Za-z]:)(\\|/|$)').firstMatch(path);
        // The system drive C: is always mounted; other drive letters can
        // be network mappings or removable media.
        if (drive != null && drive.group(1)!.toUpperCase() != 'C:') {
          return '${drive.group(1)}\\';
        }
        return null;
      case 'linux':
        // Candidate roots, most specific first. A root must be a PROPER
        // prefix of the path (followed by '/'): otherwise the optional
        // second segment would swallow the file name itself (e.g.
        // /media/usb/a.jpg must resolve to /media/usb, not the file).
        for (final pattern in [
          r'^(/run/media/[^/]+/[^/]+)/',
          r'^(/media/[^/]+/[^/]+)/',
          r'^(/media/[^/]+)/',
          r'^(/mnt/[^/]+)/',
        ]) {
          final match = RegExp(pattern).firstMatch(path);
          if (match != null) return match.group(1);
        }
        return null;
      default:
        return null;
    }
  }

  /// True when [path]'s volume is currently reachable. Paths on the system
  /// volume are always online; paths under a mount root are online iff the
  /// root directory exists. Async: the existence probe is a filesystem
  /// call that can hang on an unreachable share.
  Future<bool> isVolumeOnline(String path, {String? platformOverride}) async {
    final root = volumeRootOf(path, platformOverride: platformOverride);
    if (root == null) return true;
    return _directoryExists(root);
  }
}
