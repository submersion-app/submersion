import 'dart:convert';

import 'package:collection/collection.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_location.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_credentials_store.dart';
import 'package:submersion/core/services/shared_library/library_account_setup.dart';

/// The secret a diver types to sign in to their own server.
sealed class ServerSecret {
  const ServerSecret();
}

final class S3Secret extends ServerSecret {
  const S3Secret({required this.accessKeyId, required this.secretAccessKey});
  final String accessKeyId;
  final String secretAccessKey;
}

final class WebDavSecret extends ServerSecret {
  const WebDavSecret({required this.password, this.pinnedCertSha256});
  final String password;
  final String? pinnedCertSha256;
}

/// Acts on an account, which may be several roster rows on one server
/// (spec section 7.2). Ids and natural keys are never changed here: every
/// row written is the row its own config hashes to.
class AccountGroupService {
  AccountGroupService({
    ConnectedAccountsRepository? accounts,
    AccountCredentialsStore? credentials,
    required AccountProviderRegistry registry,
  }) : _accounts = accounts ?? ConnectedAccountsRepository(),
       _credentials = credentials ?? AccountCredentialsStore(),
       _registry = registry;

  final ConnectedAccountsRepository _accounts;
  final AccountCredentialsStore _credentials;
  final AccountProviderRegistry _registry;

  /// Signs [group] in on this device: each row's config is rebuilt from its
  /// location (or this device's stored config) with [secret], and written
  /// only when it hashes back to that row's id, so a stale or foreign
  /// location can never overwrite another row. Returns how many rows were
  /// signed in.
  Future<int> storeServerSecret(AccountGroup group, ServerSecret secret) async {
    var signedIn = 0;
    for (final row in group.rows) {
      final json = await _configJsonFor(row, group.locationOf(row.id), secret);
      if (json == null) continue;
      await _credentials.write(row.id, json.config);
      await _accounts.setLocation(row.id, json.location);
      signedIn++;
    }
    return signedIn;
  }

  Future<({String config, AccountLocation location})?> _configJsonFor(
    ConnectedAccount row,
    AccountLocation? location,
    ServerSecret secret,
  ) async {
    switch ((row.kind, secret)) {
      case (AccountKind.s3, final S3Secret s):
        final base = location is S3AccountLocation
            ? location.toConfig(
                accessKeyId: s.accessKeyId,
                secretAccessKey: s.secretAccessKey,
              )
            : (await _storedS3(row.id))?.copyWith(
                accessKeyId: s.accessKeyId,
                secretAccessKey: s.secretAccessKey,
              );
        if (base == null || _s3Id(base) != row.id) return null;
        return (
          config: jsonEncode(base.toJson()),
          location: S3AccountLocation.fromConfig(base),
        );
      case (AccountKind.webdav, final WebDavSecret s):
        final base = location is WebDavAccountLocation
            ? location.toConfig(
                password: s.password,
                pinnedCertSha256: s.pinnedCertSha256,
              )
            : (await _storedWebDav(row.id))?.copyWith(
                password: s.password,
                pinnedCertSha256: s.pinnedCertSha256,
              );
        if (base == null || _webDavId(base) != row.id) return null;
        return (
          config: jsonEncode(base.toJson()),
          location: WebDavAccountLocation.fromConfig(base),
        );
      default:
        return null;
    }
  }

  /// Creates [role]'s row on [group]'s server with the group's credentials
  /// and the role's default folder ([libraryFolder] for a library), with no
  /// form (spec section 7.2). Throws [StateError] when no row of the group
  /// holds credentials on this device.
  Future<ConnectedAccount> ensureRole(
    AccountGroup group,
    AccountRole role, {
    String? libraryFolder,
  }) async {
    final existing = role == AccountRole.library ? null : group.rowFor(role);
    if (existing != null && await _credentials.read(existing.id) != null) {
      return existing;
    }
    for (final row in group.rows) {
      switch (row.kind) {
        case AccountKind.s3:
          final server = await _storedS3(row.id);
          if (server == null) continue;
          final where = _folderFor(role, libraryFolder);
          return saveOwnServer(
            s3: server.copyWith(prefix: where.s3),
            labelNote: where.note,
          );
        case AccountKind.webdav:
          final server = await _storedWebDav(row.id);
          if (server == null) continue;
          final where = _folderFor(role, libraryFolder);
          return saveOwnServer(
            webdav: server.copyWith(folder: where.webdav),
            labelNote: where.note,
          );
        default:
          continue;
      }
    }
    throw StateError('not signed in');
  }

  ({String s3, String webdav, String? note}) _folderFor(
    AccountRole role,
    String? libraryFolder,
  ) => switch (role) {
    AccountRole.sync => (
      s3: 'submersion-sync/',
      webdav: kDefaultWebDavSyncFolder,
      note: null,
    ),
    AccountRole.media => (
      s3: 'submersion-media/',
      webdav: kDefaultWebDavMediaFolder,
      note: null,
    ),
    AccountRole.library => () {
      final where = LibraryAccountSetup.libraryFolder(libraryFolder ?? '');
      return (s3: '$where/', webdav: where, note: where);
    }(),
  };

  /// Saves a server: the row its config hashes to, with its label, location
  /// and credentials. A new server's first row is its sync-role row, created
  /// whether or not sync uses it yet (spec section 7.2). [labelNote] is the
  /// library folder a library row's label names, as today.
  Future<ConnectedAccount> saveOwnServer({
    S3Config? s3,
    WebDavConfig? webdav,
    String? labelNote,
  }) async {
    assert((s3 == null) != (webdav == null), 'exactly one server');
    final note = labelNote == null ? '' : ' ($labelNote)';
    if (s3 != null) {
      final account = await _accounts.ensure(
        kind: AccountKind.s3,
        naturalKey: s3NaturalKey(s3),
        label: '${s3.bucket} @ ${s3.displayHost}$note',
        location: S3AccountLocation.fromConfig(s3),
      );
      await _credentials.write(account.id, jsonEncode(s3.toJson()));
      return account;
    }
    final account = await _accounts.ensure(
      kind: AccountKind.webdav,
      naturalKey: webdavNaturalKey(webdav!),
      label: '${webdav.displayLabel}$note',
      location: WebDavAccountLocation.fromConfig(webdav),
    );
    await _credentials.write(account.id, jsonEncode(webdav.toJson()));
    return account;
  }

  /// Signs every row of [group] out on this device.
  Future<void> signOut(AccountGroup group) async {
    for (final row in group.rows) {
      await _adapterFor(row)?.disconnect(row);
    }
  }

  /// Signs every row out, then removes it from the roster on every device.
  Future<void> remove(AccountGroup group) async {
    for (final row in group.rows) {
      await _adapterFor(row)?.disconnect(row);
      await _accounts.delete(row.id);
    }
  }

  /// The server config this device holds for any row of [group], or null.
  Future<S3Config?> storedS3For(AccountGroup group) async {
    for (final row in group.rows) {
      final config = await _storedS3(row.id);
      if (config != null) return config;
    }
    return null;
  }

  Future<WebDavConfig?> storedWebDavFor(AccountGroup group) async {
    for (final row in group.rows) {
      final config = await _storedWebDav(row.id);
      if (config != null) return config;
    }
    return null;
  }

  /// The S3 config this device holds for the row [rowId], or null.
  Future<S3Config?> storedS3ForRow(String rowId) => _storedS3(rowId);

  /// The WebDAV config this device holds for the row [rowId], or null.
  Future<WebDavConfig?> storedWebDavForRow(String rowId) =>
      _storedWebDav(rowId);

  AccountProviderAdapter? _adapterFor(ConnectedAccount row) =>
      _registry.capabilityFor<AccountProviderAdapter>(row.kind);

  Future<S3Config?> _storedS3(String id) async {
    final raw = await _credentials.read(id);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?>
          ? S3Config.fromJson(decoded)
          : null;
    } on Object {
      return null;
    }
  }

  Future<WebDavConfig?> _storedWebDav(String id) async =>
      decodeWebDavConfig(await _credentials.read(id));

  static String _s3Id(S3Config c) =>
      accountIdFor(kind: AccountKind.s3, naturalKey: s3NaturalKey(c));

  static String _webDavId(WebDavConfig c) =>
      accountIdFor(kind: AccountKind.webdav, naturalKey: webdavNaturalKey(c));
}

extension AccountGroupLookup on List<AccountGroup> {
  /// The group holding the roster row [rowId], or null.
  AccountGroup? holding(String? rowId) => rowId == null
      ? null
      : firstWhereOrNull((g) => g.rows.any((r) => r.id == rowId));
}
