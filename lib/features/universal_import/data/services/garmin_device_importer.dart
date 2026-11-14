import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_import/data/services/fit_parser_service.dart';
import 'package:submersion/features/universal_import/data/models/garmin_import_progress.dart';
import 'package:submersion/features/universal_import/data/services/garmin_activity_marker.dart';
import 'package:submersion/features/universal_import/data/services/garmin_device_detector.dart';
import 'package:submersion/features/universal_import/data/services/garmin_download_history.dart';
import 'package:submersion/features/universal_import/data/services/garmin_mtp_stager.dart';

/// Which Garmin download to run.
class GarminImportRequest {
  const GarminImportRequest({this.computerId, this.readAll = false});

  /// The saved computer the diver chose Download on, when there is one; its
  /// marker is used. Otherwise the watch's serial finds it.
  final String? computerId;

  /// Read every activity, ignoring the marker ("Re-import all dives").
  final bool readAll;
}

/// The marker to save once the diver finishes importing [paths].
class GarminPendingMarker {
  const GarminPendingMarker({
    required this.marker,
    required this.paths,
    this.computerId,
    this.watchSerial,
  });

  final GarminActivityMarker marker;

  /// The dive files the import was offered. The marker is saved only for an
  /// import of these, not for files the diver picked by hand afterwards.
  final Set<String> paths;

  final String? computerId;
  final String? watchSerial;
}

/// What a Garmin download found.
sealed class GarminImportOutcome {
  const GarminImportOutcome();
}

/// No Garmin is connected.
final class GarminNotConnected extends GarminImportOutcome {
  const GarminNotConnected();
}

/// The watch holds no dives at all.
final class GarminNoDives extends GarminImportOutcome {
  const GarminNoDives();
}

/// Nothing after the marker is a dive: the diver has already seen them all.
/// The marker has been moved past any new non-dive activities.
final class GarminNothingNew extends GarminImportOutcome {
  const GarminNothingNew();
}

/// Dives to import.
final class GarminDivesFound extends GarminImportOutcome {
  const GarminDivesFound(this.divePaths, {this.pendingMarker});

  final List<String> divePaths;

  /// Saved once the import of [divePaths] completes; null when the files
  /// cannot be placed by name or date.
  final GarminPendingMarker? pendingMarker;
}

/// Some activity files could not be read, and none of the others is a dive,
/// so there is nothing to offer and no telling what was missed.
class GarminFilesUnreadable implements Exception {
  const GarminFilesUnreadable(this.count);

  /// How many files failed to read.
  final int count;

  @override
  String toString() => count == 1
      ? '1 activity file could not be read'
      : '$count activity files could not be read';
}

/// Reads the dives off a connected Garmin (issue #4223): mounted as a
/// drive, or over MTP (Windows), copied into a staging folder first. With
/// several connected it reads the one the diver chose Download on, when its
/// serial says which that is, and otherwise the first.
///
/// Only the activities after the watch's download marker are read, unless
/// the request says to read them all. Non-dive activities are filtered out.
///
/// The marker only ever moves past files that were read. If any file fails
/// to read it stays where it was, so the next download offers that file
/// again instead of hiding the dive in it.
class GarminDeviceImporter {
  GarminDeviceImporter({
    required GarminDeviceDetector detector,
    GarminMtpStager? mtpStager,
    GarminDownloadHistory? history,
    FitParserService fitParser = const FitParserService(),
  }) : _detector = detector,
       _mtpStager = mtpStager,
       _history = history,
       _fitParser = fitParser;

  static const _log = LoggerService('GarminDeviceImporter');

  final GarminDeviceDetector _detector;
  final GarminMtpStager? _mtpStager;
  final GarminDownloadHistory? _history;
  final FitParserService _fitParser;

  /// Runs [request], reporting each stage to [onProgress]. A staging folder
  /// goes to [onTempDir] as soon as it exists, so the caller deletes it
  /// whatever happens next.
  ///
  /// Throws what the device throws (a `PlatformException` over MTP), and
  /// [GarminFilesUnreadable] when files failed to read and no dive was found
  /// among the rest.
  Future<GarminImportOutcome> run(
    GarminImportRequest request, {
    required void Function(GarminImportProgress progress) onProgress,
    required void Function(String dirPath) onTempDir,
  }) async {
    onProgress(const GarminImportProgress(GarminImportPhase.lookingForWatch));
    final devices = await _detector.detect();
    if (devices.isEmpty) return const GarminNotConnected();
    final device = await _deviceFor(request.computerId, devices);
    final serial = device.serialNumber;

    final previous = request.readAll
        ? null
        : await _markerFor(request.computerId, serial);

    final List<String> candidates;
    final GarminActivityMarker? newest;
    final String? name;
    // Files that never came off the watch.
    var unread = 0;
    switch (device) {
      case GarminVolume(:final activityDirPath):
        name = null;
        final all = await _detector.listFitFiles(activityDirPath);
        final activities = await Future.wait(all.map(_activityAt));
        newest = GarminActivityMarker.newest(activities);
        candidates = [
          for (final (index, path) in all.indexed)
            if (previous == null || previous.isBefore(activities[index])) path,
        ];
      case GarminMtpWatch():
        final stager = _mtpStager;
        if (stager == null) return const GarminNotConnected();
        name = _garminName(device.displayName);
        onProgress(
          GarminImportProgress(GarminImportPhase.scanning, deviceName: name),
        );
        final staging = await stager.stage(
          device.deviceId,
          after: previous,
          onProgress: (copied, total) => onProgress(
            GarminImportProgress(
              GarminImportPhase.copying,
              current: copied,
              total: total,
              deviceName: name,
            ),
          ),
        );
        onTempDir(staging.dirPath);
        newest = staging.newest;
        unread = staging.failedCount;
        candidates = await _detector.listFitFiles(staging.dirPath);
    }

    final checked = await _keepDives(candidates, name, onProgress);
    final divePaths = checked.dives;
    unread += checked.unreadable;
    // A file that could not be read has not been handled. Leaving the marker
    // where it was makes the next download offer it again; moving it on would
    // hide the dive in it for good.
    final next = unread > 0 ? null : newest?.laterOf(previous);

    if (divePaths.isEmpty) {
      // Not "no dives": some files were never looked at.
      if (unread > 0) throw GarminFilesUnreadable(unread);
      // Nothing to review, so the new activities are handled already.
      if (next != null) await _save(next, request.computerId, serial);
      return previous != null
          ? const GarminNothingNew()
          : const GarminNoDives();
    }
    return GarminDivesFound(
      divePaths,
      pendingMarker: next == null
          ? null
          : GarminPendingMarker(
              marker: next,
              paths: divePaths.toSet(),
              computerId: request.computerId,
              watchSerial: serial,
            ),
    );
  }

  /// The connected Garmin that is the saved computer [computerId], told by
  /// its serial number, so a second Garmin plugged in at the same time (a
  /// bike computer mounted as a drive, say) is not read in its place. With
  /// no such match the first is used, mounted volumes ahead of MTP watches.
  Future<GarminDevice> _deviceFor(
    String? computerId,
    List<GarminDevice> devices,
  ) async {
    final history = _history;
    if (computerId == null || history == null || devices.length == 1) {
      return devices.first;
    }
    try {
      final wanted = await history.serialOf(computerId);
      if (wanted != null) {
        for (final device in devices) {
          if (device.serialNumber == wanted) return device;
        }
      }
    } catch (e) {
      _log.warning('Reading the saved Garmin serial failed: $e');
    }
    return devices.first;
  }

  Future<GarminActivityMarker?> _markerFor(
    String? computerId,
    String? serial,
  ) async {
    final history = _history;
    if (history == null) return null;
    try {
      return await history.markerFor(
        computerId: computerId,
        serialNumber: serial,
      );
    } catch (e) {
      // Without the marker everything is read, as before it existed.
      _log.warning('Reading the Garmin download marker failed: $e');
      return null;
    }
  }

  Future<void> _save(
    GarminActivityMarker marker,
    String? computerId,
    String? serial,
  ) async {
    try {
      await _history?.save(marker, computerId: computerId, watchSerial: serial);
    } catch (e) {
      _log.warning('Saving the Garmin download marker failed: $e');
    }
  }

  /// The files among [paths] that parse as dives, reporting each one
  /// checked, and how many could not be read at all. A corrupt or non-dive
  /// FIT (which parses to null, or does not parse) was read and is skipped;
  /// a file that fails to read was not, and is counted.
  Future<({List<String> dives, int unreadable})> _keepDives(
    List<String> paths,
    String? deviceName,
    void Function(GarminImportProgress progress) onProgress,
  ) async {
    void report(int checked) => onProgress(
      GarminImportProgress(
        GarminImportPhase.checking,
        current: checked,
        total: paths.length,
        deviceName: deviceName,
      ),
    );

    report(0);
    final dives = <String>[];
    var unreadable = 0;
    for (var i = 0; i < paths.length; i++) {
      final bytes = await _read(paths[i]);
      if (bytes == null) {
        unreadable++;
      } else {
        try {
          if (await _fitParser.parseFitFile(bytes) != null) {
            dives.add(paths[i]);
          }
        } catch (_) {
          // A corrupt FIT: not a dive. Keep scanning the rest.
        }
      }
      report(i + 1);
    }
    return (dives: dives, unreadable: unreadable);
  }

  /// The bytes of the file at [path]; null when it cannot be read, as when a
  /// watch mounted as a drive is unplugged part way through.
  static Future<Uint8List?> _read(String path) async {
    try {
      return await File(path).readAsBytes();
    } catch (e) {
      _log.warning('Could not read ${p.basename(path)}: $e');
      return null;
    }
  }

  static Future<GarminActivityFile> _activityAt(String path) async {
    int? modified;
    try {
      modified = (await File(path).lastModified()).millisecondsSinceEpoch;
    } catch (_) {
      // Placed by name alone.
    }
    return GarminActivityFile(name: p.basename(path), modifiedMillis: modified);
  }

  /// [name] as the diver knows the watch: Windows calls it "Descent G2".
  static String _garminName(String name) =>
      name.toLowerCase().startsWith('garmin') ? name : 'Garmin $name';
}
