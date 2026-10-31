import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';
import 'package:submersion/core/utils/off_isolate.dart';

/// Hashes one base transfer: the `sha256:<hex>` digest of each part, and a
/// rolling digest of the whole file.
///
/// Both are CPU work on megabytes of bytes, so a large transfer runs them on a
/// worker isolate instead of the isolate that called sync (issue #3829). Calls
/// are sequential: await each one before making the next.
abstract interface class BasePartHasher {
  /// Adds [part] to the whole-file hash and returns its digest. The caller
  /// keeps [part], unchanged, to upload or write.
  Future<String> addPart(Uint8List part);

  /// Completes the whole-file hash and returns its digest.
  Future<String> finish();

  /// Releases the worker, if any. Safe after a failure, and safe to repeat.
  Future<void> dispose();
}

/// A worker that started and then failed. The rolling hash died with it, so
/// the transfer cannot carry on inline: it fails, and the next sync retries.
class BasePartHasherException implements Exception {
  BasePartHasherException(this.message);

  final String message;

  @override
  String toString() => 'BasePartHasherException: $message';
}

typedef BasePartHasherOpener =
    Future<BasePartHasher> Function(int firstPartBytes);

/// Opens the hasher for a transfer whose first part is [firstPartBytes] long.
///
/// The first part is always the largest, so it stands in for the transfer: a
/// small one hashes inline and a large one gets a worker. A worker that cannot
/// start degrades to inline, today's behaviour, and reports the cause through
/// [onWorkerUnavailable]. Nothing here logs, because `LoggerService` would
/// pull Flutter into code that otherwise compiles with `dart compile exe`.
Future<BasePartHasher> openBasePartHasher(
  int firstPartBytes, {
  void Function(Object error)? onWorkerUnavailable,
  @visibleForTesting
  void Function(SendPort) entryPoint = basePartHasherWorkerMain,
  @visibleForTesting Duration handshakeTimeout = const Duration(seconds: 10),
  @visibleForTesting Duration replyTimeout = const Duration(seconds: 60),
}) async {
  if (firstPartBytes < kOffIsolateMinBytes) return _InlineBasePartHasher();
  try {
    return await WorkerBasePartHasher._spawn(
      entryPoint,
      handshakeTimeout: handshakeTimeout,
      replyTimeout: replyTimeout,
    );
  } catch (e) {
    onWorkerUnavailable?.call(e);
    return _InlineBasePartHasher();
  }
}

class _InlineBasePartHasher implements BasePartHasher {
  final _digest = _DigestSink();
  late final _whole = sha256.startChunkedConversion(_digest);

  @override
  Future<String> addPart(Uint8List part) async {
    _whole.add(part);
    return BaseChunker.checksum(part);
  }

  @override
  Future<String> finish() async {
    _whole.close();
    return 'sha256:${_digest.value}';
  }

  @override
  Future<void> dispose() async {}
}

/// Minimal `Sink<Digest>` that captures the single digest emitted at close.
/// Avoids depending on `package:convert`'s `AccumulatorSink` (not exported by
/// `crypto`).
class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

const String _finishMessage = 'finish';

/// Isolate entrypoint for the hasher worker.
///
/// Wire protocol:
///   worker -> client: its `SendPort` (the handshake), then one `String`
///     digest per request.
///   client -> worker: a `TransferableTypedData` per part, then
///     [_finishMessage].
void basePartHasherWorkerMain(SendPort client) {
  final requests = ReceivePort();
  final hasher = _InlineBasePartHasher();
  client.send(requests.sendPort);
  requests.listen((message) async {
    client.send(
      message is TransferableTypedData
          ? await hasher.addPart(message.materialize().asUint8List())
          : await hasher.finish(),
    );
  });
}

/// One isolate per transfer, holding the rolling hash. A failure latches: the
/// call in flight and every later call throw [BasePartHasherException].
class WorkerBasePartHasher implements BasePartHasher {
  WorkerBasePartHasher._(this._replyTimeout) {
    _sub = _fromWorker.listen(_onMessage);
    // A spawn that throws never reaches the await on this, and dispose still
    // fails it; unhandled, that error would escape to the zone.
    _handshake.future.ignore();
  }

  final Duration _replyTimeout;
  final ReceivePort _fromWorker = ReceivePort();
  late final StreamSubscription<dynamic> _sub;
  final Completer<SendPort> _handshake = Completer<SendPort>();
  Isolate? _isolate;
  late final SendPort _toWorker;
  Completer<String>? _pending;
  BasePartHasherException? _failure;
  bool _disposed = false;

  @visibleForTesting
  Isolate get debugIsolate => _isolate!;

  /// Throws, with nothing left running, on any spawn or handshake failure.
  static Future<WorkerBasePartHasher> _spawn(
    void Function(SendPort) entryPoint, {
    required Duration handshakeTimeout,
    required Duration replyTimeout,
  }) async {
    final hasher = WorkerBasePartHasher._(replyTimeout);
    try {
      final port = hasher._fromWorker.sendPort;
      hasher._isolate = await Isolate.spawn(
        entryPoint,
        port,
        // A hash that hit an error has unknown state, so the worker dies
        // rather than serve another request. Its exit reaches [_onMessage]
        // however it dies, which is what stops a waiter hanging.
        errorsAreFatal: true,
        onError: port,
        onExit: port,
      );
      hasher._toWorker = await hasher._handshake.future.timeout(
        handshakeTimeout,
      );
      return hasher;
    } catch (_) {
      await hasher.dispose();
      rethrow;
    }
  }

  void _onMessage(dynamic message) {
    switch (message) {
      case final SendPort port:
        if (!_handshake.isCompleted) _handshake.complete(port);
      case final String digest:
        _pending?.complete(digest);
        _pending = null;
      case final List<dynamic> error:
        _fail('worker error: ${error.first}');
      default:
        _fail('worker exited');
    }
  }

  BasePartHasherException _fail(String why) {
    final failure = _failure ??= BasePartHasherException(why);
    if (!_handshake.isCompleted) _handshake.completeError(failure);
    _pending?.completeError(failure);
    _pending = null;
    return failure;
  }

  Future<String> _request(Object message) {
    final failure = _failure;
    if (failure != null) return Future.error(failure);
    final reply = Completer<String>();
    _pending = reply;
    _toWorker.send(message);
    return reply.future.timeout(
      _replyTimeout,
      onTimeout: () => throw _fail('worker did not reply in $_replyTimeout'),
    );
  }

  @override
  Future<String> addPart(Uint8List part) =>
      _request(TransferableTypedData.fromList([part]));

  @override
  Future<String> finish() => _request(_finishMessage);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _fail('hasher disposed');
    await _sub.cancel();
    _fromWorker.close();
    _isolate?.kill(priority: Isolate.immediate);
  }
}
