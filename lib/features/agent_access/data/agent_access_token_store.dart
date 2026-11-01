import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// Device-local custody of the bearer token every MCP request must carry.
///
/// The token is 32 random bytes from [Random.secure], encoded base64url
/// without padding (43 characters). Regenerating it invalidates every client
/// configured with the old value on their next request.
class AgentAccessTokenStore {
  AgentAccessTokenStore({FlutterSecureStorage? storage, Random? random})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage()),
      _random = random ?? Random.secure();

  static const key = 'agent_access_token';
  static const _tokenBytes = 32;

  final FallbackSecureStorage _storage;
  final Random _random;

  /// Writes are serialised so two callers that both find no token (the app
  /// root and the settings page, say) agree on the one that gets stored.
  Future<void> _chain = Future.value();

  Future<String?> read() => _storage.read(key: key);

  /// Returns the stored token, generating and storing one if none exists.
  Future<String> ensure() => _serialised(() async {
    final existing = await read();
    if (existing != null && existing.isNotEmpty) return existing;
    return _writeFresh();
  });

  /// Replaces the stored token with a fresh one and returns it.
  Future<String> regenerate() => _serialised(_writeFresh);

  Future<String> _writeFresh() async {
    final token = _generate();
    await _storage.write(key: key, value: token);
    return token;
  }

  Future<String> _serialised(Future<String> Function() body) {
    final next = _chain.then((_) => body());
    _chain = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<void> clear() => _storage.delete(key: key);

  String _generate() {
    final bytes = List<int>.generate(_tokenBytes, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
