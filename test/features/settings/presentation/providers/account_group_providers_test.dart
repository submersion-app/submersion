// Issue #3482 phase 2: accounts for the pages that show them, and the kinds a
// diver can add on this platform and build.

import 'dart:convert';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_location.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/adapters/s3_account_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../support/fake_keychain_storage.dart';

ProviderContainer _container(List<Override> overrides) {
  final c = ProviderContainer(overrides: overrides);
  addTearDown(c.dispose);
  return c;
}

List<Override> _gates({
  bool apple = true,
  ICloudAvailability icloud = ICloudAvailability.available,
  bool drive = true,
  bool dropbox = true,
}) => [
  isApplePlatformProvider.overrideWithValue(apple),
  iCloudAvailabilityProvider.overrideWith((ref) async => icloud),
  googleDriveAvailableProvider.overrideWith((ref) async => drive),
  dropboxConfiguredProvider.overrideWithValue(dropbox),
];

Future<List<AccountKindOffer>> _offers(List<Override> gates) async {
  final c = _container(gates);
  c.listen(offerableAccountKindsProvider, (_, _) {});
  await c.read(iCloudAvailabilityProvider.future);
  await c.read(googleDriveAvailableProvider.future);
  return c.read(offerableAccountKindsProvider);
}

void main() {
  group('offerable kinds', () {
    test('every kind, in the spec order, where all are supported', () async {
      expect(await _offers(_gates()), [
        AccountKindOffer.icloud,
        AccountKindOffer.googleDrive,
        AccountKindOffer.dropbox,
        AccountKindOffer.ownServer,
      ]);
    });

    test('iCloud only on Apple devices that support it', () async {
      expect(
        await _offers(_gates(apple: false)),
        isNot(contains(AccountKindOffer.icloud)),
      );
      expect(
        await _offers(_gates(icloud: ICloudAvailability.unsupported)),
        isNot(contains(AccountKindOffer.icloud)),
      );
      // Signed out is still offerable: choosing it says to sign in.
      expect(
        await _offers(_gates(icloud: ICloudAvailability.signedOut)),
        contains(AccountKindOffer.icloud),
      );
    });

    test('Google Drive and Dropbox follow their build gates', () async {
      final offers = await _offers(_gates(drive: false, dropbox: false));
      expect(offers, [AccountKindOffer.icloud, AccountKindOffer.ownServer]);
    });
  });

  test('groups combine roster, status, local config and usage', () async {
    final keychain = AccountCredentialsStore(storage: InMemoryKeychain());
    final at = DateTime.utc(2026);
    final sync = ConnectedAccount(
      id: 'sync',
      kind: AccountKind.s3,
      label: 'dives @ minio.home',
      createdAt: at,
      updatedAt: at,
      location: const S3AccountLocation(
        displayHost: 'minio.home',
        endpoint: 'https://minio.home',
        bucket: 'dives',
        region: 'us-east-1',
        prefix: 'submersion-sync/',
        pathStyle: true,
      ),
    );
    // Written before v293: only this device's stored config places it.
    final library = ConnectedAccount(
      id: 'lib',
      kind: AccountKind.s3,
      label: 'dives @ minio.home (submersion-sites/reef-team)',
      createdAt: at,
      updatedAt: at,
    );
    await keychain.write(
      'lib',
      jsonEncode(
        S3Config(
          endpoint: 'https://minio.home',
          bucket: 'dives',
          prefix: 'submersion-sites/reef-team/',
          accessKeyId: 'a',
          secretAccessKey: 'b',
        ).toJson(),
      ),
    );
    final c = _container([
      connectedAccountsWithStatusProvider.overrideWith(
        (ref) async => [
          (sync, AccountStatus.needsSignIn),
          (library, AccountStatus.signedIn),
        ],
      ),
      connectedAccountUsageProvider.overrideWith(
        (ref) async => const AccountUsageSnapshot(syncAccountId: 'sync'),
      ),
      accountProviderRegistryProvider.overrideWithValue(
        AccountProviderRegistry([S3AccountAdapter(credentials: keychain)]),
      ),
    ]);
    c.listen(accountGroupsProvider, (_, _) {});

    final groups = await c.read(accountGroupsProvider.future);

    expect(groups, hasLength(1));
    final g = groups.single;
    expect(g.label, 'dives @ minio.home');
    expect(g.status, AccountStatus.needsSignIn);
    expect(g.usages.single.kind, AccountUsageKind.databaseSync);
    expect(g.rows.map((r) => r.id), unorderedEquals(['sync', 'lib']));
  });
}
