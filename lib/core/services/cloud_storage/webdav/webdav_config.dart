import 'package:submersion/core/services/cloud_storage/webdav/webdav_preset.dart';

const String kDefaultWebDavSyncFolder = 'Submersion';
const String kDefaultWebDavMediaFolder = 'Submersion Media';

/// Connection settings for a WebDAV server.
///
/// Immutable. The factory normalizes its inputs: [serverUrl] trimmed with no
/// trailing slash, [folder] trimmed of surrounding and repeated slashes.
/// [toString] never prints the password.
class WebDavConfig {
  final WebDavPreset preset;
  final String serverUrl;
  final String username;
  final String password;
  final String folder;

  /// Nextcloud user id from `current-user-principal`, which can differ from
  /// the login name (an email login, LDAP). Null until resolved.
  final String? nextcloudUserId;

  /// Lowercase hex SHA-256 of a self-signed certificate the user trusted.
  final String? pinnedCertSha256;

  const WebDavConfig._({
    required this.preset,
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.folder,
    required this.nextcloudUserId,
    required this.pinnedCertSha256,
  });

  factory WebDavConfig({
    required WebDavPreset preset,
    required String serverUrl,
    required String username,
    required String password,
    String folder = kDefaultWebDavSyncFolder,
    String? nextcloudUserId,
    String? pinnedCertSha256,
  }) => WebDavConfig._(
    preset: preset,
    serverUrl: _normalizeUrl(serverUrl),
    username: username.trim(),
    password: password,
    folder: _normalizeFolder(folder),
    nextcloudUserId: _blankToNull(nextcloudUserId),
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

  String get _base => preset.fixedRoot ?? '$serverUrl/';

  /// The collection every path is relative to.
  Uri get davRoot {
    if (preset.usesNextcloudLayout) {
      final id = Uri.encodeComponent(nextcloudUserId ?? username);
      return Uri.parse('$serverUrl/remote.php/dav/files/$id/');
    }
    final root = _base;
    return Uri.parse(root.endsWith('/') ? root : '$root/');
  }

  /// Nextcloud's chunked-upload collection, or null for other servers.
  Uri? get nextcloudUploadsRoot {
    if (!preset.supportsNextcloudChunking) return null;
    final id = Uri.encodeComponent(nextcloudUserId ?? username);
    return Uri.parse('$serverUrl/remote.php/dav/uploads/$id/');
  }

  /// Where `current-user-principal` is asked, or null when not needed.
  Uri? get principalProbeUri => preset.usesNextcloudLayout
      ? Uri.parse('$serverUrl/remote.php/dav/')
      : null;

  String get host => davRoot.host;
  int get port => davRoot.port;
  bool get isInsecure => davRoot.scheme == 'http';
  String get displayLabel => '$username @ $host';

  /// English description of the first problem, or null when valid. The
  /// settings forms validate field by field with localized text; this is
  /// the service-layer backstop.
  String? validate() {
    if (preset.needsServerUrl) {
      final uri = Uri.tryParse(serverUrl);
      if (serverUrl.isEmpty ||
          uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        return 'Enter the server address, starting with https://';
      }
      if (uri.userInfo.isNotEmpty) {
        // It would ride along in every request URL and on screen.
        return 'Put the username and password in their own fields, '
            'not in the address';
      }
      if (uri.hasQuery || uri.hasFragment) {
        // The DAV paths are appended to the address and would land there.
        return 'The server address cannot contain ? or #';
      }
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
    WebDavPreset? preset,
    String? serverUrl,
    String? username,
    String? password,
    String? folder,
    String? nextcloudUserId,
    String? pinnedCertSha256,
    bool clearNextcloudUserId = false,
    bool clearPin = false,
  }) => WebDavConfig(
    preset: preset ?? this.preset,
    serverUrl: serverUrl ?? this.serverUrl,
    username: username ?? this.username,
    password: password ?? this.password,
    folder: folder ?? this.folder,
    nextcloudUserId: clearNextcloudUserId
        ? null
        : (nextcloudUserId ?? this.nextcloudUserId),
    pinnedCertSha256: clearPin
        ? null
        : (pinnedCertSha256 ?? this.pinnedCertSha256),
  );

  Map<String, Object?> toJson() => {
    'preset': preset.name,
    'serverUrl': serverUrl,
    'username': username,
    'password': password,
    'folder': folder,
    'nextcloudUserId': nextcloudUserId,
    'pinnedCertSha256': pinnedCertSha256,
  };

  /// Throws [TypeError] on a malformed blob; callers treat that as absent.
  factory WebDavConfig.fromJson(Map<String, Object?> json) => WebDavConfig(
    preset: WebDavPreset.fromName(json['preset'] as String?),
    serverUrl: json['serverUrl'] as String? ?? '',
    username: json['username'] as String,
    password: json['password'] as String,
    folder: json['folder'] as String? ?? kDefaultWebDavSyncFolder,
    nextcloudUserId: json['nextcloudUserId'] as String?,
    pinnedCertSha256: json['pinnedCertSha256'] as String?,
  );

  @override
  String toString() =>
      'WebDavConfig(${preset.name}, $displayLabel, folder: $folder)';
}
