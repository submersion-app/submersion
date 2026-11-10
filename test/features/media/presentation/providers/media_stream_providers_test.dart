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

  test(
    'a worker that did not start is asked again on the next video',
    () async {
      // A page that was not controlled in time (a hard reload) must not be
      // told it needs a normal window for the rest of its life.
      var starts = 0;
      final host = _FakeHost(Uri.parse('https://app.test/'));
      final container = ProviderContainer(
        overrides: [
          mediaStreamWorkerHostProvider.overrideWith((ref) async {
            starts++;
            return starts == 1 ? null : host;
          }),
        ],
      );
      addTearDown(container.dispose);
      expect(await container.read(mediaStreamRelayProvider.future), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(await container.read(mediaStreamRelayProvider.future), isNotNull);
      expect(starts, 2);
    },
  );

  test('a started relay is kept while nothing watches it', () async {
    var starts = 0;
    final container = ProviderContainer(
      overrides: [
        mediaStreamWorkerHostProvider.overrideWith((ref) async {
          starts++;
          return _FakeHost(Uri.parse('https://app.test/'));
        }),
      ],
    );
    addTearDown(container.dispose);
    final first = await container.read(mediaStreamRelayProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(await container.read(mediaStreamRelayProvider.future), same(first));
    expect(starts, 1);
  });
}
