import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/sync/changeset_log/sync_temp_dir.dart';
import 'package:submersion/features/universal_import/data/services/garmin_mtp_source.dart';

/// What [GarminMtpStager.stage] copied.
class GarminMtpStaging {
  const GarminMtpStaging({
    required this.dirPath,
    required this.copiedCount,
    required this.failedCount,
  });

  /// The new folder holding the copied FIT files. The caller owns it and
  /// deletes it once the import no longer needs the files.
  final String dirPath;
  final int copiedCount;

  /// Files the watch failed to hand over; skipped, like an unreadable FIT
  /// on a mounted drive.
  final int failedCount;
}

/// Copies a Garmin watch's activity FITs from [GarminMtpSource] into a fresh
/// temporary folder, so the folder import reads them as it reads a watch
/// mounted as a drive (issue #4223).
class GarminMtpStager {
  GarminMtpStager({
    required GarminMtpSource source,
    Future<Directory> Function()? tempRoot,
  }) : _source = source,
       _tempRoot = tempRoot ?? resolveSyncTempDir;

  final GarminMtpSource _source;

  /// Where the staging folder is created: the app-container temp folder,
  /// as for ZIP expansion. Injectable so tests use their own.
  final Future<Directory> Function() _tempRoot;

  /// Copies every `.fit` file under the watch's GARMIN/Activity folder, in
  /// name order, calling [onProgress] with (handled, total) before the
  /// first file and after each one.
  ///
  /// Throws what the source throws for the listing, having removed the
  /// folder. A single file that fails to read is skipped and counted.
  Future<GarminMtpStaging> stage(
    String deviceId, {
    void Function(int handled, int total)? onProgress,
  }) async {
    final root = await _tempRoot();
    final dir = await root.createTemp('submersion_garmin_');
    try {
      final listed = await _source.listActivityFiles(deviceId);
      final files = [
        for (final file in listed)
          if (_isFit(file.name)) file,
      ]..sort((a, b) => a.name.compareTo(b.name));

      onProgress?.call(0, files.length);
      final used = <String>{};
      var copied = 0;
      var failed = 0;
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        try {
          final bytes = await _source.readFile(deviceId, file.objectId);
          final name = _uniqueName(_safeName(file.name), used);
          await File(p.join(dir.path, name)).writeAsBytes(bytes, flush: true);
          copied++;
        } catch (_) {
          failed++;
        }
        onProgress?.call(i + 1, files.length);
      }
      return GarminMtpStaging(
        dirPath: dir.path,
        copiedCount: copied,
        failedCount: failed,
      );
    } catch (_) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {
        // Best effort; the OS reclaims its temp folder anyway.
      }
      rethrow;
    }
  }

  static bool _isFit(String name) => name.toLowerCase().endsWith('.fit');

  /// The last path segment of a name the device reported, split on either
  /// separator whatever the host, so a name can never leave the folder.
  static String _safeName(String name) {
    final segment = name.split(RegExp(r'[\\/]')).last.trim();
    if (segment.isEmpty || segment == '.' || segment == '..') {
      return 'activity.fit';
    }
    return segment;
  }

  /// Two storages can each hold a file of the same name; keep both.
  static String _uniqueName(String name, Set<String> used) {
    var candidate = name;
    var n = 2;
    while (!used.add(candidate.toLowerCase())) {
      candidate = '${p.basenameWithoutExtension(name)}_$n${p.extension(name)}';
      n++;
    }
    return candidate;
  }
}
