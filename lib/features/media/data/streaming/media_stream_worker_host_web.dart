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

/// How long a fresh registration may take to control the page.
const _controlTimeout = Duration(seconds: 10);

Future<MediaStreamWorkerHost?>? _started;

/// Browser variant: registers the stream worker once per page and resolves
/// when it controls the page, or to null when the browser offers no service
/// workers or registration fails.
Future<MediaStreamWorkerHost?> startMediaStreamWorker() =>
    _started ??= _start();

Future<MediaStreamWorkerHost?> _start() async {
  try {
    if (!(web.window.navigator as JSObject).has('serviceWorker')) {
      _log.info(
        'No service workers in this browser; Drive and WebDAV videos '
        'cannot stream',
      );
      return null;
    }
    final container = web.window.navigator.serviceWorker;
    final base = Uri.parse(web.document.baseURI);
    await container
        .register(
          base.resolve('media_stream_worker.js').toString().toJS,
          web.RegistrationOptions(scope: base.toString()),
        )
        .toDart;
    await container.ready.toDart;
    if (container.controller == null) {
      final controlled = Completer<void>();
      void onChange(web.Event _) {
        if (!controlled.isCompleted) controlled.complete();
      }

      container.addEventListener('controllerchange', onChange.toJS);
      await controlled.future.timeout(_controlTimeout);
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
