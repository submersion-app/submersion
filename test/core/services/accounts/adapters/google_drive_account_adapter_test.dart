import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/adapters/google_drive_account_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive_storage_provider.dart';

import '../../../../helpers/fake_drive_server.dart';
import '../../../../helpers/revocable_client.dart';

/// Covers the media-store half of the adapter: that it declines when there
/// is no Google session, and that the store it hands back keeps working
/// after the authenticator swaps its client.
class _FakeAuthenticator implements GoogleDriveAuthenticator {
  _FakeAuthenticator(this.client);

  /// The currently published client, replaced wholesale on re-auth exactly
  /// as GoogleSignInAuthenticator._installClient does.
  http.Client? client;
  bool silentAuthResult = true;

  @override
  http.Client? get authClient => client;

  @override
  Future<void> authenticate() async {}

  @override
  Future<bool> attemptSilentAuth() async => silentAuthResult;

  @override
  Future<void> handleAuthFailure() async {}

  @override
  Future<void> signOut() async => client = null;

  @override
  Future<String?> get userEmail async => 'diver@example.com';
}

void main() {
  late Directory tmp;
  late FakeDriveServer server;
  late _FakeAuthenticator authenticator;
  late GoogleDriveAccountAdapter adapter;

  final account = domain.ConnectedAccount(
    id: 'acc-gd',
    kind: AccountKind.googledrive,
    label: 'Google Drive',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('gdrive_adapter_test');
    server = FakeDriveServer();
    authenticator = _FakeAuthenticator(RevocableClient(server.client));
    adapter = GoogleDriveAccountAdapter(
      provider: GoogleDriveStorageProvider(authenticator: authenticator),
    );
  });

  tearDown(() => tmp.delete(recursive: true));

  test('mediaObjectStore declines when there is no Google session', () async {
    authenticator
      ..client = null
      ..silentAuthResult = false;
    expect(await adapter.mediaObjectStore(account), isNull);
  });

  test('the store it returns survives a re-auth that swaps the '
      'client', () async {
    final store = (await adapter.mediaObjectStore(account))!;
    final src = File('${tmp.path}/a.jpg')..writeAsBytesSync([1, 2, 3]);
    await store.putFile(
      'smv1/objects/aa/before.jpg',
      src,
      contentType: 'image/jpeg',
    );

    // The 401 retry path: the old client is closed, a fresh one published.
    // A store that captured the client at construction dies here.
    authenticator.client!.close();
    authenticator.client = RevocableClient(server.client);

    await store.putFile(
      'smv1/objects/aa/after.jpg',
      src,
      contentType: 'image/jpeg',
    );

    expect(
      server.filesById.values.map((f) => f.name),
      containsAll(<String>[
        'smv1/objects/aa/before.jpg',
        'smv1/objects/aa/after.jpg',
      ]),
    );
  });
}
