import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_manager_tag_service.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';

import '../../../../helpers/fake_nfc.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  NfcTagService serviceOn(TargetPlatform platform) {
    debugDefaultTargetPlatformOverride = platform;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container.read(nfcTagServiceProvider);
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    test('${platform.name} uses the phone NFC reader', () {
      expect(serviceOn(platform), isA<NfcManagerTagService>());
    });
  }

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    test('${platform.name} has no NFC', () async {
      final service = serviceOn(platform);
      expect(service, isA<UnsupportedNfcTagService>());
      expect(await service.support(), NfcSupport.unsupported);
    });
  }

  test('support comes from the service', () async {
    final container = ProviderContainer(
      overrides: [
        nfcTagServiceProvider.overrideWithValue(
          FakeNfcTagService(supportValue: NfcSupport.disabled),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(nfcSupportProvider, (_, _) {});
    addTearDown(sub.close);
    expect(
      await container.read(nfcSupportProvider.future),
      NfcSupport.disabled,
    );
  });
}
