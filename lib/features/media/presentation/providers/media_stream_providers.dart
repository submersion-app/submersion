import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/streaming/media_stream_relay.dart';
import 'package:submersion/features/media/data/streaming/media_stream_worker_host.dart';

/// The page's stream worker, or null outside a browser and where the
/// browser offers none (issue #4162). The registration itself starts at
/// app start; this waits for it.
final mediaStreamWorkerHostProvider = FutureProvider<MediaStreamWorkerHost?>(
  (ref) => startMediaStreamWorker(),
);

/// The relay Google Drive and WebDAV videos stream through, serving the
/// worker's requests for as long as the app runs; null without a worker.
final mediaStreamRelayProvider = FutureProvider<MediaStreamRelay?>((ref) async {
  final host = await ref.watch(mediaStreamWorkerHostProvider.future);
  if (host == null) return null;
  final relay = MediaStreamRelay(base: host.base);
  host.serve(relay.answer);
  return relay;
});
