import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

void main() {
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

  test('isLinuxPlatformProvider is overridable for widget tests', () {
    final container = ProviderContainer(
      overrides: [isLinuxPlatformProvider.overrideWithValue(true)],
    );
    addTearDown(container.dispose);
    expect(container.read(isLinuxPlatformProvider), isTrue);
  });
}
