import 'dart:async';
import 'dart:isolate';

import 'base_parse_worker.dart';

/// Thrown when the base-parse worker reports a parse/checksum error or dies.
class BaseParseException implements Exception {
  BaseParseException(this.message);
  final String message;
  @override
  String toString() => 'BaseParseException: $message';
}

/// Main-isolate client for the base-file parse worker. Spawns a worker that
/// reads + parses a serialized sync base document off the UI isolate and streams
/// decoded rows back, pull-backpressured. See [baseParseWorkerMain] for the wire
/// protocol. Operations are sequential (one in flight at a time).
class BaseParseClient {
  BaseParseClient._(this._isolate, this._toWorker, this._fromWorker, this._sub);

  final Isolate _isolate;
  final SendPort _toWorker;
  final ReceivePort _fromWorker;
  final StreamSubscription<dynamic> _sub;
  final StreamController<Map<dynamic, dynamic>> _inbox =
      StreamController<Map<dynamic, dynamic>>.broadcast(sync: true);

  /// Spawns the worker for [filePath] and completes once its handshake arrives.
  static Future<BaseParseClient> spawn(String filePath) async {
    final fromWorker = ReceivePort();
    final ready = Completer<SendPort>();
    late final BaseParseClient client;

    final sub = fromWorker.listen((msg) {
      if (msg is Map && msg['type'] == 'ready') {
        ready.complete(msg['port'] as SendPort);
      } else if (msg is Map) {
        client._inbox.add(msg);
      } else if (msg is List) {
        // An uncaught error in the worker arrives via `onError` as
        // [errorString, stackTraceString].
        client._inbox.add(<String, Object>{
          'type': 'error',
          'message': msg.isNotEmpty ? msg.first.toString() : 'worker error',
        });
      }
    });

    final isolate = await Isolate.spawn(
      baseParseWorkerMain,
      <Object>[fromWorker.sendPort, filePath],
      onError: fromWorker.sendPort,
      errorsAreFatal: false,
    );

    final toWorker = await ready.future;
    client = BaseParseClient._(isolate, toWorker, fromWorker, sub);
    return client;
  }

  Future<void> dispose() async {
    _toWorker.send(<String, Object>{'cmd': 'dispose'});
    await _sub.cancel();
    _fromWorker.close();
    if (!_inbox.isClosed) await _inbox.close();
    _isolate.kill(priority: Isolate.immediate);
  }
}
