import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:http/http.dart' as http;

import 'package:submersion/core/services/google_photos/google_photos_auth_manager.dart';
import 'package:submersion/core/services/google_photos/google_photos_auth_store.dart';

/// Google Photos logins as accounts -- a media acquisition source, not a
/// sync/store backend, so the adapter is [MediaSourceCapable] only. Auth
/// blobs live under per-account keys; each account instance keeps its own
/// [GooglePhotosAuthManager] for the process lifetime so the in-memory
/// access-token cache and single-flight refresh are not shared across
/// accounts.
///
/// Mirrors [LightroomAccountAdapter]. The connector reads the user's
/// library through the Photos Picker API only (a Google-hosted picker,
/// then a one-shot download of the chosen items); there is no library
/// listing or background watch, by Google's design since March 2025.
class GooglePhotosAccountAdapter extends AccountProviderAdapter
    implements MediaSourceCapable {
  GooglePhotosAccountAdapter({
    GooglePhotosAuthStore Function(String storageKey)? authStoreFactory,
    http.Client Function()? httpClientFactory,
  }) : _authStoreFactory =
           authStoreFactory ??
           ((key) => GooglePhotosAuthStore(storageKey: key)),
       _httpClientFactory = httpClientFactory;

  final GooglePhotosAuthStore Function(String storageKey) _authStoreFactory;

  /// Injected so a test can supply a `MockClient` to the per-account auth
  /// managers this adapter builds; production leaves it null and each
  /// manager creates its own real client.
  final http.Client Function()? _httpClientFactory;

  final Map<String, GooglePhotosAuthManager> _managers = {};

  @override
  AccountKind get kind => AccountKind.googlePhotos;

  GooglePhotosAuthStore _storeFor(domain.ConnectedAccount account) =>
      _authStoreFactory(AccountCredentialsStore.keyFor(account.id));

  GooglePhotosAuthManager authManagerFor(domain.ConnectedAccount account) =>
      _managers.putIfAbsent(
        account.id,
        () => GooglePhotosAuthManager(
          store: _storeFor(account),
          httpClient: _httpClientFactory?.call(),
        ),
      );

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async =>
      await _storeFor(account).load() == null
      ? AccountStatus.needsSignIn
      : AccountStatus.signedIn;

  @override
  Future<void> disconnect(domain.ConnectedAccount account) async {
    // Through the manager, not the bare store: it also invalidates the
    // in-memory access-token cache and makes a best-effort server-side
    // revoke. Drop the cached manager so a later reconnect starts clean.
    await authManagerFor(account).disconnect();
    _managers.remove(account.id);
  }
}
