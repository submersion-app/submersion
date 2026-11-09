import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/streaming/media_stream_relay.dart';
import 'package:submersion/features/media/data/streaming/media_stream_worker_host.dart';

/// The page's stream worker, or null outside a browser and where it did not
/// start (issue #4162). The registration itself starts at app start; this
/// waits for it.
///
/// A worker that started is kept for the page's life. No worker is not
/// kept, so the next video asks again: a page that was not controlled in
/// time (a hard reload) gets another chance rather than being told for
/// good that it needs a normal window.
final mediaStreamWorkerHostProvider = FutureProvider<MediaStreamWorkerHost?>((
  ref,
) async {
  final host = await startMediaStreamWorker();
  if (host != null) ref.keepAlive();
  return host;
}, isAutoDispose: true);

/// The relay Google Drive and WebDAV videos stream through, serving the
/// worker's requests for as long as the page runs; null without a worker,
/// and then asked again next time, as above.
final mediaStreamRelayProvider = FutureProvider<MediaStreamRelay?>((ref) async {
  final host = await ref.watch(mediaStreamWorkerHostProvider.future);
  if (host == null) return null;
  ref.keepAlive();
  final relay = MediaStreamRelay(base: host.base);
  host.serve(relay.answer);
  return relay;
}, isAutoDispose: true);
