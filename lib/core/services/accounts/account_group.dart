import 'package:collection/collection.dart';

import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_display_name.dart';
import 'package:submersion/core/services/accounts/account_location.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';

/// What a roster row is for on its server. The folder is part of the row's
/// id, so a server used for sync and photos is two rows (spec section 7.2).
enum AccountRole { sync, media, library }

/// One account as the diver sees it: a sign-in to one server (or one OAuth
/// account), however many roster rows sit under it (issue #3482).
class AccountGroup {
  const AccountGroup({
    required this.key,
    required this.kind,
    required this.label,
    required this.rows,
    required this.status,
    required this.usages,
    required this.locations,
    required this.roles,
    this.identifier,
    this.usagesKnown = true,
    String? address,
    this.nickname,
  }) : address = address ?? label;

  /// Stable across rebuilds: kind and server for own servers, kind and row
  /// for everything else, `row|<id>` for a row nothing here can place.
  final String key;
  final AccountKind kind;

  /// The name the account is shown under: the diver's nickname, else its
  /// address with a well-known service's host named (issue #3522).
  final String label;

  /// The account's full address ("bucket @ host"), shown under a short
  /// [label] so two accounts on one service can still be told apart.
  final String address;

  /// The nickname the diver gave the account, or null.
  final String? nickname;

  /// The account email or similar, where the roster holds one.
  final String? identifier;
  final List<ConnectedAccount> rows;
  final AccountStatus status;
  final List<AccountUsage> usages;

  /// False when what uses the account could not be read: [usages] is then
  /// empty but must not be taken as unused (a sign-out still asks first).
  final bool usagesKnown;

  /// Each row's location, from the roster or this device's stored config.
  final Map<String, AccountLocation> locations;

  /// Each row's role, where its usage or folder tells.
  final Map<String, AccountRole> roles;

  bool get isOwnServer => kind == AccountKind.s3 || kind == AccountKind.webdav;

  ConnectedAccount? rowFor(AccountRole role) =>
      rows.firstWhereOrNull((r) => roles[r.id] == role);

  AccountLocation? locationOf(String rowId) => locations[rowId];
}

/// Groups roster rows into accounts (spec section 7.2).
///
/// An S3 or WebDAV row groups by its server: the roster's location first,
/// then [localLocationById] (this device's stored config), and a row known
/// to neither stands alone rather than being guessed into another group.
List<AccountGroup> groupAccounts({
  required List<ConnectedAccount> rows,
  required Map<String, AccountStatus> statusById,
  required Map<String, AccountLocation> localLocationById,
  required List<AccountUsage> Function(ConnectedAccount) usagesOf,
  bool usagesKnown = true,
}) {
  final byKey = <String, List<ConnectedAccount>>{};
  final locations = <String, AccountLocation>{};
  for (final row in rows) {
    final location = row.location ?? localLocationById[row.id];
    if (location != null) locations[row.id] = location;
    final key = switch (row.kind) {
      AccountKind.s3 || AccountKind.webdav =>
        location == null ? 'row|${row.id}' : location.serverKey,
      _ => '${row.kind.name}|${row.id}',
    };
    (byKey[key] ??= []).add(row);
  }

  final groups = [
    for (final MapEntry(:key, value: members) in byKey.entries)
      _group(key, members, statusById, locations, usagesOf, usagesKnown),
  ];
  groups.sort((a, b) {
    final byKind = _kindOrder(a.kind).compareTo(_kindOrder(b.kind));
    return byKind != 0 ? byKind : a.label.compareTo(b.label);
  });
  return groups;
}

AccountGroup _group(
  String key,
  List<ConnectedAccount> members,
  Map<String, AccountStatus> statusById,
  Map<String, AccountLocation> allLocations,
  List<AccountUsage> Function(ConnectedAccount) usagesOf,
  bool usagesKnown,
) {
  final first = members.first;
  final statuses = [
    for (final r in members) statusById[r.id] ?? AccountStatus.unavailable,
  ];
  final status = statuses.contains(AccountStatus.needsSignIn)
      ? AccountStatus.needsSignIn
      : statuses.every((s) => s == AccountStatus.unavailable)
      ? AccountStatus.unavailable
      : AccountStatus.signedIn;

  final usages = <AccountUsage>[];
  final roles = <String, AccountRole>{};
  final locations = <String, AccountLocation>{};
  for (final row in members) {
    final rowUsages = usagesOf(row);
    for (final u in rowUsages) {
      if (!usages.contains(u)) usages.add(u);
    }
    final location = allLocations[row.id];
    if (location != null) locations[row.id] = location;
    final role = _roleOf(rowUsages, location);
    if (role != null) roles[row.id] = role;
  }

  final location = locations.values.firstOrNull;
  final address = switch (location) {
    S3AccountLocation(:final bucket, :final displayHost) =>
      '$bucket @ $displayHost',
    WebDavAccountLocation(:final username, :final host) => '$username @ $host',
    null => _withoutFolderNote(first.label),
  };
  // A nickname on any row names the account; the sync-role row's wins.
  final named =
      [...members.where((r) => roles[r.id] == AccountRole.sync), ...members]
          .map((r) => r.nickname?.trim())
          .firstWhereOrNull((n) => n != null && n.isNotEmpty);
  final label = accountDisplayName(label: address, nickname: named);

  return AccountGroup(
    key: key,
    kind: first.kind,
    label: label,
    identifier: members
        .map((r) => r.accountIdentifier)
        .firstWhereOrNull((i) => i != null && i.isNotEmpty),
    rows: List.unmodifiable(members),
    status: status,
    usages: List.unmodifiable(usages),
    locations: Map.unmodifiable(locations),
    roles: Map.unmodifiable(roles),
    usagesKnown: usagesKnown,
    address: address,
    nickname: named,
  );
}

/// The role a row's usage names, else the one its default folder names.
AccountRole? _roleOf(List<AccountUsage> usages, AccountLocation? location) {
  for (final u in usages) {
    switch (u.kind) {
      case AccountUsageKind.databaseSync:
        return AccountRole.sync;
      case AccountUsageKind.mediaStorage:
        return AccountRole.media;
      case AccountUsageKind.sharedLibrary:
        return AccountRole.library;
      case AccountUsageKind.lightroom:
        break;
    }
  }
  final folder = location?.folder;
  if (folder == null) return null;
  if (folder == 'submersion-sync' || folder == kDefaultWebDavSyncFolder) {
    return AccountRole.sync;
  }
  if (folder == 'submersion-media' || folder == kDefaultWebDavMediaFolder) {
    return AccountRole.media;
  }
  if (folder == SharedLibraryLayout.librariesDir ||
      folder.startsWith('${SharedLibraryLayout.librariesDir}/')) {
    return AccountRole.library;
  }
  return null;
}

/// "dives @ minio (submersion-sites/club)" reads "dives @ minio".
String _withoutFolderNote(String label) =>
    label.replaceFirst(RegExp(r'\s*\([^()]*\)$'), '');

int _kindOrder(AccountKind kind) => switch (kind) {
  AccountKind.icloud => 0,
  AccountKind.googledrive => 1,
  AccountKind.dropbox => 2,
  AccountKind.s3 || AccountKind.webdav => 3,
  AccountKind.adobeLightroom => 4,
};
