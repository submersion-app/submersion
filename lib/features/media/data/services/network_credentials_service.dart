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
import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';
import 'package:submersion/features/media/data/repositories/network_credentials_repository.dart';
import 'package:submersion/features/media/data/synology/synology_api.dart';
import 'package:submersion/features/media/data/synology/synology_share_link.dart';
import 'package:submersion/features/media/data/synology/synology_share_sessions.dart';

/// Auth type for a Synology Photos share password. Requests to the share's
/// API carry a session cookie instead of a static header; see
/// [NetworkCredentialsService.headersFor].
const String kSynologyShareAuthType = 'synologyShare';

class NetworkCredentialsService {
  NetworkCredentialsService({
    required NetworkCredentialsRepository repository,
    required FlutterSecureStorage storage,
    void Function()? onCredentialsChanged,
    SynologyShareSessions? synologySessions,
  }) : _repo = repository,
       _storage = FallbackSecureStorage(storage),
       _onCredentialsChanged = onCredentialsChanged,
       _synologySessions = synologySessions;

  final NetworkCredentialsRepository _repo;
  final FallbackSecureStorage _storage;

  /// Opens sessions for hosts whose secret is a Synology share password.
  /// Without it such a secret yields no headers.
  final SynologyShareSessions? _synologySessions;

  /// Called after [save] or [delete] changes a host's secret, so holders of
  /// an earlier [headersFor] result can ask again.
  final void Function()? _onCredentialsChanged;

  final _log = LoggerService.forClass(NetworkCredentialsService);

  /// Per-process cache of decoded secrets (hostname -> secret) so repeated
  /// `headersFor` calls during a single bulk-import or scan don't hit
  /// the keychain on every URL. A null value records that the host has no
  /// credentials, which is most hosts. This service is the only writer of
  /// these secrets, so an entry stays valid until [save] or [delete] replaces
  /// it. A failed keychain read records nothing.
  final Map<String, _StoredSecret?> _secretCache = {};

  /// The keychain lookup under way for each host, shared by everyone who asks
  /// before it finishes. Removing an entry disowns that lookup: see
  /// [_invalidate].
  final Map<String, Future<_StoredSecret?>> _lookups = {};

  /// The last keychain change queued for each host. See [_changeKeychain].
  final Map<String, Future<void>> _keychainChanges = {};

  static const _keyPrefix = 'media_network_cred_';

  /// Persists credentials for [hostname]. For `basic` auth, both
  /// [username] and [password] are required. For `bearer` auth, [token]
  /// is required. For [kSynologyShareAuthType], [password] is required.
  /// Throws [ArgumentError] for any other combination.
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
    } else if (authType == kSynologyShareAuthType) {
      if (password == null || password.isEmpty) {
        throw ArgumentError('A Synology share requires its password');
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
    await _changeKeychain(
      hostname,
      () => _storage.write(key: _keyPrefix + hostname, value: secret),
    );
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
  ///
  /// A host holding a Synology share password answers with the share's
  /// session headers, and only for that share's URLs: see
  /// [_synologyHeaders].
  Future<Map<String, String>?> headersFor(Uri uri) async {
    final secret = await _secretFor(uri.host);
    return switch (secret) {
      null => null,
      _HeaderSecret(:final headers) => headers,
      _SynologyShareSecret(:final password) => _synologyHeaders(uri, password),
    };
  }

  /// The Synology share password saved for [host], or null when the host has
  /// no credentials or credentials of another type.
  Future<String?> synologySharePassword(String host) async {
    final secret = await _secretFor(host);
    return secret is _SynologyShareSecret ? secret.password : null;
  }

  /// Session headers for a share URL. A failing login yields no headers
  /// rather than an exception: callers treat a missing header as "fetch
  /// without credentials", and the share then answers with its own error.
  Future<Map<String, String>?> _synologyHeaders(
    Uri uri,
    String password,
  ) async {
    final sessions = _synologySessions;
    final link = SynologyShareLink.tryParseAny(uri);
    if (sessions == null || link == null) return null;
    try {
      return await sessions.headersFor(link, password);
    } on SynologyShareException catch (e) {
      _log.warning('No Synology share session for ${uri.host}: ${e.kind}');
      return null;
    }
  }

  Future<_StoredSecret?> _secretFor(String host) {
    if (_secretCache.containsKey(host)) return Future.value(_secretCache[host]);
    final running = _lookups[host];
    if (running != null) return running;
    late final Future<_StoredSecret?> lookup;
    // _lookUp reaches its first await before anything asks isCurrent, by which
    // time the lookup is assigned and registered.
    lookup = _lookUp(host, isCurrent: () => identical(_lookups[host], lookup));
    return _lookups[host] = lookup;
  }

  /// Reads and decodes [host]'s secret. Once [isCurrent] turns false the
  /// credentials changed during the read, so what was read must neither be
  /// cached nor act on the key, which now holds a newer secret.
  Future<_StoredSecret?> _lookUp(
    String host, {
    required bool Function() isCurrent,
  }) async {
    try {
      final raw = await _storage.read(key: _keyPrefix + host);
      final secret = raw == null ? null : _decodeSecret(raw);
      if (!isCurrent()) return secret;
      if (raw != null && secret == null) await _removeBlob(host, raw);
      if (isCurrent()) _secretCache[host] = secret;
      if (secret != null) await _touchLastUsed(host);
      return secret;
    } finally {
      if (isCurrent()) _lookups.remove(host);
    }
  }

  /// Deletes [host]'s secret if it is still the malformed [raw]. A save may
  /// have been writing a good secret since [raw] was read, and it only
  /// disowns the running lookup once that write has finished.
  Future<void> _removeBlob(String host, String raw) =>
      _changeKeychain(host, () async {
        final key = _keyPrefix + host;
        if (await _storage.read(key: key) == raw) {
          await _storage.delete(key: key);
        }
      });

  /// Runs [change] after every change already queued for [host], so a check
  /// and the delete it decides on cannot interleave with a write.
  Future<void> _changeKeychain(
    String host,
    Future<void> Function() change,
  ) async {
    final previous = _keychainChanges[host];
    final finished = Completer<void>();
    _keychainChanges[host] = finished.future;
    try {
      await previous;
      await change();
    } finally {
      finished.complete();
      if (identical(_keychainChanges[host], finished.future)) {
        _keychainChanges.remove(host);
      }
    }
  }

  /// The secret a stored blob [raw] stands for, or null when it is
  /// malformed or from a stale schema.
  static _StoredSecret? _decodeSecret(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded case {
      'authType': kSynologyShareAuthType,
      'password': final String password,
    } when password.isNotEmpty) {
      return _SynologyShareSecret(password);
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
    return _HeaderSecret(Map.unmodifiable({'Authorization': authorization}));
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
    _secretCache.remove(hostname);
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
    await _changeKeychain(
      row.hostname,
      () => _storage.delete(key: _keyPrefix + row.hostname),
    );
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

/// A host's decoded keychain secret.
sealed class _StoredSecret {
  const _StoredSecret();
}

/// Basic or bearer credentials: the same headers on every request.
class _HeaderSecret extends _StoredSecret {
  const _HeaderSecret(this.headers);

  final Map<String, String> headers;
}

/// A Synology share password: headers come from a session that changes.
class _SynologyShareSecret extends _StoredSecret {
  const _SynologyShareSecret(this.password);

  final String password;
}
