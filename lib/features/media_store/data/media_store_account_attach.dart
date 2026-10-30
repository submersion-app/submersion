import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_group_service.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_marker.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';

/// Sets up photo copies in an account the diver chose from the account
/// sheet (spec sections 7.4 and 8.3).
///
/// The account's photos-folder row is reached first: an own server gets
/// one made with the account's keys (`submersion-media/` or the WebDAV
/// media folder) when it has none, and the other kinds use their one row.
/// Its store is built through the same adapter the runtime uses, so the
/// copies never read keys the attachment does not name.
class MediaStoreAccountAttach {
  MediaStoreAccountAttach({
    required MediaStoreService service,
    required AccountGroupService accounts,
    required AccountProviderRegistry registry,
  }) : _service = service,
       _accounts = accounts,
       _registry = registry;

  final MediaStoreService _service;
  final AccountGroupService _accounts;
  final AccountProviderRegistry _registry;

  /// Attaches this device's copies to [group]. [storeAccountId] is the row
  /// the library's announced store records: when [group] holds it, that row
  /// is used, so a second device joins the copies in their own folder. A
  /// store that records none ([storeId] its id) is looked for on [group]'s
  /// server rows before a default folder is used. Throws
  /// [MediaStoreAccountUnusable] when the account holds no usable keys here.
  Future<MediaStoreConnectResult> attach(
    AccountGroup group, {
    String? storeAccountId,
    String? storeId,
  }) async {
    final (row, store) = await _resolve(group, storeAccountId, storeId);
    return _service.attachToAccountRow(row, store);
  }

  /// Moves this device's copies to [group]. The current copies stay
  /// attached until [group]'s store has answered its marker check, so an
  /// account with no keys here, or one that refuses or cannot be reached,
  /// fails with nothing changed. Once it answers, the attachment names
  /// [group]'s store in place of the old one (nothing in either is deleted).
  ///
  /// When the library already has copies on [group] (a switch back), their
  /// recorded row is used, so the device rejoins them in their own folder.
  Future<MediaStoreConnectResult> switchTo(AccountGroup group) async {
    final earlier = await _service.storeOnAccounts(group.rows.map((r) => r.id));
    final (row, store) = await _resolve(group, earlier?.accountId, earlier?.id);
    return _service.attachToAccountRow(row, store, replacing: true);
  }

  /// Pins the self-signed certificate [sha256] on [group]'s WebDAV keys,
  /// as the server form does when the diver trusts it, so the next attach
  /// reaches the server.
  Future<void> trustCertificate(AccountGroup group, String sha256) async {
    final held = await _accounts.storedWebDavFor(group);
    if (held == null) return;
    await _accounts.storeServerConfig(
      group,
      webdav: held.copyWith(pinnedCertSha256: sha256),
      previousWebDav: held,
    );
  }

  Future<(ConnectedAccount, MediaObjectStore?)> _resolve(
    AccountGroup group,
    String? storeAccountId,
    String? storeId,
  ) async {
    final ConnectedAccount row;
    try {
      row = await _mediaRowOf(group, storeAccountId, storeId);
    } on StateError {
      throw MediaStoreAccountUnusable(
        '${group.label} is not signed in on this device',
      );
    }
    return (row, await _storeOf(row));
  }

  Future<MediaObjectStore?> _storeOf(ConnectedAccount row) async => _registry
      .capabilityFor<MediaStoreCapable>(row.kind)
      ?.mediaObjectStore(row);

  Future<ConnectedAccount> _mediaRowOf(
    AccountGroup group,
    String? storeAccountId,
    String? storeId,
  ) async {
    final recorded = group.rows
        .where((r) => r.id == storeAccountId)
        .firstOrNull;
    if (recorded != null) {
      await _giveServerKeys(group, recorded);
      return recorded;
    }
    if (group.kind == AccountKind.s3 || group.kind == AccountKind.webdav) {
      final found = storeId == null
          ? null
          : await _rowHoldingStore(group, storeId);
      return found ?? await _accounts.ensureRole(group, AccountRole.media);
    }
    return group.rowFor(AccountRole.media) ?? group.rows.first;
  }

  /// The server row whose folder carries [storeId]'s marker: a store set
  /// up in a folder of the diver's choosing before stores recorded their
  /// row, which the default photos folder would miss. Reads one marker per
  /// row; a row that cannot be read is passed over.
  Future<ConnectedAccount?> _rowHoldingStore(
    AccountGroup group,
    String storeId,
  ) async {
    for (final row in group.rows) {
      await _giveServerKeys(group, row);
      final store = await _storeOf(row);
      if (store == null) continue;
      try {
        final marker = await StoreMarkerStore(store: store).read();
        if (marker?.storeId == storeId) return row;
      } on MediaStoreException {
        continue;
      }
    }
    return null;
  }

  /// Writes the server keys this device holds for [group] to [row] when it
  /// has none, through the same path an edit of the server takes (rows
  /// holding other keys keep them). A row that still has none afterwards is
  /// refused by the attach.
  Future<void> _giveServerKeys(AccountGroup group, ConnectedAccount row) async {
    switch (row.kind) {
      case AccountKind.s3:
        if (await _accounts.storedS3ForRow(row.id) != null) return;
        final held = await _accounts.storedS3For(group);
        if (held == null) return;
        await _accounts.storeServerConfig(group, s3: held, previousS3: held);
      case AccountKind.webdav:
        if (await _accounts.storedWebDavForRow(row.id) != null) return;
        final held = await _accounts.storedWebDavFor(group);
        if (held == null) return;
        await _accounts.storeServerConfig(
          group,
          webdav: held,
          previousWebDav: held,
        );
      default:
        return;
    }
  }
}
