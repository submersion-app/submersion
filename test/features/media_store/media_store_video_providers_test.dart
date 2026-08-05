import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

void main() {
  // On Apple/Android hosts engineForThisPlatform() returns a
  // ChannelTranscodeEngine, whose isAvailable() invokes a MethodChannel —
  // that needs the services binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('videoTranscodeAvailableProvider resolves to a bool', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // On the test host there is no engine (non-Linux) or ffmpeg may exist
    // (Linux CI): either way the provider must resolve without throwing.
    final available = await container.read(
      videoTranscodeAvailableProvider.future,
    );
    expect(available, isA<bool>());
  });

  test('videoTranscodeAvailableProvider re-checks after disposal', () async {
    // autoDispose: once the last listener drops, re-listening recomputes, so
    // the Linux hint refreshes on the next Settings visit instead of caching a
    // stale "ffmpeg missing" result.
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        videoTranscodeAvailableProvider.overrideWith((ref) async {
          calls++;
          return false;
        }),
      ],
    );
    addTearDown(container.dispose);

    final sub1 = container.listen(videoTranscodeAvailableProvider, (_, _) {});
    await container.read(videoTranscodeAvailableProvider.future);
    sub1.close(); // no listeners left -> autoDispose

    await Future<void>.delayed(Duration.zero);

    final sub2 = container.listen(videoTranscodeAvailableProvider, (_, _) {});
    await container.read(videoTranscodeAvailableProvider.future);
    sub2.close();

    expect(calls, 2, reason: 'recomputed on re-listen after autoDispose');
  });

  test('isLinuxPlatformProvider is overridable for widget tests', () {
    final container = ProviderContainer(
      overrides: [isLinuxPlatformProvider.overrideWithValue(true)],
    );
    addTearDown(container.dispose);
    expect(container.read(isLinuxPlatformProvider), isTrue);
  });
}
