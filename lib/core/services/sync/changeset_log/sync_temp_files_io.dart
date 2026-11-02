import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/sync/changeset_log/sync_temp_dir.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_temp_sink.dart';

/// Native implementation of the sync temp files: plain files in the
/// directory `resolveSyncTempDir` resolves, read and written with `dart:io`.
abstract final class SyncTempFiles {
  /// Resolves the sync temp directory, created if absent. Injectable for
  /// tests that must not touch the shared directory.
  static Future<Directory> Function() directory = resolveSyncTempDir;

  /// The path [name] has inside [directoryPath], or inside [directory].
  static Future<String> pathFor(String name, {String? directoryPath}) async =>
      p.join(directoryPath ?? (await directory()).path, name);

  /// Creates [name] for writing, truncating any earlier file of that name.
  /// [directoryPath] is the native sink's injected directory; the browser
  /// has one directory and ignores it.
  static Future<SyncTempSink> create(
    String name, {
    String? directoryPath,
  }) async {
    final path = await pathFor(name, directoryPath: directoryPath);
    final file = await File(path).open(mode: FileMode.write);
    return _FileSink(path, file);
  }

  static Stream<List<int>> openRead(String path, [int? start, int? end]) =>
      File(path).openRead(start, end);

  /// Up to [length] bytes from [offset]; shorter at the end of the file.
  static Future<Uint8List> read(String path, int offset, int length) async {
    final file = await File(path).open();
    try {
      await file.setPosition(offset);
      return await file.read(length);
    } finally {
      await file.close();
    }
  }

  static Future<int> length(String path) => File(path).length();

  static Future<bool> exists(String path) => File(path).exists();

  /// Removes [path]; a missing file is not an error.
  static Future<void> delete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Best effort: a leftover temp file is harmless and the sweep reaps it.
    }
  }

  /// The browser's whole-directory sweep. Native temp files share a
  /// general temp directory, which `sweepLeftoverSyncTempFiles` sweeps by
  /// prefix and age instead.
  static Future<int> sweepAll() async =>
      throw UnsupportedError('native sync temp files are swept by prefix');
}

class _FileSink implements SyncTempSink {
  _FileSink(this.path, this._file);

  @override
  final String path;
  final RandomAccessFile _file;
  int _length = 0;

  @override
  int get length => _length;

  @override
  Future<void> add(List<int> bytes) async {
    await _file.setPosition(_length);
    await _file.writeFrom(bytes);
    _length += bytes.length;
  }

  @override
  Future<void> writeAt(int offset, List<int> bytes) async {
    RangeError.checkValueInInterval(offset + bytes.length, 0, _length, 'end');
    await _file.setPosition(offset);
    await _file.writeFrom(bytes);
  }

  @override
  Future<String> close() async {
    await _file.flush();
    await _file.close();
    return path;
  }
}
