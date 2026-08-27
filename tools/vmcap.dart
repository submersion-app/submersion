import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Minimal VM-service CPU/frame capture for user-paced profiling.
///
/// Usage:
///
///     flutter run --profile -d macos   # note the ws://127.0.0.1:PORT/TOKEN=/ws URI
///     dart run tools/vmcap.dart <ws-uri> probe
///     dart run tools/vmcap.dart <ws-uri> clear     # right BEFORE interacting
///     (interact with the app)
///     dart run tools/vmcap.dart <ws-uri> read      # right AFTER interacting
///     dart run tools/vmcap.dart <ws-uri> frames 10 # frame events for 10 s
///
/// Gotchas (learned in the June 2026 Phase 1 effort):
/// - Always `clear` immediately before the window; otherwise the VM service's
///   own serialization functions dominate the profile.
/// - `frames` counts only events timestamped after subscribe, because the VM
///   replays the historical frame buffer to new subscribers.
Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln(
      'Usage: dart run tools/vmcap.dart <ws-uri> <probe|clear|read|frames> '
      '[seconds]',
    );
    exit(64);
  }
  final uri = args[0];
  final mode = args[1];
  final seconds = args.length > 2 ? int.parse(args[2]) : 10;

  final ws = await WebSocket.connect(uri);
  final client = _RpcClient(ws);
  try {
    final vm = await client.call('getVM');
    final isolates = (vm['isolates'] as List).cast<Map<String, dynamic>>();
    if (isolates.isEmpty) {
      stderr.writeln('No isolates.');
      exit(1);
    }
    // Prefer the isolate named 'main': a profile/debug app can expose helper
    // isolates (background workers, plugins), and isolates.first is not
    // guaranteed to be the root isolate whose CPU samples/frames we want.
    final mainIso = isolates.firstWhere(
      (iso) => iso['name'] == 'main',
      orElse: () => isolates.first,
    );
    final main = mainIso['id'] as String;

    switch (mode) {
      case 'probe':
        for (final iso in isolates) {
          stdout.writeln('${iso['id']}  ${iso['name']}');
        }
      case 'clear':
        await client.call('setFlag', {'name': 'profiler', 'value': 'true'});
        await client.call('clearCpuSamples', {'isolateId': main});
        stdout.writeln('Profiler on, samples cleared. Interact now.');
      case 'read':
        final samples = await client.call('getCpuSamples', {
          'isolateId': main,
          'timeOriginMicros': 0,
          'timeExtentMicros': 0x7fffffffffffffff,
        });
        _report(samples);
      case 'frames':
        await _frames(client, seconds);
      default:
        stderr.writeln('Unknown mode: $mode');
        exit(64);
    }
  } finally {
    await ws.close();
  }
}

void _report(Map<String, dynamic> samples) {
  final functions = (samples['functions'] as List? ?? [])
      .cast<Map<String, dynamic>>();
  String nameOf(int i) {
    final f = functions[i]['function'] as Map<String, dynamic>?;
    return (f?['name'] as String?) ?? '<unknown>';
  }

  final self = <int, int>{};
  final incl = <int, int>{};
  final sampleList = (samples['samples'] as List? ?? [])
      .cast<Map<String, dynamic>>();
  for (final s in sampleList) {
    final stack = (s['stack'] as List).cast<int>();
    if (stack.isEmpty) continue;
    self[stack.first] = (self[stack.first] ?? 0) + 1;
    for (final f in stack.toSet()) {
      incl[f] = (incl[f] ?? 0) + 1;
    }
  }
  final total = sampleList.length;
  stdout.writeln(
    'Samples: $total over ${samples['timeExtentMicros']} us window',
  );
  if (total == 0) return;
  final top = self.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  stdout.writeln('\n-- top self --');
  for (final e in top.take(30)) {
    final pct = (e.value * 100 / total).toStringAsFixed(1);
    stdout.writeln('${'$pct%'.padLeft(7)}  ${nameOf(e.key)}');
  }
  final topIncl = incl.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  stdout.writeln('\n-- top inclusive --');
  for (final e in topIncl.take(30)) {
    final pct = (e.value * 100 / total).toStringAsFixed(1);
    stdout.writeln('${'$pct%'.padLeft(7)}  ${nameOf(e.key)}');
  }
}

Future<void> _frames(_RpcClient client, int seconds) async {
  final subscribedAt = DateTime.now().microsecondsSinceEpoch;
  var count = 0, slow = 0;
  client.onEvent = (event) {
    if (event['extensionKind'] != 'Flutter.Frame') return;
    final data = event['extensionData'] as Map<String, dynamic>;
    final ts = event['timestamp'] as int? ?? 0;
    if (ts * 1000 < subscribedAt) return; // replayed history
    count++;
    final elapsed = (data['elapsed'] as num).toInt();
    if (elapsed > 16667) slow++;
  };
  await client.call('streamListen', {'streamId': 'Extension'});
  stdout.writeln('Capturing frames for $seconds s. Interact now.');
  await Future<void>.delayed(Duration(seconds: seconds));
  stdout.writeln('Frames: $count, over-16.7ms: $slow');
}

class _RpcClient {
  _RpcClient(this._ws) {
    _ws.listen((raw) {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      if (msg.containsKey('id')) {
        final completer = _pending.remove(msg['id']);
        if (msg.containsKey('error')) {
          completer?.completeError(StateError(jsonEncode(msg['error'])));
        } else {
          completer?.complete(msg['result'] as Map<String, dynamic>);
        }
      } else if (msg['method'] == 'streamNotify') {
        final event =
            (msg['params'] as Map<String, dynamic>)['event']
                as Map<String, dynamic>;
        onEvent?.call(event);
      }
    });
  }

  final WebSocket _ws;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  int _nextId = 1;
  void Function(Map<String, dynamic> event)? onEvent;

  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic>? params,
  ]) {
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _ws.add(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': ?params,
      }),
    );
    return completer.future;
  }
}
