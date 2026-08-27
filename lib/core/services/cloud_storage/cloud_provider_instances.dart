import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/icloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';

/// Process-wide cloud storage provider singletons.
///
/// Core-level (not in the settings presentation layer) so both the sync
/// providers and the account adapters can share one instance per backend
/// without a presentation -> core import cycle. Session state (Google
/// silent auth, Dropbox token cache) must be shared, which is exactly why
/// these are singletons rather than per-call constructions.
final _googleDriveProvider = GoogleDriveStorageProvider();
final _icloudProvider = ICloudStorageProvider();
final _s3Provider = S3StorageProvider();
final _dropboxProvider = DropboxStorageProvider();

/// Concrete-typed access to the S3 singleton for the configuration UI
/// (load/save config, test connection).
S3StorageProvider get s3ProviderInstance => _s3Provider;

/// Concrete-typed access to the Dropbox singleton for the connect UI
/// (begin/complete authorization, account info).
DropboxStorageProvider get dropboxProviderInstance => _dropboxProvider;

/// The singleton instance backing a [CloudProviderType]. Shared by the
/// active provider resolution, old-backend cleanup (which must reach a
/// backend the user has switched away from), and the account adapters.
CloudStorageProvider cloudProviderInstanceFor(CloudProviderType type) {
  switch (type) {
    case CloudProviderType.icloud:
      return _icloudProvider;
    case CloudProviderType.googledrive:
      return _googleDriveProvider;
    case CloudProviderType.s3:
      return _s3Provider;
    case CloudProviderType.dropbox:
      return _dropboxProvider;
  }
}
