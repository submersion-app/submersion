import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/s3_account_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';
import 'package:submersion/core/services/media_store/s3_media_object_store.dart';

import '../../../../support/fake_keychain_storage.dart';

void main() {
  late InMemoryKeychain keychain;
  late AccountCredentialsStore credStore;
  late S3AccountAdapter adapter;

  final account = domain.ConnectedAccount(
    id: 'acc-s3',
    kind: AccountKind.s3,
    label: 'MinIO',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  final validS3Config = S3Config(
    endpoint: 'https://minio.local:9000',
    bucket: 'dive-media',
    accessKeyId: 'AK',
    secretAccessKey: 'SK',
  );

  setUp(() {
    keychain = InMemoryKeychain();
    credStore = AccountCredentialsStore(storage: keychain);
    adapter = S3AccountAdapter(credentials: credStore);
  });

  test('kind is s3', () {
    expect(adapter.kind, AccountKind.s3);
  });

  test('status is signedIn when a valid S3Config blob exists', () async {
    await credStore.write(account.id, jsonEncode(validS3Config.toJson()));
    expect(await adapter.status(account), AccountStatus.signedIn);
  });

  test('status is needsSignIn when the blob is absent', () async {
    expect(await adapter.status(account), AccountStatus.needsSignIn);
  });

  test('status is needsSignIn when the blob is corrupt', () async {
    await credStore.write(account.id, 'not-json{');
    expect(await adapter.status(account), AccountStatus.needsSignIn);
  });

  test('mediaObjectStore returns null without credentials', () async {
    expect(await adapter.mediaObjectStore(account), isNull);
  });

  test('mediaObjectStore builds an S3 store from the config', () async {
    await credStore.write(account.id, jsonEncode(validS3Config.toJson()));
    expect(await adapter.mediaObjectStore(account), isA<S3MediaObjectStore>());
  });

  test('saveConfig round-trips through loadConfig', () async {
    await adapter.saveConfig(account, validS3Config);
    final loaded = await adapter.loadConfig(account);
    expect(loaded!.bucket, 'dive-media');
    expect(loaded.accessKeyId, 'AK');
  });

  test('disconnect deletes only this account credentials', () async {
    await adapter.saveConfig(account, validS3Config);
    keychain.values['other'] = 'keep';
    await adapter.disconnect(account);
    expect(await adapter.loadConfig(account), isNull);
    expect(keychain.values['other'], 'keep');
  });

  test('syncProvider returns an S3StorageProvider (account-first raw '
      'provider for sync resolution)', () {
    expect(adapter.syncProvider(account), isA<S3StorageProvider>());
  });

  // Review of #3527: signing out of the S3 sync account clears the sync
  // settings too, as WebDAV's adapter does, or the next credential mirror
  // would copy them back and sign the account in again.
  group('with the sync settings', () {
    late S3CredentialsStore legacy;
    late S3AccountAdapter withSync;
    final syncRow = domain.ConnectedAccount(
      id: accountIdFor(
        kind: AccountKind.s3,
        naturalKey: s3NaturalKey(validS3Config),
      ),
      kind: AccountKind.s3,
      label: 'dive-media @ minio.local',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );

    setUp(() async {
      legacy = S3CredentialsStore(storage: keychain);
      withSync = S3AccountAdapter(credentials: credStore, legacySync: legacy);
      await legacy.save(validS3Config);
    });

    test('signing out the sync row clears the sync settings', () async {
      await withSync.saveConfig(syncRow, validS3Config);
      await withSync.disconnect(syncRow);
      expect(await legacy.load(), isNull);
    });

    test('signing out another folder leaves sync alone', () async {
      await withSync.saveConfig(account, validS3Config);
      await withSync.disconnect(account);
      expect(await legacy.load(), isNotNull);
    });
  });
}
