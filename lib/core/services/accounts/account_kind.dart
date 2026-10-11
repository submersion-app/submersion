import 'package:submersion/core/data/repositories/sync_repository.dart';

/// The kinds of endpoints a ConnectedAccount can represent. The first five
/// mirror [CloudProviderType]; connector kinds (Lightroom now, Immich/SMB
/// later per the program spec) have no cloud provider equivalent.
enum AccountKind {
  dropbox,
  googledrive,
  icloud,
  s3,
  webdav,
  adobeLightroom;

  /// The sync/media-store provider this kind corresponds to, or null for
  /// media-source connector kinds.
  CloudProviderType? get cloudProviderType => switch (this) {
    AccountKind.dropbox => CloudProviderType.dropbox,
    AccountKind.googledrive => CloudProviderType.googledrive,
    AccountKind.icloud => CloudProviderType.icloud,
    AccountKind.s3 => CloudProviderType.s3,
    AccountKind.webdav => CloudProviderType.webdav,
    AccountKind.adobeLightroom => null,
  };

  static AccountKind fromCloudProviderType(CloudProviderType type) =>
      switch (type) {
        CloudProviderType.dropbox => AccountKind.dropbox,
        CloudProviderType.googledrive => AccountKind.googledrive,
        CloudProviderType.icloud => AccountKind.icloud,
        CloudProviderType.s3 => AccountKind.s3,
        CloudProviderType.webdav => AccountKind.webdav,
      };
}
