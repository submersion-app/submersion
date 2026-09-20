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

  test('platform gate follows defaultTargetPlatform', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(ProviderContainer().read(explorePlatformSupportedProvider), isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(ProviderContainer().read(explorePlatformSupportedProvider), isTrue);
    debugDefaultTargetPlatformOverride = null;
  });
}
