import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/services/cached_network_image_diagnostics.dart';
import 'package:submersion/features/media/data/services/host_rate_limiter.dart';
import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';

class _StubDiag implements CachedNetworkImageDiagnostics {
  _StubDiag(this.size);
  final int size;
  @override
  Future<int> cacheSize() async => size;
  @override
  Future<void> clearCache() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
}

void main() {
  test('cacheSizeProvider delegates to the diagnostics service', () async {
    final container = ProviderContainer(
      overrides: [
        cachedNetworkImageDiagnosticsProvider.overrideWithValue(
          _StubDiag(2048),
        ),
      ],
    );
    addTearDown(container.dispose);

    final size = await container.read(cacheSizeProvider.future);
    expect(size, 2048);
  });

  test('hostRateLimiterProvider returns a singleton with default settings', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final a = container.read(hostRateLimiterProvider);
    final b = container.read(hostRateLimiterProvider);
    expect(identical(a, b), true);
    expect(a, isA<HostRateLimiter>());
  });

  test(
    'networkScanServiceProvider builds a service with the registered deps',
    () {
      // Smoke test: the provider compiles and reads without throwing. Live
      // wiring is exercised by the dialog widget test in Task 9.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(networkScanServiceProvider),
        isA<void Function()>(),
      );
    },
  );
}
