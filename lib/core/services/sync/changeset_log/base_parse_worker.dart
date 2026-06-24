import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:submersion/core/services/sync/changeset_log/base_json_stream_reader.dart';

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
  final filePath = args[1] as String;
  final rx = ReceivePort();
  mainSendPort.send(<String, Object>{'type': 'ready', 'port': rx.sendPort});

  await for (final msg in rx) {
    final m = msg as Map;
    if (m['cmd'] == 'dispose') break;

    if (m['cmd'] == 'deletions') {
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
        mainSendPort.send(<String, Object>{
          'type': 'error',
          'message': e.toString(),
        });
      }
      continue;
    }
    // 'dataRows' / 'next' handlers are added in Task 3.
  }
  rx.close();
}
