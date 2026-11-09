import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/streaming/media_stream_relay.dart';
import 'package:submersion/features/media/data/streaming/media_stream_worker_host.dart';

const _log = LoggerService('MediaStreamWorker', category: LogCategory.media);

/// How long the worker may take to become ready and control the page.
const _controlTimeout = Duration(seconds: 10);

/// The start in progress, or the worker that started. A start that failed
/// is not kept, so the next video tries again.
Future<MediaStreamWorkerHost?>? _started;

/// Browser variant: registers the stream worker and resolves when it
/// controls the page, or to null when the browser offers no service workers
/// or the worker did not start in time.
Future<MediaStreamWorkerHost?> startMediaStreamWorker() {
  final started = _started;
  if (started != null) return started;
  final starting = _started = _start();
  starting.then((host) {
    if (host == null && identical(_started, starting)) _started = null;
  });
  return starting;
}

Future<MediaStreamWorkerHost?> _start() async {
  if (!(web.window.navigator as JSObject).has('serviceWorker')) {
    _log.info(
      'No service workers in this browser; Drive and WebDAV videos '
      'cannot stream',
    );
    return null;
  }
  try {
    final container = web.window.navigator.serviceWorker;
    final base = Uri.parse(web.document.baseURI);
    await container
        .register(
          base.resolve('media_stream_worker.js').toString().toJS,
          web.RegistrationOptions(scope: base.toString()),
        )
        .toDart;
    // Never resolves for a page outside the worker's scope.
    final registration = await container.ready.toDart.timeout(_controlTimeout);
    if (container.controller == null) {
      final controlled = Completer<void>();
      void onChange(web.Event _) {
        if (!controlled.isCompleted) controlled.complete();
      }

      // One JS function for both calls, so the remove finds the add.
      final listener = onChange.toJS;
      container.addEventListener('controllerchange', listener);
      // A hard reload leaves the page uncontrolled with the worker already
      // active, so no activation will claim it: ask the worker to.
      registration.active?.postMessage({'type': 'media-stream-claim'}.jsify());
      try {
        await controlled.future.timeout(_controlTimeout);
      } finally {
        container.removeEventListener('controllerchange', listener);
      }
    }
    final host = _WebHost(base);
    container.addEventListener('message', host._onMessage.toJS);
    container.startMessages();
    return host;
  } on Object catch (e) {
    _log.warning('The media stream worker did not start: $e');
    return null;
  }
}

class _WebHost implements MediaStreamWorkerHost {
  _WebHost(this.base);

  @override
  final Uri base;

  Future<RelayAnswer> Function(String ticket, String? range)? _answer;

  @override
  void serve(
    Future<RelayAnswer> Function(String ticket, String? range) answer,
  ) => _answer = answer;

  void _onMessage(web.MessageEvent event) {
    final data = event.data;
    if (data == null || !data.isA<JSObject>()) return;
    final message = data as JSObject;
    if (message.getProperty<JSAny?>('type'.toJS)?.dartify() !=
        'media-stream-request') {
      return;
    }
    final ports = event.ports.toDart;
    if (ports.isEmpty) return;
    final ticket = message.getProperty<JSAny?>('ticket'.toJS)?.dartify();
    final range = message.getProperty<JSAny?>('range'.toJS)?.dartify();
    unawaited(
      _reply(ports.first, ticket is String ? ticket : '', range as String?),
    );
  }

  Future<void> _reply(
    web.MessagePort port,
    String ticket,
    String? range,
  ) async {
    final answer = _answer;
    final RelayAnswer reply;
    try {
      reply = answer == null
          ? const RelayAnswer(status: 503)
          : await answer(ticket, range);
    } on Object catch (e) {
      _log.warning('A relayed stream request failed: $e');
      port.postMessage({'status': 502, 'headers': <String, String>{}}.jsify());
      return;
    }
    final message = JSObject()
      ..setProperty('status'.toJS, reply.status.toJS)
      ..setProperty('headers'.toJS, reply.headers.jsify());
    final body = reply.body;
    if (body == null) {
      message.setProperty('body'.toJS, null);
      port.postMessage(message);
      return;
    }
    // Transferred, not copied, to the worker; a view into a larger buffer
    // is copied out first so only its own bytes travel.
    final whole =
        body.offsetInBytes == 0 &&
            body.lengthInBytes == body.buffer.lengthInBytes
        ? body
        : Uint8List.fromList(body);
    final buffer = whole.buffer.toJS;
    message.setProperty('body'.toJS, buffer);
    port.postMessage(message, <JSObject>[buffer].toJS);
  }
}
