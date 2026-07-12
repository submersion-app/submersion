import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/google_drive_account_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/icloud_account_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/lightroom_account_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/google_drive_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/core/services/lightroom/lightroom_auth_store.dart';

import '../../../../support/fake_keychain_storage.dart';

domain.ConnectedAccount _account(String id, AccountKind kind) =>
    domain.ConnectedAccount(
      id: id,
      kind: kind,
      label: kind.name,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );

class _FakeDriveProvider extends Fake implements GoogleDriveStorageProvider {
  _FakeDriveProvider({required this.authenticated});

  final bool authenticated;
  final http.Client? client = null;
  bool signedOut = false;

  @override
  Future<bool> isAuthenticated() async => authenticated;

  @override
  Future<http.Client?> mediaHttpClient() async => client;

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  group('GoogleDriveAccountAdapter', () {
    final account = _account('acc-g', AccountKind.googledrive);

    test('status maps the session state', () async {
      expect(
        await GoogleDriveAccountAdapter(
          provider: _FakeDriveProvider(authenticated: true),
        ).status(account),
        AccountStatus.signedIn,
      );
      expect(
        await GoogleDriveAccountAdapter(
          provider: _FakeDriveProvider(authenticated: false),
        ).status(account),
        AccountStatus.needsSignIn,
      );
    });

    test('mediaObjectStore is null without a silent session', () async {
      final adapter = GoogleDriveAccountAdapter(
        provider: _FakeDriveProvider(authenticated: false),
      );
      expect(await adapter.mediaObjectStore(account), isNull);
    });

    test('disconnect signs the shared session out', () async {
      final provider = _FakeDriveProvider(authenticated: true);
      await GoogleDriveAccountAdapter(provider: provider).disconnect(account);
      expect(provider.signedOut, isTrue);
    });
  });

  group('ICloudAccountAdapter', () {
    final account = _account('acc-i', AccountKind.icloud);

    test('status maps availability', () async {
      expect(
        await ICloudAccountAdapter(
          availability: () async => ICloudAvailability.available,
        ).status(account),
        AccountStatus.signedIn,
      );
      expect(
        await ICloudAccountAdapter(
          availability: () async => ICloudAvailability.signedOut,
        ).status(account),
        AccountStatus.unavailable,
      );
    });

    test(
      'mediaObjectStore is null when the container is unavailable',
      () async {
        final adapter = ICloudAccountAdapter(
          availability: () async => ICloudAvailability.unsupported,
        );
        expect(await adapter.mediaObjectStore(account), isNull);
      },
    );
  });

  group('LightroomAccountAdapter', () {
    final account = _account('acc-lr', AccountKind.adobeLightroom);
    late InMemoryKeychain keychain;
    late LightroomAccountAdapter adapter;

    setUp(() {
      keychain = InMemoryKeychain();
      adapter = LightroomAccountAdapter(
        authStoreFactory: (key) =>
            LightroomAuthStore(storage: keychain, storageKey: key),
      );
    });

    test('status reflects the per-account blob, not the legacy key', () async {
      expect(await adapter.status(account), AccountStatus.needsSignIn);

      keychain.values['lightroom_auth'] = jsonEncode({
        'clientId': 'c',
        'refreshToken': 'r',
      });
      expect(
        await adapter.status(account),
        AccountStatus.needsSignIn,
        reason: 'legacy key must not count as signed in',
      );

      keychain.values[AccountCredentialsStore.keyFor(account.id)] = jsonEncode({
        'clientId': 'c',
        'refreshToken': 'r',
      });
      expect(await adapter.status(account), AccountStatus.signedIn);
    });

    test('authManagerFor caches one manager per account', () {
      expect(
        identical(
          adapter.authManagerFor(account),
          adapter.authManagerFor(account),
        ),
        isTrue,
      );
    });

    test('disconnect clears only the per-account blob', () async {
      final key = AccountCredentialsStore.keyFor(account.id);
      keychain.values[key] = 'x';
      keychain.values['lightroom_auth'] = 'legacy';
      await adapter.disconnect(account);
      expect(keychain.values.containsKey(key), isFalse);
      expect(keychain.values['lightroom_auth'], 'legacy');
    });
  });
}
