import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/providers/unavailable_account_kinds_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A browser cannot reach iCloud or a Git repository (issue #4121): the
/// connect step shows those two store kinds as unavailable with a reason,
/// and stops offering them.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  ProviderContainer container({bool browser = false}) {
    final c = ProviderContainer(
      overrides: [
        if (browser)
          deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
        // Every kind would be offerable on this build.
        isApplePlatformProvider.overrideWithValue(true),
        iCloudAvailabilityProvider.overrideWith(
          (ref) async => ICloudAvailability.available,
        ),
        googleDriveAvailableProvider.overrideWith((ref) async => true),
        dropboxConfiguredProvider.overrideWithValue(true),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('natively nothing is unavailable', () {
    expect(container().read(unavailableAccountKindsProvider), isEmpty);
  });

  test('a browser names iCloud and Git with their reasons', () {
    final unavailable = container(
      browser: true,
    ).read(unavailableAccountKindsProvider);
    expect(unavailable.keys, {AccountKindOffer.icloud, AccountKindOffer.git});
    expect(
      unavailable[AccountKindOffer.icloud]!(en),
      en.web_unavailable_offer_icloud,
    );
    expect(
      unavailable[AccountKindOffer.git]!(en),
      en.web_unavailable_offer_git,
    );
  });

  test('a browser stops offering the two kinds it cannot reach', () async {
    final c = container(browser: true);
    // The async availability providers settle before the list is read.
    final sub = c.listen(offerableAccountKindsProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(iCloudAvailabilityProvider.future);
    await c.read(googleDriveAvailableProvider.future);
    expect(c.read(offerableAccountKindsProvider), [
      AccountKindOffer.googleDrive,
      AccountKindOffer.dropbox,
      AccountKindOffer.ownServer,
    ]);
  });
}
