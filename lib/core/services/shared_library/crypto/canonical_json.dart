import 'dart:convert';

import 'package:crypto/crypto.dart';

/// JSON with map keys sorted at every depth and no whitespace: the exact
/// bytes a shared site library signature covers (issue #2567), identical on
/// every device.
String canonicalJson(Object? value) => jsonEncode(_sorted(value));

Object? _sorted(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => '$k').toList()..sort();
    return {for (final k in keys) k: _sorted(v[k])};
  }
  if (v is List) return [for (final e in v) _sorted(e)];
  return v;
}

/// The lower-case hex SHA-256 of [bytes].
String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();
