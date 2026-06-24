import 'dart:isolate';

/// Isolate entrypoint for the base-file parse worker.
///
/// Wire protocol (all messages are plain maps / SendPorts — isolate-sendable):
///   main -> worker:
///     {'cmd': 'deletions'}                      (Pass 1)
///     {'cmd': 'dataRows', 'tables': List<String>}  (start Pass 2/3 stream)
///     {'cmd': 'next'}                           (pull the next data batch)
///     {'cmd': 'dispose'}
///   worker -> main:
///     {'type': 'ready', 'port': SendPort}       (handshake)
///     {'type': 'deletions', 'exportedAt': int, 'rows': List}
///     {'type': 'batch', 'rows': List, 'done': bool}
///     {'type': 'error', 'message': String}
///
/// [args] is `[mainSendPort, filePath]` (Isolate.spawn passes a single message).
void baseParseWorkerMain(List<Object> args) async {
  final mainSendPort = args[0] as SendPort;
  // filePath (args[1]) is consumed by the command handlers added in later tasks.
  final rx = ReceivePort();
  mainSendPort.send(<String, Object>{'type': 'ready', 'port': rx.sendPort});

  await for (final msg in rx) {
    final m = msg as Map;
    if (m['cmd'] == 'dispose') break;
    // 'deletions' / 'dataRows' / 'next' handlers are added in Tasks 2-3.
  }
  rx.close();
}
