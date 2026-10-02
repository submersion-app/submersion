import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _FakeEngine implements NlEngine {
  _FakeEngine(this.result);
  final NlAvailability result;
  String? askedLocale;

  @override
  Future<NlAvailability> availability(String localeTag) async {
    askedLocale = localeTag;
    return result;
  }

  @override
  Future<void> prepare() async {}

  @override
  Stream<double> download() => const Stream.empty();

  @override
  Future<String> compile(String sentence, {required String localeTag}) async =>
      '{}';
}

/// Holds its answer until the test hands one over, so the loading state is
/// observable.
class _SlowEngine implements NlEngine {
  Completer<NlAvailability> _next = Completer<NlAvailability>();

  void complete(NlAvailability a) => _next.complete(a);
  void reset() => _next = Completer<NlAvailability>();

  @override
  Future<NlAvailability> availability(String localeTag) => _next.future;

  @override
  Future<void> prepare() async {}

  @override
  Stream<double> download() => const Stream.empty();

  @override
  Future<String> compile(String sentence, {required String localeTag}) async =>
      '{}';
}

void main() {
  ProviderContainer make(
    NlAvailability a, {
    bool platform = true,
    String locale = 'en',
  }) => ProviderContainer(
    overrides: [
      nlEngineProvider.overrideWithValue(_FakeEngine(a)),
      explorePlatformSupportedProvider.overrideWithValue(platform),
      localeProvider.overrideWithValue(locale),
    ],
  );

  test(
    'enabled only when the platform is supported and the model is available',
    () async {
      final c = make(NlAvailability.available);
      await c.read(exploreAvailabilityProvider.future);
      expect(c.read(exploreEnabledProvider), isTrue);
    },
  );

  test(
    'disabled on an unsupported platform even if the probe says available',
    () async {
      final c = make(NlAvailability.available, platform: false);
      expect(c.read(exploreEnabledProvider), isFalse);
    },
  );

  test(
    'disabled while the probe loads and when it says unsupportedLocale',
    () async {
      final c = make(NlAvailability.unsupportedLocale, locale: 'hu');
      expect(c.read(exploreEnabledProvider), isFalse);
      await c.read(exploreAvailabilityProvider.future);
      expect(c.read(exploreEnabledProvider), isFalse);
    },
  );

  test('the probe asks for the active locale', () async {
    final c = make(NlAvailability.available, locale: 'de');
    await c.read(exploreAvailabilityProvider.future);
    expect((c.read(nlEngineProvider) as _FakeEngine).askedLocale, 'de');
  });

  test('stays closed while a locale change re-probes', () async {
    // AsyncValue keeps the previous answer during a dependency-driven
    // reload, so an available English probe must not hold the gate open
    // while the new locale's probe is still running.
    final engine = _SlowEngine();
    final container = ProviderContainer(
      overrides: [
        nlEngineProvider.overrideWithValue(engine),
        explorePlatformSupportedProvider.overrideWithValue(true),
        localeProvider.overrideWithValue('en'),
      ],
    );
    addTearDown(container.dispose);
    container.listen(exploreEnabledProvider, (_, _) {});

    engine.complete(NlAvailability.available);
    await container.read(exploreAvailabilityProvider.future);
    expect(container.read(exploreEnabledProvider), isTrue);

    // Re-probe: the answer is not in yet.
    engine.reset();
    container.invalidate(exploreAvailabilityProvider);
    container.read(exploreAvailabilityProvider);
    expect(container.read(exploreEnabledProvider), isFalse);

    engine.complete(NlAvailability.unsupportedLocale);
    await container.read(exploreAvailabilityProvider.future);
    expect(container.read(exploreEnabledProvider), isFalse);
  });

  test('platform gate follows defaultTargetPlatform', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(ProviderContainer().read(explorePlatformSupportedProvider), isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(ProviderContainer().read(explorePlatformSupportedProvider), isTrue);
    debugDefaultTargetPlatformOverride = null;
  });
}
