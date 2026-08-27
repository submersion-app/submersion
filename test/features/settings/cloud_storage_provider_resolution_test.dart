import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/dropbox_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

/// Account-first resolution guard: `selectedSyncAccountProvider.value` can
/// return the PREVIOUS account while it recomputes after the provider type
/// changes. Resolution must not build the raw provider from a stale account
/// whose kind no longer matches the selected type.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  domain.ConnectedAccount account(AccountKind kind) => domain.ConnectedAccount(
    id: 'acc-${kind.name}',
    kind: kind,
    label: kind.name,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  Future<ProviderContainer> containerWithStaleAccount(
    AccountKind staleKind,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // A resolved account of the "stale" kind, standing in for the value
        // left behind while the real derivation recomputes.
        selectedSyncAccountProvider.overrideWith(
          (ref) async => account(staleKind),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'a stale S3 account does not resolve Dropbox sync to an S3 provider',
    () async {
      final container = await containerWithStaleAccount(AccountKind.s3);
      container.read(selectedCloudProviderTypeProvider.notifier).state =
          CloudProviderType.dropbox;
      await container.read(
        selectedSyncAccountProvider.future,
      ); // resolve .value

      final resolved = container.read(cloudStorageProviderProvider);
      expect(resolved, isA<DropboxStorageProvider>());
      expect(
        resolved,
        isNot(isA<S3StorageProvider>()),
        reason: 'kind guard rejects the stale S3 account for a Dropbox type',
      );
    },
  );

  test('a matching-kind account is used for resolution', () async {
    final container = await containerWithStaleAccount(AccountKind.dropbox);
    container.read(selectedCloudProviderTypeProvider.notifier).state =
        CloudProviderType.dropbox;
    await container.read(selectedSyncAccountProvider.future);

    // Kind matches the type, so account-first resolution applies (the
    // Dropbox adapter's syncProvider is itself a DropboxStorageProvider).
    expect(
      container.read(cloudStorageProviderProvider),
      isA<DropboxStorageProvider>(),
    );
  });

  test('a matching-kind account with no registered SyncCapable falls back to '
      'the shared provider singleton', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        selectedSyncAccountProvider.overrideWith(
          (ref) async => account(AccountKind.dropbox),
        ),
        // An empty registry has no SyncCapable for the kind, so
        // capabilityFor<SyncCapable>() returns null and resolution takes the
        // `?? cloudProviderInstanceFor(...)` singleton fallback.
        accountProviderRegistryProvider.overrideWithValue(
          AccountProviderRegistry(const []),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(selectedCloudProviderTypeProvider.notifier).state =
        CloudProviderType.dropbox;
    await container.read(selectedSyncAccountProvider.future);

    expect(
      container.read(cloudStorageProviderProvider),
      isA<DropboxStorageProvider>(),
      reason: 'the singleton fallback still yields a Dropbox provider',
    );
  });

  test('while selectedSyncAccountProvider is reloading, resolution falls back '
      'to the legacy singleton (which holds the just-edited creds)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // A pending future keeps the provider in AsyncLoading: this stands in for
    // the re-mirror reload an in-place credential edit triggers, during which
    // account-first must NOT read the momentarily-stale per-account key.
    final pending = Completer<domain.ConnectedAccount?>();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        selectedSyncAccountProvider.overrideWith((ref) => pending.future),
      ],
    );
    addTearDown(container.dispose);

    container.read(selectedCloudProviderTypeProvider.notifier).state =
        CloudProviderType.dropbox;

    // Read while the account is still loading: it must resolve to the exact
    // type-keyed singleton, not an account-first provider off a stale key.
    expect(
      identical(
        container.read(cloudStorageProviderProvider),
        cloudProviderInstanceFor(CloudProviderType.dropbox),
      ),
      isTrue,
      reason: 'a loading account resolves to the legacy singleton',
    );
  });
}
