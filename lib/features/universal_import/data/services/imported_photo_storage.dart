import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';

/// Persists imported photos into a per-dive directory under a media root.
///
/// Filename pattern: `<position>-<original-filename>`. Example:
/// `<mediaRoot>/dive/<diveId>/2-shark.jpg`.
///
/// On basename collision (same diveId receives two photos with the same
/// original filename and position), appends `-1`, `-2`, … before the
/// extension. No files are overwritten.
///
/// The [diveId] is the newly-created dive's internal ID — not the
/// source UUID. Callers resolve source-UUID → new-dive-ID after the
/// dive writer runs.
class ImportedPhotoStorage {
  /// Absolute path to the media root (e.g.
  /// `<AppSupport>/media`). Subdirectories are created on demand.
  final String mediaRoot;

  const ImportedPhotoStorage({required this.mediaRoot});

  /// Writes [bytes] to the per-dive directory, returning the resulting
  /// [File]. Parent directory is created if needed.
  Future<File> store({
    required String diveId,
    required ImportImageRef ref,
    required Uint8List bytes,
  }) async {
    final dir = Directory('$mediaRoot/dive/$diveId');
    await dir.create(recursive: true);
    final desired = '${ref.position}-${ref.filename}';
    final target = await _uniqueName(dir, desired);
    await target.writeAsBytes(bytes, flush: true);
    return target;
  }

  /// Returns a File under [dir] whose name either equals [desired] (if
  /// no file with that name exists) or `<stem>-<N><ext>` for the
  /// smallest N ≥ 1 producing an unused name.
  Future<File> _uniqueName(Directory dir, String desired) async {
    var candidate = File('${dir.path}/$desired');
    if (!await candidate.exists()) return candidate;

    final dot = desired.lastIndexOf('.');
    final hasExt = dot > 0 && dot < desired.length - 1;
    final stem = hasExt ? desired.substring(0, dot) : desired;
    final ext = hasExt ? desired.substring(dot) : '';

    var n = 1;
    while (true) {
      candidate = File('${dir.path}/$stem-$n$ext');
      if (!await candidate.exists()) return candidate;
      n++;
    }
  }
}
