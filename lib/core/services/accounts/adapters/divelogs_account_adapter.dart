import 'package:http/http.dart' as http;
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/divelogs/divelogs_auth_manager.dart';

/// Adapter for divelogs.de accounts (connector kind: per-diver logbook
/// sync, no cloud storage). Credentials are a username/password/JWT blob
/// in the keychain under the per-account key.
class DivelogsAccountAdapter extends AccountProviderAdapter
    implements LogbookSyncCapable {
  DivelogsAccountAdapter({
    required AccountCredentialsStore credentials,
    http.Client? httpClient,
  }) : _credentials = credentials,
       _httpClient = httpClient;

  final AccountCredentialsStore _credentials;
  final http.Client? _httpClient;
  final Map<String, DivelogsAuthManager> _managers = {};

  @override
  AccountKind get kind => AccountKind.divelogs;

  DivelogsAuthManager authManagerFor(domain.ConnectedAccount account) =>
      _managers.putIfAbsent(
        account.id,
        () => DivelogsAuthManager(
          credentials: _credentials,
          accountId: account.id,
          httpClient: _httpClient,
        ),
      );

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async {
    final blob = await _credentials.read(account.id);
    return (blob == null || blob.isEmpty)
        ? AccountStatus.needsSignIn
        : AccountStatus.signedIn;
  }

  @override
  Future<void> disconnect(domain.ConnectedAccount account) async {
    await authManagerFor(account).disconnect();
    _managers.remove(account.id);
  }
}
