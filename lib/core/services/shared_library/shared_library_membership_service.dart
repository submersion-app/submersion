import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/site_detacher.dart';

/// What a prefix holds, as read before joining or creating.
class LibraryProbe {
  const LibraryProbe({
    required this.exists,
    this.id,
    this.name,
    this.formatVersion = SharedLibraryLayout.formatVersion,
  });

  final bool exists;
  final String? id;
  final String? name;
  final int formatVersion;

  bool get needsNewerApp =>
      exists && formatVersion > SharedLibraryLayout.formatVersion;
}

typedef LibraryTransportFactory =
    Future<SharedLibraryTransport> Function({
      required domain.ConnectedAccount account,
      required String prefix,
    });

/// Connecting, creating, joining and leaving club libraries, member
/// display names and owner role changes (issue #2567).
class SharedLibraryMembershipService {
  SharedLibraryMembershipService({
    required SharedLibraryStore store,
    required LibraryTransportFactory transportFor,
    Future<domain.ConnectedAccount?> Function(String accountId)? accountById,
    SiteDetacher? detacher,
    String appVersion = 'unknown',
  }) : _store = store,
       _transportFor = transportFor,
       _accountById =
           accountById ?? ((id) => ConnectedAccountsRepository().getById(id)),
       _detacher = detacher ?? SiteDetacher(),
       _appVersion = appVersion;

  final SharedLibraryStore _store;
  final LibraryTransportFactory _transportFor;
  final Future<domain.ConnectedAccount?> Function(String) _accountById;
  final SiteDetacher _detacher;
  final String _appVersion;
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(SharedLibraryMembershipService);
  AppDatabase get _db => DatabaseService.instance.database;

  Future<SharedLibraryTransport> transportForLibrary(SharedLibrary lib) async {
    final account =
        await _accountById(lib.connectedAccountId) ??
        domain.ConnectedAccount(
          id: lib.connectedAccountId,
          kind: AccountKind.s3,
          label: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
    return _transportFor(account: account, prefix: lib.prefix);
  }

  Future<LibraryProbe> probe({
    required domain.ConnectedAccount account,
    required String prefix,
  }) async {
    final t = await _transportFor(account: account, prefix: prefix);
    final manifest = await t.readManifest();
    if (manifest == null) return const LibraryProbe(exists: false);
    return LibraryProbe(
      exists: true,
      id: manifest['id'] as String?,
      name: manifest['name'] as String?,
      formatVersion:
          (manifest['formatVersion'] as num?)?.toInt() ??
          SharedLibraryLayout.formatVersion,
    );
  }

  /// Writes the manifest, the roles (creator as owner) and the member card,
  /// then records the library and the membership locally.
  Future<SharedLibrary> create({
    required domain.ConnectedAccount account,
    required String prefix,
    required String name,
    required String diverId,
    required String displayName,
  }) async {
    final t = await _transportFor(account: account, prefix: prefix);
    final libraryId = _uuid.v4();
    final memberId = await _store.memberIdForDiver(diverId);
    final now = DateTime.now().toUtc();
    await t.writeManifest({
      'id': libraryId,
      'name': name,
      'formatVersion': SharedLibraryLayout.formatVersion,
      'createdBy': memberId,
      'createdAt': now.toIso8601String(),
    });
    final roles = SharedLibraryRoles(owners: {memberId});
    await t.writeRoles(roles);
    final me = SharedLibraryMember(
      memberId: memberId,
      displayName: displayName,
      joinedAt: now,
    );
    await t.writeMember(me, appVersion: _appVersion);
    final library = SharedLibrary(
      id: libraryId,
      name: name,
      connectedAccountId: account.id,
      prefix: prefix,
      roles: roles,
    );
    await _store.upsertLibrary(library);
    await _store.replaceMembers(libraryId, [me]);
    await _store.upsertMembership(
      _membership(
        libraryId: libraryId,
        libraryName: name,
        diverId: diverId,
        memberId: memberId,
        displayName: displayName,
        account: account,
        prefix: prefix,
      ),
    );
    return library;
  }

  /// Joins the library at [prefix]: the manifest must exist and be
  /// readable by this build.
  Future<SharedLibrary> join({
    required domain.ConnectedAccount account,
    required String prefix,
    required String diverId,
    required String displayName,
  }) async {
    final found = await probe(account: account, prefix: prefix);
    if (!found.exists || found.id == null || found.id!.isEmpty) {
      throw StateError('No library at $prefix');
    }
    if (found.needsNewerApp) {
      throw StateError(
        'Library format ${found.formatVersion} needs a newer app',
      );
    }
    final t = await _transportFor(account: account, prefix: prefix);
    final libraryId = found.id!;
    final name = found.name ?? prefix;
    final memberId = await _store.memberIdForDiver(diverId);
    final roles = await t.readRoles();
    final members = await t.listMembers();
    SharedLibraryMember? mine;
    for (final m in members) {
      if (m.memberId == memberId) mine = m;
    }
    final me = SharedLibraryMember(
      memberId: memberId,
      displayName: displayName,
      joinedAt: mine?.joinedAt ?? DateTime.now().toUtc(),
    );
    try {
      await t.writeMember(me, appVersion: _appVersion);
    } catch (e) {
      // A card the storage refuses is not a failed join: the library is
      // readable, and the sync retries the card.
      _log.warning('Could not write member card at $prefix: $e');
    }
    final existing = await _store.getLibrary(libraryId);
    final library =
        existing?.copyWith(name: name, roles: roles) ??
        SharedLibrary(
          id: libraryId,
          name: name,
          connectedAccountId: account.id,
          prefix: prefix,
          formatVersion: found.formatVersion,
          roles: roles,
        );
    await _store.upsertLibrary(library);
    await _store.replaceMembers(libraryId, [
      for (final m in members)
        if (m.memberId != memberId) m,
      me,
    ]);
    await _store.upsertMembership(
      _membership(
        libraryId: libraryId,
        libraryName: name,
        diverId: diverId,
        memberId: memberId,
        displayName: displayName,
        account: account,
        prefix: prefix,
      ),
    );
    return library;
  }

  SharedLibraryMembership _membership({
    required String libraryId,
    required String libraryName,
    required String diverId,
    required String memberId,
    required String displayName,
    required domain.ConnectedAccount account,
    required String prefix,
  }) => SharedLibraryMembership(
    id: _uuid.v4(),
    diverId: diverId,
    libraryId: libraryId,
    memberId: memberId,
    displayName: displayName,
    libraryName: libraryName,
    backendKind: account.kind.name,
    locationHint: '${account.label}: $prefix',
  );

  /// The profile leaves: its library sites are detached or removed, the
  /// membership is tombstoned for the profile's other devices, the member
  /// card is deleted when the storage allows, and the library row goes
  /// when no other profile on this device belongs to it.
  Future<void> leave({
    required String libraryId,
    required String diverId,
  }) async {
    final membership = await _store.membership(
      diverId: diverId,
      libraryId: libraryId,
    );
    final rows = await (_db.select(
      _db.diveSites,
    )..where((t) => t.sharedLibraryId.equals(libraryId))).get();
    for (final row in rows) {
      await _detacher.detachOrRemove(siteId: row.id, ownerDiverId: diverId);
    }
    if (membership != null) {
      await _store.deleteMembership(membership.id);
      final library = await _store.getLibrary(libraryId);
      if (library != null) {
        try {
          final t = await transportForLibrary(library);
          await t.deleteMember(membership.memberId);
        } catch (e) {
          _log.warning('Could not delete member card for $libraryId: $e');
        }
      }
    }
    if ((await _store.membershipsForLibrary(libraryId)).isEmpty) {
      await _store.deleteLibrary(libraryId);
    }
  }

  /// Renames the profile's member card and membership.
  Future<void> rename({
    required String libraryId,
    required String diverId,
    required String displayName,
  }) async {
    final membership = await _store.membership(
      diverId: diverId,
      libraryId: libraryId,
    );
    if (membership == null) throw StateError('not a member of $libraryId');
    await _store.upsertMembership(
      membership.copyWith(displayName: displayName),
    );
    final library = await _store.getLibrary(libraryId);
    if (library == null) return;
    final members = await _store.getMembers(libraryId);
    SharedLibraryMember? mine;
    for (final m in members) {
      if (m.memberId == membership.memberId) mine = m;
    }
    final me = SharedLibraryMember(
      memberId: membership.memberId,
      displayName: displayName,
      joinedAt: mine?.joinedAt ?? DateTime.now().toUtc(),
    );
    final t = await transportForLibrary(library);
    await t.writeMember(me, appVersion: _appVersion);
    await _store.replaceMembers(libraryId, [
      for (final m in members)
        if (m.memberId != membership.memberId) m,
      me,
    ]);
  }

  /// Owners only: rewrites roles.json. The last owner cannot be demoted.
  Future<void> setRole({
    required String libraryId,
    required String memberId,
    required SharedLibraryRole role,
  }) async {
    final library = await _store.getLibrary(libraryId);
    if (library == null) throw StateError('library $libraryId not connected');
    final roles = library.roles;
    if (role != SharedLibraryRole.owner &&
        roles.owners.contains(memberId) &&
        roles.owners.length == 1) {
      throw StateError('the last owner cannot be demoted');
    }
    final updated = roles.withRole(memberId, role);
    final t = await transportForLibrary(library);
    await t.writeRoles(updated);
    await _store.setLibraryStatus(libraryId, roles: updated);
  }
}
