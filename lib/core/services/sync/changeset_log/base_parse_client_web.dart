import 'dart:async';

import 'package:submersion/core/platform/compute/compute_protocol.dart';
import 'package:submersion/core/platform/compute/compute_worker_client.dart';
import 'package:submersion/core/services/sync/changeset_log/base_parse_exception.dart';

/// Browser implementation of the base parse client: the two passes run in
/// the compute worker over a file in the origin private file system, one
/// reply per pull. There is no inline fallback on the web: a base too large
/// to parse in the worker is too large for the page, so a worker that cannot
/// start surfaces as [BaseParseException] and the sync reports it.
class BaseParseClient {
  BaseParseClient._(this._path, this.onProgress);

  final String _path;

  /// Receives byte progress from the worker during a pass.
  void Function(int bytes, int total)? onProgress;

  Future<int>? _session;
  bool _dataEnded = false;
  bool _disposed = false;

  /// How long a pull may wait for the worker. Kept for the shared surface;
  /// the browser worker answers or the page is gone.
  static Duration messageTimeout = const Duration(seconds: 60);

  /// Confirms the worker can reach [filePath] and returns a client for it.
  /// Throws [BaseParseException] when the compute worker cannot start.
  static Future<BaseParseClient> spawn(
    String filePath, {
    void Function(int bytes, int total)? onProgress,
    bool gzipped = false,
  }) async {
    // Only a nearby full copy is compressed, and a browser never takes one.
    if (gzipped) throw BaseParseException('no gzipped base in a browser');
    try {
      final exists = await ComputeWorkerClient.instance.call(
        ComputeJob.opfsExists,
        {'path': filePath},
      );
      if (exists != true) {
        throw BaseParseException('no base file at $filePath');
      }
    } on ComputeWorkerUnavailable catch (e) {
      throw BaseParseException('compute worker unavailable: ${e.message}');
    }
    return BaseParseClient._(filePath, onProgress);
  }

  /// Pass 1: the `exportedAt` scalar plus every `deletions`-section row, in
  /// file order (`(table, row)` pairs).
  Future<
    ({
      int exportedAt,
      List<({String table, Map<String, dynamic> row})> deletions,
    })
  >
  readScalarsAndDeletions() async {
    _checkOpen();
    final reply =
        await _call(ComputeJob.baseParseScalars, {'path': _path}) as Map;
    return (
      exportedAt: (reply['exportedAt'] as num).toInt(),
      deletions: _decodeRows(reply['rows']),
    );
  }

  /// Begins streaming `data`-section rows whose table is in [tables]. Pull
  /// the batches with [nextDataBatch] until it returns null.
  void startDataRows(Set<String> tables) {
    _checkOpen();
    _dataEnded = false;
    final previous = _session;
    _session = () async {
      if (previous != null) await _disposeSession(previous);
      final id = await _call(ComputeJob.baseParseStart, {
        'path': _path,
        'tables': tables.toList(),
      });
      return (id as num).toInt();
    }();
  }

  /// The next batch of `(table, row)` pairs, or null when exhausted.
  Future<List<({String table, Map<String, dynamic> row})>?>
  nextDataBatch() async {
    _checkOpen();
    if (_dataEnded) return null;
    final session = _session;
    if (session == null) {
      throw StateError('startDataRows must be called before nextDataBatch');
    }
    final reply =
        await _call(ComputeJob.baseParseNext, {'session': await session})
            as Map;
    if (reply['done'] == true) _dataEnded = true;
    return _decodeRows(reply['rows']);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final session = _session;
    _session = null;
    if (session != null) await _disposeSession(session);
  }

  Future<void> _disposeSession(Future<int> session) async {
    try {
      await ComputeWorkerClient.instance.call(ComputeJob.baseParseDispose, {
        'session': await session,
      });
    } catch (_) {
      // A session that died with its worker has nothing to release.
    }
  }

  Future<Object?> _call(ComputeJob job, Map<String, Object?> args) async {
    try {
      return await ComputeWorkerClient.instance.call(
        job,
        args,
        onProgress: (bytes, total) => onProgress?.call(bytes, total),
      );
    } on BaseParseException {
      rethrow;
    } catch (e) {
      throw BaseParseException(e.toString());
    }
  }

  void _checkOpen() {
    if (_disposed) throw BaseParseException('client disposed');
  }

  static List<({String table, Map<String, dynamic> row})> _decodeRows(
    Object? rows,
  ) => [
    for (final entry in (rows as List).cast<Map>())
      (
        table: entry['table'] as String,
        row: Map<String, dynamic>.from(entry['row'] as Map),
      ),
  ];
}
