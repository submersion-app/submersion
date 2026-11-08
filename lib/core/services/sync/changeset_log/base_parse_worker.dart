import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:submersion/core/services/sync/changeset_log/base_json_stream_reader.dart';
import 'package:submersion/core/services/sync/changeset_log/byte_progress_stream.dart';
import 'package:submersion/core/services/sync/changeset_log/gzip_size_check.dart';

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
///     {'type': 'progress', 'bytes': int, 'total': int}  (liveness heartbeat)
///     {'type': 'error', 'message': String}
///
/// A progress message is sent every few MiB of file consumed during a pass
/// and once at its end. It is not a reply: the client treats it as proof the
/// worker is alive and restarts its inactivity timeout, so a pass over a
/// multi-hundred-MB base can legitimately take minutes without being mistaken
/// for a dead worker (issue #1421).
///
/// [args] is `[mainSendPort, filePath]` (Isolate.spawn passes one message),
/// optionally followed by `true` when the file is gzipped: each pass then
/// reads it through the decoder, and progress counts compressed bytes.
void baseParseWorkerMain(List<Object> args) {
  final mainSendPort = args[0] as SendPort;
  final filePath = args[1] as String;
  final gzipped = args.length > 2 && args[2] == true;
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

  final total = File(filePath).lengthSync();
  // A gzipped file is checked against its trailer on every pass. Read on
  // first use, inside a pass, so a file too short for a trailer fails that
  // pass through sendError like any other bad base.
  late final trailer = _trailer(filePath, total);
  Stream<List<int>> openWithProgress() {
    final read = withByteProgress(
      File(filePath).openRead(),
      onProgress: (consumed) => mainSendPort.send(<String, Object>{
        'type': 'progress',
        'bytes': consumed,
        'total': total,
      }),
    );
    return gzipped
        ? checkedGzipTrailer(read.transform(gzip.decoder), trailer)
        : read;
  }

  Future<void> runDeletions() async {
    try {
      var exportedAt = 0;
      final rows = <Map<String, Object?>>[];
      await BaseJsonStreamReader().parse(
        openWithProgress(),
        onScalar: (key, raw) async {
          if (key == 'exportedAt') {
            exportedAt = (jsonDecode(utf8.decode(raw)) as num?)?.toInt() ?? 0;
          }
        },
        wantRows: (section, _) => section == 'deletions',
        onRow: (section, table, rowBytes) async {
          final decoded = jsonDecode(utf8.decode(rowBytes));
          // A legacy base can encode a deletion as a bare string id. Normalise
          // it to the {id, deletedAt: 0} map the inline path synthesises, so the
          // wire row is always a map (what _decodeRows expects) and the
          // via-worker apply stays byte-identical for these peers instead of
          // crashing _decodeRows and forcing a fallback. Non-map/non-string
          // rows are dropped, mirroring the inline path's silent skip.
          final Object? row = decoded is String
              ? <String, Object?>{'id': decoded, 'deletedAt': 0}
              : decoded;
          if (row is! Map) return;
          rows.add(<String, Object?>{'table': table, 'row': row});
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
        openWithProgress(),
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

/// The trailer of the gzip at [filePath], [length] bytes long.
GzipTrailer _trailer(String filePath, int length) {
  final file = File(filePath).openSync();
  try {
    file.setPositionSync(length < 8 ? 0 : length - 8);
    return gzipTrailer(file.readSync(8));
  } finally {
    file.closeSync();
  }
}
