import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_temp_dir.dart';

/// Downloads a base's parts one at a time into a single temp file, verifying
/// integrity as bytes land so the whole base is never held in memory. Each part
/// is checked against its manifest checksum before being written; a rolling
/// SHA-256 verifies the whole-file checksum at the end. Any failure deletes the
/// partial file and returns null (transient -> the caller retries next sync).
class BasePartFileSink {
  BasePartFileSink({Future<Directory> Function()? tempDirProvider})
    : _tempDir = tempDirProvider ?? resolveSyncTempDir;

  final Future<Directory> Function() _tempDir;
  static const _uuid = Uuid();

  Future<String?> assemble({
    required String name,
    required int partCount,
    required String? wholeChecksum,
    required List<String> partChecksums,
    required Future<Uint8List?> Function(int index) downloadPart,
  }) async {
    final dir = await _tempDir();
    final path = basePartTempPath(dir.path, name, _uuid.v4());
    final file = File(path);
    final out = file.openWrite();

    // Rolling whole-file SHA-256 so we never hold the full base to checksum it.
    final digestSink = _DigestSink();
    final wholeInput = sha256.startChunkedConversion(digestSink);

    var ok = true;
    try {
      for (var i = 0; i < partCount; i++) {
        final part = await downloadPart(i);
        if (part == null) {
          ok = false;
          break;
        }
        if (i < partChecksums.length &&
            BaseChunker.checksum(part) != partChecksums[i]) {
          ok = false;
          break;
        }
        wholeInput.add(part);
        out.add(part);
      }
    } catch (_) {
      ok = false;
    }

    await out.close();
    wholeInput.close();

    if (ok && wholeChecksum != null) {
      final computed = 'sha256:${digestSink.value}';
      if (computed != wholeChecksum) ok = false;
    }

    if (!ok) {
      await deleteQuietly(path);
      return null;
    }
    return path;
  }

  Future<void> deleteQuietly(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Best effort: a leftover temp file is harmless; the OS reaps systemTemp.
    }
  }
}

/// Path a downloaded base is assembled into: `<temp dir>/<name>.<uuid>.base`.
///
/// Joins rather than interpolating a literal `/`. [dirPath] comes from
/// `resolveSyncTempDir`, which on Windows is backslashed, so interpolation
/// produced a mixed-separator path
/// (`C:\Users\...\AppData\Local\Temp/ssv1_base_devA_7.<uuid>.base`). Win32
/// accepts that for open and delete, which is all the two callers of
/// [BasePartFileSink.assemble] do with it, so nothing was broken -- but it is
/// character-for-character the shape that killed every Windows base publish in
/// #1304, where a `split(Platform.pathSeparator)` split on `\` only and left
/// the `Temp/` segment glued to the front of the "filename". Adding a basename,
/// a split or a manifest key downstream would have been enough to reproduce it,
/// so #1327 removes the shape rather than the one consumer.
///
/// [context] exists so the Windows style can be pinned in tests running on a
/// POSIX host, where `Platform.pathSeparator` is `/` and the mixed form is
/// indistinguishable from a correct one; production always wants the platform's
/// own.
String basePartTempPath(
  String dirPath,
  String name,
  String id, {
  p.Context? context,
}) => (context ?? p.context).join(dirPath, '$name.$id.base');

/// Minimal `Sink<Digest>` that captures the single digest emitted at close.
/// Avoids depending on `package:convert`'s `AccumulatorSink` (not exported by
/// `crypto`).
class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
