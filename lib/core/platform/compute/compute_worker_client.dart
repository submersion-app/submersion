import 'dart:async';
import 'dart:js_interop';

import 'package:meta/meta.dart';
import 'package:web/web.dart' as web;

import 'package:submersion/core/platform/compute/compute_protocol.dart';

/// The compute worker could not be started, or died.
///
/// Callers with an inline path fall back to it, as the native code falls
/// back when an isolate cannot start.
class ComputeWorkerUnavailable implements Exception {
  const ComputeWorkerUnavailable(this.message);

  final String message;

  @override
  String toString() => 'ComputeWorkerUnavailable: $message';
}

/// The page's end of the compute worker: one `compute_worker.js` per page,
/// started on first use, with every call matched to its reply by id.
///
/// Requests are cloned by `postMessage`, never transferred, so a caller can
/// keep using the bytes it passed in. A progress reply invokes the call's
/// [onProgress] and completes nothing.
class ComputeWorkerClient {
  ComputeWorkerClient._();

  static final ComputeWorkerClient instance = ComputeWorkerClient._();

  /// The script's name next to `main.dart.js`.
  static const String scriptName = 'compute_worker.js';

  /// Where the script is served from, relative to the page. The browser
  /// tests point it at the served test assets.
  @visibleForTesting
  static String assetBase = '';

  web.Worker? _worker;
  Object? _failure;
  int _nextId = 1;
  final Map<int, _PendingCall> _pending = {};

  /// Runs [job] in the worker and returns its result, or throws the
  /// exception the worker reported, rebuilt as the type the caller expects.
  Future<Object?> call(
    ComputeJob job,
    Map<String, Object?> args, {
    void Function(int bytes, int total)? onProgress,
  }) {
    final worker = _ensureWorker();
    final id = _nextId++;
    final pending = _PendingCall(args, onProgress);
    _pending[id] = pending;
    worker.postMessage(
      ComputeRequest(id: id, job: job, args: args).toJson().jsify(),
    );
    return pending.completer.future;
  }

  web.Worker _ensureWorker() {
    final failure = _failure;
    if (failure != null) throw ComputeWorkerUnavailable('$failure');
    final existing = _worker;
    if (existing != null) return existing;
    final web.Worker worker;
    try {
      worker = web.Worker('$assetBase$scriptName'.toJS);
    } catch (e) {
      _failure = e;
      throw ComputeWorkerUnavailable('$e');
    }
    worker.onmessage = ((web.MessageEvent event) {
      _onMessage(event.data.dartify());
    }).toJS;
    worker.onerror = ((web.Event event) {
      _fail(
        event.isA<web.ErrorEvent>()
            ? (event as web.ErrorEvent).message
            : 'worker error',
      );
    }).toJS;
    return _worker = worker;
  }

  void _onMessage(Object? data) {
    if (data is! Map) return;
    final reply = ComputeReply.fromJson(data.cast<Object?, Object?>());
    final pending = _pending[reply.id];
    if (pending == null) return;
    if (reply.isProgress) {
      pending.onProgress?.call(reply.progressBytes!, reply.progressTotal!);
      return;
    }
    _pending.remove(reply.id);
    final error = reply.error;
    if (error != null) {
      pending.completer.completeError(
        computeErrorFromWire(
          reply.errorKind ?? ComputeErrorKind.other,
          error,
          pending.args,
        ),
      );
    } else {
      pending.completer.complete(reply.result);
    }
  }

  void _fail(Object error) {
    _failure = error;
    final failed = ComputeWorkerUnavailable('$error');
    for (final pending in _pending.values) {
      pending.completer.completeError(failed);
    }
    _pending.clear();
    _worker?.terminate();
    _worker = null;
  }
}

class _PendingCall {
  _PendingCall(this.args, this.onProgress);

  final Map<String, Object?> args;
  final void Function(int bytes, int total)? onProgress;
  final Completer<Object?> completer = Completer<Object?>();
}
