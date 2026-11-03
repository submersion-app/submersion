import 'dart:typed_data';

/// Temporary sync files as the compute worker sees them: written once in
/// appends, read back in chunks, then deleted.
///
/// In a browser they live in the origin private file system under
/// [directory], the one OPFS write path all three browsers share (synchronous
/// access handles, worker-only). Paths are `opfs://submersion-sync-tmp/<name>`
/// so a caller can tell them from native file paths at a glance. A browser
/// that refuses that file system, and the tests, use `MemoryOpfsFiles`.
abstract interface class OpfsFiles {
  /// The OPFS directory that holds every temporary sync file.
  static const String directory = 'submersion-sync-tmp';

  static const String _prefix = 'opfs://$directory/';

  /// The path a file called [name] has.
  static String pathOf(String name) => '$_prefix$name';

  /// The file name inside [directory] that [path] names.
  static String nameOf(String path) {
    if (!path.startsWith(_prefix) || path.length == _prefix.length) {
      throw ArgumentError.value(path, 'path', 'not a sync temp file path');
    }
    return path.substring(_prefix.length);
  }

  /// Creates (or truncates) [name] for writing and returns a handle.
  Future<int> create(String name);

  /// Appends [bytes] to the open file behind [handle].
  Future<void> append(int handle, Uint8List bytes);

  /// Overwrites [bytes] at [offset] in the open file behind [handle]; the
  /// range must lie within what was appended.
  Future<void> writeAt(int handle, int offset, Uint8List bytes);

  /// Closes the open file behind [handle] and returns its path.
  Future<String> close(int handle);

  /// The length of the file at [path].
  Future<int> length(String path);

  /// Whether a closed file exists at [path].
  Future<bool> exists(String path);

  /// Up to [length] bytes of the file at [path] from [offset]; shorter at
  /// the end of the file.
  Future<Uint8List> read(String path, int offset, int length);

  /// Removes the file at [path]; a missing file is not an error. One that
  /// is still open through a handle, in this worker or another tab's, is:
  /// the call throws and the file stays.
  Future<void> delete(String path);

  /// The names of every file in [directory], open or closed, sorted.
  Future<List<String>> list();
}

/// The [OpfsFiles] of a context that has no temporary sync files: the
/// native isolate path and the browser's inline path, where only the
/// stateless jobs run. Every call throws.
class UnavailableOpfsFiles implements OpfsFiles {
  const UnavailableOpfsFiles();

  Never _unavailable() =>
      throw UnsupportedError('temporary sync files are worker only');

  @override
  Future<int> create(String name) async => _unavailable();

  @override
  Future<void> append(int handle, Uint8List bytes) async => _unavailable();

  @override
  Future<void> writeAt(int handle, int offset, Uint8List bytes) async =>
      _unavailable();

  @override
  Future<String> close(int handle) async => _unavailable();

  @override
  Future<int> length(String path) async => _unavailable();

  @override
  Future<bool> exists(String path) async => _unavailable();

  @override
  Future<Uint8List> read(String path, int offset, int length) async =>
      _unavailable();

  @override
  Future<void> delete(String path) async => _unavailable();

  @override
  Future<List<String>> list() async => _unavailable();
}
