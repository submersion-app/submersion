import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:submersion/core/services/sync/changeset_log/base_json_stream_reader.dart';

/// Isolate entrypoint for the base-file parse worker.
///
/// Wire protocol (all messages are plain maps / SendPorts — isolate-sendable):
///   main -> worker:
///     {'cmd': 'deletions'}                          (Pass 1)
///     {'cmd': 'dataRows', 'tables': [table names]}  (start a data-row stream)
///     {'cmd': 'next'}                               (release one paused batch)
///     {'cmd': 'dispose'}
///   worker -> main:
///     {'type': 'ready', 'port': SendPort}           (handshake)
///     {'type': 'deletions', 'exportedAt': int, 'rows': List}
///     {'type': 'batch', 'rows': List, 'done': bool}
///     {'type': 'error', 'message': String}
///
/// [args] is `[mainSendPort, filePath]` (Isolate.spawn passes one message).
void baseParseWorkerMain(List<Object> args) {
  final mainSendPort = args[0] as SendPort;
  final filePath = args[1] as String;
  final rx = ReceivePort();
  mainSendPort.send(<String, Object>{'type': 'ready', 'port': rx.sendPort});

  // Backpressure: a dataRows parse pauses (awaits [awaitNext]) after each full
  // batch; a 'next' command releases exactly one pause. The credit covers the
  // race where 'next' would arrive before the parse reaches its pause.
  Completer<void>? pendingNext;
  var credits = 0;
  Future<void> awaitNext() {
    if (credits > 0) {
      credits--;
      return Future<void>.value();
    }
    pendingNext = Completer<void>();
    return pendingNext!.future;
  }

  void sendError(Object e) => mainSendPort.send(<String, Object>{
    'type': 'error',
    'message': e.toString(),
  });

  Future<void> runDeletions() async {
    try {
      var exportedAt = 0;
      final rows = <Map<String, Object?>>[];
      await BaseJsonStreamReader().parse(
        File(filePath).openRead(),
        onScalar: (key, raw) async {
          if (key == 'exportedAt') {
            exportedAt = (jsonDecode(utf8.decode(raw)) as num?)?.toInt() ?? 0;
          }
        },
        wantRows: (section, _) => section == 'deletions',
        onRow: (section, table, rowBytes) async {
          rows.add(<String, Object?>{
            'table': table,
            'row': jsonDecode(utf8.decode(rowBytes)),
          });
        },
      );
      mainSendPort.send(<String, Object>{
        'type': 'deletions',
        'exportedAt': exportedAt,
        'rows': rows,
      });
    } catch (e) {
      sendError(e);
    }
  }

  Future<void> runDataRows(Set<String> tables) async {
    try {
      var batch = <Map<String, Object?>>[];
      await BaseJsonStreamReader().parse(
        File(filePath).openRead(),
        wantRows: (section, table) =>
            section == 'data' && tables.contains(table),
        onRow: (section, table, rowBytes) async {
          batch.add(<String, Object?>{
            'table': table,
            'row': jsonDecode(utf8.decode(rowBytes)),
          });
          if (batch.length >= 500) {
            mainSendPort.send(<String, Object>{
              'type': 'batch',
              'rows': batch,
              'done': false,
            });
            batch = <Map<String, Object?>>[];
            await awaitNext(); // pauses await-for -> pauses the file read
          }
        },
      );
      mainSendPort.send(<String, Object>{
        'type': 'batch',
        'rows': batch,
        'done': true,
      });
    } catch (e) {
      sendError(e);
    }
  }

  rx.listen((msg) {
    final m = msg as Map;
    final cmd = m['cmd'];
    if (cmd == 'dispose') {
      rx.close();
    } else if (cmd == 'next') {
      if (pendingNext != null) {
        pendingNext!.complete();
        pendingNext = null;
      } else {
        credits++;
      }
    } else if (cmd == 'deletions') {
      runDeletions();
    } else if (cmd == 'dataRows') {
      runDataRows((m['tables'] as List).cast<String>().toSet());
    }
  });
}
