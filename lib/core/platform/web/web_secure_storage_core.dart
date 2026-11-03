import 'dart:convert';

/// The browser's secure storage (issue #4121): pure Dart over a map, so the
/// VM can test it; the web backend hands it `window.localStorage`.
///
/// Two stores. The session store is a map in page memory, forgotten when
/// the tab closes: the default, so no credential reaches the browser's
/// storage unless the user asks. The remembered store is local storage,
/// scoped to the site's address, used once "remember on this device" is on.
/// The switch moves every entry between the two, so the passphrase follows
/// the credentials in both directions.
class WebSecureStorageCore {
  WebSecureStorageCore({
    required Map<String, String> localStorage,
    this.prefix = 'submersion.secure.',
  }) : _local = localStorage;

  /// The local storage key that says the user asked to be remembered.
  static const String rememberKey = 'submersion.rememberCredentials';

  /// What every remembered entry's key starts with in local storage.
  final String prefix;

  final Map<String, String> _local;
  final Map<String, String> _session = {};

  /// Whether entries live in local storage rather than the session.
  bool get remember => _local[rememberKey] == 'true';

  /// Turns remembering on or off, moving every entry to the store that
  /// now holds them.
  Future<void> setRemember(bool value) async {
    if (value == remember) return;
    if (value) {
      for (final entry in _session.entries) {
        _local[_stored(entry.key)] = _obscure(entry.value);
      }
      _session.clear();
      _local[rememberKey] = 'true';
    } else {
      for (final key in _storedKeys.toList()) {
        _session[key] = _reveal(_local[_stored(key)]!);
        _local.remove(_stored(key));
      }
      _local.remove(rememberKey);
    }
  }

  Future<String?> read(String key) async {
    if (!remember) return _session[key];
    final stored = _local[_stored(key)];
    return stored == null ? null : _reveal(stored);
  }

  Future<void> write(String key, String value) async {
    if (remember) {
      _local[_stored(key)] = _obscure(value);
    } else {
      _session[key] = value;
    }
  }

  Future<void> delete(String key) async {
    _session.remove(key);
    _local.remove(_stored(key));
  }

  /// Empties both stores and turns remembering off: Forget this device.
  Future<void> clearAll() async {
    _session.clear();
    for (final key in _storedKeys.toList()) {
      _local.remove(_stored(key));
    }
    _local.remove(rememberKey);
  }

  /// Every key held, in whichever store.
  Set<String> get keys => {..._session.keys, ..._storedKeys};

  Iterable<String> get _storedKeys => [
    for (final key in _local.keys)
      if (key.startsWith(prefix)) key.substring(prefix.length),
  ];

  String _stored(String key) => '$prefix$key';

  /// Lightly obscured, as the design says: a credential is not plain text
  /// at a glance in the dev tools. Not secrecy; anything running on the
  /// page can read local storage.
  static String _obscure(String value) => base64Url.encode(utf8.encode(value));

  static String _reveal(String stored) {
    try {
      return utf8.decode(base64Url.decode(stored));
    } on FormatException {
      return stored;
    }
  }
}
