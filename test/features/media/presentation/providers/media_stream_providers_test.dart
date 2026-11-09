import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/streaming/media_stream_relay.dart';
import 'package:submersion/features/media/data/streaming/media_stream_worker_host.dart';
import 'package:submersion/features/media/presentation/providers/media_stream_providers.dart';

class _FakeHost implements MediaStreamWorkerHost {
  _FakeHost(this.base);

  @override
  final Uri base;

  Future<RelayAnswer> Function(String ticket, String? range)? served;

  @override
  void serve(
    Future<RelayAnswer> Function(String ticket, String? range) answer,
  ) => served = answer;
}

void main() {
  test('no worker host gives no relay', () async {
    final container = ProviderContainer(
      overrides: [
        mediaStreamWorkerHostProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(mediaStreamRelayProvider.future), isNull);
  });

  test('a worker host serves a relay on its base', () async {
    final host = _FakeHost(Uri.parse('https://app.test/sub/'));
    final container = ProviderContainer(
      overrides: [
        mediaStreamWorkerHostProvider.overrideWith((ref) async => host),
      ],
    );
    addTearDown(container.dispose);
    final relay = await container.read(mediaStreamRelayProvider.future);
    expect(relay, isNotNull);
    expect(relay!.base, host.base);
    // The host answers through this relay: an unknown ticket is its 404.
    expect((await host.served!('nope', null)).status, 404);
  });

  test('outside a browser there is no worker host', () async {
    expect(await startMediaStreamWorker(), isNull);
  });
}
