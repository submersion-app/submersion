import 'package:submersion/core/services/shared_library/crypto/library_cipher.dart';
import 'package:submersion/core/services/shared_library/crypto/library_recovery.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';

/// A change of key that stopped after the new keyslots were written: the
/// library may already be under the new key, and [recoveryCode] opens it.
/// An owner's next sync finishes the rewrite.
class RekeyIncompleteError implements Exception {
  const RekeyIncompleteError(this.recoveryCode, this.cause);

  final String recoveryCode;
  final Object cause;

  @override
  String toString() => 'RekeyIncompleteError($cause)';
}

/// Reports how far a rewrite of every library file has got.
typedef RewriteProgress = void Function(int done, int total);

/// Owners turn a shared site library's encryption on and off and change
/// its passphrase (issue #2567). Each runs behind any library sync, marks
/// the manifest first (so no device writes the old form afterwards), then
/// rewrites every file.
class LibraryEncryptionService {
  LibraryEncryptionService({
    required SharedLibraryStore store,
    required SharedLibraryMembershipService memberships,
    KdfParams kdf = const KdfParams(),
  }) : _store = store,
       _memberships = memberships,
       _kdf = kdf;

  final SharedLibraryStore _store;
  final SharedLibraryMembershipService _memberships;
  final KdfParams _kdf;

  /// Encrypts the library with [passphrase]. Returns the new recovery
  /// code, which also opens it.
  Future<String> turnOn({
    required String libraryId,
    required String diverId,
    required String passphrase,
    RewriteProgress? progress,
  }) => SyncCoordinator.run(() async {
    final (library, t, me, roles) = await _asOwner(libraryId, diverId);
    if (library.encrypted) throw StateError('$libraryId is already encrypted');
    return _rekey(
      library,
      t,
      me,
      roles,
      passphrase: passphrase,
      previous: null,
      progress: progress,
    );
  });

  /// A new library key under [passphrase], every file re-sealed with it:
  /// the old passphrase, and any key a removed member kept, open nothing
  /// written from now on. Returns the new recovery code.
  Future<String> changePassphrase({
    required String libraryId,
    required String diverId,
    required String passphrase,
    RewriteProgress? progress,
  }) => SyncCoordinator.run(() async {
    final (library, t, me, roles) = await _asOwner(libraryId, diverId);
    final previous = t.cipher;
    if (!library.encrypted || previous == null) {
      throw StateError('$libraryId is not encrypted here');
    }
    return _rekey(
      library,
      t,
      me,
      roles,
      passphrase: passphrase,
      previous: previous,
      progress: progress,
    );
  });

  /// Writes every file of the library plain again and removes its key.
  Future<void> turnOff({
    required String libraryId,
    required String diverId,
    RewriteProgress? progress,
  }) => SyncCoordinator.run(() async {
    final (library, t, _, _) = await _asOwner(libraryId, diverId);
    if (!library.encrypted || t.cipher == null) {
      throw StateError('$libraryId is not encrypted here');
    }
    final manifest = await t.readManifest() ?? {};
    await t.writeManifest(
      {...manifest, 'encrypted': false, SharedLibraryLayout.rewritingFlag: true}
        ..remove('keyId'),
    );
    t.encrypting = false;
    await _rewriteAll(t, progress: progress);
    await t.clearRewritingFlag();
    await t.deleteKeyslots();
    await t.deletePreviousKeys();
    for (final m in await _store.membershipsForLibrary(libraryId)) {
      await _store.setLibraryKey(diverId: m.diverId, libraryId: libraryId);
    }
    await _store.setLibraryStatus(
      libraryId,
      encrypted: false,
      clearKeyId: true,
    );
  });

  Future<String> _rekey(
    SharedLibrary library,
    SharedLibraryTransport t,
    SharedLibraryMembership me,
    SharedLibraryRoles roles, {
    required String passphrase,
    required LibraryCipher? previous,
    RewriteProgress? progress,
  }) async {
    final cipher = await LibraryCipher.generate();
    final recovery = await LibraryRecovery.create(kdf: _kdf);
    // Every key the library has had, sealed under the new one first, so no
    // file left under an old key is ever lost.
    final earlier = previous == null
        ? const <LibraryCipher>[]
        : [...(await t.readPreviousKeys()).values, previous];
    if (earlier.isNotEmpty) {
      await t.writePreviousKeys(earlier, under: cipher);
    }
    await t.writeKeyslots(
      await cipher.keyslots(
        passphrase: passphrase,
        recoveryCode: recovery.code,
        kdf: _kdf,
      ),
    );
    // From here the new key is in the keyslots: its recovery code is the
    // way back in, so a step that fails still hands it over.
    try {
      final manifest = await t.readManifest() ?? {};
      await t.writeManifest({
        ...manifest,
        'encrypted': true,
        'keyId': cipher.keyId,
        SharedLibraryLayout.rewritingFlag: true,
      });
      t
        ..cipher = cipher
        ..encrypting = true;
      await _store.setLibraryKey(
        diverId: me.diverId,
        libraryId: library.id,
        keyId: cipher.keyId,
        key: await cipher.exportKey(),
      );
      await _store.setLibraryStatus(
        library.id,
        encrypted: true,
        keyId: cipher.keyId,
      );
      // The new recovery code signs owners in, and opens the new key.
      await _memberships.writeSignedRoles(
        library,
        t,
        roles.copyWith(
          recovery: RolesRecovery.fromJson(recovery.toRolesJson()),
        ),
        signer: me.memberId,
      );
      await _rewriteAll(t, previous: previous, progress: progress);
      await t.clearRewritingFlag();
    } catch (e) {
      throw RekeyIncompleteError(recovery.code, e);
    }
    return recovery.code;
  }

  static Future<void> _rewriteAll(
    SharedLibraryTransport t, {
    LibraryCipher? previous,
    RewriteProgress? progress,
  }) async {
    final index = await t.backupIndexFile();
    final files = {
      ...await t.sealableFiles(),
      if (index != null) index.key: index.value,
    };
    var done = 0;
    for (final e in files.entries) {
      await t.rewrite(e.key, e.value, previous: previous);
      progress?.call(++done, files.length);
    }
  }

  Future<
    (
      SharedLibrary,
      SharedLibraryTransport,
      SharedLibraryMembership,
      SharedLibraryRoles,
    )
  >
  _asOwner(String libraryId, String diverId) async {
    final library = await _store.getLibrary(libraryId);
    final me = await _store.membership(diverId: diverId, libraryId: libraryId);
    if (library == null || me == null) {
      throw StateError('not a member of $libraryId here');
    }
    final t = await _memberships.transportForLibrary(library);
    final roles = await _memberships.currentRoles(library, t);
    if (roles.roleOf(me.memberId) != SharedLibraryRole.owner) {
      throw StateError('only an owner changes encryption');
    }
    return (library, t, me, roles);
  }
}
