import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:submersion/core/services/sync/changeset_log/base_parse_worker.dart';

/// Thrown when the base-parse worker reports a parse/checksum error or dies.
class BaseParseException implements Exception {
  BaseParseException(this.message);
  final String message;
  @override
  String toString() => 'BaseParseException: $message';
}

/// Main-isolate client for the base-file parse worker. Spawns a worker that
/// reads + parses a serialized sync base document off the UI isolate and streams
/// decoded rows back, pull-backpressured (one ≤500-row batch per [nextDataBatch]).
/// Operations are sequential — one in flight at a time.
class BaseParseClient {
  BaseParseClient._(this._isolate, this._toWorker, this._fromWorker, this._sub);

  final Isolate _isolate;
  final SendPort _toWorker;
  final ReceivePort _fromWorker;
  final StreamSubscription<dynamic> _sub;

  // Buffered request/response mailbox: messages that arrive before a reader is
  // waiting are queued, so a batch sent before the first [nextDataBatch] pull is
  // never lost.
  final List<Map<dynamic, dynamic>> _queue = [];
  final List<Completer<Map<dynamic, dynamic>>> _waiters = [];
  bool _dataFirstBatch = true;
  bool _dataEnded = false;

  /// Spawns the worker for [filePath] and completes once its handshake arrives.
  ///
  /// Degrades to a thrown [BaseParseException] -- so the caller falls back to
  /// the inline parse rather than hanging -- on any spawn/handshake failure:
  /// the worker throwing before its 'ready' message, the isolate dying, or no
  /// handshake within [handshakeTimeout]. The port, subscription, and isolate
  /// it created are torn down before the error propagates.
  ///
  /// [entryPoint] and [handshakeTimeout] are injectable for tests only.
  static Future<BaseParseClient> spawn(
    String filePath, {
    @visibleForTesting
    void Function(List<Object>) entryPoint = baseParseWorkerMain,
    @visibleForTesting Duration handshakeTimeout = const Duration(seconds: 10),
  }) async {
    final fromWorker = ReceivePort();
    final ready = Completer<SendPort>();
    // The client can't be built until the handshake lands, but worker messages
    // (an early error, or -- defensively -- a stray response) can arrive first.
    // Hold them until the client exists instead of touching a not-yet-built one
    // (which would throw a LateInitializationError inside the listener).
    BaseParseClient? client;
    final preInit = <Map<dynamic, dynamic>>[];
    void route(Map<dynamic, dynamic> m) {
      if (client != null) {
        client._deliver(m);
      } else {
        preInit.add(m);
      }
    }

    final sub = fromWorker.listen((msg) {
      if (msg is Map && msg['type'] == 'ready') {
        if (!ready.isCompleted) ready.complete(msg['port'] as SendPort);
      } else if (msg is Map) {
        route(msg);
      } else if (msg is List) {
        // An uncaught worker error arrives via `onError` as
        // [errorString, stackTraceString]. Before the handshake, fail the spawn
        // so the caller falls back; after it, deliver it as a normal error
        // response so the in-flight pull rejects.
        final message = msg.isNotEmpty ? msg.first.toString() : 'worker error';
        if (!ready.isCompleted) {
          ready.completeError(BaseParseException(message));
        } else {
          route(<String, Object>{'type': 'error', 'message': message});
        }
      }
    });

    // Backstop for a worker that dies without an `onError` (e.g. an OS OOM
    // kill): without it a missing handshake would hang `ready.future` forever.
    final timeout = Timer(handshakeTimeout, () {
      if (!ready.isCompleted) {
        ready.completeError(BaseParseException('worker handshake timed out'));
      }
    });

    Isolate? isolate;
    try {
      isolate = await Isolate.spawn(
        entryPoint,
        <Object>[fromWorker.sendPort, filePath],
        onError: fromWorker.sendPort,
        errorsAreFatal: false,
      );
      final toWorker = await ready.future;
      client = BaseParseClient._(isolate, toWorker, fromWorker, sub);
    } catch (_) {
      // Spawn failed, the worker errored before handshake, or it timed out:
      // tear down so we never leak the port/subscription/isolate, then rethrow
      // so the caller degrades to the inline parse.
      await sub.cancel();
      fromWorker.close();
      isolate?.kill(priority: Isolate.immediate);
      rethrow;
    } finally {
      timeout.cancel();
    }

    // Flush anything that raced in between the handshake and assignment.
    final spawned = client;
    for (final m in preInit) {
      spawned._deliver(m);
    }
    return spawned;
  }

  void _deliver(Map<dynamic, dynamic> m) {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete(m);
    } else {
      _queue.add(m);
    }
  }

  /// Per-message backstop: after the handshake, a worker can still die or hang
  /// without delivering an `onError` (e.g. an OS OOM kill), which would leave a
  /// waiting pull blocked forever and hang the whole sync. Time out and surface
  /// a [BaseParseException] so the caller (readScalarsAndDeletions /
  /// nextDataBatch) falls back to the inline parser. Injectable for tests.
  @visibleForTesting
  static Duration messageTimeout = const Duration(seconds: 60);

  Future<Map<dynamic, dynamic>> _nextMessage() {
    if (_queue.isNotEmpty) return Future.value(_queue.removeAt(0));
    final c = Completer<Map<dynamic, dynamic>>();
    _waiters.add(c);
    return c.future.timeout(
      messageTimeout,
      onTimeout: () {
        _waiters.remove(c);
        throw BaseParseException('worker message timed out');
      },
    );
  }

  List<({String table, Map<String, dynamic> row})> _decodeRows(Object? raw) {
    return (raw as List)
        .map(
          (e) => (
            table: (e as Map)['table'] as String,
            row: (e['row'] as Map).cast<String, dynamic>(),
          ),
        )
        .toList();
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
    _toWorker.send(<String, Object>{'cmd': 'deletions'});
    final m = await _nextMessage();
    if (m['type'] == 'error') {
      throw BaseParseException(m['message'] as String);
    }
    return (
      exportedAt: m['exportedAt'] as int,
      deletions: _decodeRows(m['rows']),
    );
  }

  /// Begins streaming `data`-section rows whose table is in [tables]. Pull the
  /// batches with [nextDataBatch] until it returns null. Strict backpressure:
  /// the worker parses one ≤500-row batch per pull.
  void startDataRows(Set<String> tables) {
    _dataFirstBatch = true;
    _dataEnded = false;
    _toWorker.send(<String, Object>{
      'cmd': 'dataRows',
      'tables': tables.toList(),
    });
  }

  /// The next ≤500-row batch of `(table, row)` pairs, or null when exhausted.
  Future<List<({String table, Map<String, dynamic> row})>?>
  nextDataBatch() async {
    if (_dataEnded) return null;
    if (!_dataFirstBatch) _toWorker.send(<String, Object>{'cmd': 'next'});
    _dataFirstBatch = false;
    final m = await _nextMessage();
    if (m['type'] == 'error') {
      throw BaseParseException(m['message'] as String);
    }
    if (m['done'] == true) _dataEnded = true;
    return _decodeRows(m['rows']);
  }

  Future<void> dispose() async {
    _toWorker.send(<String, Object>{'cmd': 'dispose'});
    await _sub.cancel();
    _fromWorker.close();
    for (final w in _waiters) {
      if (!w.isCompleted) {
        w.completeError(BaseParseException('client disposed'));
      }
    }
    _waiters.clear();
    _queue.clear();
    _isolate.kill(priority: Isolate.immediate);
  }
}
