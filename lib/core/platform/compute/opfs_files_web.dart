import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:submersion/core/platform/compute/opfs_files.dart';

/// [OpfsFiles] over the origin private file system's synchronous access
/// handles, which only a worker may open. Every file lives in the
/// `submersion-sync-tmp` directory.
///
/// A sync access handle locks its file, so files are written through one
/// handle kept open from [create] to [close], and read through a handle
/// opened and closed around each call.
class WebOpfsFiles implements OpfsFiles {
  WebOpfsFiles({web.StorageManager? storage}) : _storage = storage;

  final web.StorageManager? _storage;
  web.FileSystemDirectoryHandle? _directory;
  final Map<int, _OpenFile> _open = {};
  int _nextHandle = 1;

  Future<web.FileSystemDirectoryHandle> _dir() async {
    final existing = _directory;
    if (existing != null) return existing;
    final storage =
        _storage ?? (globalContext as web.WorkerGlobalScope).navigator.storage;
    final root = await storage.getDirectory().toDart;
    return _directory = await root
        .getDirectoryHandle(
          OpfsFiles.directory,
          web.FileSystemGetDirectoryOptions(create: true),
        )
        .toDart;
  }

  Future<web.FileSystemSyncAccessHandle> _access(
    String name, {
    required bool create,
  }) async {
    final file = await (await _dir())
        .getFileHandle(name, web.FileSystemGetFileOptions(create: create))
        .toDart;
    return file.createSyncAccessHandle().toDart;
  }

  @override
  Future<int> create(String name) async {
    final access = await _access(name, create: true);
    access.truncate(0);
    final handle = _nextHandle++;
    _open[handle] = _OpenFile(name, access);
    return handle;
  }

  @override
  Future<void> append(int handle, Uint8List bytes) async {
    final open = _openFile(handle);
    open.access.write(
      bytes.toJS,
      web.FileSystemReadWriteOptions(at: open.size),
    );
    open.size += bytes.length;
  }

  @override
  Future<void> writeAt(int handle, int offset, Uint8List bytes) async {
    final open = _openFile(handle);
    RangeError.checkValueInInterval(offset + bytes.length, 0, open.size, 'end');
    open.access.write(bytes.toJS, web.FileSystemReadWriteOptions(at: offset));
  }

  @override
  Future<String> close(int handle) async {
    final open = _openFile(handle);
    _open.remove(handle);
    open.access.flush();
    open.access.close();
    return OpfsFiles.pathOf(open.name);
  }

  @override
  Future<int> length(String path) async {
    final access = await _access(OpfsFiles.nameOf(path), create: false);
    try {
      return access.getSize();
    } finally {
      access.close();
    }
  }

  /// Whether [name] is in the directory, locked or not: a plain file handle
  /// needs no access lock, so a file another tab is writing still counts.
  Future<bool> _present(String name) async {
    try {
      await (await _dir())
          .getFileHandle(name, web.FileSystemGetFileOptions(create: false))
          .toDart;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> exists(String path) => _present(OpfsFiles.nameOf(path));

  @override
  Future<Uint8List> read(String path, int offset, int length) async {
    final access = await _access(OpfsFiles.nameOf(path), create: false);
    try {
      final buffer = Uint8List(length);
      final read = access.read(
        buffer.toJS,
        web.FileSystemReadWriteOptions(at: offset),
      );
      return read == length ? buffer : Uint8List.sublistView(buffer, 0, read);
    } finally {
      access.close();
    }
  }

  @override
  Future<void> delete(String path) async {
    try {
      await (await _dir()).removeEntry(OpfsFiles.nameOf(path)).toDart;
    } catch (e) {
      // A missing file is not an error. A locked one (an open access
      // handle, here or in another tab) rejects and stays, which the
      // caller must hear about.
      if (!await _present(OpfsFiles.nameOf(path))) return;
      rethrow;
    }
  }

  /// `FileSystemDirectoryHandle.keys()` is an async iterator that
  /// package:web does not bind, so it is driven by hand.
  @override
  Future<List<String>> list() async {
    final keys = (await _dir()).callMethod<JSObject>('keys'.toJS);
    final names = <String>[];
    while (true) {
      final step = await keys
          .callMethod<JSPromise<JSObject>>('next'.toJS)
          .toDart;
      if (step.getProperty<JSBoolean>('done'.toJS).toDart) break;
      names.add(step.getProperty<JSString>('value'.toJS).toDart);
    }
    return names..sort();
  }

  _OpenFile _openFile(int handle) =>
      _open[handle] ?? (throw StateError('no open file for handle $handle'));
}

class _OpenFile {
  _OpenFile(this.name, this.access);

  final String name;
  final web.FileSystemSyncAccessHandle access;
  int size = 0;
}
