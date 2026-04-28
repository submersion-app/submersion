// Adapted from plan `docs/superpowers/plans/2026-04-28-media-source-extension-phase3a.md`
// Task 6. Deviations from the plan code:
//
// - `delete` takes a `String` id (not `int`) to match the schema-driven
//   adaptation already applied in Tasks 3+4 (`network_credential_hosts.id`
//   is TEXT). The plan's surrounding code in `headersFor` calls
//   `_repo.touchLastUsed(row.id)`; that signature is already String-based
//   on the repository so no further change is needed there.
// - `list()` returns `Future<List<NetworkCredentialHost>>` using the Drift
//   data class generated for the `network_credential_hosts` table; the
//   plan refers to `NetworkCredentialHost` as well, but the import comes
//   from `core/database/database.dart` (Drift export) rather than a domain
//   entity layer (which doesn't exist for this row).
//
// Composes `NetworkCredentialsRepository` (Drift row metadata) with
// `FlutterSecureStorage` (the actual secret blob) so that callers in later
// Phase 3 tasks can ask "what Authorization header should I send for this
// host?" without juggling persistence layers themselves.
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/network_credentials_repository.dart';

class NetworkCredentialsService {
  NetworkCredentialsService({
    required NetworkCredentialsRepository repository,
    required FlutterSecureStorage storage,
  }) : _repo = repository,
       _storage = storage;

  final NetworkCredentialsRepository _repo;
  final FlutterSecureStorage _storage;

  /// Per-process cache of resolved (hostname -> headers) so repeated
  /// `headersFor` calls during a single bulk-import or scan don't hit
  /// the keychain on every URL.
  final Map<String, Map<String, String>> _headerCache = {};

  static const _keyPrefix = 'media_network_cred_';

  /// Persists credentials for [hostname]. For `basic` auth, both
  /// [username] and [password] are required. For `bearer` auth, [token]
  /// is required. Throws [ArgumentError] for any other combination.
  ///
  /// The Drift row carries non-secret metadata (auth type, display name,
  /// last-used timestamp) while the actual secret blob is JSON-encoded
  /// and stored in the platform keychain via [FlutterSecureStorage].
  Future<void> save({
    required String hostname,
    required String authType,
    String? username,
    String? password,
    String? token,
    String? displayName,
  }) async {
    if (authType == 'basic') {
      if (username == null || password == null) {
        throw ArgumentError('Basic auth requires username + password');
      }
    } else if (authType == 'bearer') {
      if (token == null) {
        throw ArgumentError('Bearer auth requires token');
      }
    } else {
      throw ArgumentError('Unsupported authType: $authType');
    }

    await _repo.upsert(
      hostname: hostname,
      authType: authType,
      displayName: displayName,
    );
    final secret = jsonEncode({
      'authType': authType,
      'username': username,
      'password': password,
      'token': token,
    });
    await _storage.write(key: _keyPrefix + hostname, value: secret);
    _headerCache.remove(hostname);
  }

  /// Returns the `Authorization`-bearing header map for [uri]'s host, or
  /// `null` if no credentials are stored for that host (or the secret
  /// blob is missing). Successful lookups are cached and bump the
  /// `lastUsedAt` timestamp on the underlying row.
  Future<Map<String, String>?> headersFor(Uri uri) async {
    final host = uri.host;
    final cached = _headerCache[host];
    if (cached != null) return cached;
    final raw = await _storage.read(key: _keyPrefix + host);
    if (raw == null) return null;
    final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
    final headers = <String, String>{};
    if (map['authType'] == 'basic') {
      final token = base64Encode(
        utf8.encode('${map['username']}:${map['password']}'),
      );
      headers['Authorization'] = 'Basic $token';
    } else if (map['authType'] == 'bearer') {
      headers['Authorization'] = 'Bearer ${map['token']}';
    }
    _headerCache[host] = headers;
    final row = await _repo.findByHostname(host);
    if (row != null) await _repo.touchLastUsed(row.id);
    return headers;
  }

  /// Deletes the row for [id] and the associated secret blob, and
  /// invalidates any cached headers for the row's hostname. No-op if the
  /// row is already gone.
  Future<void> delete(String id) async {
    final row = await _repo.findById(id);
    if (row == null) return;
    await _repo.delete(id);
    await _storage.delete(key: _keyPrefix + row.hostname);
    _headerCache.remove(row.hostname);
  }

  /// Returns all stored credential-host rows. Used by the Settings page
  /// (Phase 3c) to render the credentials list.
  Future<List<NetworkCredentialHost>> list() => _repo.list();
}
