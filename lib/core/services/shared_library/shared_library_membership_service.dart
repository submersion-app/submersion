import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/shared_library/crypto/library_cipher.dart';
import 'package:submersion/core/services/shared_library/crypto/library_recovery.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/crypto/roles_trust.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_errors.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/site_detacher.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';

export 'package:submersion/core/services/shared_library/shared_library_membership_errors.dart';

part 'shared_library_membership_ownership.dart';

/// Connecting, creating, joining and leaving shared site libraries, member
/// display names and owner role changes (issue #2567).
class SharedLibraryMembershipService with _MembershipOwnership {
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

  @override
  final SharedLibraryStore _store;
  final LibraryTransportFactory _transportFor;
  final Future<domain.ConnectedAccount?> Function(String) _accountById;
  final SiteDetacher _detacher;
  final String _appVersion;

  /// Argon2id for the recovery code (lighter in tests).
  @override
  final KdfParams _recoveryKdf;
  final _uuid = const Uuid();
  @override
  final _log = LoggerService.forClass(SharedLibraryMembershipService);
  AppDatabase get _db => DatabaseService.instance.database;

  /// A transport for the folder at [prefix] of [account], with no key set.
  Future<SharedLibraryTransport> transportAt({
    required domain.ConnectedAccount account,
    required String prefix,
  }) => _transportFor(account: account, prefix: prefix);

  @override
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
    final t = await _transportFor(account: account, prefix: lib.prefix);
    await _keyFor(t, lib, lib.roles);
    return t;
  }

  /// Keys [t] for [lib]'s folder as it stands, settled against [roles]:
  /// not this device's last view of it, since a device that has not synced
  /// since an owner turned encryption off, or changed the key, must neither
  /// seal a file under a key every other device has dropped nor under an
  /// old one. With the key the manifest names held by no local profile (nor
  /// kept aside by personal sync), nothing sealed is written (or read).
  Future<void> _keyFor(
    SharedLibraryTransport t,
    SharedLibrary lib,
    SharedLibraryRoles roles,
  ) async {
    Map<String, dynamic>? manifest;
    try {
      manifest = await t.readManifest();
    } catch (e) {
      if (!SharedLibraryTransport.isUnreadable(e)) rethrow;
    }
    // As a sync settles it: the manifest, unless it says off where the
    // trusted roles say on.
    final state = manifest == null
        ? null
        : libraryEncryptionOf(manifest, roles);
    final encrypted = state?.encrypted ?? lib.encrypted;
    final keyId = state == null ? lib.keyId : state.keyId;
    final diverId = (await _store.membershipsForLibrary(
      lib.id,
    )).firstOrNull?.diverId;
    t
      ..cipher = encrypted && keyId != null
          ? diverId == null
                ? await _store.libraryCipherFor(lib.id, keyId: keyId)
                : await _store.cipherNamed(
                    lib.id,
                    keyId: keyId,
                    diverId: diverId,
                  )
          : await _store.libraryCipherFor(lib.id)
      ..encrypting = encrypted;
  }

  /// Unlocks the encrypted library [t] reaches with [secret] (the
  /// passphrase or the recovery code) and sets its cipher.
  Future<LibraryCipher> _unlock(
    SharedLibraryTransport t,
    String? secret,
  ) async {
    final slots = await t.readKeyslots();
    final cipher = slots == null || secret == null
        ? null
        : await LibraryCipher.unlock(slots, secret);
    if (cipher == null) throw WrongPassphraseError();
    t
      ..cipher = cipher
      ..encrypting = true;
    return cipher;
  }

  /// [probe] of an encrypted library, unlocked with [secret] to read its
  /// name. Throws [WrongPassphraseError] when [secret] opens nothing.
  Future<LibraryProbe> unlockProbe({
    required domain.ConnectedAccount account,
    required String prefix,
    required String secret,
  }) async {
    final t = await _transportFor(account: account, prefix: prefix);
    final found = await _probeWith(t);
    if (!found.encrypted) return found;
    await _unlock(t, secret);
    return LibraryProbe(
      exists: true,
      id: found.id,
      name: await t.readName(),
      formatVersion: found.formatVersion,
      encrypted: true,
      keyId: found.keyId,
    );
  }

  /// Keeps the key of [libraryId] for the profile [diverId] after its
  /// passphrase or recovery code [secret] opened it (a library encrypted,
  /// or re-keyed, since this device joined).
  Future<void> unlockLibrary({
    required String libraryId,
    required String diverId,
    required String secret,
  }) async {
    final library = await _store.getLibrary(libraryId);
    if (library == null) throw StateError('library $libraryId not connected');
    final t = await transportForLibrary(library);
    final cipher = await _unlock(t, secret);
    await _store.setLibraryKey(
      diverId: diverId,
      libraryId: libraryId,
      keyId: cipher.keyId,
      key: await cipher.exportKey(),
    );
    await _store.setLibraryStatus(
      libraryId,
      encrypted: true,
      keyId: cipher.keyId,
    );
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
    String? name = switch (manifest['name']) {
      final String n => n,
      _ => null,
    };
    if (version >= SharedLibraryLayout.minFormatVersion && !encrypted) {
      name = await t.readName() ?? name;
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
    ).signed(libraryId: libraryId, signedBy: memberId, key: myKey);
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
  ///
  /// A library this device already trusts roles for (another profile's
  /// membership, or this one's before a reconnect) keeps them: the folder's
  /// roles then go through the sync's check like any change, so a file the
  /// sync refused never becomes trusted by joining. [adoptFolderRoles] takes
  /// the folder's roles all the same: a restore into an empty folder, whose
  /// backup was checked against the trusted roles first. [signingKey] is
  /// the key to join with, when the caller already chose it.
  Future<SharedLibrary> join({
    required domain.ConnectedAccount account,
    required String prefix,
    required String diverId,
    required String displayName,
    String? secret,
    bool adoptFolderRoles = false,
    LibrarySigningKey? signingKey,
  }) async {
    // One transport for the whole join: each resolves its folders afresh.
    final t = await _transportFor(account: account, prefix: prefix);
    final found = await _probeWith(t);
    final cipher = found.encrypted ? await _unlock(t, secret) : null;
    if (!found.exists ||
        found.id == null ||
        !SharedLibraryLayout.isValidLibraryId(found.id!)) {
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
    final name = found.name ?? await t.readName() ?? prefix;
    final libraryKey = await cipher?.exportKey();
    final memberId = await _store.memberIdForDiver(diverId);
    final roles = await t.readRoles();
    final held = await _store.getLibrary(libraryId);
    final keepTrust =
        !adoptFolderRoles && held != null && held.roles.version > 0;
    // Nothing is trusted yet: the roles must at least be signed by one of
    // their own owners (or the recovery key), as the creator wrote them.
    if (!keepTrust && !await isSelfConsistent(roles, libraryId: libraryId)) {
      throw UntrustedRolesError(prefix);
    }
    final members = await t.listMembers();
    SharedLibraryMember? mine;
    for (final m in members) {
      if (m.memberId == memberId) mine = m;
    }
    // The membership's own key on a reconnect, else the profile's, else a
    // new one stored with the membership below.
    final myKey =
        signingKey ??
        (await _store.membership(
          diverId: diverId,
          libraryId: libraryId,
        ))?.signingKey ??
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
      roles: keepTrust ? held.roles : roles,
      rolesRejected: keepTrust && held.rolesRejected,
      pendingRoles: keepTrust ? held.pendingRoles : null,
      lastSyncAt: held?.lastSyncAt,
      lastAutoBackupAt: held?.lastAutoBackupAt,
      encrypted: found.encrypted,
      keyId: cipher?.keyId,
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
      (existing ?? fresh).copyWith(
        displayName: displayName,
        libraryName: name,
        backendKind: fresh.backendKind,
        locationHint: fresh.locationHint,
        signingKey: myKey,
        libraryKeyId: cipher?.keyId,
        libraryKey: libraryKey,
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
    // Whether [roles] are the folder's own: only then is the revocation
    // below written, so roles this device could not read or trust (a newer
    // version, sealed under a key it lacks) are never replaced by its
    // older copy.
    var fresh = false;
    var folderRead = false;
    if (membership != null && library != null) {
      // The folder's roles when it can be reached: the cache may predate
      // another owner's change, and the revocation below writes these.
      try {
        t = await transportForLibrary(library);
        roles = await currentRoles(library, t);
        fresh = roles == await t.readRoles();
        folderRead = true;
      } catch (e) {
        _log.warning('Using cached roles to leave $libraryId: $e');
      }
      // As setRole keeps an owner, so does leave: nobody else could manage
      // roles or review suggestions afterwards. Not where the folder holds
      // roles this device refused: who owns the library it cannot tell,
      // and leaving is the way back to roles it can follow.
      final others = [
        for (final m in await _store.getMembers(libraryId))
          if (m.memberId != membership.memberId) m,
      ];
      if (others.isNotEmpty &&
          (fresh || !folderRead) &&
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
          if (fresh &&
              roles.roleOf(membership.memberId) == SharedLibraryRole.owner) {
            await writeSignedRoles(
              library!,
              t,
              roles.changeRole(
                membership.memberId,
                SharedLibraryRole.reader,
                at: DateTime.now(),
              ),
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
      key: membership.signingKey ?? await _store.ensureSigningKey(diverId),
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
  @override
  Future<SharedLibraryRoles> currentRoles(
    SharedLibrary library,
    SharedLibraryTransport t,
  ) async {
    final roles = await _currentGiven(library, await t.readRoles());
    // Newer roles may settle encryption otherwise (an owner turned it off
    // since this device last synced): [t] writes as they say.
    if (roles != library.roles) await _keyFor(t, library, roles);
    return roles;
  }

  Future<SharedLibraryRoles> _currentGiven(
    SharedLibrary library,
    SharedLibraryRoles folder,
  ) async {
    final trusted = library.roles;
    if (folder == trusted) return trusted;
    final verdict = await judgeRoles(
      trusted: trusted,
      incoming: folder,
      libraryId: library.id,
    );
    return verdict == RolesVerdict.trusted ? folder : trusted;
  }

  /// The roles an owner action by [memberId] builds on ([currentRoles]),
  /// checked before the action changes any file: [memberId] is an owner
  /// in them ([action] says what only an owner does otherwise), signing
  /// with the key they approve, and the folder holds no newer roles this
  /// device refused, which anything it writes would undo. A backup, which
  /// keeps the roles this device trusts and changes nothing they cover,
  /// passes [overRefusedRoles].
  @override
  Future<SharedLibraryRoles> ownerRoles(
    SharedLibrary library,
    SharedLibraryTransport t,
    String memberId, {
    required String action,
    bool overRefusedRoles = false,
  }) async {
    final folder = await t.readRoles();
    final roles = await _currentGiven(library, folder);
    if (roles != library.roles) await _keyFor(t, library, roles);
    if (roles.roleOf(memberId) != SharedLibraryRole.owner) {
      throw StateError('only an owner $action');
    }
    if (!overRefusedRoles && folder.version > roles.version) {
      throw RolesOutOfDateError(library.id);
    }
    final key = await _keyOfMember(library.id, memberId);
    if (roles.approvedKeys[memberId] != key.publicKey) {
      throw StateError('the key of $memberId here is not the approved one');
    }
    return roles;
  }

  /// Writes [roles] one version past [library]'s trusted ones, signed by
  /// [signer] (a member id of this device's profiles), and trusts them here.
  @override
  Future<SharedLibraryRoles> writeSignedRoles(
    SharedLibrary library,
    SharedLibraryTransport t,
    SharedLibraryRoles roles, {
    required String signer,
    LibrarySigningKey? key,
  }) async {
    final signingKey = key ?? await _keyOfMember(library.id, signer);
    // An owner whose device signs with another key than the one the
    // trusted roles approve for them (a key made afresh on this device)
    // would write roles every other member refuses, while this device
    // trusted them.
    final trusted = library.roles;
    if (signer != SharedLibraryRoles.recoverySigner &&
        trusted.owners.contains(signer) &&
        trusted.approvedKeys[signer] != signingKey.publicKey) {
      throw StateError('the key of $signer here is not the approved one');
    }
    // Past every version a member may trust. Only the recovery key writes
    // over roles this device refused: an owner's write would undo another
    // owner's change it never saw.
    final folder = (await t.readRoles()).version;
    var base = roles.version > trusted.version
        ? roles.version
        : trusted.version;
    if (folder > base) {
      if (signer != SharedLibraryRoles.recoverySigner) {
        throw RolesOutOfDateError(library.id);
      }
      base = folder;
    }
    final signed = await roles
        .copyWith(version: base + 1, reset: false)
        .signed(libraryId: library.id, signedBy: signer, key: signingKey);
    await t.writeRoles(signed);
    await _store.setLibraryStatus(
      library.id,
      roles: signed,
      rolesRejected: false,
    );
    // As when a sync takes new roles: an approval makes held edits count,
    // a rejection makes them repair, so documents already read are read
    // again (the next sync finds these roles already trusted).
    if (!signed.judgesFieldsAs(trusted)) {
      await _store.clearRemoteStamps(library.id);
    }
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
}
