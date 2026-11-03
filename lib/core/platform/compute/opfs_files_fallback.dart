import 'dart:typed_data';

import 'package:submersion/core/platform/compute/memory_opfs_files.dart';
import 'package:submersion/core/platform/compute/opfs_files.dart';

export 'package:submersion/core/platform/compute/memory_opfs_files.dart';

/// [OpfsFiles] that falls back to memory where the browser refuses the origin
/// private file system, as a Safari private window can (issue #4121).
///
/// Sync's temp files only live for one transfer, so memory loses nothing but
/// headroom for a very large library; without it the first sync would fail
/// on a browser the database itself copes with. Asked once, on first use.
class FallbackOpfsFiles implements OpfsFiles {
  FallbackOpfsFiles(this._primary);

  final OpfsFiles _primary;
  Future<OpfsFiles>? _chosen;

  Future<OpfsFiles> get _files => _chosen ??= _choose();

  Future<OpfsFiles> _choose() async {
    try {
      await _primary.list();
      return _primary;
    } catch (_) {
      return MemoryOpfsFiles();
    }
  }

  @override
  Future<int> create(String name) async => (await _files).create(name);

  @override
  Future<void> append(int handle, Uint8List bytes) async =>
      (await _files).append(handle, bytes);

  @override
  Future<void> writeAt(int handle, int offset, Uint8List bytes) async =>
      (await _files).writeAt(handle, offset, bytes);

  @override
  Future<String> close(int handle) async => (await _files).close(handle);

  @override
  Future<int> length(String path) async => (await _files).length(path);

  @override
  Future<bool> exists(String path) async => (await _files).exists(path);

  @override
  Future<Uint8List> read(String path, int offset, int length) async =>
      (await _files).read(path, offset, length);

  @override
  Future<void> delete(String path) async => (await _files).delete(path);

  @override
  Future<List<String>> list() async => (await _files).list();
}
