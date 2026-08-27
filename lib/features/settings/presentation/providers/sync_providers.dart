import 'dart:async';
import 'dart:io' show Platform;

import 'package:cryptography/cryptography.dart' show SecretKey;
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/domain/entities/storage_config.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/cloud_storage/cloud_provider_instances.dart';
export 'package:submersion/core/services/cloud_storage/cloud_provider_instances.dart'
    show cloudProviderInstanceFor;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_app.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';
import 'package:submersion/core/services/cloud_storage/dropbox_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/encrypting_cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';
import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart';
import 'package:submersion/core/services/sync/established_provider_store.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/library_replace_intent.dart';
import 'package:submersion/core/services/sync/sync_device_metadata.dart';
import 'package:submersion/core/services/sync/library_moved.dart';
import 'package:submersion/core/services/sync/library_moved_store.dart';
import 'package:submersion/core/services/sync/post_restore_sync_store.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';
import 'package:submersion/core/services/sync/sync_preferences.dart';
import 'package:submersion/core/services/sync/sync_cleanup_outcome.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Sync repository provider
final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepository();
});

/// Sync data serializer provider
final syncDataSerializerProvider = Provider<SyncDataSerializer>((ref) {
  return SyncDataSerializer();
});

/// Runtime iCloud availability for the current build/device. Drives the iCloud
/// provider tile's enabled state and its connection-failure messaging.
final iCloudAvailabilityProvider = FutureProvider<ICloudAvailability>((
  ref,
) async {
  return ICloudNativeService.getAvailability();
});

/// Whether the host is an Apple platform (iOS/macOS), where iCloud can exist at
/// all. Exposed as a provider so the iCloud tile is never enabled on non-Apple
/// platforms (even transiently while [iCloudAvailabilityProvider] loads), and so
/// widget tests can simulate an Apple platform on a non-Apple CI host.
final isApplePlatformProvider = Provider<bool>(
  (ref) => Platform.isIOS || Platform.isMacOS,
);

/// Whether the host is Linux, where video transcoding depends on a system
/// ffmpeg. A provider (not Platform.isLinux inline) so widget tests can
/// simulate Linux on any CI host — same pattern as [isApplePlatformProvider].
final isLinuxPlatformProvider = Provider<bool>((ref) => Platform.isLinux);

/// Sync preferences provider
final syncPreferencesProvider = Provider<SyncPreferences>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SyncPreferences(prefs);
});

/// Device-local custody of the encryption master key + keyslot mirror.
final encryptionKeyStoreProvider = Provider<EncryptionKeyStore>((ref) {
  return EncryptionKeyStore();
});

/// Encryption lifecycle operations (enable / unlock / rotate / self-heal).
final syncEncryptionServiceProvider = Provider<SyncEncryptionService>((ref) {
  return SyncEncryptionService(
    keyStore: ref.watch(encryptionKeyStoreProvider),
    preferences: ref.watch(syncPreferencesProvider),
  );
});

/// Unlocked-session state: null = encryption disabled, or enabled but locked
/// (no key on this device yet). Non-null makes the provider wrap encrypting.
class EncryptionSessionState {
  final UnlockedKey key;
  final SecretKey dataKey;

  const EncryptionSessionState({required this.key, required this.dataKey});
}

class EncryptionKeyNotifier extends StateNotifier<EncryptionSessionState?> {
  EncryptionKeyNotifier(this._keyStore, this._preferences) : super(null);

  final EncryptionKeyStore _keyStore;
  final SyncPreferences _preferences;
  Future<EncryptionSessionState?>? _loading;

  /// Memoized load from the key store; sync triggers await this before
  /// resolving the sync service so the provider wrap is already in place.
  Future<EncryptionSessionState?> ensureLoaded() {
    return _loading ??= _load();
  }

  Future<EncryptionSessionState?> _load() async {
    if (state != null) return state;
    // The stored key outlives a disable (old encrypted backups stay
    // restorable via EncryptionKeyStore directly); a SESSION only exists
    // while the feature flag is on, so the provider wrap follows the flag.
    if (!_preferences.syncEncryptionEnabled) return null;
    final key = await _keyStore.loadKey();
    if (key == null) return null;
    final dataKey = await Keyslots.deriveDataKey(key.mlk);
    if (!mounted) return null;
    state = EncryptionSessionState(key: key, dataKey: dataKey);
    return state;
  }

  Future<void> setUnlocked(UnlockedKey key) async {
    final dataKey = await Keyslots.deriveDataKey(key.mlk);
    if (!mounted) return;
    state = EncryptionSessionState(key: key, dataKey: dataKey);
    _loading = Future.value(state);
  }

  Future<void> clear() async {
    state = null;
    // Reset the memoization to null (not a completed null future) so a later
    // ensureLoaded() genuinely re-reads secure storage -- e.g. a disable
    // followed by a re-enable in the same container must pick up the new key.
    _loading = null;
  }
}

final encryptionKeyNotifierProvider =
    StateNotifierProvider<EncryptionKeyNotifier, EncryptionSessionState?>((
      ref,
    ) {
      return EncryptionKeyNotifier(
        ref.watch(encryptionKeyStoreProvider),
        ref.watch(syncPreferencesProvider),
      );
    });

/// Library epoch persistence (mirror + pending replace intent).
final libraryEpochStoreProvider = Provider<LibraryEpochStore>((ref) {
  return LibraryEpochStore(ref.watch(sharedPreferencesProvider));
});

/// "Library moved" persistence (acknowledged-move signature + pending
/// old-backend cleanup target) for backend switches.
final libraryMovedStoreProvider = Provider<LibraryMovedStore>((ref) {
  return LibraryMovedStore(ref.watch(sharedPreferencesProvider));
});

/// Merge-restore "sync once on next launch" intent.
final postRestoreSyncStoreProvider = Provider<PostRestoreSyncStore>((ref) {
  return PostRestoreSyncStore(ref.watch(sharedPreferencesProvider));
});

/// Providers this install has successfully synced to (survives restore).
final establishedProviderStoreProvider = Provider<EstablishedProviderStore>((
  ref,
) {
  return EstablishedProviderStore(ref.watch(sharedPreferencesProvider));
});

/// Behavior settings for auto-sync
class SyncBehaviorSettings {
  final bool autoSyncEnabled;
  final bool syncOnLaunch;
  final bool syncOnResume;

  const SyncBehaviorSettings({
    required this.autoSyncEnabled,
    required this.syncOnLaunch,
    required this.syncOnResume,
  });

  SyncBehaviorSettings copyWith({
    bool? autoSyncEnabled,
    bool? syncOnLaunch,
    bool? syncOnResume,
  }) {
    return SyncBehaviorSettings(
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      syncOnLaunch: syncOnLaunch ?? this.syncOnLaunch,
      syncOnResume: syncOnResume ?? this.syncOnResume,
    );
  }
}

class SyncBehaviorNotifier extends StateNotifier<SyncBehaviorSettings> {
  final SyncPreferences _prefs;

  SyncBehaviorNotifier(this._prefs)
    : super(
        SyncBehaviorSettings(
          autoSyncEnabled: _prefs.autoSyncEnabled,
          syncOnLaunch: _prefs.syncOnLaunch,
          syncOnResume: _prefs.syncOnResume,
        ),
      );

  Future<void> setAutoSyncEnabled(bool value) async {
    await _prefs.setAutoSyncEnabled(value);
    state = state.copyWith(autoSyncEnabled: value);
  }

  Future<void> setSyncOnLaunch(bool value) async {
    await _prefs.setSyncOnLaunch(value);
    state = state.copyWith(syncOnLaunch: value);
  }

  Future<void> setSyncOnResume(bool value) async {
    await _prefs.setSyncOnResume(value);
    state = state.copyWith(syncOnResume: value);
  }
}

final syncBehaviorProvider =
    StateNotifierProvider<SyncBehaviorNotifier, SyncBehaviorSettings>((ref) {
      return SyncBehaviorNotifier(ref.watch(syncPreferencesProvider));
    });

/// Selected cloud provider type
final selectedCloudProviderTypeProvider = StateProvider<CloudProviderType?>(
  (ref) => null,
);

/// Whether Google Drive can be offered on this platform/build. True on
/// iOS/macOS/Android; on Windows/Linux only when the Desktop-app OAuth
/// client is compiled in (GoogleDriveClientConfig).
final googleDriveAvailableProvider = FutureProvider<bool>((ref) {
  return cloudProviderInstanceFor(CloudProviderType.googledrive).isAvailable();
});

/// Signed-in Google account email for the provider tile subtitle, or null
/// when Google Drive is not the selected provider, is not authenticated, or
/// no account is known.
///
/// Selecting `isAuthenticated` serves two purposes, and the value matters as
/// much as the subscription. As a subscription it re-runs on connect and
/// sign-out without re-running on every sync progress tick. As a value it
/// suppresses a STALE subtitle: GoogleSignInAuthenticator.handleAuthFailure()
/// deliberately keeps `_currentUser` so a transient token refresh cannot blank
/// a still-valid account, which means getUserEmail() keeps returning an
/// address after a revoked grant. Without this gate the tile would keep
/// advertising a connected account that can no longer sync.
final googleDriveAccountEmailProvider = FutureProvider<String?>((ref) async {
  final type = ref.watch(selectedCloudProviderTypeProvider);
  if (type != CloudProviderType.googledrive) return null;
  final isAuthenticated = ref.watch(
    syncStateProvider.select((s) => s.isAuthenticated),
  );
  if (!isAuthenticated) return null;
  return cloudProviderInstanceFor(CloudProviderType.googledrive).getUserEmail();
});

/// The sync account for [type]. The pre-account selection UI picks provider
/// TYPES; this shim maps a type onto the accounts model so selection state
/// stays consistent until the Phase 3 UI selects accounts directly.
///
/// Preference order: the persisted sync account (when it still matches the
/// kind), then for single-instance kinds the kind's account, else a fresh
/// row. S3 never adopts an arbitrary existing account: S3 accounts are
/// instances (sync-S3 vs media-S3), so grabbing the newest could silently
/// select the media-storage endpoint for sync.
Future<domain.ConnectedAccount> ensureAccountForProviderType(
  CloudProviderType type,
  ConnectedAccountsRepository repo, {
  SyncRepository? syncRepository,
  S3CredentialsStore? s3Credentials,
}) async {
  final kind = AccountKind.fromCloudProviderType(type);
  final persistedId = await (syncRepository ?? SyncRepository())
      .getSyncAccountId();
  if (persistedId != null) {
    final persisted = await repo.getById(persistedId);
    if (persisted != null && persisted.kind == kind) return persisted;
  }
  if (kind == AccountKind.s3) {
    // S3 accounts are instances, so the endpoint identifies them. Read the
    // legacy config (the source of truth on this path, mirrored by
    // _mirrorLegacyCredentials) to derive that identity. Without it, fall
    // back to a fresh row: an account with no resolvable endpoint cannot be
    // matched to any other, and the deduplicator will canonicalize it once
    // the config is readable.
    final config = await (s3Credentials ?? S3CredentialsStore()).load();
    if (config == null) {
      return repo.create(
        kind: kind,
        label: cloudProviderInstanceFor(type).providerName,
      );
    }
    return repo.ensure(
      kind: kind,
      naturalKey: s3NaturalKey(config),
      label: '${config.bucket} @ ${config.displayHost}',
    );
  }
  return repo.ensure(
    kind: kind,
    naturalKey: naturalKeyForKind(kind)!,
    label: cloudProviderInstanceFor(type).providerName,
  );
}

/// File-scoped logger for the top-level sync providers (the provider bodies
/// below are not class members, so they cannot use SyncNotifier's `_log`).
const _providersLog = LoggerService('SyncProviders');

/// The connected account driving sync, derived from the selected provider
/// type and persisted to sync metadata.
///
/// The connect UIs (S3 config page, Dropbox dialog) still write credentials
/// to the LEGACY keychain keys, which remain the source of truth. Here we
/// mirror those legacy blobs into the account's per-account key
/// (overwrite), so account-first resolution in [cloudStorageProviderProvider]
/// always reads current credentials. This runs on every derivation (launch,
/// provider selection, and explicit invalidation after a config edit), and
/// covers every connect path — settings pages and the setup wizard alike —
/// without each having to re-key. iCloud/Google Drive are session-managed
/// (no keychain blob) and skip the mirror.
// no-tick: derivation WITH side effects -- it calls setSyncAccount and mirrors
// credentials. A tick on the accounts table would re-run those writes on every
// account change, which writes the accounts table again. The selection is
// re-derived on each launch and on a deliberate provider-type change, which is
// the intended trigger.
final selectedSyncAccountProvider = FutureProvider<domain.ConnectedAccount?>((
  ref,
) async {
  final type = ref.watch(selectedCloudProviderTypeProvider);
  if (type == null) return null;
  final repo = ref.watch(connectedAccountsRepositoryProvider);
  try {
    final account = await ensureAccountForProviderType(
      type,
      repo,
      syncRepository: ref.read(syncRepositoryProvider),
      s3Credentials: ref.read(s3CredentialsStoreProvider),
    );
    await ref
        .read(syncRepositoryProvider)
        .setSyncAccount(accountId: account.id, providerType: type);
    await _mirrorLegacyCredentials(ref, account);
    return account;
  } catch (e, st) {
    // Returning null degrades resolution to the legacy singleton, which is
    // the correct fallback: the selection is re-derived on every launch, so
    // a failed write (teardown race) must not surface as a sync error, and
    // a failed credential mirror must NOT leave account-first resolution
    // reading a stale/missing per-account key. Log (with error + stack) so
    // the fallback is diagnosable in the field without changing behaviour.
    _providersLog.warning(
      'Sync account derivation failed; falling back to legacy resolution',
      error: e,
      stackTrace: st,
    );
    return null;
  }
});

/// Keep the account's per-account credential blob an exact mirror of the
/// legacy source-of-truth key, so account-first resolution never reads a
/// stale copy — and a cleared legacy credential (sign-out / remove) can
/// neither be read from nor resurrected into the per-account key. Copies
/// when the legacy key is present, deletes the per-account key when absent.
///
/// Deliberately NOT swallowed: if the mirror fails (keychain error), the
/// per-account key is in an unknown state, so this rethrows to
/// [selectedSyncAccountProvider], whose catch returns a null account —
/// which makes [cloudStorageProviderProvider] fall back to the legacy
/// singleton (still valid) rather than resolve from a stale/missing
/// per-account key. The next derivation retries the mirror.
Future<void> _mirrorLegacyCredentials(
  Ref ref,
  domain.ConnectedAccount account,
) async {
  final legacyKey = switch (account.kind) {
    AccountKind.s3 => S3CredentialsStore.storageKey,
    AccountKind.dropbox => DropboxAuthStore.storageKey,
    // Session-managed / not a sync kind: no keychain blob to mirror.
    AccountKind.googledrive ||
    AccountKind.icloud ||
    AccountKind.adobeLightroom => null,
  };
  if (legacyKey == null) return;
  await ref
      .read(accountCredentialsStoreProvider)
      .mirrorLegacy(legacyKey: legacyKey, accountId: account.id);
}

/// Cloud storage provider instance (null if none selected or custom folder mode)
///
/// When using custom folder mode, app-managed cloud sync is disabled to prevent
/// conflicts with external sync services (Dropbox, Google Drive desktop, etc.)
final cloudStorageProviderProvider = Provider<CloudStorageProvider?>((ref) {
  // Check if using custom folder mode - disable app-managed sync
  final storageConfigState = ref.watch(storageConfigNotifierProvider);
  if (storageConfigState.config.mode == StorageLocationMode.customFolder) {
    return null; // External sync handles it via the custom folder
  }

  final providerType = ref.watch(selectedCloudProviderTypeProvider);
  if (providerType == null) return null;

  // Account-first resolution: build the raw provider from the selected
  // account's adapter, which reads per-account credentials (kept current by
  // selectedSyncAccountProvider's legacy mirror). Fall back to the legacy
  // singleton — always keyed by the current providerType, and valid because
  // the connect UIs still write the legacy keys — when the account is not
  // usable yet, so sync can never resolve to nothing.
  //
  // The account is trusted only once selectedSyncAccountProvider has SETTLED
  // on data. `.value` retains the PREVIOUS account while the provider is
  // (re)loading, which happens in two windows that must both fall back:
  //   * providerType just changed (S3 -> Dropbox): the retained account is of
  //     the wrong kind and would resolve to the wrong backend; and
  //   * an in-place credential edit (S3 config save / Dropbox reconnect)
  //     invalidates the provider to re-mirror -- during that reload the kind
  //     still matches, but the per-account key is momentarily stale while the
  //     legacy key already holds the new creds.
  // Treating a loading/refreshing state as "no account" keeps both windows on
  // the type-keyed legacy singleton, whose creds are always current. The kind
  // guard then covers the settled-but-wrong-kind edge.
  final accountAsync = ref.watch(selectedSyncAccountProvider);
  final account = accountAsync.isLoading ? null : accountAsync.value;
  final matchesType =
      account != null &&
      account.kind == AccountKind.fromCloudProviderType(providerType);
  CloudStorageProvider raw;
  if (matchesType) {
    final capable = ref
        .watch(accountProviderRegistryProvider)
        .capabilityFor<SyncCapable>(account.kind);
    raw =
        capable?.syncProvider(account) ??
        cloudProviderInstanceFor(providerType);
  } else {
    raw = cloudProviderInstanceFor(providerType);
  }
  // End-to-end encryption: with an unlocked session, every byte through this
  // provider is sealed/opened at the byte boundary (spec 4.1). No session
  // (disabled, or enabled-but-locked) resolves to the raw provider; a locked
  // library is detected downstream and halts with awaitingPassphrase.
  final session = ref.watch(encryptionKeyNotifierProvider);
  if (session == null) return raw;
  return EncryptingCloudStorageProvider(
    raw,
    dataKey: session.dataKey,
    libraryKeyId: session.key.libraryKeyId,
  );
});

/// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    syncRepository: ref.watch(syncRepositoryProvider),
    serializer: ref.watch(syncDataSerializerProvider),
    cloudProvider: ref.watch(cloudStorageProviderProvider),
    syncInitializer: ref.watch(syncInitializerProvider),
    epochStore: ref.watch(libraryEpochStoreProvider),
    encryptionService: ref.watch(syncEncryptionServiceProvider),
    localizations: () => l10nForLocaleTag(ref.read(localeProvider)),
  );
});

/// Sync status enum
enum SyncStatus { idle, syncing, success, error, hasConflicts }

/// Sync state
class SyncState {
  final SyncStatus status;
  final String? message;
  final double? progress;
  final DateTime? lastSync;
  final int pendingChanges;
  final int conflicts;

  /// Peers held during the last pull because their declared compatibility
  /// floor exceeds this build's schema, as (name, shortId) pairs. Drives the
  /// newer-schema banner; cleared when a fresh sync starts. A null name means
  /// the peer published none, and the UI renders a short id instead.
  final List<({String? name, String shortId})> newerSchemaPeerLabels;

  /// Peers held back by the library-epoch fence during the last pull, as
  /// (name, shortId) pairs. Drives the "needs to adopt" banner; cleared when a
  /// fresh sync starts. A null name means the peer published none, and the
  /// page renders the localized `device <shortId>` label instead -- resolving
  /// it here is impossible because a notifier has no BuildContext.
  final List<({String? name, String shortId})> skippedPeerLabels;
  final bool isAuthenticated;
  final bool firstSyncAwaitingConfirmation;

  /// True while the one forced post-restore sync is running. Drives the
  /// app-root "Syncing your restored library..." notice; never persisted.
  final bool postRestoreSyncing;

  /// True when the cloud library was replaced from a backup under an epoch
  /// this device has not accepted; sync is paused until the user adopts.
  final bool replaceAwaitingAdoption;

  /// True when the cloud library is end-to-end encrypted and this device has
  /// no matching key; sync is paused until the user enters the passphrase.
  final bool needsPassphrase;

  /// The replacement marker behind [replaceAwaitingAdoption] (who/when).
  final LibraryEpochMarker? replaceMarker;

  /// Non-null when the backend this device is on carries a "library moved"
  /// marker pointing elsewhere that the user has not yet acknowledged -- a
  /// straggler left behind by another device's backend switch. Advisory only:
  /// sync still works, but the banner offers to follow the move.
  final LibraryMovedMarker? movedMarker;

  /// Non-null after the first successful sync on a freshly switched-to backend
  /// when an old backend is still armed for cleanup: the providerId of that
  /// old backend, whose orphaned data the user can now choose to delete.
  final String? cleanupOldBackendProviderId;

  static const Object _messageSentinel = Object();
  static const Object _markerSentinel = Object();
  static const Object _movedSentinel = Object();
  static const Object _cleanupSentinel = Object();

  const SyncState({
    this.status = SyncStatus.idle,
    this.message,
    this.progress,
    this.lastSync,
    this.pendingChanges = 0,
    this.conflicts = 0,
    this.newerSchemaPeerLabels = const [],
    this.skippedPeerLabels = const [],
    this.isAuthenticated = false,
    this.firstSyncAwaitingConfirmation = false,
    this.postRestoreSyncing = false,
    this.replaceAwaitingAdoption = false,
    this.needsPassphrase = false,
    this.replaceMarker,
    this.movedMarker,
    this.cleanupOldBackendProviderId,
  });

  SyncState copyWith({
    SyncStatus? status,
    Object? message = _messageSentinel,
    double? progress,
    DateTime? lastSync,
    int? pendingChanges,
    int? conflicts,
    List<({String? name, String shortId})>? newerSchemaPeerLabels,
    List<({String? name, String shortId})>? skippedPeerLabels,
    bool? isAuthenticated,
    bool? firstSyncAwaitingConfirmation,
    bool? postRestoreSyncing,
    bool? replaceAwaitingAdoption,
    bool? needsPassphrase,
    Object? replaceMarker = _markerSentinel,
    Object? movedMarker = _movedSentinel,
    Object? cleanupOldBackendProviderId = _cleanupSentinel,
  }) {
    return SyncState(
      status: status ?? this.status,
      message: identical(message, _messageSentinel)
          ? this.message
          : message as String?,
      progress: progress ?? this.progress,
      lastSync: lastSync ?? this.lastSync,
      pendingChanges: pendingChanges ?? this.pendingChanges,
      conflicts: conflicts ?? this.conflicts,
      newerSchemaPeerLabels:
          newerSchemaPeerLabels ?? this.newerSchemaPeerLabels,
      skippedPeerLabels: skippedPeerLabels ?? this.skippedPeerLabels,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      firstSyncAwaitingConfirmation:
          firstSyncAwaitingConfirmation ?? this.firstSyncAwaitingConfirmation,
      postRestoreSyncing: postRestoreSyncing ?? this.postRestoreSyncing,
      replaceAwaitingAdoption:
          replaceAwaitingAdoption ?? this.replaceAwaitingAdoption,
      needsPassphrase: needsPassphrase ?? this.needsPassphrase,
      replaceMarker: identical(replaceMarker, _markerSentinel)
          ? this.replaceMarker
          : replaceMarker as LibraryEpochMarker?,
      movedMarker: identical(movedMarker, _movedSentinel)
          ? this.movedMarker
          : movedMarker as LibraryMovedMarker?,
      cleanupOldBackendProviderId:
          identical(cleanupOldBackendProviderId, _cleanupSentinel)
          ? this.cleanupOldBackendProviderId
          : cleanupOldBackendProviderId as String?,
    );
  }
}

/// What the first sync would combine: shown to the user before the first
/// library-merging sync is allowed to run.
class FirstSyncMergeInfo {
  final int peerFileCount;
  final int localDiveCount;

  const FirstSyncMergeInfo({
    required this.peerFileCount,
    required this.localDiveCount,
  });
}

/// Blast radius for the Replace confirmation: how much of this device's
/// library is about to become authoritative, and how many peers will be asked
/// to adopt it.
///
/// [peerFileCount] is null only when the peer listing FAILED or timed out --
/// never when it succeeded and found none. The dialog then falls back to a
/// count-less sentence rather than blocking, because a pre-check must not gate
/// the escape hatch it is describing.
class ReplacePreflight {
  const ReplacePreflight({required this.localDiveCount, this.peerFileCount});

  final int localDiveCount;
  final int? peerFileCount;

  bool get hasPeerCount => peerFileCount != null;
}

/// Sync state notifier
class SyncNotifier extends StateNotifier<SyncState> {
  final SyncRepository _syncRepository;
  final Ref _ref;
  final _log = LoggerService.forClass(SyncNotifier);
  StreamSubscription<void>? _changeSubscription;
  Timer? _autoSyncTimer;
  Timer? _pendingCountTimer;
  int _pendingCountGeneration = 0;
  bool _syncInFlight = false;

  SyncNotifier(this._syncRepository, this._ref) : super(const SyncState()) {
    _initialize();
    _listenForChanges();
  }

  /// Get the current sync service (reads dynamically to get latest cloudProvider)
  SyncService get _syncService => _ref.read(syncServiceProvider);

  /// Localizations for the status text this notifier writes into
  /// [SyncState.message]. The notifier runs outside the widget tree
  /// (launch sync, resume sync, post-write debounce), so there is no
  /// BuildContext; resolve from the same locale setting MaterialApp uses.
  AppLocalizations get _l10n => l10nForLocaleTag(_ref.read(localeProvider));

  Future<void> _initialize() async {
    if (!mounted) return;
    // Restore the saved provider before reading sync state: restoreLastProvider
    // is async, so without awaiting it _initialize can race ahead and read a
    // null provider, skipping the post-restore intent and replaced-library
    // surfacing for the whole session. Mirrors _maybeSyncOnLaunch awaiting
    // reconcileDeviceIdentityProvider.
    try {
      await _ref.read(restoreLastProviderProvider.future);
    } catch (_) {
      // Non-fatal: proceed with whatever provider state exists.
    }
    if (!mounted) return;
    await refreshState();
    if (!mounted) return;

    // Every post-restore intent below needs a cloud provider. Without one, a
    // persisted Replace intent would drive performSync() into a "no provider
    // configured" error state on launch -- even for users who never enabled
    // cloud sync. Keep the intent dormant until a provider exists; it survives
    // in libraryEpochStore for a later launch that has one.
    final provider = _ref.read(cloudStorageProviderProvider);
    if (provider == null) return;

    // A Replace restore persists its cloud side as a pending intent; execute
    // it as soon as the app is back up, regardless of auto-sync settings.
    if (_ref.read(libraryEpochStoreProvider).pendingReplace != null) {
      unawaited(performSync());
      return;
    }

    // A Merge restore persists a post-restore intent: the restore dialog's
    // Merge choice is the consent, so force one sync that bypasses the
    // first-contact gate (auto:false) regardless of the auto-sync toggles.
    if (_ref.read(postRestoreSyncStoreProvider).pending) {
      unawaited(_runPostRestoreSync());
      return;
    }

    // On the other devices, surface a Replace-everywhere adoption proactively
    // (even with auto-sync off) so a paused device is never hidden behind a
    // manual Sync Now.
    unawaited(_detectReplacedLibraryForSurfacing());
  }

  /// Force the one consented post-restore sync. `performSync(auto:false)` skips
  /// the first-contact gate; the success path clears the intent.
  Future<void> _runPostRestoreSync() async {
    if (!mounted) return;
    state = state.copyWith(postRestoreSyncing: true);
    await performSync();
    if (mounted) state = state.copyWith(postRestoreSyncing: false);
  }

  /// On a device that did NOT restore, surface a Replace-everywhere adoption
  /// proactively -- even with auto-sync off -- so the pause is never hidden
  /// behind a manual Sync Now. Detection only; the destructive adopt stays
  /// behind the confirmation dialog.
  Future<void> _detectReplacedLibraryForSurfacing() async {
    final marker = await libraryReplaceInfo();
    if (marker == null || !mounted) return;
    // Surface only -- never sync from here. Only devices that HOLD dives pause
    // and need the unmissable prompt; an empty device has nothing to lose and
    // auto-adopts through performSync's own awaiting-adoption path on its next
    // sync. Syncing from a detection hook would also race other launch-time
    // syncs (and test setups), so detection stays pure: read marker, set state.
    final diveCount = await _ref.read(diveRepositoryProvider).getDiveCount();
    if (!mounted || diveCount == 0) return;
    state = state.copyWith(
      replaceAwaitingAdoption: true,
      replaceMarker: marker,
    );
  }

  void _listenForChanges() {
    _changeSubscription = SyncEventBus.changes.listen((_) {
      // Refresh the displayed count REGARDLESS of the auto-sync setting.
      // _scheduleAutoSync returns immediately when auto-sync is off, which is
      // how the "Synced" chip used to survive a whole session of edits (#990):
      // nothing else recomputes pendingChanges between syncs.
      _schedulePendingCountRefresh();
      _scheduleAutoSync();
    });
  }

  /// Debounced: one local action (a bulk edit, a multi-entity save) fires many
  /// bus events, and each refresh is two queries.
  void _schedulePendingCountRefresh() {
    _pendingCountTimer?.cancel();
    _pendingCountTimer = Timer(
      const Duration(milliseconds: 400),
      _refreshPendingCount,
    );
  }

  /// Deliberately narrower than [refreshState]: this runs on every local write,
  /// so it must not probe the network via isSyncAvailable() nor rewrite
  /// status/message (which would stomp a sync or an error the user is reading).
  ///
  /// The debounce cancels pending TIMERS, not an in-flight refresh: once the
  /// queries are running, a later write can start a second refresh alongside
  /// the first. [_pendingCountGeneration] makes the newest caller the only one
  /// allowed to publish, so a slow earlier query cannot land a stale count on
  /// top of a fresher one.
  Future<void> _refreshPendingCount() async {
    if (!mounted) return;
    // A sync clears pending records as it publishes; its own post-sync
    // refreshState lands the settled number.
    if (state.status == SyncStatus.syncing) return;
    final generation = ++_pendingCountGeneration;
    try {
      final providerId = _ref.read(cloudStorageProviderProvider)?.providerId;
      final count = await _syncRepository.getUnsyncedChangeCount(
        providerId: providerId,
      );
      if (!mounted || generation != _pendingCountGeneration) return;
      if (state.pendingChanges == count) return;
      state = state.copyWith(pendingChanges: count);
    } catch (e) {
      // A count is advisory: leave the last known value rather than pushing
      // the whole page into an error state over a failed status query.
      _log.error('Failed to refresh pending count', error: e);
    }
  }

  void _scheduleAutoSync() {
    final settings = _ref.read(syncBehaviorProvider);
    if (!settings.autoSyncEnabled) return;
    if (state.status == SyncStatus.syncing) return;

    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer(const Duration(seconds: 5), () {
      performSync(auto: true);
    });
  }

  void _setupProgressCallback() {
    _syncService.setProgressCallback((progress) {
      // A launch-triggered sync can outlive this notifier (container torn
      // down mid-upload); progress ticks must not touch a disposed notifier.
      if (!mounted) return;
      state = state.copyWith(
        progress: progress.progress,
        message: progress.message,
      );
    });
  }

  /// Refresh the sync state from the database
  Future<void> refreshState() async {
    try {
      // Scope the displayed "last synced" to the active backend: after a
      // switch, showing the cursor from the old backend would claim we are
      // synced with a backend we have never contacted.
      final activeProvider = _ref.read(cloudStorageProviderProvider);
      final lastSync = await _syncRepository.getLastSyncTime(
        forProvider: activeProvider?.providerId,
      );
      // Same composite count the live refresh uses (record edits + tombstones
      // above the publish watermark), so the two paths cannot disagree.
      final pendingCount = await _syncRepository.getUnsyncedChangeCount(
        providerId: activeProvider?.providerId,
      );
      final conflictCount = await _syncRepository.getConflictCount();
      final isAvailable = await _syncService.isSyncAvailable();

      if (!mounted) return;
      state = state.copyWith(
        lastSync: lastSync,
        pendingChanges: pendingCount,
        conflicts: conflictCount,
        isAuthenticated: isAvailable,
        status: conflictCount > 0 ? SyncStatus.hasConflicts : SyncStatus.idle,
        message: null,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        status: SyncStatus.error,
        message: _l10n.settings_cloudSync_message_loadStateFailed(e),
      );
    }
  }

  /// Non-null when the NEXT sync would be this device's first contact with
  /// existing cloud data while this device already holds dives -- the case
  /// where a sync irreversibly combines two libraries (and duplicates any
  /// dives that were imported separately on each device). The UI must
  /// confirm before running that sync; auto-sync defers it entirely.
  Future<FirstSyncMergeInfo?> firstSyncMergeInfo() async {
    try {
      final provider = _ref.read(cloudStorageProviderProvider);
      if (provider == null) return null;
      // An established device is never first-contact: a restore wipes the
      // in-DB cursor (lastSyncTime), but this anchor survives, so the gate
      // must not re-fire for a device that already merged here.
      if (_ref
          .read(establishedProviderStoreProvider)
          .contains(provider.providerId)) {
        return null;
      }
      // Scoped: first contact is per-backend. A cursor minted against a
      // backend the user switched away from must not mask the first,
      // library-combining sync against the new one.
      final lastSync = await _syncRepository.getLastSyncTime(
        forProvider: provider.providerId,
      );
      if (lastSync != null) return null;
      final localDives = await _ref.read(diveRepositoryProvider).getDiveCount();
      if (localDives == 0) return null;
      final peers = await _ref
          .read(syncInitializerProvider)
          .peerSyncFiles(provider)
          .timeout(const Duration(seconds: 8));
      if (peers.isEmpty) return null;
      return FirstSyncMergeInfo(
        peerFileCount: peers.length,
        localDiveCount: localDives,
      );
    } catch (e) {
      // The guard must never block sync outright; on failure fall through
      // to normal behavior.
      _log.warning('First-contact check failed: $e');
      return null;
    }
  }

  /// Non-null when the cloud library was replaced under an epoch this device
  /// has not accepted -- the next sync would halt for adoption. Mirrors the
  /// [firstSyncMergeInfo] pre-check pattern for the Sync Now button.
  Future<LibraryEpochMarker?> libraryReplaceInfo() async {
    try {
      // Load any stored encryption key BEFORE resolving the provider, for the
      // same reason performSync does: the provider wrap watches the SESSION, so
      // reading it first hands back the raw provider and every byte of an
      // encrypted library reads as an opaque SBE1 envelope. This runs from an
      // unawaited launch hook (_detectReplacedLibraryForSurfacing), which is
      // precisely when the session has not been loaded yet -- so without this
      // an encrypted library could never surface a replace at all.
      await _ref.read(encryptionKeyNotifierProvider.notifier).ensureLoaded();
      if (!mounted) return null;
      final provider = _ref.read(cloudStorageProviderProvider);
      if (provider == null) return null;
      final store = _ref.read(libraryEpochStoreProvider);
      if (store.pendingReplace != null) return null; // we ARE the replacer
      final marker = await _syncService
          .readLibraryEpochMarker(provider)
          .timeout(const Duration(seconds: 8));
      if (marker == null) return null;
      final accepted =
          await _syncRepository.getLastAcceptedEpochId() ??
          store.lastAcceptedEpochId;
      if (marker.epochId == accepted) return null;
      return marker;
    } on SyncEncryptionRequired {
      // Encrypted with no key on this device yet: an expected state, not a
      // fault. performSync halts with awaitingPassphrase and the UI prompts,
      // so this pre-check simply has nothing to report -- logging it as a
      // warning on every launch would be noise.
      _log.debug('Library replace pre-check skipped: library is locked');
      return null;
    } catch (e) {
      // Never block the button on this pre-check; performSync gates anyway.
      _log.warning('Library replace pre-check failed: $e');
      return null;
    }
  }

  /// (name, shortId) per peer the epoch fence held back. Returns the raw
  /// pieces rather than finished strings: a notifier has no BuildContext, so
  /// the unnamed-device fallback has to be localized by the page. Sorted so
  /// the banner text is stable across syncs instead of reordering each pull.
  ///
  /// Static and visible for testing for the same reason as
  /// [SyncService.pullResultMessages]: it is pure, and the naming/fallback/
  /// ordering rules deserve tests that do not need a container.
  @visibleForTesting
  static List<({String? name, String shortId})> skippedPeerLabels(
    SyncResult result,
  ) => heldPeerLabels(result.skippedPeerDeviceIds, result.skippedPeerNames);

  /// (name, shortId) per held peer, shared by the epoch-fence and
  /// newer-schema banners. Sorted so the banner text is stable across syncs
  /// instead of reordering each pull.
  @visibleForTesting
  static List<({String? name, String shortId})> heldPeerLabels(
    Set<String> ids,
    Map<String, String> names,
  ) {
    final entries =
        ids.map((id) {
          final name = names[id];
          final shortId = id.length > 8 ? id.substring(0, 8) : id;
          return (
            name: (name != null && name.isNotEmpty) ? name : null,
            shortId: shortId,
          );
        }).toList()..sort(
          (a, b) => (a.name ?? a.shortId).compareTo(b.name ?? b.shortId),
        );
    return entries;
  }

  /// Blast radius for the Replace confirmation. Never throws: a failed or slow
  /// peer listing degrades to a null count, because a pre-check must not gate
  /// the escape hatch it is describing.
  Future<ReplacePreflight> replacePreflight() async {
    final localDives = await _ref.read(diveRepositoryProvider).getDiveCount();
    final provider = _ref.read(cloudStorageProviderProvider);
    if (provider == null) {
      return ReplacePreflight(localDiveCount: localDives);
    }
    try {
      final peers = await _ref
          .read(syncInitializerProvider)
          .peerSyncFiles(provider)
          .timeout(const Duration(seconds: 8));
      return ReplacePreflight(
        localDiveCount: localDives,
        peerFileCount: peers.length,
      );
    } catch (e) {
      _log.warning('Replace preflight peer listing failed: $e');
      return ReplacePreflight(localDiveCount: localDives);
    }
  }

  /// Make this device's library the one every device uses.
  ///
  /// Arms the replace intent, then syncs: the epoch gate checks pendingReplace
  /// BEFORE reading the cloud marker, so this also works on a device currently
  /// fenced off awaiting someone else's adoption -- it is the universal escape
  /// hatch. If the sync fails the intent survives, and the next sync (or the
  /// launch sync) retries rather than merging.
  ///
  /// The CALLER is responsible for the safety backup (cloud_sync_page runs it
  /// via backupServiceProvider to avoid a provider import cycle), matching
  /// [adoptReplacedLibrary].
  Future<void> replaceCloudLibraryFromThisDevice() async {
    final provider = _ref.read(cloudStorageProviderProvider);
    if (provider == null) {
      state = state.copyWith(
        status: SyncStatus.error,
        message: _l10n.settings_cloudSync_message_noProviderConfigured,
      );
      return;
    }
    final store = _ref.read(libraryEpochStoreProvider);
    // Already armed (a previous attempt failed mid-flight): do not mint a
    // second epoch, just drive the pending one to completion.
    if (store.pendingReplace == null) {
      await LibraryReplaceIntent(
        SyncDeviceMetadata(_syncRepository).resolve,
        store,
      ).mint();
    }
    await performSync();
  }

  /// After a successful sync, if an old backend is armed for cleanup and we
  /// just synced against a DIFFERENT backend, surface the cleanup offer. The
  /// different-backend guard means the first real sync on the new backend has
  /// landed -- only then is deleting the old copy safe.
  Future<void> _surfaceOldBackendCleanupOffer() async {
    final pending = _ref.read(libraryMovedStoreProvider).pendingCleanup;
    if (pending == null) return;
    final active = _ref.read(cloudStorageProviderProvider);
    if (active == null || active.providerId == pending) return;
    if (!mounted) return;
    state = state.copyWith(cleanupOldBackendProviderId: pending);
  }

  /// Record this device leaving [oldProvider] for the backend [toProviderId].
  /// Called when the user confirms a backend switch, BEFORE the active
  /// provider selection changes (so [oldProvider] is still reachable):
  ///
  /// - stamps the (possibly legacy/unstamped) cursor for the old backend, so
  ///   it cannot read as "synced here" against the new one;
  /// - leaves a "library moved" marker on the old backend so a straggler still
  ///   pointed there learns where the library went instead of syncing into an
  ///   abandoned copy forever;
  /// - arms the old backend for optional cleanup after the first successful
  ///   sync on the new one.
  ///
  /// All steps are best-effort: a switch must never be blocked by the old
  /// backend being unreachable.
  Future<void> recordBackendDeparture({
    required CloudStorageProvider oldProvider,
    required String toProviderId,
    String? toProviderName,
  }) async {
    final oldId = oldProvider.providerId;
    try {
      await _syncRepository.stampLegacyCursorProvider(oldId);
    } catch (e) {
      _log.warning('Could not stamp cursor for old backend $oldId: $e');
    }

    final meta = await _deviceMetadata();
    final marker = LibraryMovedMarker(
      movedAt: DateTime.now().millisecondsSinceEpoch,
      toProviderId: toProviderId,
      toProviderName: toProviderName,
      deviceId: meta.$1,
      deviceName: meta.$2,
      appVersion: meta.$3,
    );
    await _syncService.writeLibraryMovedMarker(oldProvider, marker);
    await _ref.read(libraryMovedStoreProvider).setPendingCleanup(oldId);
    _log.info('Recorded backend departure $oldId -> $toProviderId');
  }

  /// Network pre-check: does the backend we are on carry a "moved" marker
  /// pointing at a DIFFERENT backend that we have not acknowledged? If so,
  /// surface it; the banner offers to follow the move. Never throws.
  Future<void> checkLibraryMoved() async {
    try {
      final provider = _ref.read(cloudStorageProviderProvider);
      if (provider == null) return;
      final marker = await _syncService.readLibraryMovedMarker(provider);
      if (!mounted) return;
      final store = _ref.read(libraryMovedStoreProvider);
      // A marker pointing at the backend we are already on is not a move away
      // from us; ignore it. So is one the user already dismissed.
      if (marker == null ||
          marker.toProviderId == provider.providerId ||
          store.isAcknowledged(marker)) {
        if (state.movedMarker != null) {
          state = state.copyWith(movedMarker: null);
        }
        return;
      }
      state = state.copyWith(movedMarker: marker);
    } catch (e) {
      _log.warning('Library moved pre-check failed: $e');
    }
  }

  /// Dismiss the "library moved" banner and remember the dismissal so the
  /// same move does not re-notify on the next sync.
  Future<void> acknowledgeMoved() async {
    final marker = state.movedMarker;
    if (marker != null) {
      await _ref.read(libraryMovedStoreProvider).acknowledge(marker);
    }
    if (!mounted) return;
    state = state.copyWith(movedMarker: null);
  }

  /// Delete the orphaned data left on a backend the user switched away from,
  /// in response to the post-switch cleanup offer. Best-effort; clears the
  /// offer regardless so it is not presented again.
  Future<void> cleanupOldBackendData() async {
    final id = state.cleanupOldBackendProviderId;
    final store = _ref.read(libraryMovedStoreProvider);
    if (id != null) {
      try {
        final type = CloudProviderType.values.firstWhere((t) => t.name == id);
        await _syncService.cleanupOldBackend(cloudProviderInstanceFor(type));
      } catch (e) {
        _log.warning('Old-backend cleanup failed for $id: $e');
      }
    }
    await store.clearPendingCleanup();
    if (!mounted) return;
    state = state.copyWith(cleanupOldBackendProviderId: null);
  }

  /// Decline the post-switch cleanup offer: leave the old backend's data in
  /// place (the user may still want it) and stop offering.
  Future<void> dismissOldBackendCleanup() async {
    await _ref.read(libraryMovedStoreProvider).clearPendingCleanup();
    if (!mounted) return;
    state = state.copyWith(cleanupOldBackendProviderId: null);
  }

  /// Device identity for a marker: (deviceId, deviceName, appVersion). Each
  /// piece degrades to a safe default; markers are shown in banners so the
  /// origin must always be displayable.
  Future<(String, String?, String?)> _deviceMetadata() async {
    final identity = await SyncDeviceMetadata(_syncRepository).resolve();
    return (identity.id, identity.name, identity.appVersion);
  }

  /// Adopt the replaced cloud library. The CALLER is responsible for the
  /// safety backup (cloud_sync_page runs it via backupServiceProvider to
  /// avoid a provider import cycle). Ends with a follow-up sync that uploads
  /// this device's freshly stamped file.
  Future<void> adoptReplacedLibrary() async {
    if (_syncInFlight || state.status == SyncStatus.syncing) return;
    state = state.copyWith(
      status: SyncStatus.syncing,
      message: _l10n.settings_cloudSync_message_adopting,
    );
    final result = await _syncService.adoptReplacedLibrary();
    if (!result.isSuccess) {
      state = state.copyWith(
        status: SyncStatus.error,
        message: result.message ?? _l10n.settings_cloudSync_message_adoptFailed,
      );
      return;
    }
    await realignActiveDiverAfterDataReplace(
      _ref.read(sharedPreferencesProvider),
    );
    state = state.copyWith(
      status: SyncStatus.idle,
      replaceAwaitingAdoption: false,
      replaceMarker: null,
      message: null,
    );
    await performSync();
  }

  /// Perform a sync operation.
  ///
  /// [auto] marks unattended triggers (launch, resume, post-write debounce).
  /// An auto sync defers this device's FIRST library-combining contact to a
  /// manual, user-confirmed Sync Now instead of merging unannounced.
  Future<void> performSync({bool auto = false}) async {
    _log.debug('performSync() called');
    if (_syncInFlight || state.status == SyncStatus.syncing) {
      _log.debug('Already syncing, returning early');
      return;
    }
    _syncInFlight = true;
    try {
      // Load any stored encryption key BEFORE resolving the sync service:
      // the provider wrap watches the session, so a launch-triggered sync
      // must not race the async key load and run unencrypted-eyed.
      await _ref.read(encryptionKeyNotifierProvider.notifier).ensureLoaded();
      if (!mounted) return;

      if (auto) {
        final info = await firstSyncMergeInfo();
        if (info != null) {
          _log.info(
            'Deferring auto sync: first contact with existing cloud data '
            'needs user confirmation',
          );
          state = state.copyWith(
            firstSyncAwaitingConfirmation: true,
            message: _l10n.settings_cloudSync_message_firstSyncNeedsConfirm,
          );
          return;
        }
      }

      state = state.copyWith(
        status: SyncStatus.syncing,
        message: _l10n.settings_cloudSync_message_startingSync,
        progress: 0.0,
        newerSchemaPeerLabels: const [],
        skippedPeerLabels: const [],
        firstSyncAwaitingConfirmation: false,
        replaceAwaitingAdoption: false,
        needsPassphrase: false,
        replaceMarker: null,
      );

      // Set up progress callback on the current sync service
      _setupProgressCallback();

      _log.debug('Calling _syncService.performSync()...');
      try {
        var result = await _syncService.performSync();
        _log.debug('Result: ${result.status}, message: ${result.message}');
        // This notifier can be disposed while a launch-triggered sync is in
        // flight; never touch state after an await without re-checking.
        if (!mounted) return;

        if (result.status == SyncResultStatus.awaitingAdoption) {
          final diveCount = await _ref
              .read(diveRepositoryProvider)
              .getDiveCount();
          if (!mounted) return;
          if (diveCount == 0) {
            // Nothing local to lose: adopt silently, like an empty device
            // joining sync, then run the normal sync to upload our file.
            final adopt = await _syncService.adoptReplacedLibrary();
            if (adopt.isSuccess) {
              await realignActiveDiverAfterDataReplace(
                _ref.read(sharedPreferencesProvider),
              );
              result = await _syncService.performSync();
            } else {
              result = adopt;
            }
            if (!mounted) return;
          } else {
            state = state.copyWith(
              status: SyncStatus.idle,
              replaceAwaitingAdoption: true,
              replaceMarker: result.replaceMarker,
              message: _l10n.settings_cloudSync_message_replacePaused,
              progress: null,
            );
            return;
          }
        }

        if (result.status == SyncResultStatus.awaitingPassphrase) {
          state = state.copyWith(
            status: SyncStatus.idle,
            needsPassphrase: true,
            message:
                result.message ??
                _l10n.settings_cloudSync_message_encryptedPaused,
            progress: null,
          );
          return;
        }

        if (result.isSuccess) {
          final defaultMessage = result.conflictsFound > 0
              ? _l10n.settings_cloudSync_message_completedWithConflicts
              : _l10n.settings_cloudSync_message_completedSuccessfully;
          state = state.copyWith(
            status: result.conflictsFound > 0
                ? SyncStatus.hasConflicts
                : SyncStatus.success,
            message: result.message ?? defaultMessage,
            lastSync: result.lastSyncTime,
            conflicts: result.conflictsFound,
            newerSchemaPeerLabels: heldPeerLabels(
              result.newerSchemaPeerDeviceIds,
              result.newerSchemaPeerNames,
            ),
            skippedPeerLabels: skippedPeerLabels(result),
            progress: 1.0,
          );
          // Mark this provider established and consume any post-restore intent:
          // a future restore that wipes the in-DB cursor must not make this
          // device look like first-contact again, and the Merge restore's
          // one-shot intent is now satisfied.
          final syncedProvider = _ref.read(cloudStorageProviderProvider);
          if (syncedProvider != null) {
            await _ref
                .read(establishedProviderStoreProvider)
                .add(syncedProvider.providerId);
          }
          await _ref.read(postRestoreSyncStoreProvider).clear();
          await _surfaceOldBackendCleanupOffer();
          // A straggler syncing into a backend another device moved away from
          // learns of the move here -- the moment it is actively writing into
          // the now-orphaned copy.
          await checkLibraryMoved();
          // A GPS track that just synced in may cover dives imported earlier
          // on this device (phone-records/desktop-imports race): sweep
          // GPS-less dives against the freshly merged tracks. Best-effort.
          try {
            await _ref.read(gpsTrackMatchServiceProvider).sweep();
          } catch (e, stackTrace) {
            // Matching is an enhancement; the sync itself succeeded. Log so
            // "why didn't my dives get positioned?" is diagnosable.
            _log.error(
              'Post-sync GPS match sweep failed',
              error: e,
              stackTrace: stackTrace,
            );
          }
        } else {
          state = state.copyWith(
            status: SyncStatus.error,
            message:
                result.message ?? _l10n.settings_cloudSync_message_syncFailed,
            progress: null,
          );
        }
      } catch (e) {
        if (!mounted) return;
        final l10n = _l10n;
        final phase =
            state.message ?? l10n.settings_cloudSync_message_phaseDefault;
        state = state.copyWith(
          status: SyncStatus.error,
          message: l10n.settings_cloudSync_message_syncErrorDuring(phase, e),
          progress: null,
        );
      }

      // Refresh state after a brief delay so status is readable.
      if (state.status == SyncStatus.success ||
          state.status == SyncStatus.hasConflicts) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        await refreshState();
      }
    } finally {
      _syncInFlight = false;
    }
  }

  /// Resolve a conflict
  Future<void> resolveConflict(
    String entityType,
    String recordId,
    ConflictResolution resolution,
  ) async {
    await _syncService.resolveConflict(entityType, recordId, resolution);
    await refreshState();
  }

  /// Sign out from the cloud provider
  ///
  /// For S3 the credentials are hand-entered, so disconnecting only
  /// deselects the provider; the stored configuration survives and the
  /// S3 settings page offers the explicit, destructive
  /// "Remove Configuration" instead.
  Future<void> signOut() async {
    final selected = _ref.read(selectedCloudProviderTypeProvider);
    if (selected != CloudProviderType.s3) {
      await _syncService.signOut();
      // Account-first resolution means _syncService.signOut() cleared the
      // PER-ACCOUNT Dropbox blob (and revoked); also clear the legacy
      // source-of-truth key, otherwise the UI still reads it as connected
      // and the next credential mirror would resurrect it. Best-effort: a
      // keychain failure must not abort sign-out (selection/prefs/state
      // still need clearing); the mirror would delete the per-account key
      // on the next derivation regardless.
      if (selected == CloudProviderType.dropbox) {
        try {
          await DropboxAuthStore().clear();
        } catch (e, st) {
          _log.warning(
            'Could not clear legacy Dropbox key on sign-out',
            error: e,
            stackTrace: st,
          );
        }
      }
    } else {
      // Match SyncService.signOut()'s metadata clearing without the
      // provider sign-out, so the hand-entered credentials survive.
      await _syncRepository.setCloudProvider(null);
      await _syncRepository.setRemoteFileId(null);
    }
    _ref.read(selectedCloudProviderTypeProvider.notifier).state = null;
    // Clear the saved provider from SharedPreferences
    await _ref.read(syncInitializerProvider).saveProvider(null);
    // The S3 tile watches this; a sign-out (or future config change) must
    // not leave it showing stale state.
    _ref.invalidate(s3ConfigProvider);
    state = const SyncState();
  }

  /// Turns cloud sync off as part of a database reset.
  ///
  /// Without this, wiping the local database is immediately undone: the
  /// post-reset launch sync ([SubmersionApp]'s `_maybeSyncOnLaunch`) merges
  /// the entire cloud library back in, resurrecting the data the user just
  /// cleared. Disabling auto-sync closes that launch/resume path and signing
  /// out disconnects the provider so a manual sync cannot re-pull either.
  ///
  /// The cloud library itself is left intact -- reconnecting sync re-adopts
  /// it -- so this is a local-only reset, not a fleet-wide wipe.
  Future<void> disableForDatabaseReset() async {
    // Cancel any in-flight auto-sync debounce first. Its callback calls
    // performSync(auto: true) WITHOUT re-checking autoSyncEnabled, so a timer
    // scheduled by a write just before the reset would otherwise still fire and
    // race the DB wipe (or re-pull). Flipping autoSyncEnabled below only stops
    // NEW timers from being scheduled.
    _autoSyncTimer?.cancel();

    // Two independent guards against the post-reset re-pull: disabling
    // auto-sync closes the launch/resume sync, and signing out disconnects the
    // provider so a manual sync cannot pull either. Attempt BOTH even if one
    // throws -- either surviving still helps the reset stick -- then surface
    // the first failure so the caller can log it.
    Object? firstError;
    StackTrace? firstStack;
    Future<void> attempt(Future<void> Function() op) async {
      try {
        await op();
      } catch (e, st) {
        firstError ??= e;
        firstStack ??= st;
      }
    }

    await attempt(
      () => _ref.read(syncBehaviorProvider.notifier).setAutoSyncEnabled(false),
    );
    await attempt(signOut);

    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStack!);
    }
  }

  /// Reset sync state
  ///
  /// Also adopts a brand-new device identity. Reset is the user-facing
  /// recovery for sync gone wrong, and the worst such state -- two installs
  /// syncing as the same device after cross-device restores -- is only
  /// fixable with a fresh identity. Restore detection deliberately preserves
  /// the anchored identity, so a clone survives everything short of this.
  /// The retired identity's cloud file is removed best-effort: after the id
  /// changes it would otherwise be merged back as a stale "peer" forever.
  Future<void> resetSyncState() async {
    final oldDeviceId = await _syncRepository.getDeviceId();
    await _syncService.resetSyncState();
    await _ref.read(syncInitializerProvider).adoptFreshIdentity();
    await _syncService.deleteDeviceSyncFile(oldDeviceId);
    // Reset is the manual escape hatch: drop any stuck replace intent and
    // un-pause an awaiting-adoption state.
    await _ref.read(libraryEpochStoreProvider).clearPendingReplace();
    await _ref.read(postRestoreSyncStoreProvider).clear();
    await _ref.read(establishedProviderStoreProvider).clear();
    state = state.copyWith(replaceAwaitingAdoption: false, replaceMarker: null);
    await refreshState();
  }

  /// Comprehensive local repair: the full [resetSyncState] (fresh identity,
  /// this device's cloud file removed, pending-replace/awaiting-adoption
  /// cleared) PLUS the last-accepted epoch marker and leftover base temp files,
  /// ending with any error cleared. The guaranteed local escape from a wedged
  /// sync (issue #509); dive data is never touched.
  Future<void> repairSync() async {
    await resetSyncState();
    await _ref.read(libraryEpochStoreProvider).clear();
    await _syncService.deleteLeftoverBaseTempFiles();
    state = state.copyWith(status: SyncStatus.idle, message: null);
    await refreshState();
  }

  /// Remove THIS device's sync files from the active backend (issue #509,
  /// cloud clear 3a). Safe: other devices keep syncing; frees this device's
  /// changeset log, base parts, and manifest.
  Future<SyncCleanupOutcome> removeThisDeviceCloudFiles({
    SyncCleanupProgress? onProgress,
  }) async {
    final deviceId = await _syncRepository.getDeviceId();
    final outcome = await _syncService.deleteDeviceSyncFile(
      deviceId,
      onProgress: onProgress,
    );
    await refreshState();
    return outcome;
  }

  /// Wipe ALL sync data on the active backend, including the epoch/moved
  /// markers (issue #509, cloud clear 3b). Every device re-establishes from
  /// scratch. Dive data is untouched.
  Future<SyncCleanupOutcome> wipeAllCloudSyncData({
    SyncCleanupProgress? onProgress,
  }) async {
    final outcome = await _syncService.wipeAllSyncDataOnActiveProvider(
      onProgress: onProgress,
    );
    await refreshState();
    return outcome;
  }

  /// Escape a stuck library replacement whose uploader went offline (issue
  /// #509): rebuild this backend from THIS device's library, then publish it so
  /// peers adopt from us. Un-pauses the awaiting-adoption state.
  Future<void> rebuildBackendFromThisDevice({
    SyncCleanupProgress? onProgress,

    /// Fires once the clear-out is done and the (much longer) full-library
    /// republish begins, so a caller showing progress can retitle rather than
    /// leave a completed file count on screen for minutes (issue #1032).
    void Function()? onPublishStarted,
  }) async {
    final result = await _syncService.rebuildBackendFromThisDevice(
      onProgress: onProgress,
    );
    if (result.status != SyncResultStatus.success) {
      // Keep the error visible: refreshState (which recomputes status from the
      // repository) must NOT run here, or it would clear the reason.
      state = state.copyWith(status: SyncStatus.error, message: result.message);
      return;
    }
    state = state.copyWith(
      replaceAwaitingAdoption: false,
      replaceMarker: null,
      status: SyncStatus.idle,
      message: null,
    );
    await _ref.read(libraryEpochStoreProvider).clearPendingReplace();
    onPublishStarted?.call();
    await performSync(); // publish our library as the epoch's base
    await refreshState();
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _pendingCountTimer?.cancel();
    _changeSubscription?.cancel();
    super.dispose();
  }
}

/// Sync state provider
final syncStateProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(ref.watch(syncRepositoryProvider), ref);
});

/// Last sync time provider (for display)
final lastSyncTimeProvider = Provider<DateTime?>((ref) {
  return ref.watch(syncStateProvider).lastSync;
});

/// Is sync enabled provider
final isSyncEnabledProvider = Provider<bool>((ref) {
  // Check if cloud sync is disabled due to custom folder mode
  if (ref.watch(isCloudSyncDisabledByCustomFolderProvider)) {
    return false;
  }
  return ref.watch(selectedCloudProviderTypeProvider) != null;
});

/// Whether cloud sync is disabled because custom folder mode is active
final isCloudSyncDisabledByCustomFolderProvider = Provider<bool>((ref) {
  final storageConfigState = ref.watch(storageConfigNotifierProvider);
  return storageConfigState.config.mode == StorageLocationMode.customFolder;
});

/// Pending changes count provider
final pendingChangesCountProvider = Provider<int>((ref) {
  return ref.watch(syncStateProvider).pendingChanges;
});

/// Conflicts count provider
final conflictsCountProvider = Provider<int>((ref) {
  return ref.watch(syncStateProvider).conflicts;
});

/// Is syncing provider
final isSyncingProvider = Provider<bool>((ref) {
  return ref.watch(syncStateProvider).status == SyncStatus.syncing;
});

/// Sync progress provider
final syncProgressProvider = Provider<double?>((ref) {
  return ref.watch(syncStateProvider).progress;
});

/// Sync message provider
final syncMessageProvider = Provider<String?>((ref) {
  return ref.watch(syncStateProvider).message;
});

/// Get conflicts provider
final conflictsProvider = FutureProvider<List<SyncConflict>>((ref) async {
  final syncService = ref.watch(syncServiceProvider);
  return syncService.getConflicts();
});

/// Sync initializer provider
final syncInitializerProvider = Provider<SyncInitializer>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SyncInitializer(
    syncRepository: ref.watch(syncRepositoryProvider),
    prefs: prefs,
    localizations: () => l10nForLocaleTag(ref.read(localeProvider)),
  );
});

/// Sync check on launch provider
/// Returns the result of checking sync status on app launch
final syncLaunchCheckProvider = FutureProvider<SyncCheckResult>((ref) async {
  final initializer = ref.watch(syncInitializerProvider);
  final provider = ref.watch(cloudStorageProviderProvider);
  return initializer.checkSyncOnLaunch(provider);
});

/// Reconcile the sync device identity on app launch.
///
/// Detects a database restore -- the on-disk database no longer matches the
/// anchors mirrored outside it: a rotated instance token (the primary signal,
/// which catches a same-device backup) or the device id -- and re-baselines
/// sync so a rewound baseline can't stall sync or resurrect deletes. Runs
/// unconditionally at startup, independent of whether a cloud provider is
/// configured. See [SyncInitializer.reconcileDeviceIdentity].
final reconcileDeviceIdentityProvider = FutureProvider<DeviceIdentityStatus>((
  ref,
) async {
  final initializer = ref.watch(syncInitializerProvider);
  return initializer.reconcileDeviceIdentity();
});

/// Restore last used provider on app launch
final restoreLastProviderProvider = FutureProvider<void>((ref) async {
  final initializer = ref.watch(syncInitializerProvider);
  final lastProvider = initializer.getLastProvider();
  if (lastProvider != null) {
    // Defer mutation to avoid changing provider state during initialization.
    await Future<void>.microtask(() {
      ref.read(selectedCloudProviderTypeProvider.notifier).state = lastProvider;
    });
  }
});

/// Direct access to the S3 provider singleton for the configuration UI
/// (load/save config, test connection).
final s3StorageProviderInstanceProvider = Provider<S3StorageProvider>(
  (ref) => s3ProviderInstance,
);

/// The stored S3 configuration, or null when S3 has not been set up.
/// Invalidate after saving or removing the configuration.
final s3ConfigProvider = FutureProvider<S3Config?>((ref) async {
  return ref.watch(s3StorageProviderInstanceProvider).loadConfig();
});

/// Direct access to the Dropbox provider singleton for the connect UI
/// (begin/complete authorization, account info).
final dropboxStorageProviderInstanceProvider = Provider<DropboxStorageProvider>(
  (ref) => dropboxProviderInstance,
);

/// The stored Dropbox connection, or null when Dropbox is not connected.
/// Invalidate after connecting or disconnecting.
final dropboxAuthDataProvider = FutureProvider<DropboxAuthData?>((ref) async {
  return ref.watch(dropboxStorageProviderInstanceProvider).loadAuth();
});

/// Whether this build carries a Dropbox app key; the settings tile hides
/// otherwise.
final dropboxConfiguredProvider = Provider<bool>(
  (ref) => dropboxAppKey.isNotEmpty,
);
