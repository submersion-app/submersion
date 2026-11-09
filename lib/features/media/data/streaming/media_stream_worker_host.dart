/// The page's connection to the media stream worker (issue #4162).
///
/// In a browser, `startMediaStreamWorker` registers
/// `media_stream_worker.js` under the page's base and hands back a host that
/// answers the worker's relayed requests. Anywhere else, and in a browser
/// with no service workers (a private window in Firefox), it gives null:
/// Google Drive and WebDAV videos then say they need a normal window.
library;

import 'package:submersion/features/media/data/streaming/media_stream_relay.dart';

export 'package:submersion/features/media/data/streaming/media_stream_worker_host_io.dart'
    if (dart.library.js_interop) 'package:submersion/features/media/data/streaming/media_stream_worker_host_web.dart';

/// A registered stream worker, controlling this page.
abstract interface class MediaStreamWorkerHost {
  /// The page's base address, which the worker's scope and every stream
  /// address sit under.
  Uri get base;

  /// Answers every request the worker relays with [answer].
  void serve(Future<RelayAnswer> Function(String ticket, String? range) answer);
}
