import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/sync/changeset_log/base_part_hasher.dart';
import 'package:submersion/core/services/sync/changeset_log/base_part_hasher_logged.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_temp_dir.dart';
import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';

/// [BasePartFileSink.assemble] stopped for a reason that says nothing about the
/// base in the cloud: a download failed or the checksum worker died.
///
/// Distinct from its null result on purpose. Pull is additive, so it can treat
/// both as "retry next sync". Adopt and the retirement fence are delete-all
/// refills, and they read "nothing assembled" as "no readable library": the
/// fence then drops the device's retirement marker and republishes from local.
/// A dropped connection must not be able to say that.
///
/// A refused download is not one of these: no later sync gets past it, so it
/// leaves [BasePartFileSink.assemble] as itself for the sync to offer a sign-in.
class BaseFetchInterrupted implements Exception {
  BaseFetchInterrupted(this.cause);

  final Object cause;

  @override
  String toString() => 'BaseFetchInterrupted: $cause';
}

/// Downloads a base's parts one at a time into a single temp file, verifying
/// integrity as bytes land so the whole base is never held in memory. Each part
/// is checked against its manifest checksum before being written; a rolling
/// SHA-256 verifies the whole-file checksum at the end. The hashing runs on a
/// worker isolate for a large base, so it does not stall the isolate that
/// called sync (issue #3829).
class BasePartFileSink {
  BasePartFileSink({
    Future<Directory> Function()? tempDirProvider,
    BasePartHasherOpener openHasher = openLoggedBasePartHasher,
  }) : _tempDir = tempDirProvider ?? resolveSyncTempDir,
       _openHasher = openHasher;

  final Future<Directory> Function() _tempDir;
  final BasePartHasherOpener _openHasher;
  static const _uuid = Uuid();

  /// Returns the assembled file's path.
  ///
  /// Returns null, with the partial file deleted, when the cloud's copy cannot
  /// be used: a part is missing, a checksum does not match, an envelope is
  /// corrupt, or it needs a key this device lacks. Throws
  /// [BaseFetchInterrupted], also with the partial file deleted, for any other
  /// failure but a refused download, which it throws as itself. See that class
  /// for why these must stay apart.
  Future<String?> assemble({
    required String name,
    required int partCount,
    required String? wholeChecksum,
    required List<String> partChecksums,
    required Future<Uint8List?> Function(int index) downloadPart,
    void Function(int downloaded, int total)? onPartDownloaded,
  }) async {
    final Directory dir;
    try {
      dir = await _tempDir();
    } catch (e, st) {
      Error.throwWithStackTrace(BaseFetchInterrupted(e), st);
    }
    final path = basePartTempPath(dir.path, name, _uuid.v4());
    final file = File(path);
    final out = file.openWrite();

    // Created once the first part lands, as its size picks inline or worker.
    BasePartHasher? hasher;
    Object? interruption;
    StackTrace? interruptionStack;

    var ok = true;
    try {
      for (var i = 0; i < partCount; i++) {
        final part = await downloadPart(i);
        if (part == null) {
          ok = false;
          break;
        }
        final parts = hasher ??= await _openHasher(part.length);
        final digest = await parts.addPart(part);
        if (i < partChecksums.length && digest != partChecksums[i]) {
          ok = false;
          break;
        }
        out.add(part);
        onPartDownloaded?.call(i + 1, partCount);
      }
      if (ok && wholeChecksum != null) {
        final whole = hasher ??= await _openHasher(0);
        if (await whole.finish() != wholeChecksum) ok = false;
      }
    } on EnvelopeCorruptException {
      ok = false;
    } on SyncEncryptionRequired {
      ok = false;
    } catch (e, st) {
      ok = false;
      interruption = e;
      interruptionStack = st;
    }

    try {
      await out.close();
    } catch (e, st) {
      // A failed write surfaces here, as a local fault. The cloud's copy
      // having already failed stays the answer, so this cannot upgrade a null.
      if (ok) {
        interruption = e;
        interruptionStack = st;
      }
      ok = false;
    } finally {
      await hasher?.dispose();
    }

    if (!ok) await deleteQuietly(path);
    if (interruption != null) {
      Error.throwWithStackTrace(
        isAccessRefused(interruption)
            ? interruption
            : BaseFetchInterrupted(interruption),
        interruptionStack!,
      );
    }
    return ok ? path : null;
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
