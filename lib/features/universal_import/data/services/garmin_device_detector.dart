import 'dart:io';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:path/path.dart' as p;

/// A Garmin dive computer mounted as a USB mass-storage volume.
///
/// Garmin watches (Descent, etc.) do not use a libdivecomputer download
/// protocol -- when connected by cable they appear as a plain drive whose
/// activities live as FIT files under `GARMIN/Activity`.
class GarminDevice {
  const GarminDevice({
    required this.volumeName,
    required this.volumeRootPath,
    required this.activityDirPath,
    required this.fitFileCount,
  });

  /// Display name of the mounted volume (e.g. "GARMIN").
  final String volumeName;

  /// Absolute path of the mounted volume root (e.g. `/Volumes/GARMIN`).
  final String volumeRootPath;

  /// Absolute path of the `GARMIN/Activity` directory holding the FIT files.
  final String activityDirPath;

  /// Number of `.fit` files found directly under [activityDirPath].
  final int fitFileCount;
}

/// Detects Garmin dive computers attached as USB mass-storage volumes.
///
/// This is desktop-only: mobile platforms cannot mount a watch as a drive.
/// Detection is purely filesystem-based (no vendor API, credentials, or
/// network) -- it looks for the `GARMIN/Activity` folder that every Garmin
/// device exposes, regardless of the volume's name.
class GarminDeviceDetector {
  /// [volumeRoots] overrides the platform mount-point scan; used by tests to
  /// point detection at a temporary directory tree.
  const GarminDeviceDetector({List<Directory> Function()? volumeRoots})
    : _volumeRootsOverride = volumeRoots;

  final List<Directory> Function()? _volumeRootsOverride;

  /// Whether the current platform can mount a Garmin device as a drive.
  static bool get isSupportedPlatform {
    if (kIsWeb) return false;
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
  }

  /// Scan mounted volumes and return every one that looks like a Garmin
  /// device (i.e. contains a non-empty `GARMIN/Activity` folder).
  Future<List<GarminDevice>> detect() async {
    final roots = _volumeRootsOverride != null
        ? _volumeRootsOverride()
        : _defaultVolumeRoots();

    final devices = <GarminDevice>[];
    for (final root in roots) {
      try {
        final activityDir = Directory(p.join(root.path, 'GARMIN', 'Activity'));
        if (!await activityDir.exists()) continue;
        final fitCount = await _countFitFiles(activityDir);
        if (fitCount == 0) continue;
        devices.add(
          GarminDevice(
            volumeName: p.basename(root.path).isEmpty
                ? root.path
                : p.basename(root.path),
            volumeRootPath: root.path,
            activityDirPath: activityDir.path,
            fitFileCount: fitCount,
          ),
        );
      } catch (_) {
        // A volume can be unmounted mid-scan or be unreadable; skip it.
      }
    }
    return devices;
  }

  /// All `.fit` file paths directly under [activityDirPath], sorted for a
  /// stable order. Callers filter dives from non-dive activities.
  Future<List<String>> listFitFiles(String activityDirPath) async {
    final paths = <String>[];
    final dir = Directory(activityDirPath);
    if (!await dir.exists()) return paths;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && _isFit(entity.path)) paths.add(entity.path);
    }
    paths.sort();
    return paths;
  }

  Future<int> _countFitFiles(Directory dir) async {
    var count = 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && _isFit(entity.path)) count++;
    }
    return count;
  }

  static bool _isFit(String path) => p.extension(path).toLowerCase() == '.fit';

  /// Candidate mounted-volume roots per platform.
  List<Directory> _defaultVolumeRoots() {
    if (Platform.isMacOS) {
      return _childDirs('/Volumes');
    }
    if (Platform.isLinux) {
      final user =
          Platform.environment['USER'] ?? Platform.environment['LOGNAME'];
      final roots = <Directory>[];
      if (user != null && user.isNotEmpty) {
        roots
          ..addAll(_childDirs('/media/$user'))
          ..addAll(_childDirs('/run/media/$user'));
      }
      roots.addAll(_childDirs('/media'));
      return roots;
    }
    if (Platform.isWindows) {
      // Removable drives get a letter; skip C: (the system volume).
      return [
        for (var c = 'D'.codeUnitAt(0); c <= 'Z'.codeUnitAt(0); c++)
          Directory('${String.fromCharCode(c)}:\\'),
      ];
    }
    return const [];
  }

  static List<Directory> _childDirs(String path) {
    try {
      final dir = Directory(path);
      if (!dir.existsSync()) return const [];
      return dir.listSync(followLinks: false).whereType<Directory>().toList();
    } catch (_) {
      return const [];
    }
  }
}
