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
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';

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
  }) => SyncCoordinator.run(() async {
    final library = await _store.getLibrary(libraryId);
    final me = await _store.membership(diverId: diverId, libraryId: libraryId);
    if (library == null || me == null) {
      throw StateError('not a member of $libraryId here');
    }
    final t = await _memberships.transportForLibrary(library);
    final roles = await _memberships.currentRoles(library, t);
    if (roles.roleOf(me.memberId) != SharedLibraryRole.owner) {
      throw StateError('only an owner restores a library');
    }
    final path = await _backups.localCopy(backupId, libraryId: libraryId);
    final contents = await LibraryBackupArchive.read(
      await File(path).readAsBytes(),
    );
    if (contents.header.libraryId != libraryId) {
      throw const BackupRefusedError('otherLibrary');
    }
    // Everything is opened before anything changes: a missing key stops
    // the restore with the library untouched.
    final opened = await _openAll(contents.files, t.cipher, oldSecret);
    final backupRoles = _rolesIn(opened);
    _checkCreator(contents.header, backupRoles);

    final before = await _backups.backUp(
      libraryId: libraryId,
      diverId: diverId,
      beforeRestore: true,
    );
    await _backups.setPinned(
      before.backupId,
      libraryId: libraryId,
      diverId: diverId,
      pinned: true,
    );

    final key = await _store.ensureSigningKey(diverId);
    await _restoreSites(t, library.id, me.memberId, key, opened);
    await _memberships.writeSignedRoles(
      library,
      t,
      (backupRoles ?? roles)
          .withRole(me.memberId, SharedLibraryRole.owner)
          .copyWith(
            version: roles.version,
            approvedKeys: {
              ...?backupRoles?.approvedKeys,
              me.memberId: key.publicKey,
            },
            recovery: roles.recovery,
            clearRecovery: roles.recovery == null,
          ),
      signer: me.memberId,
      key: key,
    );
    await _restoreOthers(t, opened);
    await _store.clearRemoteStamps(libraryId);
    await _store.replaceMembers(libraryId, await t.listMembers());
  });

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
  }) => SyncCoordinator.run(() async {
    final contents = await LibraryBackupArchive.read(
      await File(path).readAsBytes(),
    );
    final h = contents.header;
    final t = await _memberships.transportAt(account: account, prefix: prefix);
    if (await t.readManifest() != null) throw LibraryExistsError(prefix);
    final opened = await _openAll(contents.files, null, secret);
    _checkCreator(h, _rolesIn(opened));

    final old = await _store.getLibrary(h.libraryId);
    var oldStillThere = false;
    // The same folder name in another account is another place.
    if (old != null &&
        (old.prefix != prefix || old.connectedAccountId != account.id)) {
      try {
        final manifest = await (await _memberships.transportForLibrary(
          old,
        )).readManifest();
        oldStillThere = manifest?['id'] == h.libraryId;
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
    final manifest = contents.files[SharedLibraryLayout.manifestFile];
    if (manifest == null) throw const BackupRefusedError('notABackup');
    await t.writeRaw(SharedLibraryLayout.manifestFile, manifest);
    final library = await _memberships.join(
      account: account,
      prefix: prefix,
      diverId: diverId,
      displayName: displayName,
      secret: secret,
    );
    return RestoredLibrary(library: library, oldStillThere: oldStillThere);
  });

  /// The backup's files opened, by path, without the manifest and keyslots.
  Future<Map<String, Uint8List>> _openAll(
    Map<String, Uint8List> files,
    LibraryCipher? current,
    String? oldSecret,
  ) async {
    LibraryCipher? older;
    final out = <String, Uint8List>{};
    for (final e in files.entries) {
      if (_plain.contains(e.key)) continue;
      final raw = e.value;
      if (!LibraryCipher.isSealed(raw)) {
        out[e.key] = raw;
        continue;
      }
      final keyId = LibraryCipher.keyIdOf(raw);
      var opener = current != null && current.keyId.toLowerCase() == keyId
          ? current
          : older;
      if (opener == null || opener.keyId.toLowerCase() != keyId) {
        final slots = files[SharedLibraryLayout.keyslotsFile];
        older = slots == null || oldSecret == null
            ? null
            : await LibraryCipher.unlock(
                KeyslotFile.fromJsonBytes(slots),
                oldSecret,
              );
        if (older == null || older.keyId.toLowerCase() != keyId) {
          throw BackupNeedsOldKeyError(keyId);
        }
        opener = older;
      }
      out[e.key] = await opener.open(e.key, raw);
    }
    return out;
  }

  static SharedLibraryRoles? _rolesIn(Map<String, Uint8List> opened) {
    final bytes = opened[SharedLibraryLayout.rolesFile];
    if (bytes == null) return null;
    final decoded = jsonDecode(utf8.decode(bytes));
    return decoded is Map<String, dynamic>
        ? SharedLibraryRoles.fromJson(decoded)
        : null;
  }

  /// A backup counts only when its maker was an owner, with that key, in
  /// the roles it holds.
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

  Future<void> _restoreSites(
    SharedLibraryTransport t,
    String libraryId,
    String memberId,
    LibrarySigningKey key,
    Map<String, Uint8List> opened,
  ) async {
    final restored = <String, SiteDocument>{};
    const dir = '${SharedLibraryLayout.sitesDir}/';
    for (final e in opened.entries) {
      if (e.key.startsWith(dir)) {
        final doc = SiteDocument.decode(e.value);
        restored[doc.id] = doc;
      }
    }
    final current = <String, SiteDocument>{};
    for (final f in await t.listSites()) {
      try {
        current[SharedLibraryTransport.siteIdOf(f)] = await t.readSite(f.id);
      } on FormatException {
        // An unreadable document is replaced or tombstoned all the same.
        current[SharedLibraryTransport.siteIdOf(f)] = SiteDocument(
          id: SharedLibraryTransport.siteIdOf(f),
          fields: const {},
          clocks: const {},
        );
      }
    }

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
    for (final id in {...restored.keys, ...current.keys}) {
      final from = restored[id];
      final now = current[id];
      final names = {...?from?.fields.keys, ...?now?.fields.keys};
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
                : SiteDocument.listFields.contains(n)
                ? const <Object?>[]
                : null,
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
      final path =
          '$suggestions'
          '${SharedLibraryTransport.suggestionFileName(SharedLibraryTransport.suggestionIdOf(f))}';
      if (!opened.containsKey(path)) await t.deleteRaw(path);
    }
  }
}
