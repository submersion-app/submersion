import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive_storage_provider.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';

import '../../helpers/fake_drive_server.dart';
import '../../helpers/revocable_client.dart';

/// A Google session whose token can be made to expire: handleAuthFailure
/// drops the client and a silent re-auth publishes [refreshedClient], as
/// GoogleSignInAuthenticator does.
class _FakeAuthenticator implements GoogleDriveAuthenticator {
  _FakeAuthenticator(this.client);

  http.Client? client;
  http.Client? refreshedClient;

  @override
  http.Client? get authClient => client;

  @override
  Future<void> authenticate() async {}

  @override
  Future<bool> attemptSilentAuth() async {
    client ??= refreshedClient;
    return client != null;
  }

  @override
  Future<void> handleAuthFailure() async => client = null;

  @override
  Future<void> signOut() async => client = null;

  @override
  Future<String?> get userEmail async => 'diver@example.com';
}

void main() {
  test('the Google Drive store it builds refreshes an expired token', () async {
    // The access token expires after about an hour. The store built for a
    // pre-account Drive attachment must hand the 401 back to the provider
    // for a refresh rather than fail every transfer as an auth error
    // (#3602).
    final server = FakeDriveServer();
    final authenticator = _FakeAuthenticator(
      MockClient((_) async => http.Response('{"error":{"code":401}}', 401)),
    )..refreshedClient = RevocableClient(server.client);
    final provider = GoogleDriveStorageProvider(authenticator: authenticator);

    final store = await buildMediaObjectStore(
      CloudProviderType.googledrive,
      instanceFor: (_) => provider,
    );

    expect(store, isNotNull);
    expect(await store!.head('smv1/objects/aa/x.jpg'), isNull);
  });
}
