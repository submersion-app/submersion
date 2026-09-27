import 'dart:io';

import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/security_scoped_bookmark_service.dart';

/// Whether the dive log a location points at is on this device.
enum DiveLogAvailability {
  /// Open it, or create it when the location has never held one.
  ready,

  /// iCloud holds the dive log, but its contents are not on this device.
  inICloudOnly,

  /// The folder held a dive log once and holds nothing now.
  missing,
}

/// Reads a file's iCloud state. Null means unknown.
typedef ICloudStatusReader = Future<ICloudItemStatus?> Function(String path);

/// Asks iCloud for a file's contents and reports whether they arrived.
typedef ICloudDownloader =
    Future<bool> Function(String path, {required Duration timeout});

/// Tells a dive log that is not on this device apart from a folder that has
/// never held one (issue #2177).
///
/// Opening the database cannot tell them apart: a missing file is simply
/// created, so an evicted iCloud file or an unplugged drive used to become a
/// new, empty dive log with no warning. Startup asks this first, before
/// anything could create one.
///
/// Only custom locations are checked. The default location lives in the
/// app's own container, which iCloud does not evict and no drive can be
/// unplugged from, so a missing file there really is a first launch.
class DiveLogAvailabilityService {
  DiveLogAvailabilityService(
    this._location, {
    ICloudStatusReader? readICloudStatus,
    ICloudDownloader? downloadFromICloud,
  }) : _readICloudStatus =
           readICloudStatus ??
           SecurityScopedBookmarkService.iCloudDownloadStatus,
       _downloadFromICloud =
           downloadFromICloud ??
           SecurityScopedBookmarkService.downloadICloudItem;

  final DatabaseLocationService _location;
  final ICloudStatusReader _readICloudStatus;
  final ICloudDownloader _downloadFromICloud;

  /// How long startup waits for iCloud before explaining instead. Long
  /// enough for a large dive log on an ordinary connection; "Try again"
  /// waits again, and iCloud keeps downloading in between.
  static const downloadTimeout = Duration(seconds: 60);

  /// Where the configured dive log stands. Never downloads anything.
  Future<DiveLogAvailability> check() async {
    final config = await _location.getStorageConfig();
    if (!config.isCustomLocation || config.customFolderPath == null) {
      return DiveLogAvailability.ready;
    }

    final dbPath = await _location.getDatabasePath();
    if (await FileSystemEntity.type(dbPath) != FileSystemEntityType.notFound) {
      // macOS Sonoma and later evict in place: the file keeps its name and
      // only iCloud can say whether its contents are here.
      final iCloud = await _readICloudStatus(dbPath);
      return iCloud == ICloudItemStatus.notDownloaded
          ? DiveLogAvailability.inICloudOnly
          : DiveLogAvailability.ready;
    }

    // The placeholder proves a dive log exists, whatever else is known.
    if (await File(iCloudPlaceholderPath(dbPath)).exists()) {
      return DiveLogAvailability.inICloudOnly;
    }

    // Every flow that saves a custom location puts a verified dive log there
    // first and stamps it, so a stamped location with nothing in it has lost
    // one. An unstamped one has never held one: its first launch creates the
    // dive log (#218).
    return config.lastVerified == null
        ? DiveLogAvailability.ready
        : DiveLogAvailability.missing;
  }

  /// Asks iCloud for the configured dive log. True once its contents are on
  /// this device, false if they did not arrive within [downloadTimeout].
  Future<bool> downloadFromICloud() async {
    final dbPath = await _location.getDatabasePath();
    return _downloadFromICloud(dbPath, timeout: downloadTimeout);
  }
}
