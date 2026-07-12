import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/core/services/cloud_storage/icloud_storage_provider.dart';
import 'package:submersion/core/services/media_store/icloud_media_object_store.dart';
import 'package:submersion/core/services/media_store/icloud_media_platform.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';

/// The OS iCloud identity as a credential-less pseudo-account (program spec
/// open question 1, resolved: one implicit single-instance account). Status
/// is derived from container availability; disconnect is a no-op because
/// the sign-in belongs to the OS, not the app.
class ICloudAccountAdapter extends AccountProviderAdapter
    implements SyncCapable, MediaStoreCapable {
  ICloudAccountAdapter({
    Future<ICloudAvailability> Function()? availability,
    CloudStorageProvider? syncProviderInstance,
  }) : _availability = availability ?? ICloudNativeService.getAvailability,
       _syncProviderInstance = syncProviderInstance ?? ICloudStorageProvider();

  final Future<ICloudAvailability> Function() _availability;
  final CloudStorageProvider _syncProviderInstance;

  @override
  AccountKind get kind => AccountKind.icloud;

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async =>
      await _availability() == ICloudAvailability.available
      ? AccountStatus.signedIn
      : AccountStatus.unavailable;

  @override
  Future<void> disconnect(domain.ConnectedAccount account) async {}

  @override
  CloudStorageProvider syncProvider(domain.ConnectedAccount account) =>
      _syncProviderInstance;

  @override
  Future<MediaObjectStore?> mediaObjectStore(
    domain.ConnectedAccount account,
  ) async {
    if (await _availability() != ICloudAvailability.available) return null;
    return ICloudMediaObjectStore(platform: NativeICloudMediaPlatform());
  }
}
