import 'dart:convert';

import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';

/// Where an S3 or WebDAV roster row points, without any secret (issue #3482).
///
/// Synced on `connected_accounts.location`, so a device that never saw the
/// row's credentials can rebuild its config from the secret alone. It
/// carries the row's own folder because the folder is part of the row's id:
/// without it a second device could not rebuild the config, nor prove the
/// rebuilt config hashes back to the row it is signing in. The WebDAV user
/// name is not a secret; the synced roster label already shows it.
sealed class AccountLocation {
  const AccountLocation();

  static const _version = 1;

  /// Rows on one server share this, whatever their folder.
  String get serverKey;

  /// The row's own folder on its server, without a trailing slash
  /// ("submersion-sync", "submersion-sites/reef").
  String get folder;

  Map<String, Object?> _fields();

  String toJsonString() => jsonEncode({'v': _version, ..._fields()});

  /// Null for null, malformed JSON, an unknown kind, a newer version or a
  /// field of the wrong type, so a bad value never breaks loading a row.
  static AccountLocation? tryParse(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, Object?>) return null;
      final version = decoded['v'];
      if (version is! int || version > _version) return null;
      return switch (decoded['kind']) {
        's3' => S3AccountLocation(
          displayHost: decoded['displayHost']! as String,
          endpoint: decoded['endpoint']! as String,
          bucket: decoded['bucket']! as String,
          region: decoded['region']! as String,
          prefix: decoded['prefix']! as String,
          pathStyle: decoded['pathStyle']! as bool,
        ),
        // A synced address that does not parse would throw later, while
        // the accounts are grouped; it reads as no location instead.
        'webdav' when Uri.tryParse('${decoded['serverUrl']}/') != null =>
          WebDavAccountLocation(
            serverUrl: decoded['serverUrl']! as String,
            username: decoded['username']! as String,
            folder: decoded['folder']! as String,
          ),
        _ => null,
      };
    } on Object {
      return null;
    }
  }
}

final class S3AccountLocation extends AccountLocation {
  const S3AccountLocation({
    required this.displayHost,
    required this.endpoint,
    required this.bucket,
    required this.region,
    required this.prefix,
    required this.pathStyle,
  });

  factory S3AccountLocation.fromConfig(S3Config c) => S3AccountLocation(
    displayHost: c.displayHost,
    endpoint: c.endpoint,
    bucket: c.bucket,
    region: c.region,
    prefix: c.prefix,
    pathStyle: c.pathStyle,
  );

  /// Derivable from [endpoint] and [region], and stored all the same: the
  /// [serverKey] (and the row ids built the same way) must not move if the
  /// derivation in [S3Config.displayHost] ever changes.
  final String displayHost;
  final String endpoint;
  final String bucket;
  final String region;
  final String prefix;
  final bool pathStyle;

  @override
  String get serverKey => 's3|$displayHost|$bucket';

  S3AccountLocation copyWith({String? prefix}) => S3AccountLocation(
    displayHost: displayHost,
    endpoint: endpoint,
    bucket: bucket,
    region: region,
    prefix: prefix ?? this.prefix,
    pathStyle: pathStyle,
  );

  @override
  String get folder => prefix.replaceAll(RegExp(r'/+$'), '');

  S3Config toConfig({
    required String accessKeyId,
    required String secretAccessKey,
  }) => S3Config(
    endpoint: endpoint,
    region: region,
    bucket: bucket,
    prefix: prefix,
    pathStyle: pathStyle,
    accessKeyId: accessKeyId,
    secretAccessKey: secretAccessKey,
  );

  @override
  Map<String, Object?> _fields() => {
    'kind': 's3',
    'displayHost': displayHost,
    'endpoint': endpoint,
    'bucket': bucket,
    'region': region,
    'prefix': prefix,
    'pathStyle': pathStyle,
  };
}

final class WebDavAccountLocation extends AccountLocation {
  const WebDavAccountLocation({
    required this.serverUrl,
    required this.username,
    required this.folder,
  });

  factory WebDavAccountLocation.fromConfig(WebDavConfig c) =>
      WebDavAccountLocation(
        serverUrl: c.serverUrl,
        username: c.username,
        folder: c.folder,
      );

  final String serverUrl;
  final String username;
  @override
  final String folder;

  /// The same root [WebDavConfig.davRoot] computes, so the key matches the
  /// server part of the row's natural key.
  Uri get davRoot => Uri.parse('$serverUrl/');

  String get host => davRoot.host;

  @override
  String get serverKey => 'webdav|$davRoot';

  WebDavAccountLocation copyWith({String? folder}) => WebDavAccountLocation(
    serverUrl: serverUrl,
    username: username,
    folder: folder ?? this.folder,
  );

  WebDavConfig toConfig({required String password}) => WebDavConfig(
    serverUrl: serverUrl,
    username: username,
    password: password,
    folder: folder,
  );

  @override
  Map<String, Object?> _fields() => {
    'kind': 'webdav',
    'serverUrl': serverUrl,
    'username': username,
    'folder': folder,
  };
}
