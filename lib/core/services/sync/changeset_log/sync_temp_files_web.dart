import 'dart:typed_data';

import 'package:submersion/core/platform/compute/compute_protocol.dart';
import 'package:submersion/core/platform/compute/compute_worker_client.dart';
import 'package:submersion/core/platform/compute/opfs_files.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_temp_sink.dart';

/// Browser implementation of the sync temp files: files in the origin
/// private file system, written and read by the compute worker, since only
/// a worker may open the synchronous access handles every browser supports.
/// Paths are `opfs://submersion-sync-tmp/<name>`.
abstract final class SyncTempFiles {
  static ComputeWorkerClient get _worker => ComputeWorkerClient.instance;

  static Future<String> pathFor(String name, {String? directoryPath}) async =>
      OpfsFiles.pathOf(name);

  /// [directoryPath] is the native sink's injected directory and is ignored
  /// here: the browser has one directory.
  static Future<SyncTempSink> create(
    String name, {
    String? directoryPath,
  }) async {
    final handle = await _worker.call(ComputeJob.opfsCreate, {'name': name});
    return _OpfsSink((handle as num).toInt(), OpfsFiles.pathOf(name));
  }

  /// The file from [start] to [end] in chunks of [chunkBytes].
  static Stream<List<int>> openRead(
    String path, [
    int? start,
    int? end,
  ]) async* {
    final total = await length(path);
    var offset = start ?? 0;
    final stop = end == null || end > total ? total : end;
    while (offset < stop) {
      final want = stop - offset < chunkBytes ? stop - offset : chunkBytes;
      final chunk = await read(path, offset, want);
      if (chunk.isEmpty) break;
      offset += chunk.length;
      yield chunk;
    }
  }

  /// Bytes per worker round trip when streaming a file back.
  static const int chunkBytes = 1 << 20;

  static Future<Uint8List> read(String path, int offset, int length) async =>
      await _worker.call(ComputeJob.opfsRead, {
            'path': path,
            'offset': offset,
            'length': length,
          })
          as Uint8List;

  static Future<int> length(String path) async =>
      ((await _worker.call(ComputeJob.opfsLength, {'path': path})) as num)
          .toInt();

  static Future<bool> exists(String path) async =>
      (await _worker.call(ComputeJob.opfsExists, {'path': path})) as bool;

  static Future<void> delete(String path) =>
      _worker.call(ComputeJob.opfsDelete, {'path': path});

  /// Removes every file in the browser's sync temp directory and returns
  /// how many went. A file still open for writing, in this tab or another,
  /// is locked by its handle and stays.
  static Future<int> sweepAll() async =>
      ((await _worker.call(ComputeJob.opfsSweep, const {})) as num).toInt();
}

class _OpfsSink implements SyncTempSink {
  _OpfsSink(this._handle, this.path);

  final int _handle;
  @override
  final String path;
  int _length = 0;

  @override
  int get length => _length;

  @override
  Future<void> add(List<int> bytes) async {
    await ComputeWorkerClient.instance.call(ComputeJob.opfsAppend, {
      'handle': _handle,
      'bytes': bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
    });
    _length += bytes.length;
  }

  @override
  Future<void> writeAt(int offset, List<int> bytes) async {
    RangeError.checkValueInInterval(offset + bytes.length, 0, _length, 'end');
    await ComputeWorkerClient.instance.call(ComputeJob.opfsWriteAt, {
      'handle': _handle,
      'offset': offset,
      'bytes': bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
    });
  }

  @override
  Future<String> close() async {
    await ComputeWorkerClient.instance.call(ComputeJob.opfsClose, {
      'handle': _handle,
    });
    return path;
  }
}
