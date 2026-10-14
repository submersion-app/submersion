part of 'shared_library_membership_service.dart';

/// The owner actions on a library's roles (issue #2567): approving and
/// rejecting members, changing roles, the recovery code, recovering and
/// resetting ownership.
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
  /// nothing it wrote counts. Only new storage keys stop the member from
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
      // Rejected: nothing the member wrote counts, before or after.
      roles
          .withRole(memberId, SharedLibraryRole.reader)
          .copyWith(
            approvedKeys: keys,
            retired: {...roles.retired}..remove(memberId),
          ),
      signer: actingMemberId,
    );
    await _store.replaceMembers(libraryId, await t.listMembers());
  });

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
