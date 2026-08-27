import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive_storage_provider.dart';
import 'package:submersion/core/services/media_store/google_drive_media_object_store.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/cloud_storage/cloud_provider_instances.dart';

/// The Google login as a session-managed, single-instance account. Auth is
/// owned by whichever authenticator the provider selected -- the SDK session
/// in GoogleSignIn.instance on mobile and the sandboxed macOS build, or a
/// refresh token in GoogleDriveTokenStore wherever the loopback flow is used
/// (Windows, Linux, and the Developer ID macOS build). Either way this
/// adapter holds no credential of its own, so it delegates to the shared
/// core-level provider singleton (cloud_provider_instances) for session
/// reuse, avoiding a presentation -> core import cycle.
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
