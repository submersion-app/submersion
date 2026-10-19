import 'dart:convert';

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
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_credentials_store.dart';
import 'package:submersion/core/services/shared_library/library_account_setup.dart';

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
    // Rows of the same role first: a club may hand out keys for its library
    // folder on the bucket a diver also syncs to, and a new library should
    // take those, not the diver's own sync keys.
    final ordered = [
      ...group.rows.where((r) => group.roles[r.id] == role),
      ...group.rows.where((r) => group.roles[r.id] != role),
    ];
    for (final row in ordered) {
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

  /// The server config this device holds for [group]: its sync-role row's
  /// first, so an edit form never starts from a library or photos folder.
  Future<S3Config?> storedS3For(AccountGroup group) async {
    for (final row in _syncFirst(group)) {
      final config = await _storedS3(row.id);
      if (config != null) return config;
    }
    return null;
  }

  Future<WebDavConfig?> storedWebDavFor(AccountGroup group) async {
    for (final row in _syncFirst(group)) {
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

  static List<ConnectedAccount> _syncFirst(AccountGroup group) => [
    ...group.rows.where((r) => group.roles[r.id] == AccountRole.sync),
    ...group.rows.where((r) => group.roles[r.id] != AccountRole.sync),
  ];

  /// Saves an edit of [group]'s server: each row takes the submitted
  /// settings (keys, region, addressing, certificate) with its own folder,
  /// only when the result still hashes to that row's id, and only when the
  /// row holds no keys here or the same keys as [previousS3] /
  /// [previousWebDav] (what the form was filled from): a club's own keys on
  /// its library folder are not replaced by the diver's. Returns how many
  /// rows were written.
  Future<int> storeServerConfig(
    AccountGroup group, {
    S3Config? s3,
    WebDavConfig? webdav,
    S3Config? previousS3,
    WebDavConfig? previousWebDav,
  }) async {
    var written = 0;
    for (final row in group.rows) {
      if (!await _holdsKeysOf(row, previousS3, previousWebDav)) continue;
      final folder =
          group.locationOf(row.id)?.folder ??
          switch (row.kind) {
            AccountKind.s3 => (await _storedS3(
              row.id,
            ))?.prefix.replaceAll(RegExp(r'/+$'), ''),
            AccountKind.webdav => (await _storedWebDav(row.id))?.folder,
            _ => null,
          };
      if (folder == null) continue;
      switch (row.kind) {
        case AccountKind.s3 when s3 != null:
          final config = s3.copyWith(prefix: folder.isEmpty ? '' : '$folder/');
          if (_s3Id(config) != row.id) continue;
          await _credentials.write(row.id, jsonEncode(config.toJson()));
          await _accounts.setLocation(
            row.id,
            S3AccountLocation.fromConfig(config),
          );
          written++;
        case AccountKind.webdav when webdav != null:
          final config = webdav.copyWith(folder: folder);
          if (_webDavId(config) != row.id) continue;
          await _credentials.write(row.id, jsonEncode(config.toJson()));
          await _accounts.setLocation(
            row.id,
            WebDavAccountLocation.fromConfig(config),
          );
          written++;
        default:
          continue;
      }
    }
    return written;
  }

  /// Whether [row] holds no keys here, or the same keys as the previous
  /// config (with no previous config, any).
  Future<bool> _holdsKeysOf(
    ConnectedAccount row,
    S3Config? previousS3,
    WebDavConfig? previousWebDav,
  ) async {
    switch (row.kind) {
      case AccountKind.s3:
        final held = await _storedS3(row.id);
        return held == null ||
            previousS3 == null ||
            held.accessKeyId == previousS3.accessKeyId;
      case AccountKind.webdav:
        final held = await _storedWebDav(row.id);
        return held == null ||
            previousWebDav == null ||
            (held.username == previousWebDav.username &&
                held.password == previousWebDav.password);
      default:
        return true;
    }
  }

  AccountProviderAdapter? _adapterFor(ConnectedAccount row) =>
      _registry.capabilityFor<AccountProviderAdapter>(row.kind);

  Future<S3Config?> _storedS3(String id) async =>
      decodeS3Config(await _credentials.read(id));

  Future<WebDavConfig?> _storedWebDav(String id) async =>
      decodeWebDavConfig(await _credentials.read(id));

  static String _s3Id(S3Config c) =>
      accountIdFor(kind: AccountKind.s3, naturalKey: s3NaturalKey(c));

  static String _webDavId(WebDavConfig c) =>
      accountIdFor(kind: AccountKind.webdav, naturalKey: webdavNaturalKey(c));
}
