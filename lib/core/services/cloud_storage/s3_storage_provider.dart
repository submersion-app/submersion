import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Builds an [S3ApiClient] for a config; injectable for tests.
typedef S3ApiClientFactory =
    S3ApiClient Function(
      S3Config config, {
      void Function(String region)? onRegionCorrected,
    });

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
  int _generation = 0;

  /// In-flight region-correction save, if any. [saveConfig] and [signOut]
  /// await this so a background save cannot race past `_store.clear()` and
  /// resurrect credentials, or cross-write a freshly-saved config.
  Future<void>? _persistInFlight;

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
    await _persistInFlight;
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
    final client = _apiClientFactory(
      config,
      onRegionCorrected: _schedulePersistCorrectedRegion,
    );
    try {
      await _probe(client, config);
    } finally {
      client.close();
    }
    _log.info('S3 probe succeeded for bucket ${config.bucket}');
  }

  /// Validates [config] with the same live read+write probe as
  /// [authenticate], without touching the stored credentials. Used by the
  /// settings form's Test Connection action on unsaved values.
  /// [onRegionCorrected] reports a server-corrected region to the caller;
  /// nothing is persisted here.
  Future<void> testConnection(
    S3Config config, {
    void Function(String region)? onRegionCorrected,
  }) async {
    final error = config.validate();
    if (error != null) throw CloudStorageException(error);
    final client = _apiClientFactory(
      config,
      onRegionCorrected: onRegionCorrected,
    );
    try {
      await _probe(client, config);
    } finally {
      client.close();
    }
  }

  /// Read permission (capped list), then write, read-back, and delete of a
  /// tiny probe object under the prefix. Shared by [authenticate] and
  /// [testConnection] so the two paths cannot drift.
  Future<void> _probe(S3ApiClient client, S3Config config) async {
    await client.listObjects(prefix: config.prefix, maxKeys: 1);
    final probeKey = '${config.prefix}$probeObjectName';
    await client.putObject(probeKey, Uint8List.fromList('probe'.codeUnits));
    await client.getObject(probeKey);
    await client.deleteObject(probeKey);
  }

  @override
  Future<void> signOut() async {
    await _persistInFlight;
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
    final session = await _requireSession();
    final key = '${folderId ?? session.config.prefix}$filename';
    await session.client.putObject(key, data);
    return UploadResult(fileId: key, uploadTime: DateTime.now().toUtc());
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    final session = await _requireSession();
    return session.client.getObject(fileId);
  }

  /// Chunk/part size for streamed transfers; matches S3MediaObjectStore.
  static const int _transferChunkBytes = 8 * 1024 * 1024;

  /// Streams the local file up as a multipart upload in 8 MiB parts
  /// (mirroring S3MediaObjectStore._putMultipart, minus resume state:
  /// backups are one-shot artifacts). SigV4 signs each part's own payload
  /// hash, so per-part signing works where a single streamed PUT cannot.
  /// A failed upload aborts the session so parts never strand and bill.
  @override
  Future<UploadResult> uploadFileFromPath(
    String sourcePath,
    String filename, {
    String? folderId,
  }) async {
    final source = File(sourcePath);
    final length = await source.length();
    if (length <= _transferChunkBytes) {
      return uploadFile(
        await source.readAsBytes(),
        filename,
        folderId: folderId,
      );
    }

    final session = await _requireSession();
    final key = '${folderId ?? session.config.prefix}$filename';
    String? uploadId;
    try {
      uploadId = await session.client.createMultipartUpload(
        key,
        contentType: 'application/octet-stream',
      );
      final parts = <S3PartInfo>[];
      final totalParts =
          (length + _transferChunkBytes - 1) ~/ _transferChunkBytes;
      final raf = await source.open();
      try {
        for (var n = 1; n <= totalParts; n++) {
          final offset = (n - 1) * _transferChunkBytes;
          await raf.setPosition(offset);
          final chunk = await raf.read(
            min(_transferChunkBytes, length - offset),
          );
          final etag = await session.client.uploadPart(
            key,
            uploadId: uploadId,
            partNumber: n,
            bytes: chunk,
          );
          parts.add(S3PartInfo(partNumber: n, etag: etag));
        }
      } finally {
        await raf.close();
      }
      await session.client.completeMultipartUpload(
        key,
        uploadId: uploadId,
        parts: parts,
      );
      return UploadResult(fileId: key, uploadTime: DateTime.now().toUtc());
    } catch (_) {
      if (uploadId != null) {
        try {
          await session.client.abortMultipartUpload(key, uploadId: uploadId);
        } catch (_) {
          // Best-effort abort; the original error is the one that matters.
        }
      }
      rethrow;
    }
  }

  /// Ranged download straight to disk (mirroring S3MediaObjectStore.getFile),
  /// one 8 MiB slice resident at a time.
  @override
  Future<void> downloadToFile(String fileId, String destinationPath) async {
    final session = await _requireSession();
    final dest = File(destinationPath);
    try {
      final info = await session.client.headObject(fileId);
      if (info == null) {
        throw CloudStorageException('File not found in S3: $fileId');
      }
      final total = info.size;
      if (total == null || total <= _transferChunkBytes) {
        final bytes = await session.client.getObject(fileId);
        await dest.writeAsBytes(bytes, flush: true);
        return;
      }
      final raf = await dest.open(mode: FileMode.write);
      try {
        var received = 0;
        while (received < total) {
          final end = min(received + _transferChunkBytes, total) - 1;
          final range = await session.client.getObjectRange(
            fileId,
            start: received,
            endInclusive: end,
          );
          await raf.writeFrom(range.bytes);
          received += range.bytes.length;
        }
        await raf.flush();
      } finally {
        await raf.close();
      }
    } catch (_) {
      if (await dest.exists()) {
        try {
          await dest.delete();
        } catch (_) {
          // Best-effort cleanup of a partial download.
        }
      }
      rethrow;
    }
  }

  @override
  Future<CloudFileInfo?> getFileInfo(String fileId) async {
    final session = await _requireSession();
    final info = await session.client.headObject(fileId);
    return info == null ? null : _toCloudFileInfo(info);
  }

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) async {
    final session = await _requireSession();
    final objects = await session.client.listObjects(
      prefix: folderId ?? session.config.prefix,
    );
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
    final session = await _requireSession();
    await session.client.deleteObject(fileId);
  }

  @override
  Future<bool> fileExists(String fileId) async {
    final session = await _requireSession();
    return (await session.client.headObject(fileId)) != null;
  }

  @override
  Future<String> createFolder(
    String folderName, {
    String? parentFolderId,
  }) async {
    final config = await _requireConfig();
    final base = parentFolderId ?? config.prefix;
    return '$base$folderName/';
  }

  @override
  Future<String> getOrCreateSyncFolder() async =>
      (await _requireConfig()).prefix;

  CloudFileInfo _toCloudFileInfo(S3ObjectInfo info) => CloudFileInfo(
    id: info.key,
    name: info.key.split('/').last,
    modifiedTime: info.lastModified,
    sizeBytes: info.size,
  );

  Future<S3Config?> _loadConfig() async {
    final cached = _cachedConfig;
    if (cached != null) return cached;
    final generation = _generation;
    final loaded = await _store.load();
    if (generation != _generation) {
      // saveConfig/signOut raced this load; do not pin the stale value.
      return _cachedConfig;
    }
    return _cachedConfig = loaded;
  }

  Future<S3Config> _requireConfig() async {
    final config = await _loadConfig();
    if (config == null) {
      throw const CloudStorageException('S3 is not configured');
    }
    return config;
  }

  /// Config+client captured consistently: if an invalidation races the
  /// config load, re-loads so an operation never pins or uses a
  /// pre-invalidation pair.
  Future<({S3Config config, S3ApiClient client})> _requireSession() async {
    while (true) {
      final generation = _generation;
      final config = await _loadConfig();
      if (config == null) {
        throw const CloudStorageException('S3 is not configured');
      }
      if (generation != _generation) continue;
      return (
        config: config,
        client: _client ??= _apiClientFactory(
          config,
          onRegionCorrected: _schedulePersistCorrectedRegion,
        ),
      );
    }
  }

  /// Fire-and-forget wrapper that exposes the running save through
  /// [_persistInFlight] so [saveConfig]/[signOut] can wait it out.
  void _schedulePersistCorrectedRegion(String region) {
    final future = _persistCorrectedRegion(region);
    _persistInFlight = future.whenComplete(() {
      if (identical(_persistInFlight, future)) _persistInFlight = null;
    });
  }

  /// Persists a server-corrected region without invalidating the live
  /// client, which already signs with the correction. A failed persist is
  /// harmless: the correction simply recurs on the next launch.
  ///
  /// Cancels itself if [_invalidate] fired between scheduling and the save
  /// completing: signOut/saveConfig already await [_persistInFlight] to
  /// avoid the obvious race, but a `_generation` bump that lands mid-call
  /// (e.g. from a parallel save) must still leave the post-invalidate
  /// state untouched.
  Future<void> _persistCorrectedRegion(String region) async {
    final generation = _generation;
    final config = _cachedConfig;
    if (config == null || config.region == region) return;
    if (generation != _generation) return;
    final updated = config.copyWith(region: region);
    try {
      await _store.save(updated);
      if (generation != _generation) return;
      _cachedConfig = updated;
      _log.info('Persisted server-corrected S3 region: $region');
    } catch (e) {
      _log.warning('Could not persist corrected S3 region: $e');
    }
  }

  void _invalidate() {
    _generation++;
    _client?.close();
    _client = null;
    _cachedConfig = null;
  }
}
