import 'dart:collection';

import 'package:web/web.dart' as web;

/// `window.localStorage` as a Dart map, for `WebSecureStorageCore`.
///
/// Every key of the origin is visible here, the app's own preferences
/// included, so callers touch only the keys they own; [clear] empties the
/// whole origin and nothing in the app calls it.
class BrowserLocalStorage extends MapBase<String, String> {
  BrowserLocalStorage([web.Storage? storage])
    : _storage = storage ?? web.window.localStorage;

  final web.Storage _storage;

  @override
  String? operator [](Object? key) =>
      key is String ? _storage.getItem(key) : null;

  @override
  void operator []=(String key, String value) => _storage.setItem(key, value);

  @override
  void clear() => _storage.clear();

  @override
  Iterable<String> get keys => [
    for (var i = 0; i < _storage.length; i++) _storage.key(i)!,
  ];

  @override
  String? remove(Object? key) {
    if (key is! String) return null;
    final value = _storage.getItem(key);
    _storage.removeItem(key);
    return value;
  }
}
