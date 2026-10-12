import 'package:submersion/core/services/cloud_storage/webdav/webdav_legacy_config.dart';

const String kDefaultWebDavSyncFolder = 'Submersion';
const String kDefaultWebDavMediaFolder = 'Submersion Media';

/// Connection settings for a WebDAV server.
///
/// Immutable. The factory normalizes its inputs: [serverUrl] trimmed with no
/// trailing slash, [folder] trimmed of surrounding and repeated slashes.
/// [toString] never prints the password.
class WebDavConfig {
  /// The full WebDAV address of the collection every path is relative to.
  final String serverUrl;
  final String username;
  final String password;
  final String folder;

  /// Lowercase hex SHA-256 of a self-signed certificate the user trusted.
  final String? pinnedCertSha256;

  const WebDavConfig._({
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.folder,
    required this.pinnedCertSha256,
  });

  factory WebDavConfig({
    required String serverUrl,
    required String username,
    required String password,
    String folder = kDefaultWebDavSyncFolder,
    String? pinnedCertSha256,
  }) => WebDavConfig._(
    serverUrl: _normalizeUrl(serverUrl),
    username: username.trim(),
    password: password,
    folder: _normalizeFolder(folder),
    pinnedCertSha256: _blankToNull(pinnedCertSha256)?.toLowerCase(),
  );

  static String _normalizeUrl(String raw) {
    var value = raw.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  static String _normalizeFolder(String raw) => raw
      .trim()
      .split('/')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .join('/');

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// The collection every path is relative to.
  Uri get davRoot => Uri.parse('$serverUrl/');

  /// Where chunked uploads go, or null when the address does not offer them.
  ///
  /// Servers with the chunked upload protocol serve each user's files at
  /// `remote.php/dav/files/<user>/` and take chunks at
  /// `remote.php/dav/uploads/<user>/`, so an address of that shape is the
  /// signal. A server that matches but refuses chunking falls back to a
  /// single upload. Built from the raw path so an encoded user id stays
  /// encoded exactly once.
  Uri? get chunkedUploadsRoot {
    final root = davRoot;
    final segments = root.path.split('/');
    for (var i = 0; i + 3 < segments.length; i++) {
      if (segments[i] == 'remote.php' &&
          segments[i + 1] == 'dav' &&
          segments[i + 2] == 'files' &&
          segments[i + 3].isNotEmpty) {
        final path = [
          ...segments.sublist(0, i + 2),
          'uploads',
          segments[i + 3],
          '',
        ].join('/');
        return root.replace(path: path);
      }
    }
    return null;
  }

  String get host => davRoot.host;
  int get port => davRoot.port;
  bool get isInsecure => davRoot.scheme == 'http';
  String get displayLabel => '$username @ $host';

  /// English description of the first problem, or null when valid. The
  /// settings forms validate field by field with localized text; this is
  /// the service-layer backstop.
  String? validate() {
    final uri = Uri.tryParse(serverUrl);
    if (serverUrl.isEmpty ||
        uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return 'Enter the WebDAV address, starting with https://';
    }
    if (uri.userInfo.isNotEmpty) {
      // It would ride along in every request URL and on screen.
      return 'Put the username and password in their own fields, '
          'not in the address';
    }
    if (uri.hasQuery || uri.hasFragment) {
      // The DAV paths are appended to the address and would land there.
      return 'The WebDAV address cannot contain ? or #';
    }
    if (username.isEmpty) return 'Enter the username';
    if (password.isEmpty) return 'Enter the password';
    if (folder.isEmpty) return 'Enter a folder name';
    if (folder.split('/').any((s) => s == '.' || s == '..')) {
      return 'The folder name cannot contain . or .. segments';
    }
    return null;
  }

  WebDavConfig copyWith({
    String? serverUrl,
    String? username,
    String? password,
    String? folder,
    String? pinnedCertSha256,
    bool clearPin = false,
  }) => WebDavConfig(
    serverUrl: serverUrl ?? this.serverUrl,
    username: username ?? this.username,
    password: password ?? this.password,
    folder: folder ?? this.folder,
    pinnedCertSha256: clearPin
        ? null
        : (pinnedCertSha256 ?? this.pinnedCertSha256),
  );

  Map<String, Object?> toJson() => {
    'serverUrl': serverUrl,
    'username': username,
    'password': password,
    'folder': folder,
    'pinnedCertSha256': pinnedCertSha256,
  };

  /// Throws [TypeError] on a malformed blob; callers treat that as absent.
  /// A blob saved with a server type is rewritten to its full address.
  factory WebDavConfig.fromJson(Map<String, Object?> raw) {
    final json = upgradeLegacyWebDavJson(raw);
    return WebDavConfig(
      serverUrl: json['serverUrl'] as String? ?? '',
      username: json['username'] as String,
      password: json['password'] as String,
      folder: json['folder'] as String? ?? kDefaultWebDavSyncFolder,
      pinnedCertSha256: json['pinnedCertSha256'] as String?,
    );
  }

  @override
  String toString() => 'WebDavConfig($displayLabel, folder: $folder)';
}
