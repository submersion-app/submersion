import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive_storage_provider.dart';
import 'package:submersion/core/services/media_store/google_drive_media_object_store.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

/// The Google login as a session-managed, single-instance account. Auth
/// lives in GoogleSignIn.instance (OS/SDK session) -- there is no keychain
/// blob to re-key -- so this adapter delegates to the shared provider
/// singleton for session reuse.
class GoogleDriveAccountAdapter extends AccountProviderAdapter
    implements SyncCapable, MediaStoreCapable {
  GoogleDriveAccountAdapter({GoogleDriveStorageProvider? provider})
    : _provider =
          provider ??
          cloudProviderInstanceFor(CloudProviderType.googledrive)
              as GoogleDriveStorageProvider;

  final GoogleDriveStorageProvider _provider;

  @override
  AccountKind get kind => AccountKind.googledrive;

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async =>
      await _provider.isAuthenticated()
      ? AccountStatus.signedIn
      : AccountStatus.needsSignIn;

  @override
  Future<void> disconnect(domain.ConnectedAccount account) =>
      _provider.signOut();

  @override
  CloudStorageProvider syncProvider(domain.ConnectedAccount account) =>
      _provider;

  @override
  Future<MediaObjectStore?> mediaObjectStore(
    domain.ConnectedAccount account,
  ) async {
    final client = await _provider.mediaHttpClient();
    if (client == null) return null;
    return GoogleDriveMediaObjectStore(client: client);
  }
}
