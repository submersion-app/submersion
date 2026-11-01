// Adapted from plan `docs/design/plans/2026-04-28-media-source-extension-phase3a.md`
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
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';
import 'package:submersion/features/media/data/repositories/network_credentials_repository.dart';

class NetworkCredentialsService {
  NetworkCredentialsService({
    required NetworkCredentialsRepository repository,
    required FlutterSecureStorage storage,
    void Function()? onCredentialsChanged,
  }) : _repo = repository,
       _storage = FallbackSecureStorage(storage),
       _onCredentialsChanged = onCredentialsChanged;

  final NetworkCredentialsRepository _repo;
  final FallbackSecureStorage _storage;

  /// Called after [save] or [delete] changes a host's secret, so holders of
  /// an earlier [headersFor] result can ask again.
  final void Function()? _onCredentialsChanged;

  final _log = LoggerService.forClass(NetworkCredentialsService);

  /// Per-process cache of resolved (hostname -> headers) so repeated
  /// `headersFor` calls during a single bulk-import or scan don't hit
  /// the keychain on every URL. A null value records that the host has no
  /// credentials, which is most hosts. This service is the only writer of
  /// these secrets, so an entry stays valid until [save] or [delete] replaces
  /// it. A failed keychain read records nothing.
  final Map<String, Map<String, String>?> _headerCache = {};

  /// The keychain lookup under way for each host, shared by everyone who asks
  /// before it finishes. Removing an entry disowns that lookup: see
  /// [_invalidate].
  final Map<String, Future<Map<String, String>?>> _lookups = {};

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
    _invalidate(hostname);
  }

  /// Returns the `Authorization`-bearing header map for [uri]'s host, or
  /// `null` if no credentials are stored for that host (or the secret
  /// blob is missing / corrupted / from a stale schema). Both answers are
  /// cached, callers for a host with a lookup under way share it, and a
  /// successful keychain read bumps the `lastUsedAt` timestamp on the
  /// underlying row.
  ///
  /// Tolerates malformed blobs: any decode failure or missing/wrong-type
  /// field deletes the offending key (so the user is prompted to re-enter
  /// credentials) and returns `null` rather than letting the exception
  /// propagate into network fetches and break URL/manifest imports.
  Future<Map<String, String>?> headersFor(Uri uri) {
    final host = uri.host;
    if (_headerCache.containsKey(host)) return Future.value(_headerCache[host]);
    final running = _lookups[host];
    if (running != null) return running;
    late final Future<Map<String, String>?> lookup;
    // _lookUp reaches its first await before anything asks isCurrent, by which
    // time the lookup is assigned and registered.
    lookup = _lookUp(host, isCurrent: () => identical(_lookups[host], lookup));
    return _lookups[host] = lookup;
  }

  /// Reads and decodes [host]'s secret. Once [isCurrent] turns false the
  /// credentials changed during the read, so what was read must neither be
  /// cached nor act on the key, which now holds a newer secret.
  Future<Map<String, String>?> _lookUp(
    String host, {
    required bool Function() isCurrent,
  }) async {
    try {
      final raw = await _storage.read(key: _keyPrefix + host);
      final headers = raw == null ? null : _decodeHeaders(raw);
      if (!isCurrent()) return headers;
      if (raw != null && headers == null) {
        await _storage.delete(key: _keyPrefix + host);
      }
      if (isCurrent()) _headerCache[host] = headers;
      if (headers != null) await _touchLastUsed(host);
      return headers;
    } finally {
      if (isCurrent()) _lookups.remove(host);
    }
  }

  /// The header map a stored secret [raw] stands for, or null when it is
  /// malformed or from a stale schema.
  static Map<String, String>? _decodeHeaders(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    final authorization = switch (decoded) {
      {
        'authType': 'basic',
        'username': final String username,
        'password': final String password,
      } =>
        'Basic ${base64Encode(utf8.encode('$username:$password'))}',
      {'authType': 'bearer', 'token': final String token} => 'Bearer $token',
      _ => null,
    };
    if (authorization == null) return null;
    return Map.unmodifiable({'Authorization': authorization});
  }

  /// `lastUsedAt` is display metadata, so failing to record it must not cost
  /// the caller its headers or the user their saved secret.
  Future<void> _touchLastUsed(String host) async {
    try {
      final row = await _repo.findByHostname(host);
      if (row != null) await _repo.touchLastUsed(row.id);
    } catch (e, st) {
      _log.warning('Could not record credential use', error: e, stackTrace: st);
    }
  }

  /// Forgets everything known about [hostname] after its secret changed.
  /// Disowning a running lookup keeps later callers from joining a read that
  /// predates the change, and keeps that read out of the cache.
  void _invalidate(String hostname) {
    _headerCache.remove(hostname);
    _lookups.remove(hostname);
    _onCredentialsChanged?.call();
  }

  /// Deletes the row for [id] and the associated secret blob, and
  /// invalidates any cached headers for the row's hostname. No-op if the
  /// row is already gone. The secret goes first: the row is what lets the
  /// user retry, so it must outlive a keychain failure.
  Future<void> delete(String id) async {
    final row = await _repo.findById(id);
    if (row == null) return;
    await _storage.delete(key: _keyPrefix + row.hostname);
    _invalidate(row.hostname);
    await _repo.delete(id);
  }

  /// Returns all stored credential-host rows. Used by the Settings page
  /// (Phase 3c) to render the credentials list.
  Future<List<NetworkCredentialHost>> list() => _repo.list();

  /// Updates the `displayName` for the row identified by [id]. Pass `null`
  /// to clear it. The secret blob in secure storage is left untouched.
  ///
  /// Phase 3c seam: needed by the Saved hosts card's Edit action (Task 6)
  /// so users can rename a credential without re-typing username/password.
  Future<void> updateDisplayName(String id, String? displayName) =>
      _repo.updateDisplayName(id, displayName);
}
