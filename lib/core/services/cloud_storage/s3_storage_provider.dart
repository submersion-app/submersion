import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Builds an [S3ApiClient] for a config; injectable for tests.
typedef S3ApiClientFactory = S3ApiClient Function(S3Config config);

/// S3-compatible object storage implementation of [CloudStorageProvider]
/// (AWS S3, MinIO, Cloudflare R2, Backblaze B2, NAS appliances).
///
/// Semantic mappings onto the OAuth-shaped interface:
/// - fileId is the full object key; "folders" are the configured key prefix
///   (S3 has no folders, so createFolder is a lookup, not a write).
/// - authenticate() is a live read+write probe of the stored config.
/// - getUserEmail() returns the account label `<bucket> @ <host>`.
class S3StorageProvider
    with CloudStorageProviderMixin
    implements CloudStorageProvider {
  static final _log = LoggerService.forClass(S3StorageProvider);

  /// Basename of the temporary object written and removed by the probe.
  static const String probeObjectName = '.submersion-probe';

  S3StorageProvider({
    S3CredentialsStore? store,
    S3ApiClientFactory? apiClientFactory,
  }) : _store = store ?? S3CredentialsStore(),
       _apiClientFactory = apiClientFactory ?? S3ApiClient.new;

  final S3CredentialsStore _store;
  final S3ApiClientFactory _apiClientFactory;

  S3Config? _cachedConfig;
  S3ApiClient? _client;

  @override
  String get providerName => 'S3-Compatible Storage';

  @override
  String get providerId => 's3';

  @override
  Future<bool> isAvailable() async => true;

  /// True iff a config blob exists in secure storage (presence-only; no
  /// network -- this runs on UI rebuild paths). Platform keychain failures
  /// PROPAGATE by design, unlike the iCloud/Drive providers which swallow
  /// to false: a locked keychain must not read as "not configured". Every
  /// sync call path (refreshState, checkSyncOnLaunch, performSync) guards
  /// with try/catch.
  @override
  Future<bool> isAuthenticated() async => (await _loadConfig()) != null;

  /// The stored configuration, for the settings UI. Null when unset.
  Future<S3Config?> loadConfig() => _loadConfig();

  /// Persists [config] and drops the cached client so the next operation
  /// uses the new settings.
  Future<void> saveConfig(S3Config config) async {
    await _store.save(config);
    _invalidate();
  }

  @override
  Future<void> authenticate() async {
    final config = await _loadConfig();
    if (config == null) {
      throw const CloudStorageException(
        'S3 is not configured. Open the S3 settings and enter your '
        'bucket details.',
      );
    }
    await _probe(_apiClientFactory(config), config);
    _log.info('S3 probe succeeded for bucket ${config.bucket}');
  }

  /// Validates [config] with the same live read+write probe as
  /// [authenticate], without touching the stored credentials. Used by the
  /// settings form's Test Connection action on unsaved values.
  Future<void> testConnection(S3Config config) async {
    final error = config.validate();
    if (error != null) throw CloudStorageException(error);
    final client = _apiClientFactory(config);
    try {
      await _probe(client, config);
    } finally {
      client.close();
    }
  }

  /// Read permission (list) then write permission (put + delete of a tiny
  /// probe object under the prefix). Shared by [authenticate] and
  /// [testConnection] so the two paths cannot drift.
  Future<void> _probe(S3ApiClient client, S3Config config) async {
    await client.listObjects(prefix: config.prefix);
    final probeKey = '${config.prefix}$probeObjectName';
    await client.putObject(probeKey, Uint8List.fromList('probe'.codeUnits));
    await client.deleteObject(probeKey);
  }

  @override
  Future<void> signOut() async {
    await _store.clear();
    _invalidate();
  }

  @override
  Future<String?> getUserEmail() async {
    final config = await _loadConfig();
    if (config == null) return null;
    return '${config.bucket} @ ${config.displayHost}';
  }

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) async {
    final config = await _requireConfig();
    final client = _requireClient(config);
    final key = '${folderId ?? config.prefix}$filename';
    await client.putObject(key, data);
    return UploadResult(fileId: key, uploadTime: DateTime.now().toUtc());
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    final client = _requireClient(await _requireConfig());
    return client.getObject(fileId);
  }

  @override
  Future<CloudFileInfo?> getFileInfo(String fileId) async {
    final client = _requireClient(await _requireConfig());
    final info = await client.headObject(fileId);
    return info == null ? null : _toCloudFileInfo(info);
  }

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) async {
    final config = await _requireConfig();
    final client = _requireClient(config);
    final objects = await client.listObjects(prefix: folderId ?? config.prefix);
    return objects
        .map(_toCloudFileInfo)
        // Some servers list the bare prefix as a zero-length "directory"
        // object whose basename is empty; it is never a sync file.
        .where((f) => f.name.isNotEmpty)
        .where((f) => namePattern == null || f.name.contains(namePattern))
        .toList();
  }

  @override
  Future<void> deleteFile(String fileId) async {
    final client = _requireClient(await _requireConfig());
    await client.deleteObject(fileId);
  }

  @override
  Future<bool> fileExists(String fileId) async {
    final client = _requireClient(await _requireConfig());
    return (await client.headObject(fileId)) != null;
  }

  @override
  Future<String> createFolder(String folderName, {String? parentFolderId}) =>
      getOrCreateSyncFolder();

  @override
  Future<String> getOrCreateSyncFolder() async =>
      (await _requireConfig()).prefix;

  CloudFileInfo _toCloudFileInfo(S3ObjectInfo info) => CloudFileInfo(
    id: info.key,
    name: info.key.split('/').last,
    modifiedTime: info.lastModified,
    sizeBytes: info.size,
  );

  Future<S3Config?> _loadConfig() async =>
      _cachedConfig ??= await _store.load();

  Future<S3Config> _requireConfig() async {
    final config = await _loadConfig();
    if (config == null) {
      throw const CloudStorageException('S3 is not configured');
    }
    return config;
  }

  S3ApiClient _requireClient(S3Config config) =>
      _client ??= _apiClientFactory(config);

  void _invalidate() {
    _client?.close();
    _client = null;
    _cachedConfig = null;
  }
}
