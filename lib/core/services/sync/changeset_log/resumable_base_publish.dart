import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A full base export that has been written to disk but not yet fully uploaded.
///
/// A backend wipe forces the whole library to be republished as a fresh base --
/// 80 parts and roughly 640 MB for the reporter of issue #1032. On a phone that
/// is minutes of upload, and if the app is closed partway through, the publish
/// restarted from part 0 on the next attempt. Combined with a progress bar that
/// looked frozen, the user kept killing it, and sync could never finish.
///
/// This record is the sidecar that makes the next attempt continue instead. It
/// deliberately stores only what cannot be recovered otherwise:
///
///   * WHICH parts already landed is NOT stored. Part filenames encode the
///     device id, base seq and part index, so the answer is a listing away and
///     the cloud is authoritative. Local bookkeeping could only disagree with
///     it.
///   * Checksums are NOT stored. They are recomputed from the bytes actually on
///     disk during the resumed pass, so a truncated or tampered file can never
///     be certified by a checksum that was recorded when it was still intact.
class ResumableBasePublish {
  const ResumableBasePublish({
    required this.providerId,
    required this.deviceId,
    required this.seq,
    required this.dataPath,
    required this.byteLength,
    required this.createdAt,
    this.epochId,
    this.uploadNonce,
    this.toHlc,
  });

  final String providerId;
  final String deviceId;

  /// The base sequence number the parts are named with. A resumed publish MUST
  /// keep it: changing it would orphan every part already uploaded.
  final int seq;

  final String dataPath;

  /// Size of the export when it was written. A mismatch against the file on
  /// disk means a truncated or partially-purged file, which is discarded rather
  /// than resumed.
  final int byteLength;

  final int createdAt;

  /// The library epoch baked into the exported bytes. A resume is only valid
  /// while the epoch still matches: under a new epoch these bytes would publish
  /// a base every peer ignores.
  final String? epochId;

  /// Reused rather than regenerated. The nonce is written into the exported
  /// bytes, so it cannot be restamped at manifest time without desyncing the
  /// manifest from the base it describes. It was recorded before the first
  /// attempt, so twin detection still recognises it as ours.
  final String? uploadNonce;

  /// The watermark this base publishes, from the export. Rows written after the
  /// export are not lost by resuming: they carry higher HLCs than this
  /// watermark and go out as the next changeset.
  final String? toHlc;

  String get sidecarPath => sidecarPathFor(dataPath);

  static const String sidecarSuffix = '.publish';

  static String sidecarPathFor(String dataPath) => '$dataPath$sidecarSuffix';

  /// The export a sidecar at [sidecarPath] describes, derived from the name
  /// alone. Recovers the data file when the sidecar's CONTENTS cannot be read,
  /// which is the only way a corrupt record's export gets reclaimed -- and it
  /// can be hundreds of megabytes sitting in a directory nothing else purges.
  static String dataPathForSidecar(String sidecarPath) =>
      sidecarPath.endsWith(sidecarSuffix)
      ? sidecarPath.substring(0, sidecarPath.length - sidecarSuffix.length)
      : sidecarPath;

  Map<String, dynamic> toJson() => {
    'providerId': providerId,
    'deviceId': deviceId,
    'seq': seq,
    'dataPath': dataPath,
    'byteLength': byteLength,
    'createdAt': createdAt,
    'epochId': epochId,
    'uploadNonce': uploadNonce,
    'toHlc': toHlc,
  };

  static ResumableBasePublish fromJson(Map<String, dynamic> json) =>
      ResumableBasePublish(
        providerId: json['providerId'] as String,
        deviceId: json['deviceId'] as String,
        seq: json['seq'] as int,
        dataPath: json['dataPath'] as String,
        byteLength: json['byteLength'] as int,
        createdAt: json['createdAt'] as int,
        epochId: json['epochId'] as String?,
        uploadNonce: json['uploadNonce'] as String?,
        toHlc: json['toHlc'] as String?,
      );
}

/// Persists [ResumableBasePublish] records as sidecar files beside the base
/// exports they describe.
///
/// Sidecars rather than a database table: the record is only meaningful while
/// its data file exists, and keeping the two together means they cannot drift
/// apart or outlive one another. It also keeps this off the schema ladder
/// entirely, so recovering an interrupted publish needs no migration.
class ResumableBasePublishStore {
  ResumableBasePublishStore({Future<Directory> Function()? directory})
    : _directory = directory ?? resolveBasePublishDir;

  final Future<Directory> Function() _directory;

  /// How recently an unreferenced export must have been touched to be spared
  /// as "probably still being written" rather than swept as an orphan.
  static const Duration _orphanGrace = Duration(minutes: 5);

  Future<Directory> get directory => _directory();

  /// Record [publish], overwriting any previous record for its data file.
  Future<void> save(ResumableBasePublish publish) async {
    await File(
      publish.sidecarPath,
    ).writeAsString(jsonEncode(publish.toJson()), flush: true);
  }

  /// The resumable publish for [providerId]/[deviceId] under [epochId], or null
  /// when there is nothing safe to resume.
  ///
  /// Anything unusable is deleted on the way past, so a doomed export cannot
  /// accumulate: a sidecar whose data file is gone or the wrong size (the OS
  /// purged or truncated it), one stamped with a different epoch, one whose
  /// record will not parse, and -- via [_pruneUnreferencedExports] -- an export
  /// with no sidecar at all.
  Future<ResumableBasePublish?> find({
    required String providerId,
    required String deviceId,
    String? epochId,
  }) async {
    final dir = await directory;
    if (!await dir.exists()) return null;

    /// Data files a surviving sidecar still points at. Everything else in this
    /// directory is unreachable and gets swept below.
    final referenced = <String>{};
    ResumableBasePublish? best;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File ||
          !entity.path.endsWith(ResumableBasePublish.sidecarSuffix)) {
        continue;
      }
      ResumableBasePublish record;
      try {
        record = ResumableBasePublish.fromJson(
          jsonDecode(await entity.readAsString()) as Map<String, dynamic>,
        );
      } catch (_) {
        // Drop the export too, not just the record. The path is derivable from
        // the sidecar's NAME, so an unreadable record is no reason to strand
        // its bytes here forever (PR #1033 review).
        await _discardSidecarAndData(entity.path);
        continue;
      }

      referenced.add(record.dataPath);
      if (record.providerId != providerId || record.deviceId != deviceId) {
        continue;
      }
      if (record.epochId != epochId) {
        await discard(record);
        continue;
      }
      final data = File(record.dataPath);
      if (!await data.exists() || await data.length() != record.byteLength) {
        await discard(record);
        continue;
      }
      // Keep the newest: an earlier interrupted attempt under the same epoch is
      // superseded by a later one and its parts are dead weight.
      if (best == null || record.createdAt > best.createdAt) {
        if (best != null) await discard(best);
        best = record;
      } else {
        await discard(record);
      }
    }
    if (best != null) referenced.add(best.dataPath);
    await _pruneUnreferencedExports(dir, referenced);
    return best;
  }

  /// Delete exports in [dir] that no sidecar points at.
  ///
  /// `_recordResumable` moves the export into place and only then writes its
  /// sidecar, so an app killed inside that window leaves a data file nothing
  /// references. Because [find] scans sidecars, such a file would never be
  /// discovered again -- a whole library's worth of bytes stranded forever in a
  /// directory nothing else purges (PR #1033 review).
  ///
  /// Skips anything touched within [_orphanGrace]. The only writer here is
  /// `_recordResumable`, and publishes are serialized, so a file younger than
  /// that is far more likely to be one being written right now than an orphan.
  /// A true orphan is simply reclaimed by the next sync instead.
  static Future<void> _pruneUnreferencedExports(
    Directory dir,
    Set<String> referenced,
  ) async {
    final cutoff = DateTime.now().subtract(_orphanGrace);
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (path.endsWith(ResumableBasePublish.sidecarSuffix)) continue;
      if (referenced.contains(path)) continue;
      // A sidecar may exist but have been skipped above (another provider's
      // record, say), so check the filesystem rather than only `referenced`.
      if (await File(ResumableBasePublish.sidecarPathFor(path)).exists()) {
        continue;
      }
      try {
        if ((await entity.stat()).modified.isAfter(cutoff)) continue;
      } catch (_) {
        continue;
      }
      await _deleteQuietly(path);
    }
  }

  /// Delete a record and the export it describes.
  Future<void> discard(ResumableBasePublish publish) async {
    await _deleteQuietly(publish.sidecarPath);
    await _deleteQuietly(publish.dataPath);
  }

  /// Drop every record for [providerId], used when sync state is reset.
  Future<void> clearForProvider(String providerId) async {
    final dir = await directory;
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File ||
          !entity.path.endsWith(ResumableBasePublish.sidecarSuffix)) {
        continue;
      }
      try {
        final record = ResumableBasePublish.fromJson(
          jsonDecode(await entity.readAsString()) as Map<String, dynamic>,
        );
        if (record.providerId == providerId) await discard(record);
      } catch (_) {
        await _discardSidecarAndData(entity.path);
      }
    }
  }

  /// Delete a sidecar and the export its name points at.
  ///
  /// Used when the sidecar cannot be parsed, so [discard] (which needs a
  /// decoded record) is not available.
  static Future<void> _discardSidecarAndData(String sidecarPath) async {
    await _deleteQuietly(sidecarPath);
    await _deleteQuietly(ResumableBasePublish.dataPathForSidecar(sidecarPath));
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }
}

/// Directory holding in-flight base exports.
///
/// Application support, NOT the temp/cache directory the rest of the streaming
/// sync uses. iOS and Android both purge caches under pressure and macOS maps
/// the temp dir to `Library/Caches`, so an export parked there could vanish
/// between attempts -- which is precisely the failure this exists to end. The
/// tradeoff is that nothing reclaims these files automatically, so every exit
/// path from a publish must discard its record.
Future<Directory> resolveBasePublishDir() async {
  Directory base;
  try {
    base = await getApplicationSupportDirectory();
  } on MissingPluginException {
    base = Directory.systemTemp;
  } on FlutterError catch (e) {
    // Only the "no test binding" case, mirroring resolveSyncTempDir. Any other
    // FlutterError is a real problem and must surface.
    if (!e.toString().contains('Binding has not yet been initialized')) rethrow;
    base = Directory.systemTemp;
  }
  final dir = Directory(p.join(base.path, 'sync_base_publish'));
  await dir.create(recursive: true);
  return dir;
}

/// Where an export at [sourcePath] is moved to inside the publish directory.
///
/// Takes the name with [p.Context.basename] rather than splitting on
/// [Platform.pathSeparator]. Sync assembles its paths by interpolating a
/// literal `/`, so on Windows an export path mixes separators
/// (`C:\Users\...\Local\Temp/ssv1_base_x.json`) and a backslash split kept the
/// `Temp/` in front of the name. That moved the export into a subdirectory of
/// the publish directory which nothing ever creates, so every base publish on
/// Windows failed with `PathNotFoundException` (#1304). `basename` treats both
/// separators as separators under the Windows style, so either shape resolves.
///
/// [context] exists so the Windows style can be pinned in tests running on a
/// POSIX host; production always wants the platform's own.
String basePublishTargetPath(
  String publishDirPath,
  String sourcePath, {
  p.Context? context,
}) {
  final ctx = context ?? p.context;
  return ctx.join(publishDirPath, ctx.basename(sourcePath));
}
