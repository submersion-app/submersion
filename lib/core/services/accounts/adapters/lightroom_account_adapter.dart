import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/core/services/lightroom/lightroom_auth_store.dart';

/// Adobe Lightroom logins as accounts (a media acquisition source, not a
/// sync/store backend). Auth blobs live under per-account keys; the IMS
/// manager keeps its process-wide token cache per account instance.
class LightroomAccountAdapter extends AccountProviderAdapter
    implements MediaSourceCapable {
  LightroomAccountAdapter({
    LightroomAuthStore Function(String storageKey)? authStoreFactory,
  }) : _authStoreFactory =
           authStoreFactory ?? ((key) => LightroomAuthStore(storageKey: key));

  final LightroomAuthStore Function(String storageKey) _authStoreFactory;

  /// Single-flight token refresh requires one manager per account for the
  /// process lifetime, so instances are cached by account id.
  final Map<String, AdobeImsAuthManager> _managers = {};

  @override
  AccountKind get kind => AccountKind.adobeLightroom;

  LightroomAuthStore _storeFor(domain.ConnectedAccount account) =>
      _authStoreFactory(AccountCredentialsStore.keyFor(account.id));

  AdobeImsAuthManager authManagerFor(domain.ConnectedAccount account) =>
      _managers.putIfAbsent(
        account.id,
        () => AdobeImsAuthManager(store: _storeFor(account)),
      );

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async =>
      await _storeFor(account).load() == null
      ? AccountStatus.needsSignIn
      : AccountStatus.signedIn;

  @override
  Future<void> disconnect(domain.ConnectedAccount account) =>
      _storeFor(account).clear();
}
