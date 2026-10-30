part of 'shared_library_membership_service.dart';

/// The owner actions on a library's roles (issue #2567): approving,
/// rejecting and removing members (issue #3481), changing roles, the
/// recovery code, recovering and resetting ownership.
mixin _MembershipOwnership {
  SharedLibraryStore get _store;
  KdfParams get _recoveryKdf;
  LoggerService get _log;

  Future<SharedLibraryTransport> transportForLibrary(SharedLibrary lib);

  Future<SharedLibraryRoles> currentRoles(
    SharedLibrary library,
    SharedLibraryTransport t,
  );

  Future<SharedLibraryRoles> ownerRoles(
    SharedLibrary library,
    SharedLibraryTransport t,
    String memberId, {
    required String action,
    bool overRefusedRoles = false,
  });

  Future<SharedLibraryRoles> writeSignedRoles(
    SharedLibrary library,
    SharedLibraryTransport t,
    SharedLibraryRoles roles, {
    required String signer,
    LibrarySigningKey? key,
  });

  Future<LibrarySigningKey> _keyOfMember(String libraryId, String memberId);

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
    final myKey =
        membership.signingKey ?? await _store.ensureSigningKey(diverId);
    await writeSignedRoles(
      library,
      t,
      roles
          .withRole(membership.memberId, SharedLibraryRole.owner)
          .approveKey(membership.memberId, myKey.publicKey, at: DateTime.now()),
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
    // On an encrypted library the code also opens the key. The new slot
    // joins the old one first; the old goes only once the roles name the
    // new code, so a write that fails in between leaves the old code
    // working rather than neither.
    final cipher = t.cipher;
    // The new code must open the key too: without the library's current
    // key here it could only replace the code that does.
    if (t.encrypting && cipher == null) {
      throw LibraryLockedException(library.keyId ?? '');
    }
    final slots = t.encrypting ? await t.readKeyslots() : null;
    final slot = cipher != null && slots != null
        ? await cipher.recoverySlot(recovery.code, kdf: _recoveryKdf)
        : null;
    if (slots != null && slot != null) {
      await t.writeKeyslots(
        KeyslotFile(
          version: slots.version,
          libraryKeyId: slots.libraryKeyId,
          slots: [...slots.slots, slot],
        ),
      );
    }
    await writeSignedRoles(
      library,
      t,
      roles.copyWith(recovery: RolesRecovery.fromJson(recovery.toRolesJson())),
      signer: membership.memberId,
    );
    if (slots != null && slot != null) {
      try {
        await t.writeKeyslots(slots.withReplacedSlot(slot));
      } catch (e) {
        // The new code is recorded; the old one opens the key until the
        // next new code. Not worth losing the new one over.
        _log.warning('Old recovery slot of $libraryId kept: $e');
      }
    }
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
    final myKey =
        membership.signingKey ?? await _store.ensureSigningKey(diverId);
    final folder = await t.readRoles();
    final version =
        (folder.version > roles.version ? folder.version : roles.version) + 1;
    final reset = await roles
        .resetTo(
          membership.memberId,
          myKey.publicKey,
          version: version,
          at: DateTime.now(),
        )
        .signed(
          libraryId: libraryId,
          signedBy: membership.memberId,
          key: myKey,
        );
    await t.writeRoles(reset);
    await _store.setLibraryStatus(
      libraryId,
      roles: reset,
      rolesRejected: false,
      clearPendingRoles: true,
    );
    // Written apart from writeSignedRoles, so the removals the former
    // owners signed are carried here: a reset is no undoing of them.
    await _carryRemovals(
      libraryId,
      t,
      roles,
      reset,
      membership.memberId,
      myKey,
    );
    if (!reset.judgesFieldsAs(library.roles)) {
      await _store.clearRemoteStamps(libraryId);
    }
  });

  /// Trusts the ownership reset this device holds for [libraryId].
  Future<void> acceptReset(String libraryId) => SyncCoordinator.run(() async {
    final library = await _store.getLibrary(libraryId);
    final pending = library?.pendingRoles;
    if (library == null || pending == null) return;
    await _store.setLibraryStatus(
      libraryId,
      roles: pending,
      rolesRejected: false,
      clearPendingRoles: true,
    );
    if (!pending.judgesFieldsAs(library.roles)) {
      await _store.clearRemoteStamps(libraryId);
    }
  });

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

  /// Owners only: approves [publicKey], the key the owner was shown on
  /// [memberId]'s card and compared, so its edits and suggestions count from
  /// the next sync of every member (issue #2567). A card that holds another
  /// key by now (rewritten by anyone who may write member cards) is
  /// refused with [MemberKeyChangedError], and the list refreshed to show
  /// it.
  Future<void> approveMember({
    required String libraryId,
    required String memberId,
    required String actingMemberId,
    required String publicKey,
  }) => SyncCoordinator.run(() async {
    final (library, t, roles) = await _asOwner(libraryId, actingMemberId);
    SharedLibraryMember? card;
    final members = await t.listMembers();
    for (final m in members) {
      if (m.memberId == memberId) card = m;
    }
    if (card == null || !card.cardVerified || card.publicKey == null) {
      throw StateError('no genuine card for $memberId in $libraryId');
    }
    if (card.publicKey != publicKey) {
      await _store.replaceMembers(libraryId, members);
      throw MemberKeyChangedError(memberId);
    }
    await writeSignedRoles(
      library,
      t,
      roles.approveKey(memberId, card.publicKey!, at: DateTime.now()),
      signer: actingMemberId,
    );
    await _store.replaceMembers(libraryId, await t.listMembers());
  });

  /// Owners only: removes [memberId]'s card and any approval and role, so
  /// nothing its current key wrote counts (keys retired earlier keep their
  /// edits). Only new storage keys stop the member from
  /// writing files at all.
  Future<void> rejectMember({
    required String libraryId,
    required String memberId,
    required String actingMemberId,
  }) => SyncCoordinator.run(() async {
    final (library, t, roles) = await _asOwner(libraryId, actingMemberId);
    if (roles.owners.contains(memberId) && roles.owners.length == 1) {
      throw LastOwnerDemoteError(libraryId);
    }
    await t.deleteMember(memberId);
    final keys = {...roles.approvedKeys}..remove(memberId);
    await writeSignedRoles(
      library,
      t,
      // Rejected: nothing the key waiting for approval wrote counts. Keys
      // retired before (a member removed, then allowed back, issue #3481)
      // keep what they signed until then: contributions always stay.
      roles
          .withRole(memberId, SharedLibraryRole.reader)
          .copyWith(approvedKeys: keys),
      signer: actingMemberId,
    );
    await _store.replaceMembers(libraryId, await t.listMembers());
  });

  /// Owners only: removes [memberId], who may be approved (issue #3481).
  /// Unlike [rejectMember], everything they contributed keeps counting:
  /// an editor's or owner's key is retired as of now rather than dropped
  /// ([MemberRemovalRoles.removing]). A signed removal record beside the
  /// cards keeps their own device from listing them again. The roles are
  /// written first, so a refused write leaves no record and the card in
  /// place.
  Future<void> removeMember({
    required String libraryId,
    required String memberId,
    required String actingMemberId,
  }) => SyncCoordinator.run(() async {
    if (memberId == actingMemberId) {
      throw StateError('an owner leaves rather than removing themselves');
    }
    final (library, t, roles) = await _asOwner(libraryId, actingMemberId);
    SharedLibraryMember? card;
    for (final m in await t.listMembers()) {
      if (m.memberId == memberId) card = m;
    }
    final at = DateTime.now();
    final written = await writeSignedRoles(
      library,
      t,
      roles.removing(memberId, at: at),
      signer: actingMemberId,
    );
    await t.writeRemoval(
      await MemberRemoval.signed(
        libraryId: libraryId,
        memberId: memberId,
        displayName: card?.displayName ?? '',
        // The approved key only: a key no owner approved proves nothing.
        publicKey: roles.approvedKeys[memberId],
        removedAt: at,
        removedBy: actingMemberId,
        key: await _keyOfMember(libraryId, actingMemberId),
      ),
    );
    await t.deleteMember(memberId);
    await _refreshMembers(library.id, t, written);
  });

  /// Owners only: deletes [memberId]'s removal record. Their next sync
  /// writes their card again and they wait for approval like anyone new;
  /// the roles stay as the removal left them.
  Future<void> allowBack({
    required String libraryId,
    required String memberId,
    required String actingMemberId,
  }) => SyncCoordinator.run(() async {
    final (_, t, roles) = await _asOwner(libraryId, actingMemberId);
    await t.deleteRemoval(memberId);
    await _refreshMembers(libraryId, t, roles);
  });

  /// Removals that held under [before] but not under [after] (their signer
  /// was removed, demoted or re-keyed): signed again by [signer], an owner
  /// in [after], so a removal outlives its owner's ownership (issue #3481).
  /// The recovery key signs no removal; its roles leave them as they are.
  Future<void> _carryRemovals(
    String libraryId,
    SharedLibraryTransport t,
    SharedLibraryRoles before,
    SharedLibraryRoles after,
    String signer,
    LibrarySigningKey key,
  ) async {
    if (!after.owners.contains(signer)) return;
    // Most roles writes leave every owner signing as before: nothing can
    // have stopped holding, so nothing is listed.
    final unchanged = before.owners.every(
      (o) =>
          after.owners.contains(o) &&
          after.approvedKeys[o] == before.approvedKeys[o],
    );
    if (unchanged) return;
    var carried = false;
    for (final r in await t.listRemovals()) {
      if (await r.verify(libraryId, after) ||
          !await r.verify(libraryId, before)) {
        continue;
      }
      await t.writeRemoval(
        await MemberRemoval.signed(
          libraryId: libraryId,
          memberId: r.memberId,
          displayName: r.displayName,
          publicKey: r.publicKey,
          removedAt: r.removedAt,
          removedBy: signer,
          key: key,
        ),
      );
      carried = true;
    }
    if (carried) {
      await _store.setRemovals(
        libraryId,
        await validRemovals(await t.listRemovals(), libraryId, after),
      );
    }
  }

  /// The cards, and the removals an owner in [roles] (the folder's, as the
  /// owner action just read or wrote them) signed.
  Future<void> _refreshMembers(
    String libraryId,
    SharedLibraryTransport t,
    SharedLibraryRoles roles,
  ) async {
    await _store.replaceMembers(libraryId, await t.listMembers());
    await _store.setRemovals(
      libraryId,
      await validRemovals(await t.listRemovals(), libraryId, roles),
    );
  }

  /// The library, its transport and its current roles, when
  /// [actingMemberId] is an owner in them ([ownerRoles]).
  Future<(SharedLibrary, SharedLibraryTransport, SharedLibraryRoles)> _asOwner(
    String libraryId,
    String actingMemberId,
  ) async {
    final library = await _store.getLibrary(libraryId);
    if (library == null) throw StateError('library $libraryId not connected');
    final t = await transportForLibrary(library);
    final roles = await ownerRoles(
      library,
      t,
      actingMemberId,
      action: 'manages members',
    );
    return (library, t, roles);
  }

  /// Owners only: rewrites roles.json. [actingMemberId] must be an owner
  /// in the current roles ([ownerRoles]: the folder's when an owner wrote
  /// them, so another owner's change since the last sync survives), and the
  /// last owner cannot be demoted.
  Future<void> setRole({
    required String libraryId,
    required String actingMemberId,
    required String memberId,
    required SharedLibraryRole role,
  }) => SyncCoordinator.run(() async {
    final library = await _store.getLibrary(libraryId);
    if (library == null) throw StateError('library $libraryId not connected');
    final t = await transportForLibrary(library);
    final roles = await ownerRoles(
      library,
      t,
      actingMemberId,
      action: 'changes roles',
    );
    if (role != SharedLibraryRole.owner &&
        roles.owners.contains(memberId) &&
        roles.owners.length == 1) {
      throw LastOwnerDemoteError(libraryId);
    }
    await writeSignedRoles(
      library,
      t,
      roles.changeRole(memberId, role, at: DateTime.now()),
      signer: actingMemberId,
    );
  });
}
