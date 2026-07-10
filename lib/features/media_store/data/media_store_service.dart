import 'dart:io';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_api_client.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_manager.dart';
import 'package:submersion/core/services/cloud_storage/google_drive_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/media_store/dropbox_media_object_store.dart';
import 'package:submersion/core/services/media_store/google_drive_media_object_store.dart';
import 'package:submersion/core/services/media_store/icloud_media_object_store.dart';
import 'package:submersion/core/services/media_store/icloud_media_platform.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/media_store_credentials_store.dart';
import 'package:submersion/core/services/media_store/s3_media_object_store.dart';
import 'package:submersion/core/services/media_store/store_marker.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

/// Builds the store adapter for [type], or null when the provider is not
/// usable right now (missing config, no silent Google session, iCloud
/// unavailable). Shared by the runtime provider and the connect flows.
Future<MediaObjectStore?> buildMediaObjectStore(
  CloudProviderType type, {
  S3Config? s3Config,
}) async {
  switch (type) {
    case CloudProviderType.s3:
      if (s3Config == null) return null;
      return S3MediaObjectStore(
        client: S3ApiClient(s3Config),
        keyPrefix: s3Config.prefix,
      );
    case CloudProviderType.dropbox:
      final auth = DropboxAuthManager();
      if (await auth.loadAuth() == null) return null;
      return DropboxMediaObjectStore(
        client: DropboxApiClient(
          getAccessToken: auth.getAccessToken,
          onAccessTokenRejected: auth.invalidateAccessToken,
        ),
      );
    case CloudProviderType.googledrive:
      final provider =
          cloudProviderInstanceFor(CloudProviderType.googledrive)
              as GoogleDriveStorageProvider;
      final client = await provider.mediaHttpClient();
      if (client == null) return null;
      return GoogleDriveMediaObjectStore(client: client);
    case CloudProviderType.icloud:
      final availability = await ICloudNativeService.getAvailability();
      if (availability != ICloudAvailability.available) return null;
      return ICloudMediaObjectStore(platform: NativeICloudMediaPlatform());
  }
}

class MediaStoreConnectResult {
  final String storeId;
  final bool createdNewStore;

  const MediaStoreConnectResult({
    required this.storeId,
    required this.createdNewStore,
  });
}

/// Connect/test/disconnect flows for the media store (design spec
/// sections 13-14). Owns no long-lived state; the runtime provider is
/// invalidated after these calls and rebuilds from persisted config.
class MediaStoreService {
  MediaStoreService({
    required MediaStoreCredentialsStore credentials,
    required MediaStoreAttachState attachState,
    required MediaStoresRepository storesRepository,
    MediaObjectStore Function(S3Config config)? storeFactory,
    Future<MediaObjectStore?> Function()? dropboxStoreFactory,
    Future<MediaObjectStore?> Function()? googleDriveStoreFactory,
    Future<MediaObjectStore?> Function()? icloudStoreFactory,
  }) : _credentials = credentials,
       _attachState = attachState,
       _storesRepository = storesRepository,
       _storeFactory = storeFactory ?? _defaultStoreFactory,
       _dropboxStoreFactory =
           dropboxStoreFactory ??
           (() => buildMediaObjectStore(CloudProviderType.dropbox)),
       _googleDriveStoreFactory =
           googleDriveStoreFactory ??
           (() => buildMediaObjectStore(CloudProviderType.googledrive)),
       _icloudStoreFactory =
           icloudStoreFactory ??
           (() => buildMediaObjectStore(CloudProviderType.icloud));

  final MediaStoreCredentialsStore _credentials;
  final MediaStoreAttachState _attachState;
  final MediaStoresRepository _storesRepository;
  final MediaObjectStore Function(S3Config config) _storeFactory;
  final Future<MediaObjectStore?> Function() _dropboxStoreFactory;
  final Future<MediaObjectStore?> Function() _googleDriveStoreFactory;
  final Future<MediaObjectStore?> Function() _icloudStoreFactory;

  static MediaObjectStore _defaultStoreFactory(S3Config config) =>
      S3MediaObjectStore(client: S3ApiClient(config), keyPrefix: config.prefix);

  /// Live write+read-back+delete probe against the unsaved [config].
  /// Throws MediaStoreException on failure.
  Future<void> testConnection(S3Config config) async {
    _validate(config);
    final store = _storeFactory(config);
    const probeKey = 'smv1/.submersion-media-probe';
    final tmp = await _tempFile('probe');
    try {
      await tmp.writeAsString('probe', flush: true);
      await store.putFile(probeKey, tmp, contentType: 'text/plain');
      final info = await store.head(probeKey);
      if (info == null) {
        throw const MediaStoreException(
          'Probe object vanished after write',
          kind: MediaStoreErrorKind.fatal,
        );
      }
    } finally {
      try {
        await store.delete(probeKey);
      } on MediaStoreException {
        // Best-effort cleanup; a stranded probe object is harmless.
      }
      if (await tmp.exists()) await tmp.delete();
    }
  }

  /// Ensures the bucket carries a store marker (adopting an existing one),
  /// persists credentials and attach state, and announces the store in the
  /// synced descriptor table.
  Future<MediaStoreConnectResult> connectS3(S3Config config) async {
    _validate(config);
    final store = _storeFactory(config);
    final ensured = await StoreMarkerStore(store: store).ensure();
    await _credentials.save(config);
    await _attachState.setAttached(
      ensured.marker.storeId,
      providerType: CloudProviderType.s3,
    );
    await _storesRepository.upsertActive(
      storeId: ensured.marker.storeId,
      providerType: 's3',
      displayHint: '${config.bucket} @ ${config.displayHost}',
    );
    return MediaStoreConnectResult(
      storeId: ensured.marker.storeId,
      createdNewStore: ensured.created,
    );
  }

  /// Connects the media store through the user's Dropbox link (made in
  /// Cloud Sync settings); media lives in the Dropbox app folder.
  Future<MediaStoreConnectResult> connectDropbox() => _connectManaged(
    CloudProviderType.dropbox,
    'Dropbox',
    _dropboxStoreFactory,
  );

  /// Connects through the Google account session; media lives in this
  /// app's private Drive space.
  Future<MediaStoreConnectResult> connectGoogleDrive() => _connectManaged(
    CloudProviderType.googledrive,
    'Google Drive',
    _googleDriveStoreFactory,
  );

  /// Connects through the signed-in Apple ID's iCloud container.
  Future<MediaStoreConnectResult> connectICloud() =>
      _connectManaged(CloudProviderType.icloud, 'iCloud', _icloudStoreFactory);

  /// Shared managed-provider flow: no credentials-store write - managed
  /// providers keep credentials in their own auth stores.
  Future<MediaStoreConnectResult> _connectManaged(
    CloudProviderType type,
    String displayHint,
    Future<MediaObjectStore?> Function() factory,
  ) async {
    final store = await factory();
    if (store == null) {
      throw MediaStoreException(
        '$displayHint is not connected or unavailable on this device',
        kind: MediaStoreErrorKind.auth,
      );
    }
    final ensured = await StoreMarkerStore(store: store).ensure();
    await _attachState.setAttached(ensured.marker.storeId, providerType: type);
    await _storesRepository.upsertActive(
      storeId: ensured.marker.storeId,
      providerType: type.name,
      displayHint: displayHint,
    );
    return MediaStoreConnectResult(
      storeId: ensured.marker.storeId,
      createdNewStore: ensured.created,
    );
  }

  /// Detaches this device. Credentials and attach state are cleared; the
  /// synced descriptor row and everything in the bucket remain.
  Future<void> disconnect() async {
    await _credentials.clear();
    await _attachState.clear();
  }

  void _validate(S3Config config) {
    final error = config.validate();
    if (error != null) {
      throw MediaStoreException(error, kind: MediaStoreErrorKind.fatal);
    }
  }

  Future<File> _tempFile(String label) async {
    return File(
      '${Directory.systemTemp.path}/submersion_media_${label}_'
      '${DateTime.now().microsecondsSinceEpoch}',
    );
  }
}
