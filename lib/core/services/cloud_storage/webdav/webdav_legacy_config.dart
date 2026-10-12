/// Rewrites a config saved by a build that asked for a server type into the
/// single-address form.
///
/// Those builds stored the type's name and, for some types, only a host or
/// nothing at all, and derived the WebDAV address from it. This derives the
/// same address once, so the config keeps connecting where it did. The
/// address must come out byte for byte: it feeds the connected account's
/// id, and a different id would fork the account across devices.
///
/// A blob with no stored type is already in the new form and is returned
/// unchanged, which also makes the rewrite safe to apply on every load.
Map<String, Object?> upgradeLegacyWebDavJson(Map<String, Object?> json) {
  final type = json['preset'];
  if (type is! String) return json;
  final serverUrl = _trimTrailingSlashes(
    (json['serverUrl'] as String? ?? '').trim(),
  );
  final address = switch (type) {
    'koofr' => 'https://app.koofr.net/dav/Koofr',
    'pcloudUs' => 'https://webdav.pcloud.com',
    'pcloudEu' => 'https://ewebdav.pcloud.com',
    'fastmail' => 'https://myfiles.fastmail.com',
    'yandex' => 'https://webdav.yandex.com',
    'nextcloud' || 'owncloud' =>
      '$serverUrl/remote.php/dav/files/${Uri.encodeComponent(_userId(json))}',
    _ => serverUrl,
  };
  return {
    for (final entry in json.entries)
      if (entry.key != 'preset' && entry.key != 'nextcloudUserId')
        entry.key: entry.value,
    'serverUrl': address,
  };
}

/// The user id those builds resolved from the server, or the login name
/// they fell back to.
String _userId(Map<String, Object?> json) {
  final resolved = (json['nextcloudUserId'] as String?)?.trim();
  if (resolved != null && resolved.isNotEmpty) return resolved;
  return (json['username'] as String).trim();
}

String _trimTrailingSlashes(String value) {
  var result = value;
  while (result.endsWith('/')) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}
