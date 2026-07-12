import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_api_client.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_manager.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';
import 'package:submersion/core/services/cloud_storage/dropbox_storage_provider.dart';
import 'package:submersion/core/services/media_store/dropbox_media_object_store.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';

/// Dropbox logins as accounts: the per-account payload is the refresh-token
/// blob (DropboxAuthData JSON), read through DropboxAuthStore pointed at the
/// per-account keychain key.
class DropboxAccountAdapter extends AccountProviderAdapter
    implements SyncCapable, MediaStoreCapable {
  DropboxAccountAdapter({
    DropboxAuthStore Function(String storageKey)? authStoreFactory,
  }) : _authStoreFactory =
           authStoreFactory ?? ((key) => DropboxAuthStore(storageKey: key));

  final DropboxAuthStore Function(String storageKey) _authStoreFactory;

  /// Single-flight token refresh requires one manager per account for the
  /// process lifetime, so instances are cached by account id.
  final Map<String, DropboxAuthManager> _managers = {};

  @override
  AccountKind get kind => AccountKind.dropbox;

  DropboxAuthStore _storeFor(domain.ConnectedAccount account) =>
      _authStoreFactory(AccountCredentialsStore.keyFor(account.id));

  DropboxAuthManager authManagerFor(domain.ConnectedAccount account) =>
      _managers.putIfAbsent(
        account.id,
        () => DropboxAuthManager(store: _storeFor(account)),
      );

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async =>
      await _storeFor(account).load() == null
      ? AccountStatus.needsSignIn
      : AccountStatus.signedIn;

  @override
  Future<void> disconnect(domain.ConnectedAccount account) async {
    // Through the manager, not the bare store: revokes the refresh token
    // (best-effort), invalidates the in-memory access-token cache, and
    // clears the per-account blob. Drop the cached manager so a later
    // reconnect starts clean.
    await authManagerFor(account).disconnect();
    _managers.remove(account.id);
  }

  @override
  CloudStorageProvider syncProvider(domain.ConnectedAccount account) =>
      DropboxStorageProvider(authManager: authManagerFor(account));

  @override
  Future<MediaObjectStore?> mediaObjectStore(
    domain.ConnectedAccount account,
  ) async {
    final auth = authManagerFor(account);
    if (await auth.loadAuth() == null) return null;
    return DropboxMediaObjectStore(
      client: DropboxApiClient(
        getAccessToken: auth.getAccessToken,
        onAccessTokenRejected: auth.invalidateAccessToken,
      ),
    );
  }
}
