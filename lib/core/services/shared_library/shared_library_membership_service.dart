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
import 'package:submersion/core/services/sync/sync_coordinator.dart';

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
/// Leaving would leave the library without an owner while other members
/// remain: one of them must be made owner first.
class LastOwnerLeaveError extends StateError {
  LastOwnerLeaveError(String libraryId)
    : super('the only owner of $libraryId cannot leave its members');
}

/// A library already lives at the location a create was asked for.
class LibraryExistsError extends StateError {
  LibraryExistsError(String prefix)
    : super('A library already exists at $prefix');
}

/// A role change would leave the library without an owner.
class LastOwnerDemoteError extends StateError {
  LastOwnerDemoteError(String libraryId)
    : super('the last owner of $libraryId cannot be demoted');
}

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
  }) async => _probeWith(await _transportFor(account: account, prefix: prefix));

  static Future<LibraryProbe> _probeWith(SharedLibraryTransport t) async {
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
    // A probe may be stale (another member created it meanwhile): writing
    // over a manifest would cut every existing member out.
    if (await t.readManifest() != null) throw LibraryExistsError(prefix);
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
    // The membership before the library row: a library row with none is
    // released by the next sync (releaseOrphanedLibraries).
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
    await _store.upsertLibrary(library);
    await _store.replaceMembers(libraryId, [me]);
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
    // One transport for the whole join: each resolves its folders afresh.
    final t = await _transportFor(account: account, prefix: prefix);
    final found = await _probeWith(t);
    if (!found.exists || found.id == null || found.id!.isEmpty) {
      throw StateError('No library at $prefix');
    }
    if (found.needsNewerApp) {
      throw StateError(
        'Library format ${found.formatVersion} needs a newer app',
      );
    }
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
    // The account and prefix the member joined through now, even when the
    // library row already exists from an earlier account.
    final library = SharedLibrary(
      id: libraryId,
      name: name,
      connectedAccountId: account.id,
      prefix: prefix,
      formatVersion: found.formatVersion,
      roles: roles,
    );
    // Connecting on another device finds the profile's membership already
    // synced in: keep its id, or the profile ends up with two and leaving
    // ends only one of them.
    final existing = await _store.membership(
      diverId: diverId,
      libraryId: libraryId,
    );
    final fresh = _membership(
      libraryId: libraryId,
      libraryName: name,
      diverId: diverId,
      memberId: memberId,
      displayName: displayName,
      account: account,
      prefix: prefix,
    );
    await _store.upsertMembership(
      existing == null
          ? fresh
          : existing.copyWith(
              displayName: displayName,
              libraryName: name,
              backendKind: fresh.backendKind,
              locationHint: fresh.locationHint,
            ),
    );
    await _store.upsertLibrary(library);
    await _store.replaceMembers(libraryId, [
      for (final m in members)
        if (m.memberId != memberId) m,
      me,
    ]);
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
  Future<void> leave({required String libraryId, required String diverId}) =>
      // Behind any library sync in flight: it would re-create the rows and
      // states this removes.
      SyncCoordinator.run(() => _leave(libraryId, diverId));

  Future<void> _leave(String libraryId, String diverId) async {
    final membership = await _store.membership(
      diverId: diverId,
      libraryId: libraryId,
    );
    final library = await _store.getLibrary(libraryId);
    SharedLibraryTransport? t;
    var roles = library?.roles ?? SharedLibraryRoles.empty;
    if (membership != null && library != null) {
      // The folder's roles when it can be reached: the cache may predate
      // another owner's change, and the revocation below writes these.
      try {
        t = await transportForLibrary(library);
        roles = await t.readRoles();
      } catch (e) {
        _log.warning('Using cached roles to leave $libraryId: $e');
      }
      // As setRole keeps an owner, so does leave: nobody else could manage
      // roles or review suggestions afterwards.
      final others = [
        for (final m in await _store.getMembers(libraryId))
          if (m.memberId != membership.memberId) m,
      ];
      if (others.isNotEmpty &&
          roles.owners.length == 1 &&
          roles.owners.contains(membership.memberId)) {
        throw LastOwnerLeaveError(libraryId);
      }
    }
    if (membership != null) {
      await _store.deleteMembership(membership.id);
      if (t != null) {
        try {
          // The member id outlives this library when the profile is in
          // another one, so a role left behind would come back on a rejoin.
          if (roles.roleOf(membership.memberId) != SharedLibraryRole.reader) {
            await t.writeRoles(
              roles.withRole(membership.memberId, SharedLibraryRole.reader),
            );
          }
          await t.deleteMember(membership.memberId);
        } catch (e) {
          _log.warning('Could not delete member card for $libraryId: $e');
        }
      }
    }
    // Another profile on this device may still belong to the library; its
    // sites stay until the last local membership goes.
    if ((await _store.membershipsForLibrary(libraryId)).isNotEmpty) return;
    await _releaseLocalRows(libraryId, ownerDiverId: diverId);
  }

  /// Detaches or removes [libraryId]'s sites here and drops its row.
  Future<void> _releaseLocalRows(
    String libraryId, {
    required String ownerDiverId,
  }) async {
    final rows = await (_db.select(
      _db.diveSites,
    )..where((t) => t.sharedLibraryId.equals(libraryId))).get();
    for (final row in rows) {
      await _detacher.detachOrRemove(
        siteId: row.id,
        ownerDiverId: ownerDiverId,
      );
    }
    await _store.deleteLibrary(libraryId);
  }

  /// Libraries this device holds that no local profile belongs to any
  /// more, because the membership was left on another device: released as
  /// a leave here would have, linked sites surviving as personal copies
  /// owned by [fallbackOwnerDiverId] (shared with every local profile).
  Future<void> releaseOrphanedLibraries({
    required String fallbackOwnerDiverId,
  }) => SyncCoordinator.run(() async {
    for (final library in await _store.getLibraries()) {
      if ((await _store.membershipsForLibrary(library.id)).isNotEmpty) {
        continue;
      }
      await _releaseLocalRows(library.id, ownerDiverId: fallbackOwnerDiverId);
    }
  });

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

  /// Owners only: rewrites roles.json. [actingMemberId] must hold the owner
  /// role in the cached roles, and the last owner cannot be demoted.
  Future<void> setRole({
    required String libraryId,
    required String actingMemberId,
    required String memberId,
    required SharedLibraryRole role,
  }) async {
    final library = await _store.getLibrary(libraryId);
    if (library == null) throw StateError('library $libraryId not connected');
    final t = await transportForLibrary(library);
    // The folder's roles, not the cache of the last sync: another owner's
    // change since then must survive this write.
    final roles = await t.readRoles();
    if (roles.roleOf(actingMemberId) != SharedLibraryRole.owner) {
      throw StateError('only an owner changes roles');
    }
    if (role != SharedLibraryRole.owner &&
        roles.owners.contains(memberId) &&
        roles.owners.length == 1) {
      throw LastOwnerDemoteError(libraryId);
    }
    final updated = roles.withRole(memberId, role);
    await t.writeRoles(updated);
    await _store.setLibraryStatus(libraryId, roles: updated);
  }
}
