import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/s3_account_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
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
}
