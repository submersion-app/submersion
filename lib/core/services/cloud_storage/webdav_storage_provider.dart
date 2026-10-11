import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/nextcloud_chunked_upload.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/logger_service.dart';

typedef WebDavClientFactory = WebDavClient Function(WebDavConfig config);

/// [config] with its Nextcloud user id resolved from
/// `current-user-principal`, or unchanged when the preset has no Nextcloud
/// layout or the server will not say. Only failures that would also sink
/// the probe (bad credentials, an untrusted certificate, an unreachable
/// host) are raised; anything else falls back to the login name.
Future<WebDavConfig> resolveNextcloudUserId(
  WebDavConfig config,
  WebDavClientFactory clientFactory,
) async {
  if (!config.preset.usesNextcloudLayout) return config;
  final lookup = clientFactory(config);
  try {
    final id = await lookup.resolveNextcloudUserId();
    return (id == null || id == config.nextcloudUserId)
        ? config
        : config.copyWith(nextcloudUserId: id);
  } on WebDavException catch (e) {
    if (e.code == WebDavErrorCode.unauthorized ||
        e.code == WebDavErrorCode.untrustedCertificate ||
        e.code == WebDavErrorCode.unreachable) {
      rethrow;
    }
    return config;
  } finally {
    lookup.close();
  }
}

/// WebDAV implementation of [CloudStorageProvider] (Nextcloud, ownCloud,
/// Synology, Koofr, pCloud, Fastmail, Yandex and any other WebDAV server).
///
/// - fileId is the path relative to the DAV root (`Submersion/x.json`); the
///   sync folder is the configured folder.
/// - authenticate() is a live read and write probe of the stored config.
/// - getUserEmail() returns the account label `<user> @ <host>`.
class WebDavStorageProvider
    with CloudStorageProviderMixin
    implements CloudStorageProvider {
  static final _log = LoggerService.forClass(WebDavStorageProvider);

  static const String probeObjectName = '.submersion-probe';

  static final Random _random = Random();

  static String _probeSuffix() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';

  WebDavStorageProvider({
    WebDavCredentialsStore? store,
    WebDavClientFactory? clientFactory,
  }) : _store = store ?? WebDavCredentialsStore(),
       _clientFactory = clientFactory ?? WebDavClient.new;

  final WebDavCredentialsStore _store;
  final WebDavClientFactory _clientFactory;

  WebDavConfig? _cachedConfig;
  WebDavClient? _client;
  int _generation = 0;

  @override
  String get providerName => 'WebDAV';

  @override
  String get providerId => 'webdav';

  @override
  Future<bool> isAvailable() async => true;

  /// Presence only, no network (UI rebuild paths call this). Keychain
  /// failures propagate, as for S3: a locked keychain is not "unset".
  @override
  Future<bool> isAuthenticated() async => (await _loadConfig()) != null;

  Future<WebDavConfig?> loadConfig() => _loadConfig();

  Future<void> saveConfig(WebDavConfig config) async {
    await _store.save(config);
    _invalidate();
  }

  @override
  Future<void> authenticate() async {
    final config = await _loadConfig();
    if (config == null) {
      throw WebDavException(
        'WebDAV is not configured. Open the WebDAV settings and enter your server details.',
        code: WebDavErrorCode.invalidConfig,
      );
    }
    final client = _clientFactory(config);
    try {
      await probe(client, config.folder);
    } finally {
      client.close();
    }
    _log.info('WebDAV probe succeeded for ${config.host}');
  }

  /// Validates unsaved [config] with the same probe as [authenticate] and
  /// returns it with the Nextcloud user id resolved. Saves nothing.
  Future<WebDavConfig> testConnection(WebDavConfig config) async {
    final error = config.validate();
    if (error != null) {
      throw WebDavException(error, code: WebDavErrorCode.invalidConfig);
    }
    final resolved = await resolveNextcloudUserId(config, _clientFactory);
    final client = _clientFactory(resolved);
    try {
      await probe(client, resolved.folder);
    } finally {
      client.close();
    }
    return resolved;
  }

  /// The DAV root exists and is a collection; the folder can be created;
  /// a small file round-trips and is removed.
  static Future<void> probe(WebDavClient client, String folder) async {
    final root = await client.stat('');
    if (root == null || !root.isCollection) {
      throw WebDavException(
        'No WebDAV folder at this address. Check the server type and URL.',
        code: WebDavErrorCode.notFound,
      );
    }
    await client.ensureCollection(folder);
    // A name of its own, so a probe never overwrites or deletes a file the
    // user keeps there, nor one another device's probe is using right now.
    final probePath = '$folder/$probeObjectName-${_probeSuffix()}';
    try {
      await client.putBytes(
        probePath,
        Uint8List.fromList(utf8.encode('probe')),
      );
      final back = await client.getBytes(probePath);
      if (utf8.decode(back, allowMalformed: true) != 'probe') {
        throw WebDavException(
          'The server returned different bytes for the test file.',
          code: WebDavErrorCode.unexpected,
        );
      }
    } finally {
      try {
        await client.delete(probePath);
      } on WebDavException {
        // Best effort; the original failure is the one to report.
      }
    }
  }

  @override
  Future<void> signOut() async {
    await _store.clear();
    _invalidate();
  }

  /// Drops the cached config and client, for when the stored config was
  /// changed or removed by someone other than this provider.
  void forgetCachedConfig() => _invalidate();

  @override
  Future<String?> getUserEmail() async => (await _loadConfig())?.displayLabel;

  String _pathIn(String? folderId, WebDavConfig config, String filename) =>
      '${folderId ?? config.folder}/$filename';

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) async {
    final session = await _requireSession();
    final path = _pathIn(folderId, session.config, filename);
    await session.client.putBytes(path, data);
    return UploadResult(fileId: path, uploadTime: DateTime.now().toUtc());
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    final session = await _requireSession();
    return session.client.getBytes(fileId);
  }

  @override
  Future<UploadResult> uploadFileFromPath(
    String sourcePath,
    String filename, {
    String? folderId,
  }) async {
    final session = await _requireSession();
    final path = _pathIn(folderId, session.config, filename);
    final source = File(sourcePath);
    final length = await source.length();
    var done = false;
    if (NextcloudChunkedUpload.appliesTo(session.client, length)) {
      done = await NextcloudChunkedUpload(session.client).upload(path, source);
    }
    if (!done) await session.client.putFile(path, source);
    return UploadResult(fileId: path, uploadTime: DateTime.now().toUtc());
  }

  @override
  Future<void> downloadToFile(String fileId, String destinationPath) async {
    final session = await _requireSession();
    await session.client.getToFile(fileId, File(destinationPath));
  }

  @override
  Future<CloudFileInfo?> getFileInfo(String fileId) async {
    final session = await _requireSession();
    final entry = await session.client.stat(fileId);
    if (entry == null || entry.isCollection) return null;
    return _toInfo(entry);
  }

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) async {
    final session = await _requireSession();
    final List<WebDavEntry> children;
    try {
      children = await session.client.listChildren(
        folderId ?? session.config.folder,
      );
    } on WebDavException catch (e) {
      if (e.code == WebDavErrorCode.notFound) return const [];
      rethrow;
    }
    return children
        .where((e) => !e.isCollection)
        .where((e) => namePattern == null || e.name.contains(namePattern))
        .map(_toInfo)
        .toList();
  }

  @override
  Future<void> deleteFile(String fileId) async {
    final session = await _requireSession();
    await session.client.delete(fileId);
  }

  @override
  Future<bool> fileExists(String fileId) async =>
      (await getFileInfo(fileId)) != null;

  @override
  Future<String> createFolder(
    String folderName, {
    String? parentFolderId,
  }) async {
    final session = await _requireSession();
    final path = '${parentFolderId ?? session.config.folder}/$folderName';
    await session.client.ensureCollection(path);
    return path;
  }

  @override
  Future<String> getOrCreateSyncFolder() async {
    final session = await _requireSession();
    await session.client.ensureCollection(session.config.folder);
    return session.config.folder;
  }

  CloudFileInfo _toInfo(WebDavEntry e) => CloudFileInfo(
    id: e.path,
    name: e.name,
    modifiedTime: e.lastModified,
    sizeBytes: e.sizeBytes,
  );

  Future<WebDavConfig?> _loadConfig() async {
    final cached = _cachedConfig;
    if (cached != null) return cached;
    final generation = _generation;
    final loaded = await _store.load();
    if (generation != _generation) return _cachedConfig;
    return _cachedConfig = loaded;
  }

  Future<({WebDavConfig config, WebDavClient client})> _requireSession() async {
    while (true) {
      final generation = _generation;
      final config = await _loadConfig();
      if (config == null) {
        throw WebDavException(
          'WebDAV is not configured',
          code: WebDavErrorCode.invalidConfig,
        );
      }
      if (generation != _generation) continue;
      return (config: config, client: _client ??= _clientFactory(config));
    }
  }

  void _invalidate() {
    _generation++;
    _client?.close();
    _client = null;
    _cachedConfig = null;
  }
}
