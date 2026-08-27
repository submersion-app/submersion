import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/cloud_provider_instances.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/encrypting_cloud_storage_provider.dart';
import 'package:submersion/core/services/database_location_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart'
    show lastCloudProviderFromPrefs;
import 'package:submersion/core/services/sync/sync_preferences.dart';

const _log = LoggerService('HeadlessCloudProvider');

/// The configured cloud provider, resolved without a `ProviderScope`.
///
/// The foreground app resolves the same thing through
/// `cloudStorageProviderProvider`; a headless isolate (the Workmanager
/// scheduled backup) has no Riverpod container, so it rebuilds the answer
/// from the two stores that ARE reachable there: SharedPreferences (which
/// provider was selected, which storage mode is active) and secure storage
/// (credentials, and the master library key).
///
/// Differences from the foreground resolution, both deliberate:
///   * account-first resolution is skipped -- picking a connected account
///     needs the database-backed registry. The legacy per-type singleton it
///     falls back to is always valid, because the connect UIs keep writing
///     the legacy credential keys.
///   * a provider whose auth cannot be re-established headlessly (Google
///     Drive needs an interactive session) still resolves here; the upload
///     then fails and the caller keeps its local-only artifact.
///
/// Returns null when nothing should be uploaded: no provider selected, an
/// unreadable selection, or custom-folder storage mode (where an external
/// sync client owns the folder and app-managed sync is off).
Future<CloudStorageProvider?> resolveHeadlessCloudProvider({
  required SharedPreferences prefs,
  EncryptionKeyStore? encryptionKeyStore,
  CloudStorageProvider Function(CloudProviderType type)? instanceFor,
}) async {
  try {
    final storage = await DatabaseLocationService(prefs).getStorageConfig();
    if (storage.isCustomLocation) return null;

    final type = lastCloudProviderFromPrefs(prefs);
    if (type == null) return null;

    final raw = (instanceFor ?? cloudProviderInstanceFor)(type);

    // End-to-end encryption: mirror the foreground wrap so nothing this
    // provider stores can be plaintext by accident. Backup artifacts frame
    // themselves and are exempt from the decorator, so for a scheduled
    // backup this is a safety net rather than the active codec.
    if (!SyncPreferences(prefs).syncEncryptionEnabled) return raw;
    final key = await (encryptionKeyStore ?? EncryptionKeyStore()).loadKey();
    if (key == null) return raw;
    return EncryptingCloudStorageProvider(
      raw,
      dataKey: await Keyslots.deriveDataKey(key.mlk),
      libraryKeyId: key.libraryKeyId,
    );
  } catch (e, stack) {
    // A locked keychain or an unreadable preference must not take the whole
    // scheduled task down: resolving to no provider degrades to a local
    // backup, which is what this isolate did before it could reach the cloud.
    _log.warning(
      'Headless cloud provider resolution failed; staying local-only',
      error: e,
      stackTrace: stack,
    );
    return null;
  }
}
