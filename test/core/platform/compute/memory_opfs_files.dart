import 'dart:typed_data';

import 'package:submersion/core/platform/compute/opfs_files.dart';

/// An [OpfsFiles] held in memory, for VM tests of the compute job handlers
/// and of the web sync temp files.
class MemoryOpfsFiles implements OpfsFiles {
  final Map<String, BytesBuilder> _open = {};
  final Map<String, Uint8List> _files = {};
  int _nextHandle = 1;
  final Map<int, String> _handleNames = {};

  /// The names of every stored file.
  Iterable<String> get names => _files.keys;

  @override
  Future<int> create(String name) async {
    final handle = _nextHandle++;
    _handleNames[handle] = name;
    _open[name] = BytesBuilder(copy: true);
    _files.remove(name);
    return handle;
  }

  @override
  Future<void> append(int handle, Uint8List bytes) async {
    _open[_nameOf(handle)]!.add(bytes);
  }

  @override
  Future<void> writeAt(int handle, int offset, Uint8List bytes) async {
    final builder = _open[_nameOf(handle)]!;
    final current = builder.takeBytes();
    RangeError.checkValueInInterval(
      offset + bytes.length,
      0,
      current.length,
      'end',
    );
    current.setRange(offset, offset + bytes.length, bytes);
    builder.add(current);
  }

  @override
  Future<String> close(int handle) async {
    final name = _nameOf(handle);
    _files[name] = _open.remove(name)!.takeBytes();
    _handleNames.remove(handle);
    return OpfsFiles.pathOf(name);
  }

  @override
  Future<int> length(String path) async => _stored(path).length;

  @override
  Future<bool> exists(String path) async =>
      _files.containsKey(OpfsFiles.nameOf(path));

  @override
  Future<Uint8List> read(String path, int offset, int length) async {
    final bytes = _stored(path);
    final end = (offset + length).clamp(0, bytes.length);
    return Uint8List.sublistView(bytes, offset.clamp(0, bytes.length), end);
  }

  @override
  Future<void> delete(String path) async {
    final name = OpfsFiles.nameOf(path);
    // An open sync access handle locks its file, as OPFS does.
    if (_open.containsKey(name)) throw StateError('$name is still open');
    _files.remove(name);
  }

  @override
  Future<List<String>> list() async => [..._files.keys, ..._open.keys]..sort();

  String _nameOf(int handle) {
    final name = _handleNames[handle];
    if (name == null) throw StateError('no open file for handle $handle');
    return name;
  }

  Uint8List _stored(String path) {
    final bytes = _files[OpfsFiles.nameOf(path)];
    if (bytes == null) throw StateError('no file at $path');
    return bytes;
  }
}
