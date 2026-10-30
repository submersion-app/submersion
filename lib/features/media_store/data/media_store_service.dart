import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
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
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

/// Builds the store adapter for [type], or null when the provider is not
/// usable right now (missing config, no silent Google session, iCloud
/// unavailable). Shared by the runtime provider and the connect flows.
///
/// [instanceFor] supplies the Google Drive provider, the only branch built
/// over a provider instance; S3, Dropbox and iCloud ignore it. It defaults
/// to the process-wide singletons and exists so a test can supply a
/// provider with a fake session (the same seam as
/// resolveHeadlessCloudProvider's).
Future<MediaObjectStore?> buildMediaObjectStore(
  CloudProviderType type, {
  S3Config? s3Config,
  CloudStorageProvider Function(CloudProviderType type)? instanceFor,
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
          (instanceFor ?? cloudProviderInstanceFor)(
                CloudProviderType.googledrive,
              )
              as GoogleDriveStorageProvider;
      // Probe once for "is there a session at all", then let the store
      // resolve the client per request: the authenticator closes and
      // replaces its client on every re-auth and this store is cached in a
      // long-lived runtime.
      if (await provider.mediaHttpClient() == null) return null;
      return GoogleDriveMediaObjectStore(
        clientSupplier: provider.mediaHttpClient,
        onAuthRejected: provider.mediaAuthRejected,
      );
    case CloudProviderType.icloud:
      final availability = await ICloudNativeService.getAvailability();
      if (availability != ICloudAvailability.available) return null;
      return ICloudMediaObjectStore(platform: NativeICloudMediaPlatform());
    case CloudProviderType.webdav:
      // WebDAV media is always attached through an account, so the runtime
      // resolves it with buildMediaObjectStoreForAccount; there is no
      // pre-account WebDAV attachment to rebuild here.
      return null;
    case CloudProviderType.git:
      // Never a media store: photos and videos in Git history would grow
      // the repository without bound.
      return null;
  }
}

/// Account-first store construction: resolve the account's
/// MediaStoreCapable adapter. Null when the kind lacks the capability or
/// this device has no working credentials for the account.
Future<MediaObjectStore?> buildMediaObjectStoreForAccount(
  domain.ConnectedAccount account,
  AccountProviderRegistry registry,
) async {
  final capable = registry.capabilityFor<MediaStoreCapable>(account.kind);
  if (capable == null) return null;
  return capable.mediaObjectStore(account);
}

class MediaStoreConnectResult {
  final String storeId;
  final bool createdNewStore;

  const MediaStoreConnectResult({
    required this.storeId,
    required this.createdNewStore,
  });
}

/// Attach and detach flows for the media store (design spec sections
/// 13-14). Owns no long-lived state; the runtime provider is invalidated
/// after these calls and rebuilds from persisted config.
class MediaStoreService {
  MediaStoreService({
    required MediaStoreCredentialsStore credentials,
    required MediaStoreAttachState attachState,
    required MediaStoresRepository storesRepository,
    required MediaRepository mediaRepository,
    List<Duration>? markerRetryBackoff,
  }) : _markerRetryBackoff = markerRetryBackoff ?? defaultMarkerRetryBackoff,
       _credentials = credentials,
       _attachState = attachState,
       _storesRepository = storesRepository,
       _mediaRepository = mediaRepository;

  /// How long to wait between attempts at the identity marker when the store
  /// answers that it cannot serve it yet.
  ///
  /// Attaching is a deliberate foreground action the user is watching, and
  /// on iCloud the container's copy of `store.json` may still be coming down
  /// when they choose the account. Failing on the first attempt would refuse
  /// an attach that succeeds seconds later, which is the shape issue #1356
  /// leaves behind now that an unreadable marker is no longer mistaken for
  /// an absent one.
  static const List<Duration> defaultMarkerRetryBackoff = [
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  final List<Duration> _markerRetryBackoff;

  /// The legacy S3 blob a pre-account attachment kept; cleared on detach so
  /// the runtime's legacy fallback cannot reattach behind the diver's back.
  final MediaStoreCredentialsStore _credentials;
  final MediaStoreAttachState _attachState;
  final MediaStoresRepository _storesRepository;

  /// Claims the stamps that name no store before moving to another one.
  final MediaRepository _mediaRepository;

  /// Attaches [store], built from the roster row [row], as the photo copies
  /// (issue #3482): today's marker check adopts the store already in that
  /// folder or starts one, and the attachment and the synced descriptor both
  /// name [row], so a second device holding the account joins with nothing
  /// to type. A null [store] means the account has no usable keys here.
  ///
  /// [replacing] moves an attached device to [store]: the current
  /// attachment stands until the marker check succeeds, and only then is
  /// it replaced and the legacy key blob cleared, so a failure leaves the
  /// device on the copies it had.
  ///
  /// With [withinGeneration], the attach goes ahead only while the
  /// attachment is still the one of that [MediaStoreAttachState.attachGeneration]
  /// once the marker check has answered: a caller deciding from what it read
  /// earlier (the guided reconnect, issue #2303) must not claim stamps for,
  /// or overwrite, an attachment made since. It throws, with nothing changed.
  Future<MediaStoreConnectResult> attachToAccountRow(
    domain.ConnectedAccount row,
    MediaObjectStore? store, {
    bool replacing = false,
    int? withinGeneration,
  }) async {
    final type = row.kind.cloudProviderType;
    if (store == null || type == null) {
      throw MediaStoreAccountUnusable(
        '${row.label} is not signed in or cannot hold copies on this device',
      );
    }
    // Read before anything changes: the store this device is on is the one
    // its unclaimed stamps were made in.
    final previous =
        await _attachState.attachedStoreId() ??
        (await _storesRepository.getActive())?.id;
    final ensured = await _ensureMarker(store);
    if (withinGeneration != null &&
        await _attachState.attachGeneration() != withinGeneration) {
      throw const MediaStoreException(
        'The photo copies changed on this device while reconnecting',
        kind: MediaStoreErrorKind.transient,
      );
    }
    final newId = ensured.marker.storeId;
    // Stamps naming no store were made in the store this device was on, or
    // else the one the library announces. Claim them for it before moving,
    // or they would count as copies in the new store (issue #3482).
    if (previous != null && previous != newId) {
      await _mediaRepository.claimUnownedStamps(previous);
    }
    // Replaces any attachment in one step and bumps its generation, so the
    // old store's worker stands down.
    await _attachState.setAttached(
      ensured.marker.storeId,
      providerType: type,
      accountId: row.id,
    );
    if (replacing) await _credentials.clear();
    await _storesRepository.upsertActive(
      storeId: ensured.marker.storeId,
      providerType: type.name,
      displayHint: row.label,
      accountId: row.id,
    );
    return MediaStoreConnectResult(
      storeId: ensured.marker.storeId,
      createdNewStore: ensured.created,
    );
  }

  /// Reads or creates the store's identity marker, waiting out a store that
  /// says it cannot serve it yet. Only [MediaStoreErrorKind.transient] is
  /// retried: an auth or fatal answer will not improve by asking again.
  Future<({StoreMarker marker, bool created})> _ensureMarker(
    MediaObjectStore store,
  ) async {
    final markers = StoreMarkerStore(store: store);
    for (var attempt = 0; ; attempt++) {
      try {
        return await markers.ensure();
      } on MediaStoreException catch (e) {
        if (e.kind != MediaStoreErrorKind.transient ||
            attempt >= _markerRetryBackoff.length) {
          rethrow;
        }
        await Future<void>.delayed(_markerRetryBackoff[attempt]);
      }
    }
  }

  /// Records this device's account on its store's descriptor when that
  /// names none (schema v302 added the column with no backfill), so a
  /// second device joins the copies in their own folder rather than a
  /// default one.
  Future<void> recordAttachedAccount() async {
    final storeId = await _attachState.attachedStoreId();
    final accountId = await _attachState.attachedAccountId();
    if (storeId == null || accountId == null) return;
    await _storesRepository.recordAccount(storeId, accountId);
  }

  /// The store the library most recently announced on one of [accountIds].
  Future<MediaStoreDescriptor?> storeOnAccounts(Iterable<String> accountIds) =>
      _storesRepository.latestOnAccounts(accountIds);

  /// Detaches this device. Credentials and attach state are cleared; the
  /// synced descriptor row and everything in the bucket remain.
  Future<void> disconnect() async {
    await _credentials.clear();
    await _attachState.clear();
  }
}

/// An account chosen for the copies that holds no usable keys on this
/// device, or cannot hold copies at all. Raised before anything changes;
/// the screens ask the diver to sign in rather than show [message].
class MediaStoreAccountUnusable extends MediaStoreException {
  const MediaStoreAccountUnusable(super.message)
    : super(kind: MediaStoreErrorKind.auth);
}
