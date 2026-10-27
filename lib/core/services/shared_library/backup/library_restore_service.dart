import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/shared_library/backup/library_backup_archive.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_service.dart';
import 'package:submersion/core/services/shared_library/crypto/field_signatures.dart';
import 'package:submersion/core/services/shared_library/crypto/library_cipher.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/member_clock.dart';
import 'package:submersion/core/services/shared_library/member_removal.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';

/// The backup was sealed under a key the library no longer uses: the
/// passphrase or recovery code of that time opens it.
class BackupNeedsOldKeyError implements Exception {
  const BackupNeedsOldKeyError(this.keyId);

  final String keyId;

  @override
  String toString() => 'BackupNeedsOldKeyError($keyId)';
}

/// A library restored into an empty folder.
class RestoredLibrary {
  const RestoredLibrary({required this.library, required this.oldStillThere});

  final SharedLibrary library;

  /// Whether the folder the library lived in before still holds it: the
  /// members there go on using that copy until they move.
  final bool oldStillThere;
}

/// Puts a shared site library back to one of its backups (issue #2567).
///
/// Every restored field is stamped anew under the restoring owner, after
/// every clock in the library and the backup, so the restore wins on every
/// member's next sync however slow this device's clock runs.
class LibraryRestoreService {
  LibraryRestoreService({
    required SharedLibraryStore store,
    required SharedLibraryMembershipService memberships,
    required LibraryBackupService backups,
    int Function()? nowMs,
  }) : _store = store,
       _memberships = memberships,
       _backups = backups,
       _nowMs = nowMs;

  final SharedLibraryStore _store;
  final SharedLibraryMembershipService _memberships;
  final LibraryBackupService _backups;
  final int Function()? _nowMs;

  static const _plain = {
    SharedLibraryLayout.manifestFile,
    SharedLibraryLayout.keyslotsFile,
  };

  /// Restores [backupId] over the library. Owners only. A pinned backup of
  /// the library as it stands is made first. [oldSecret] opens a backup
  /// sealed under an earlier key.
  Future<void> restore({
    required String libraryId,
    required String diverId,
    required String backupId,
    String? oldSecret,
  }) async {
    DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.sharedLibrary);
    return SyncCoordinator.run(() async {
      final library = await _store.getLibrary(libraryId);
      final me = await _store.membership(
        diverId: diverId,
        libraryId: libraryId,
      );
      if (library == null || me == null) {
        throw StateError('not a member of $libraryId here');
      }
      final t = await _memberships.transportForLibrary(library);
      final roles = await _memberships.ownerRoles(
        library,
        t,
        me.memberId,
        action: 'restores a library',
      );
      final path = await _backups.localCopy(backupId, libraryId: libraryId);
      final contents = await LibraryBackupArchive.read(
        await File(path).readAsBytes(),
      );
      if (contents.header.libraryId != libraryId) {
        throw const BackupRefusedError('otherLibrary');
      }
      // The backup the owner picked, not another file put in its place.
      if (contents.header.backupId != backupId) {
        throw const BackupRefusedError('notABackup');
      }
      // Made by an owner this device trusts, with the key it approves: the
      // roles inside a zip are whatever its maker wrote.
      _checkCreator(contents.header, roles);
      // Everything is opened and checked before anything changes: a missing
      // key or a broken file stops the restore with the library untouched.
      // The library's earlier keys open a backup sealed before a passphrase
      // change; only a key it no longer keeps is asked for.
      final opened = await _openAll(
        contents.files,
        t.cipher,
        oldSecret,
        earlier: await t.readPreviousKeys(),
      );
      final backupRoles = _rolesIn(opened);
      if (backupRoles == null) throw const BackupRefusedError('notABackup');
      final sites = _sitesIn(opened);

      final before = await _backups.backUpHeld(
        libraryId: libraryId,
        diverId: diverId,
        beforeRestore: true,
      );
      await _backups.setPinnedHeld(
        before.backupId,
        libraryId: libraryId,
        diverId: diverId,
        pinned: true,
      );

      final key = me.signingKey ?? await _store.ensureSigningKey(diverId);
      // Removals are not in backups (issue #3481): the folder's own outlive
      // the restore, applied again to the roles it brings back.
      final removals = [
        for (final r in await validRemovals(
          await t.listRemovals(),
          libraryId,
          roles,
        ))
          if (r.memberId != me.memberId) r,
      ];
      await _restoreSites(
        t,
        library.id,
        me.memberId,
        key,
        sites,
        // Fields count when signed by a member trusted then or now.
        signers: [backupRoles, roles],
      );
      final restored = await _memberships.writeSignedRoles(
        library,
        t,
        // The backup's roles with this owner kept as owner (an earlier key of
        // theirs retired, its edits still counting), the current recovery
        // key, and every current removal applied again.
        _removingAll(removals, backupRoles)
            .withRole(me.memberId, SharedLibraryRole.owner)
            .approveKey(me.memberId, key.publicKey, at: DateTime.now())
            .copyWith(
              version: roles.version,
              recovery: roles.recovery,
              clearRecovery: roles.recovery == null,
              // A restore changes the sites, not how the library is sealed.
              encryption: roles.encryption,
              clearEncryption: roles.encryption == null,
            ),
        signer: me.memberId,
        key: key,
      );
      // writeSignedRoles signed again any removal whose owner the restored
      // roles do not list; the cache follows the restored roles.
      await _store.setRemovals(
        libraryId,
        await validRemovals(await t.listRemovals(), libraryId, restored),
      );
      await _restoreOthers(t, opened);
      // The backup's card of someone removed since stays gone.
      for (final r in removals) {
        await t.deleteMember(r.memberId);
      }
      await _store.clearRemoteStamps(libraryId);
      await _store.replaceMembers(libraryId, await t.listMembers());
    });
  }

  static SharedLibraryRoles _removingAll(
    List<MemberRemoval> removals,
    SharedLibraryRoles roles,
  ) => removals.fold(
    roles,
    (acc, r) => acc.removing(r.memberId, at: r.removedAt),
  );

  /// Writes the backup at [path] into the empty folder [prefix] of
  /// [account] and joins it there as [diverId]: the library keeps its id.
  /// [secret] unlocks an encrypted backup.
  Future<RestoredLibrary> restoreInto({
    required domain.ConnectedAccount account,
    required String prefix,
    required String diverId,
    required String displayName,
    required String path,
    String? secret,
  }) async {
    DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.sharedLibrary);
    return SyncCoordinator.run(() async {
      final contents = await LibraryBackupArchive.read(
        await File(path).readAsBytes(),
      );
      final h = contents.header;
      final manifest = contents.files[SharedLibraryLayout.manifestFile];
      if (manifest == null) throw const BackupRefusedError('notABackup');
      // The library the header names, which the creator was checked for, is
      // the one the folder becomes.
      final Object? manifestId;
      try {
        final decoded = jsonDecode(utf8.decode(manifest));
        manifestId = decoded is Map ? decoded['id'] : null;
      } on FormatException {
        throw const BackupRefusedError('notABackup');
      }
      if (manifestId != h.libraryId) {
        throw const BackupRefusedError('otherLibrary');
      }
      final t = await _memberships.transportAt(
        account: account,
        prefix: prefix,
      );
      if (await t.readManifest() != null) throw LibraryExistsError(prefix);
      final opened = await _openAll(contents.files, null, secret);
      final backupRoles = _rolesIn(opened);
      if (backupRoles == null) throw const BackupRefusedError('notABackup');
      final old = await _store.getLibrary(h.libraryId);
      final held = old != null && old.roles.version > 0;
      // Against the roles this device trusts, when it holds the library; a
      // device new to it has only the backup's own to go by.
      final trusted = held ? old.roles : backupRoles;
      _checkCreator(h, trusted);
      // The restoring profile, when it is an owner there signing with the
      // key they approve: it signs the restored roles past every version a
      // member trusts, or members who know later roles refuse them. On a
      // device that holds the library only such an owner restores it.
      final memberId = await _store.memberIdForDiver(diverId);
      final approved = trusted.roleOf(memberId) == SharedLibraryRole.owner
          ? trusted.approvedKeys[memberId]
          : null;
      LibrarySigningKey? key;
      for (final candidate in [
        (await _store.membership(
          diverId: diverId,
          libraryId: h.libraryId,
        ))?.signingKey,
        await _store.signingKeyForDiver(diverId),
      ]) {
        if (approved != null && candidate?.publicKey == approved) {
          key = candidate;
          break;
        }
      }
      if (held && key == null) throw const BackupRefusedError('notOwner');

      var oldStillThere = false;
      var oldFolderVersion = 0;
      // The same folder name in another account is another place.
      if (old != null &&
          (old.prefix != prefix || old.connectedAccountId != account.id)) {
        try {
          final oldT = await _memberships.transportForLibrary(old);
          final found = await oldT.readManifest();
          oldStillThere = found?['id'] == h.libraryId;
          if (oldStillThere) {
            oldFolderVersion = (await oldT.readRoles()).version;
          }
        } catch (_) {
          // The old folder cannot be reached: nobody is using it either.
        }
      }
      // The manifest last: until it lands the folder is no library.
      for (final e in contents.files.entries) {
        if (e.key != SharedLibraryLayout.manifestFile) {
          await t.writeRaw(e.key, e.value);
        }
      }
      await t.writeRaw(SharedLibraryLayout.manifestFile, manifest);
      final library = await _memberships.join(
        account: account,
        prefix: prefix,
        diverId: diverId,
        displayName: displayName,
        secret: secret,
        // Checked above: the restored roles are the library's now.
        adoptFolderRoles: true,
        signingKey: key,
      );
      if (key == null) {
        return RestoredLibrary(library: library, oldStillThere: oldStillThere);
      }
      final versions = [
        backupRoles.version,
        if (held) old.roles.version,
        oldFolderVersion,
      ];
      await _memberships.writeSignedRoles(
        library,
        await _memberships.transportForLibrary(library),
        backupRoles
            .withRole(memberId, SharedLibraryRole.owner)
            .approveKey(memberId, key.publicKey, at: DateTime.now())
            .copyWith(version: versions.reduce((a, b) => a > b ? a : b)),
        signer: memberId,
        key: key,
      );
      return RestoredLibrary(
        library: await _store.getLibrary(library.id) ?? library,
        oldStillThere: oldStillThere,
      );
    });
  }

  /// The backup's files opened, by path, without the manifest, keyslots and
  /// lists of earlier keys. A file under a key neither [current] nor
  /// [earlier] holds opens with the backup's own key ([oldSecret] unlocks
  /// its keyslots) or one of that key's earlier keys.
  Future<Map<String, Uint8List>> _openAll(
    Map<String, Uint8List> files,
    LibraryCipher? current,
    String? oldSecret, {
    Map<String, LibraryCipher> earlier = const {},
  }) async {
    final keys = {...earlier};
    LibraryCipher? backupKey;
    Future<LibraryCipher?> keyFor(String keyId) async {
      if (current != null && current.keyId.toLowerCase() == keyId) {
        return current;
      }
      final known = keys[keyId];
      if (known != null) return known;
      if (backupKey == null) {
        final slots = files[SharedLibraryLayout.keyslotsFile];
        if (slots == null || oldSecret == null) return null;
        final unlocked = await LibraryCipher.unlock(
          KeyslotFile.fromJsonBytes(slots),
          oldSecret,
        );
        if (unlocked == null) return null;
        backupKey = unlocked;
        keys[unlocked.keyId.toLowerCase()] = unlocked;
        final list =
            files[SharedLibraryLayout.previousKeysFileFor(unlocked.keyId)];
        if (list != null) {
          keys.addAll(
            await SharedLibraryTransport.previousKeysIn(list, under: unlocked),
          );
        }
      }
      return keys[keyId];
    }

    final out = <String, Uint8List>{};
    for (final e in files.entries) {
      if (_plain.contains(e.key) ||
          e.key.startsWith(SharedLibraryLayout.previousKeysPrefix)) {
        continue;
      }
      final raw = e.value;
      if (!LibraryCipher.isSealed(raw)) {
        out[e.key] = raw;
        continue;
      }
      // A file no key opens (a broken envelope, or junk that only looks
      // sealed, which any member's storage key may have written) is left
      // out, as a sync skips it. Only a key the backup itself may hold is
      // asked for: its own, or while that is not open yet, an earlier one.
      try {
        final keyId = LibraryCipher.keyIdOf(raw);
        final opener = await keyFor(keyId);
        if (opener == null) {
          final slots = files[SharedLibraryLayout.keyslotsFile];
          final ownKey = slots == null
              ? null
              : KeyslotFile.fromJsonBytes(slots).libraryKeyId.toLowerCase();
          final mayHold =
              ownKey != null &&
              (ownKey == keyId ||
                  (backupKey == null &&
                      ownKey != current?.keyId.toLowerCase()));
          if (mayHold) throw BackupNeedsOldKeyError(keyId);
          continue;
        }
        out[e.key] = await opener.open(e.key, raw);
      } on BackupNeedsOldKeyError {
        rethrow;
      } catch (err) {
        if (!SharedLibraryTransport.isUnreadable(err) ||
            err is LibraryLockedException) {
          rethrow;
        }
      }
    }
    return out;
  }

  static SharedLibraryRoles? _rolesIn(Map<String, Uint8List> opened) {
    final bytes = opened[SharedLibraryLayout.rolesFile];
    if (bytes == null) return null;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      return decoded is Map<String, dynamic>
          ? SharedLibraryRoles.fromJson(decoded)
          : null;
    } catch (e) {
      if (!SharedLibraryTransport.isUnreadable(e)) rethrow;
      return null;
    }
  }

  /// The backup's site documents by the id their file names: one that
  /// cannot be read, or names another id inside, is left out, as a sync
  /// skips it.
  static Map<String, SiteDocument> _sitesIn(Map<String, Uint8List> opened) {
    const dir = '${SharedLibraryLayout.sitesDir}/site-';
    final out = <String, SiteDocument>{};
    for (final e in opened.entries) {
      if (!e.key.startsWith(dir) || !e.key.endsWith('.json')) continue;
      final id = e.key.substring(dir.length, e.key.length - '.json'.length);
      try {
        final doc = SiteDocument.decode(e.value);
        if (doc.id == id) out[id] = doc;
      } catch (err) {
        if (!SharedLibraryTransport.isUnreadable(err)) rethrow;
      }
    }
    return out;
  }

  /// A backup counts only when its maker is an owner, with that key, in
  /// [roles].
  static void _checkCreator(
    LibraryBackupHeader header,
    SharedLibraryRoles? roles,
  ) {
    if (roles == null ||
        roles.roleOf(header.createdBy) != SharedLibraryRole.owner ||
        roles.approvedKeys[header.createdBy] != header.createdByKey) {
      throw const BackupRefusedError('creator');
    }
  }

  /// [docs] with every field none of [signers] can prove dropped, as a sync
  /// drops it: the restore signs what it writes, so it must never sign a
  /// value nobody trusted.
  Future<Map<String, SiteDocument>> _proven(
    Map<String, SiteDocument> docs,
    String libraryId,
    List<SharedLibraryRoles> signers,
  ) async {
    final ids = docs.keys.toList();
    final retired = <String, List<(String, int)>>{};
    for (final r in signers) {
      for (final e in r.retiredKeys.entries) {
        retired[e.key] = [...?retired[e.key], ...e.value];
      }
    }
    final checked = await dropUnverifiedAll(
      [for (final id in ids) (docs[id]!, SiteDocument(id: id))],
      libraryId: libraryId,
      approvedKeys: {for (final r in signers) ...r.editingKeys},
      retiredKeys: retired,
    );
    return {for (var k = 0; k < ids.length; k++) ids[k]: checked[k]};
  }

  Future<void> _restoreSites(
    SharedLibraryTransport t,
    String libraryId,
    String memberId,
    LibrarySigningKey key,
    Map<String, SiteDocument> backedUp, {
    required List<SharedLibraryRoles> signers,
  }) async {
    final restored = await _proven(backedUp, libraryId, signers);
    final read = <String, SiteDocument>{};
    for (final f in await t.listSites()) {
      final id = SharedLibraryTransport.siteIdOf(f);
      try {
        final doc = await t.readSite(f.id);
        // A document naming another id is no copy of this site.
        read[id] = doc.id == id ? doc : SiteDocument(id: id);
      } catch (e) {
        if (!SharedLibraryTransport.isUnreadable(e)) rethrow;
        // An unreadable document is replaced or tombstoned all the same.
        read[id] = SiteDocument(id: id);
      }
    }
    final current = await _proven(read, libraryId, signers);

    final clock = MemberClock(memberId, now: _nowMs);
    for (final doc in [...current.values, ...restored.values]) {
      for (final c in doc.clocks.values) {
        clock.receive(c.hlc);
      }
    }
    for (final s in (await _store.siteStates(libraryId)).values) {
      for (final c in s.clocks.values) {
        clock.receive(c.hlc);
      }
    }

    FieldClock stamp() => FieldClock(hlc: clock.next(), memberId: memberId);
    Object? cleared(String field) =>
        SiteDocument.listFields.contains(field) ? const <Object?>[] : null;
    for (final id in {...restored.keys, ...current.keys}) {
      if (!SharedLibraryTransport.isSafeFileId(id)) continue;
      final from = restored[id];
      final raw = backedUp[id];
      final now = current[id];
      final names = {...?raw?.fields.keys, ...?now?.fields.keys};
      final doc = SiteDocument(
        id: id,
        // A site made since the backup goes, keeping its fields for undo.
        deleted: from?.deleted ?? true,
        fields: {
          for (final n in names)
            n: from == null
                ? now!.fields[n]
                : from.fields.containsKey(n)
                ? from.fields[n]
                // Backed up but proven by nobody: the library's value now.
                : raw!.fields.containsKey(n) &&
                      (now?.fields.containsKey(n) ?? false)
                ? now!.fields[n]
                : cleared(n),
        },
        clocks: {
          if (from != null)
            for (final n in names) n: stamp(),
          if (from == null) ...?now?.clocks,
          SiteDocument.deletedField: stamp(),
        },
        extra: from?.extra ?? now?.extra ?? const {},
      );
      await t.writeSite(
        await signOwnFields(
          doc,
          libraryId: libraryId,
          memberId: memberId,
          key: key,
        ),
      );
    }
  }

  /// The library's name, member cards and suggestions as backed up. Cards
  /// of members who joined since stay: they are pending until approved.
  Future<void> _restoreOthers(
    SharedLibraryTransport t,
    Map<String, Uint8List> opened,
  ) async {
    const suggestions = '${SharedLibraryLayout.suggestionsDir}/';
    final info = opened[SharedLibraryLayout.infoFile];
    if (info != null) await t.writeOpened(SharedLibraryLayout.infoFile, info);
    for (final e in opened.entries) {
      if (e.key.startsWith('${SharedLibraryLayout.membersDir}/') ||
          e.key.startsWith(suggestions)) {
        await t.writeOpened(e.key, e.value);
      }
    }
    for (final f in await t.listSuggestions()) {
      final path = '$suggestions${f.name.split('/').last}';
      if (!opened.containsKey(path)) await t.deleteRaw(path);
    }
  }
}
