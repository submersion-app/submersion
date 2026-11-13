import 'dart:io';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:path/path.dart' as p;

import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/core/platform/desktop_target_platform.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/universal_import/data/services/garmin_mtp_source.dart';

/// A Garmin dive computer connected by cable: mounted as a drive
/// ([GarminVolume]) or, for newer watches on Windows, reachable over MTP
/// ([GarminMtpWatch], issue #4223).
///
/// Garmin watches (Descent, etc.) do not use a libdivecomputer download
/// protocol; either way their activities are FIT files under
/// `GARMIN/Activity`.
sealed class GarminDevice {
  const GarminDevice();

  /// What to call the device: the volume name or the watch's own name.
  String get displayName;

  /// The watch's unit ID, the serial number its FIT files carry, when the
  /// device reports one.
  String? get serialNumber;
}

/// A Garmin dive computer mounted as a USB mass-storage volume.
final class GarminVolume extends GarminDevice {
  const GarminVolume({
    required this.volumeName,
    required this.volumeRootPath,
    required this.activityDirPath,
    required this.fitFileCount,
    this.serialNumber,
  });

  /// Display name of the mounted volume (e.g. "GARMIN").
  final String volumeName;

  /// Absolute path of the mounted volume root (e.g. `/Volumes/GARMIN`).
  final String volumeRootPath;

  /// Absolute path of the `GARMIN/Activity` directory holding the FIT files.
  final String activityDirPath;

  /// Number of `.fit` files found directly under [activityDirPath].
  final int fitFileCount;

  /// From `GARMIN/GarminDevice.xml`, which every Garmin writes.
  @override
  final String? serialNumber;

  @override
  String get displayName => volumeName;
}

/// A Garmin watch reachable over MTP, which Windows lists as a device with
/// no drive letter (the Descent G2, Mk3 and others).
///
/// Its files are not counted at detection: listing them over MTP is slow,
/// and detection runs every time the import page opens.
final class GarminMtpWatch extends GarminDevice {
  const GarminMtpWatch({
    required this.deviceId,
    required this.displayName,
    this.serialNumber,
  });

  /// The id [GarminMtpSource] calls take.
  final String deviceId;

  @override
  final String displayName;

  @override
  final String? serialNumber;
}

/// Detects Garmin dive computers attached by cable.
///
/// This is desktop-only: mobile platforms cannot mount a watch as a drive.
/// Volume detection is purely filesystem-based (no vendor API, credentials,
/// or network) -- it looks for the `GARMIN/Activity` folder that every Garmin
/// device exposes, regardless of the volume's name. With an [mtpSource]
/// (Windows), watches that connect over MTP are listed too.
class GarminDeviceDetector {
  /// [volumeRoots] overrides the platform mount-point scan; used by tests to
  /// point detection at a temporary directory tree.
  const GarminDeviceDetector({
    List<Directory> Function()? volumeRoots,
    this.mtpSource,
  }) : _volumeRootsOverride = volumeRoots;

  static const _log = LoggerService('GarminDeviceDetector');

  final List<Directory> Function()? _volumeRootsOverride;

  /// Reads watches that connect over MTP; null where there is none (every
  /// platform but Windows).
  final GarminMtpSource? mtpSource;

  /// Whether the current platform can mount a Garmin device as a drive.
  static bool get isSupportedPlatform {
    if (HostPlatform.isWeb) return false;
    return isDesktopTargetPlatform(defaultTargetPlatform);
  }

  /// Every connected Garmin: mounted volumes that look like one (a
  /// non-empty `GARMIN/Activity` folder) first, then MTP watches.
  Future<List<GarminDevice>> detect() async {
    return [...await _detectVolumes(), ...await _detectMtpWatches()];
  }

  Future<List<GarminMtpWatch>> _detectMtpWatches() async {
    final source = mtpSource;
    if (source == null) return const [];
    try {
      final devices = await source.listDevices();
      return [
        for (final device in devices)
          GarminMtpWatch(
            deviceId: device.id,
            displayName: device.friendlyName,
            serialNumber: unitIdFromMtpSerial(device.serialNumber),
          ),
      ];
    } catch (e) {
      // An MTP failure must not hide a watch mounted as a drive.
      _log.warning('Listing Garmin MTP devices failed: $e');
      return const [];
    }
  }

  /// The unit ID a Garmin's FIT files carry, from the serial Windows
  /// reports for it over MTP: the same number in hex, zero-padded to 12
  /// digits (`0000c7067d17` for 3339091223). Any other form is returned as
  /// it came, trimmed.
  static String? unitIdFromMtpSerial(String? serial) {
    final trimmed = serial?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (!_mtpHexSerial.hasMatch(trimmed)) return trimmed;
    final value = int.parse(trimmed, radix: 16);
    _log.info('Garmin MTP serial $trimmed is unit ID $value');
    return '$value';
  }

  static final _mtpHexSerial = RegExp(r'^[0-9a-fA-F]{12}$');

  Future<List<GarminVolume>> _detectVolumes() async {
    final roots = _volumeRootsOverride != null
        ? _volumeRootsOverride()
        : _defaultVolumeRoots();

    final devices = <GarminVolume>[];
    for (final root in roots) {
      try {
        final activityDir = Directory(p.join(root.path, 'GARMIN', 'Activity'));
        if (!await activityDir.exists()) continue;
        final fitCount = await _countFitFiles(activityDir);
        if (fitCount == 0) continue;
        devices.add(
          GarminVolume(
            volumeName: p.basename(root.path).isEmpty
                ? root.path
                : p.basename(root.path),
            volumeRootPath: root.path,
            activityDirPath: activityDir.path,
            fitFileCount: fitCount,
            serialNumber: await _unitId(root),
          ),
        );
      } catch (_) {
        // A volume can be unmounted mid-scan or be unreadable; skip it.
      }
    }
    return devices;
  }

  /// The `<Id>` in `GARMIN/GarminDevice.xml`: the unit ID, which the FIT
  /// files carry as their serial number. Null when the file is missing or
  /// has none.
  Future<String?> _unitId(Directory root) async {
    try {
      final file = File(p.join(root.path, 'GARMIN', 'GarminDevice.xml'));
      if (!await file.exists()) return null;
      final match = _unitIdPattern.firstMatch(await file.readAsString());
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  static final _unitIdPattern = RegExp(r'<Id>\s*(\d+)\s*</Id>');

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
    if (HostPlatform.isMacOS) {
      return _childDirs('/Volumes');
    }
    if (HostPlatform.isLinux) {
      final user =
          HostPlatform.environment['USER'] ??
          HostPlatform.environment['LOGNAME'];
      final roots = <Directory>[];
      if (user != null && user.isNotEmpty) {
        roots
          ..addAll(_childDirs('/media/$user'))
          ..addAll(_childDirs('/run/media/$user'));
      }
      roots.addAll(_childDirs('/media'));
      return roots;
    }
    if (HostPlatform.isWindows) {
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
