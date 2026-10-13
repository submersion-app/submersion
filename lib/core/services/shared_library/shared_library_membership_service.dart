import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/shared_library/crypto/library_recovery.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/crypto/roles_trust.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
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
    this.encrypted = false,
    this.keyId,
  });

  final bool exists;
  final String? id;

  /// Null for an encrypted library until it is unlocked.
  final String? name;
  final int formatVersion;
  final bool encrypted;
  final String? keyId;

  bool get needsNewerApp =>
      exists && formatVersion > SharedLibraryLayout.formatVersion;

  /// Made by a test build before signing existed: it cannot be joined.
  bool get retired =>
      exists && formatVersion < SharedLibraryLayout.minFormatVersion;
}

typedef LibraryTransportFactory =
    Future<SharedLibraryTransport> Function({
      required domain.ConnectedAccount account,
      required String prefix,
    });

/// Connecting, creating, joining and leaving shared site libraries, member
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

/// The roles file of a library to join was not signed by one of its own
/// owners: whoever wrote it had no right to (issue #2567).
class UntrustedRolesError extends StateError {
  UntrustedRolesError(String prefix)
    : super('The roles of the library at $prefix are not signed by an owner');
}

/// The recovery code typed in does not stand for the library's recovery
/// key.
class WrongRecoveryCodeError extends StateError {
  WrongRecoveryCodeError() : super('That is not the recovery code');
}

/// A library just made, and the recovery code its creator must keep.
class CreatedLibrary {
  const CreatedLibrary({required this.library, required this.recoveryCode});

  final SharedLibrary library;
  final String recoveryCode;
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
    KdfParams recoveryKdf = const KdfParams(),
  }) : _recoveryKdf = recoveryKdf,
       _store = store,
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

  /// Argon2id for the recovery code (lighter in tests).
  final KdfParams _recoveryKdf;
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
    final version = (manifest['formatVersion'] as num?)?.toInt() ?? 1;
    final encrypted = manifest['encrypted'] == true;
    final keyId = manifest['keyId'];
    String? name = manifest['name'] as String?;
    if (version >= SharedLibraryLayout.minFormatVersion && !encrypted) {
      name = (await t.readInfo())?['name'] as String? ?? name;
    }
    return LibraryProbe(
      exists: true,
      id: manifest['id'] as String?,
      name: encrypted ? null : name,
      formatVersion: version,
      encrypted: encrypted,
      keyId: keyId is String ? keyId : null,
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
  }) async => (await createWithRecovery(
    account: account,
    prefix: prefix,
    name: name,
    diverId: diverId,
    displayName: displayName,
  )).library;

  /// [create], also handing back the library's recovery code: the creator
  /// is shown it once and must keep it.
  Future<CreatedLibrary> createWithRecovery({
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
      'formatVersion': SharedLibraryLayout.formatVersion,
      'encrypted': false,
      'createdBy': memberId,
      'createdAt': now.toIso8601String(),
    });
    await t.writeInfo({'name': name});
    // The profile may have no membership yet to carry a key: the one made
    // here goes on the new membership below.
    final myKey =
        await _store.signingKeyForDiver(diverId) ??
        await LibrarySigner.generate();
    final recovery = await LibraryRecovery.create(kdf: _recoveryKdf);
    final roles = await SharedLibraryRoles(
      version: 1,
      owners: {memberId},
      approvedKeys: {memberId: myKey.publicKey},
      recovery: RolesRecovery.fromJson(recovery.toRolesJson()),
    ).signed(signedBy: memberId, key: myKey);
    await t.writeRoles(roles);
    final me = await SharedLibraryMember.signed(
      memberId: memberId,
      displayName: displayName,
      joinedAt: now,
      key: myKey,
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
        signingKey: myKey,
      ),
    );
    await _store.upsertLibrary(library);
    await _store.replaceMembers(libraryId, [me]);
    return CreatedLibrary(library: library, recoveryCode: recovery.code);
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
    if (found.retired) {
      throw StateError('Library format ${found.formatVersion} is retired');
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
    // Nothing is trusted yet: the roles must at least be signed by one of
    // their own owners (or the recovery key), as the creator wrote them.
    if (!await isSelfConsistent(roles)) throw UntrustedRolesError(prefix);
    final members = await t.listMembers();
    SharedLibraryMember? mine;
    for (final m in members) {
      if (m.memberId == memberId) mine = m;
    }
    // The profile's key, or a new one stored with the membership below.
    final myKey =
        await _store.signingKeyForDiver(diverId) ??
        await LibrarySigner.generate();
    final me = await SharedLibraryMember.signed(
      memberId: memberId,
      displayName: displayName,
      joinedAt: mine?.joinedAt ?? DateTime.now().toUtc(),
      key: myKey,
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
      signingKey: myKey,
    );
    await _store.upsertMembership(
      existing == null
          ? fresh
          : existing.copyWith(
              displayName: displayName,
              libraryName: name,
              backendKind: fresh.backendKind,
              locationHint: fresh.locationHint,
              signingKey: myKey,
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
    LibrarySigningKey? signingKey,
  }) => SharedLibraryMembership(
    id: _uuid.v4(),
    diverId: diverId,
    libraryId: libraryId,
    memberId: memberId,
    displayName: displayName,
    libraryName: libraryName,
    backendKind: account.kind.name,
    locationHint: '${account.label}: $prefix',
    signingKey: signingKey,
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
        roles = await currentRoles(library, t);
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
          // Only an owner may sign roles; an editor's role stays listed
          // until an owner removes it.
          if (roles.roleOf(membership.memberId) == SharedLibraryRole.owner) {
            await writeSignedRoles(
              library!,
              t,
              roles.withRole(membership.memberId, SharedLibraryRole.reader),
              signer: membership.memberId,
              // The membership row is gone by now; its key is not.
              key:
                  membership.signingKey ??
                  await _store.ensureSigningKey(diverId),
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
    final me = await SharedLibraryMember.signed(
      memberId: membership.memberId,
      displayName: displayName,
      joinedAt: mine?.joinedAt ?? DateTime.now().toUtc(),
      key: await _store.ensureSigningKey(diverId),
    );
    final t = await transportForLibrary(library);
    await t.writeMember(me, appVersion: _appVersion);
    await _store.replaceMembers(libraryId, [
      for (final m in members)
        if (m.memberId != membership.memberId) m,
      me,
    ]);
  }

  /// The roles to build a change on: the folder's when this device can
  /// trust them (an owner moved them on since the last sync), else the
  /// trusted copy.
  Future<SharedLibraryRoles> currentRoles(
    SharedLibrary library,
    SharedLibraryTransport t,
  ) async {
    final folder = await t.readRoles();
    final trusted = library.roles;
    if (folder == trusted) return trusted;
    final ok = trusted.version == 0
        ? await isSelfConsistent(folder)
        : await judgeRoles(trusted: trusted, incoming: folder) ==
              RolesVerdict.trusted;
    return ok ? folder : trusted;
  }

  /// Writes [roles] one version past [library]'s trusted ones, signed by
  /// [signer] (a member id of this device's profiles), and trusts them here.
  Future<SharedLibraryRoles> writeSignedRoles(
    SharedLibrary library,
    SharedLibraryTransport t,
    SharedLibraryRoles roles, {
    required String signer,
    LibrarySigningKey? key,
  }) async {
    final signingKey = key ?? await _keyOfMember(library.id, signer);
    final base = roles.version > library.roles.version
        ? roles.version
        : library.roles.version;
    final signed = await roles
        .copyWith(version: base + 1, reset: false)
        .signed(signedBy: signer, key: signingKey);
    await t.writeRoles(signed);
    await _store.setLibraryStatus(
      library.id,
      roles: signed,
      rolesRejected: false,
    );
    return signed;
  }

  /// The signing key of the local profile that is [memberId] in
  /// [libraryId].
  Future<LibrarySigningKey> _keyOfMember(
    String libraryId,
    String memberId,
  ) async {
    for (final m in await _store.membershipsForLibrary(libraryId)) {
      if (m.memberId == memberId) {
        return m.signingKey ?? await _store.ensureSigningKey(m.diverId);
      }
    }
    throw StateError('$memberId is no member of $libraryId on this device');
  }

  /// Makes the profile [diverId] an owner with the library's recovery code
  /// (issue #2567): roles signed with the key the code stands for, which
  /// every member's device accepts like an owner's.
  Future<void> recoverOwnership({
    required String libraryId,
    required String diverId,
    required String code,
  }) => SyncCoordinator.run(() async {
    final (library, t, membership) = await _mine(libraryId, diverId);
    final roles = await currentRoles(library, t);
    final recovery = roles.recovery;
    if (recovery == null) throw WrongRecoveryCodeError();
    final key = await LibraryRecovery.derive(
      code: code,
      salt: recovery.salt,
      kdf: KdfParams.fromJson(recovery.kdf),
    );
    if (key.publicKey != recovery.publicKey) throw WrongRecoveryCodeError();
    final myKey = await _store.ensureSigningKey(diverId);
    await writeSignedRoles(
      library,
      t,
      roles
          .withRole(membership.memberId, SharedLibraryRole.owner)
          .copyWith(
            approvedKeys: {
              ...roles.approvedKeys,
              membership.memberId: myKey.publicKey,
            },
          ),
      signer: SharedLibraryRoles.recoverySigner,
      key: key,
    );
  });

  /// Owners only: a new recovery code, which replaces the old one in the
  /// roles. Returned once, to be shown and stored.
  Future<String> reissueRecoveryCode({
    required String libraryId,
    required String diverId,
  }) => SyncCoordinator.run(() async {
    final (library, t, membership) = await _mine(libraryId, diverId);
    final (_, _, roles) = await _asOwner(libraryId, membership.memberId);
    final recovery = await LibraryRecovery.create(kdf: _recoveryKdf);
    await writeSignedRoles(
      library,
      t,
      roles.copyWith(recovery: RolesRecovery.fromJson(recovery.toRolesJson())),
      signer: membership.memberId,
    );
    return recovery.code;
  });

  /// For someone with full storage keys but neither an owner key nor the
  /// recovery code: roles naming the profile [diverId] as the only owner,
  /// marked as a reset, which every other member's device must accept.
  Future<void> resetOwnership({
    required String libraryId,
    required String diverId,
  }) => SyncCoordinator.run(() async {
    final (library, t, membership) = await _mine(libraryId, diverId);
    final roles = await currentRoles(library, t);
    final myKey = await _store.ensureSigningKey(diverId);
    final folder = await t.readRoles();
    final version =
        (folder.version > roles.version ? folder.version : roles.version) + 1;
    final reset = await SharedLibraryRoles(
      version: version,
      owners: {membership.memberId},
      approvedKeys: {membership.memberId: myKey.publicKey},
      reset: true,
    ).signed(signedBy: membership.memberId, key: myKey);
    await t.writeRoles(reset);
    await _store.setLibraryStatus(
      libraryId,
      roles: reset,
      rolesRejected: false,
      clearPendingRoles: true,
    );
  });

  /// Trusts the ownership reset this device holds for [libraryId].
  Future<void> acceptReset(String libraryId) async {
    final library = await _store.getLibrary(libraryId);
    final pending = library?.pendingRoles;
    if (library == null || pending == null) return;
    await _store.setLibraryStatus(
      libraryId,
      roles: pending,
      rolesRejected: false,
      clearPendingRoles: true,
    );
    await _store.clearRemoteStamps(libraryId);
  }

  Future<(SharedLibrary, SharedLibraryTransport, SharedLibraryMembership)>
  _mine(String libraryId, String diverId) async {
    final library = await _store.getLibrary(libraryId);
    final membership = await _store.membership(
      diverId: diverId,
      libraryId: libraryId,
    );
    if (library == null || membership == null) {
      throw StateError('not a member of $libraryId here');
    }
    return (library, await transportForLibrary(library), membership);
  }

  /// Owners only: approves the key on [memberId]'s card, so its edits and
  /// suggestions count from the next sync of every member (issue #2567).
  Future<void> approveMember({
    required String libraryId,
    required String memberId,
    required String actingMemberId,
  }) async {
    final (library, t, roles) = await _asOwner(libraryId, actingMemberId);
    SharedLibraryMember? card;
    for (final m in await t.listMembers()) {
      if (m.memberId == memberId) card = m;
    }
    if (card == null || !card.cardVerified || card.publicKey == null) {
      throw StateError('no genuine card for $memberId in $libraryId');
    }
    await writeSignedRoles(
      library,
      t,
      roles.copyWith(
        approvedKeys: {...roles.approvedKeys, memberId: card.publicKey!},
      ),
      signer: actingMemberId,
    );
    await _store.replaceMembers(libraryId, await t.listMembers());
  }

  /// Owners only: removes [memberId]'s card and any approval and role, so
  /// nothing it wrote counts. Only new storage keys stop the member from
  /// writing files at all.
  Future<void> rejectMember({
    required String libraryId,
    required String memberId,
    required String actingMemberId,
  }) async {
    final (library, t, roles) = await _asOwner(libraryId, actingMemberId);
    if (roles.owners.contains(memberId) && roles.owners.length == 1) {
      throw LastOwnerDemoteError(libraryId);
    }
    await t.deleteMember(memberId);
    final keys = {...roles.approvedKeys}..remove(memberId);
    await writeSignedRoles(
      library,
      t,
      roles
          .withRole(memberId, SharedLibraryRole.reader)
          .copyWith(approvedKeys: keys),
      signer: actingMemberId,
    );
    await _store.replaceMembers(libraryId, await t.listMembers());
  }

  /// The library, its transport and its current roles, when
  /// [actingMemberId] is an owner in them.
  Future<(SharedLibrary, SharedLibraryTransport, SharedLibraryRoles)> _asOwner(
    String libraryId,
    String actingMemberId,
  ) async {
    final library = await _store.getLibrary(libraryId);
    if (library == null) throw StateError('library $libraryId not connected');
    final t = await transportForLibrary(library);
    final roles = await currentRoles(library, t);
    if (roles.roleOf(actingMemberId) != SharedLibraryRole.owner) {
      throw StateError('only an owner manages members');
    }
    return (library, t, roles);
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
    // The folder's roles when an owner wrote them, not the cache of the
    // last sync: another owner's change since then must survive this write.
    final roles = await currentRoles(library, t);
    if (roles.roleOf(actingMemberId) != SharedLibraryRole.owner) {
      throw StateError('only an owner changes roles');
    }
    if (role != SharedLibraryRole.owner &&
        roles.owners.contains(memberId) &&
        roles.owners.length == 1) {
      throw LastOwnerDemoteError(libraryId);
    }
    await writeSignedRoles(
      library,
      t,
      roles.withRole(memberId, role),
      signer: actingMemberId,
    );
  }
}
