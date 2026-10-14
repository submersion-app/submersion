import 'dart:async';

import 'package:collection/collection.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/shared_library/crypto/roles_trust.dart';
import 'package:submersion/core/services/shared_library/crypto/field_signatures.dart';
import 'package:submersion/core/services/shared_library/crypto/library_cipher.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/crypto/suggestion_signatures.dart';
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/core/services/shared_library/library_site_notes.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/shared_library/site_document_bridge.dart';
import 'package:submersion/core/services/shared_library/site_document_merge.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';

part 'shared_library_sync_parts.dart';

enum SharedLibrarySyncStatus {
  success,
  readOnly,
  notALibrary,
  needsNewerApp,

  /// Made by a test build before format 2: it can only be created again.
  retired,

  /// Encrypted, and this device holds no key for it (or an older one):
  /// nothing is read or written until the passphrase is entered.
  locked,
  notConnected,
  failed,
}

class SharedLibrarySyncResult {
  const SharedLibrarySyncResult({
    required this.status,
    this.pulled = 0,
    this.pushed = 0,
    this.error,
  });

  final SharedLibrarySyncStatus status;
  final int pulled;
  final int pushed;
  final String? error;

  bool get isHealthy =>
      status == SharedLibrarySyncStatus.success ||
      status == SharedLibrarySyncStatus.readOnly;
}

/// Removes a library site from this device when its tombstone arrives or
/// the member leaves: linked rows survive as a personal site, unlinked
/// ones go. Task 12's SiteDetacher implements it; the default removes the
/// row outright.
typedef LibrarySiteRemover =
    Future<void> Function({
      required String siteId,
      required String ownerDiverId,
    });

/// One sync of one shared site library (issue #2567): manifest, roles and members,
/// pull and per-field merge, push of dirty sites, suggestions, status.
class SharedLibraryService {
  SharedLibraryService({
    required SharedLibraryStore store,
    required Future<SharedLibraryTransport> Function(SharedLibrary library)
    transportFor,
    SiteDocumentBridge? bridge,
    LibrarySiteRemover? remover,
    String appVersion = 'unknown',
    DateTime Function()? now,
  }) : _store = store,
       _transportFor = transportFor,
       _bridge = bridge ?? SiteDocumentBridge(),
       _remover = remover ?? _removeRow,
       _appVersion = appVersion,
       _now = now ?? DateTime.now;

  final SharedLibraryStore _store;
  final Future<SharedLibraryTransport> Function(SharedLibrary) _transportFor;
  final SiteDocumentBridge _bridge;
  final LibrarySiteRemover _remover;
  final String _appVersion;
  final DateTime Function() _now;
  final _log = LoggerService.forClass(SharedLibraryService);
  final _gates = <String, Future<void>>{};

  static Future<void> _removeRow({
    required String siteId,
    required String ownerDiverId,
  }) async {
    await SiteRepository().deleteSite(siteId, logTombstones: false);
  }

  /// Syncs [libraryId] for the profile [diverId]. Two calls for the same
  /// library run one after the other, never together.
  Future<SharedLibrarySyncResult> sync(
    String libraryId, {
    required String diverId,
  }) async {
    final previous = _gates[libraryId] ?? Future<void>.value();
    final completer = Completer<void>();
    _gates[libraryId] = previous.then((_) => completer.future);
    await previous;
    try {
      return await _syncOnce(libraryId, diverId: diverId);
    } finally {
      completer.complete();
    }
  }

  Future<SharedLibrarySyncResult> _syncOnce(
    String libraryId, {
    required String diverId,
  }) async {
    final library = await _store.getLibrary(libraryId);
    if (library == null) {
      return const SharedLibrarySyncResult(
        status: SharedLibrarySyncStatus.notConnected,
      );
    }
    final membership = await _store.membership(
      diverId: diverId,
      libraryId: libraryId,
    );
    // Another local profile's library: this profile may neither read its
    // rows in nor upload as an unknown member.
    if (membership == null) {
      return const SharedLibrarySyncResult(
        status: SharedLibrarySyncStatus.notConnected,
      );
    }
    try {
      final SharedLibraryTransport t;
      try {
        t = await _transportFor(library);
      } on StateError catch (e) {
        return await _fail(
          libraryId,
          SharedLibrarySyncStatus.notConnected,
          e.message,
        );
      }

      // 1. Manifest.
      final manifest = await t.readManifest();
      if (manifest == null) {
        return await _fail(
          libraryId,
          SharedLibrarySyncStatus.notALibrary,
          'No library at this location',
        );
      }
      final version = (manifest['formatVersion'] as num?)?.toInt() ?? 1;
      if (version < SharedLibraryLayout.minFormatVersion) {
        return await _fail(
          libraryId,
          SharedLibrarySyncStatus.retired,
          'This library was made by a test build of Submersion. '
          'Create it again.',
        );
      }
      if (version > SharedLibraryLayout.formatVersion) {
        return await _fail(
          libraryId,
          SharedLibrarySyncStatus.needsNewerApp,
          'Library format $version needs a newer app',
        );
      }

      // Encryption, as the manifest declares it, unless it says off where
      // the trusted roles say on: only an owner turns it off, by recording
      // so in the roles first. Settled with the roles trusted so far (which
      // opening the folder's needs), then again with the roles this sync
      // trusts.
      var encryption = libraryEncryptionOf(manifest, library.roles);
      final locked = await _useKey(t, libraryId, diverId, encryption);
      // Locked only by this device's older roles overruling a manifest that
      // says off: the folder's roles, rewritten plain, may say an owner
      // turned it off since.
      if (locked != null && !encryption.overruled) return locked;

      // 2. Roles and members. Only roles this device can trust count: a
      // file rewritten by someone who is no owner changes nothing here,
      // and one it cannot read (sealed under a key it lacks) neither.
      final incoming = await t.readRolesOrNull();
      final roles = incoming == null
          ? library.roles
          : await _trustRoles(library, incoming);
      final settled = libraryEncryptionOf(manifest, roles);
      if (locked != null || settled != encryption) {
        encryption = settled;
        final stillLocked = await _useKey(t, libraryId, diverId, encryption);
        if (stillLocked != null) return stillLocked;
      }
      if (encryption.overruled) {
        _log.warning(
          'The manifest of $libraryId says encryption is off; '
          'its roles, which an owner signs, say on',
        );
      }
      final encrypted = encryption.encrypted;
      final rewriting = encryption.rewriting;
      // Turned off by an owner: the key is no longer needed here, once
      // every file has been rewritten plain.
      if (!encrypted && !rewriting) await _dropLibraryKeys(libraryId);
      final members = await t.listMembers();
      await _store.setLibraryStatus(
        libraryId,
        name:
            await t.readName() ??
            switch (manifest['name']) {
              final String n => n,
              _ => null,
            },
      );
      await _store.replaceMembers(libraryId, members);
      // Probed afresh every sync: a refused upload sets it, so upgraded
      // credentials clear the banner on the next run. An ownership reset
      // waiting for this member's answer holds every write back, and so do
      // roles this device refused: whether forged, or newer than it can
      // follow (it missed the change that made their signer an owner), its
      // uploads would only fight the edits of owners it does not know. The
      // banner says so; leaving and joining again (with every local profile
      // that belongs to the library) brings the device back.
      final now = await _store.getLibrary(libraryId);
      final holdWrites =
          now?.pendingRoles != null || (now?.rolesRejected ?? false);
      var readOnly = holdWrites;
      SharedLibraryMember? mine;
      for (final m in members) {
        if (m.memberId == membership.memberId) mine = m;
      }
      // The card is rewritten, signed, whenever it lacks this profile's
      // key, its name changed, or its signature does not hold.
      // This membership's own key: the one the owners approved here, even
      // where two devices of the profile each made one before personal
      // sync met.
      final myKey =
          membership.signingKey ?? await _store.ensureSigningKey(diverId);
      if (mine == null ||
          mine.displayName != membership.displayName ||
          mine.publicKey != myKey.publicKey ||
          !mine.cardVerified) {
        try {
          final card = await SharedLibraryMember.signed(
            memberId: membership.memberId,
            displayName: membership.displayName,
            joinedAt: mine?.joinedAt ?? _now().toUtc(),
            key: myKey,
          );
          await t.writeMember(card, appVersion: _appVersion);
          await _store.replaceMembers(libraryId, [
            for (final m in members)
              if (m.memberId != membership.memberId) m,
            card,
          ]);
        } catch (e) {
          // A member card is a courtesy: a refused write is not a
          // read-only library (readers may write cards by policy).
          _log.warning('Could not write member card for $libraryId: $e');
        }
      }
      // Editors and owners with a genuine card whose key no owner approved
      // yet: their edits are held, neither applied nor overwritten.
      final pendingKeys = {
        for (final m in members)
          if (m.cardVerified &&
              m.publicKey != null &&
              roles.roleOf(m.memberId) != SharedLibraryRole.reader &&
              roles.approvedKeys[m.memberId] != m.publicKey)
            m.memberId: m.publicKey!,
      };

      // Notes an earlier build left only on the site rows become the
      // profile's own records, for personal sync to carry: once, before
      // any pull here adopts rows of its own.
      await _store.backfillSiteNotes(libraryId: libraryId, diverId: diverId);

      // 3. Pull, in batches: each batch's documents are read, their
      // signatures checked together (in parallel), then merged in order.
      final states = await _store.siteStates(libraryId);
      var pulled = 0;
      // Sites edited here after their batch read them: merged against what
      // they are now by the next sync, and not uploaded by this one, which
      // has not merged the folder's copy into them.
      final deferred = <String>{};
      final siteFiles = await t.listSites();
      final changed = [
        for (final f in siteFiles)
          if (states[SharedLibraryTransport.siteIdOf(f)]?.remoteModifiedTime !=
              f.modifiedTime.toUtc().toIso8601String())
            f,
      ];
      for (var i = 0; i < changed.length; i += _pullBatch) {
        final batch = <_Pulled>[];
        for (final f in changed.skip(i).take(_pullBatch)) {
          final siteId = SharedLibraryTransport.siteIdOf(f);
          final SiteDocument remote;
          try {
            remote = await t.readSite(f.id);
          } catch (e) {
            // Unreadable, or sealed under another key mid passphrase
            // change: next time.
            if (!SharedLibraryTransport.isUnreadable(e)) rethrow;
            _log.warning('Skipping unreadable site document ${f.name}: $e');
            continue;
          }
          if (remote.id != siteId) {
            _log.warning('Site document ${f.name} names another id; skipped');
            continue;
          }
          // Read afresh: an edit saved since the sync began has new clocks.
          final state = await _store.getSiteState(siteId);
          final hasRow = await SiteRepository().getSiteById(siteId) != null;
          batch.add(
            _Pulled(
              remote: remote,
              stamp: f.modifiedTime.toUtc().toIso8601String(),
              state: state,
              hasRow: hasRow,
              local: await _localDocument(siteId, state, hasRow: hasRow),
            ),
          );
        }
        final checked = await dropUnverifiedAll(
          [for (final p in batch) (p.remote, p.local)],
          libraryId: libraryId,
          approvedKeys: roles.editingKeys,
          retiredKeys: roles.retiredKeys,
          pendingKeys: pendingKeys,
        );
        for (var k = 0; k < batch.length; k++) {
          final siteId = batch[k].remote.id;
          if (_editedSince(batch[k].state, await _store.getSiteState(siteId))) {
            deferred.add(siteId);
            continue;
          }
          if (await _mergeRemote(
            library,
            batch[k],
            checked[k],
            diverId: diverId,
          )) {
            pulled++;
          }
        }
      }

      // A site that arrived (or changed) here takes the private notes and
      // rating the profile wrote for it on another device.
      if (pulled > 0) {
        await applyLibrarySiteNotes(DatabaseService.instance.database);
      }

      // 4. Push. Each field is signed by the local profile that edited it:
      // another member profile on this device may have, and a field left
      // unsigned counts for no other member.
      final dirty = await _store.dirtySites(libraryId);
      final localKeys = dirty.isEmpty
          ? const <String, LibrarySigningKey>{}
          : {
              for (final m in await _store.membershipsForLibrary(libraryId))
                m.memberId:
                    m.signingKey ?? await _store.ensureSigningKey(m.diverId),
            };
      var pushed = 0;
      var uploadAttempted = false;
      final remoteFiles = {
        for (final f in siteFiles) SharedLibraryTransport.siteIdOf(f): f.id,
      };
      for (final state in dirty) {
        if (readOnly) break;
        if (deferred.contains(state.siteId)) continue;
        // No file can be named after it: a site pulled before such names
        // were refused stays on this device.
        if (!SharedLibraryTransport.isSafeFileId(state.siteId)) continue;
        SiteDocument doc;
        try {
          doc = await _documentFor(state);
        } on StateError {
          // The row is gone and no tombstone was recorded: nothing to send.
          await _store.deleteSiteState(state.siteId);
          continue;
        }
        // Fields carried up for a member awaiting approval, with the clock
        // this device held for each: never recorded as what it holds.
        var carried = const <String, FieldClock?>{};
        final remoteId = remoteFiles[state.siteId];
        final othersSigned = doc.clocks.values.any(
          (c) => !localKeys.containsKey(c.memberId),
        );
        if (remoteId != null &&
            (state.deleted || pendingKeys.isNotEmpty || othersSigned)) {
          try {
            final remote = await t.readSite(remoteId);
            doc = await _authorsValues(
              doc,
              remote,
              localKeys.keys.toSet(),
              libraryId: libraryId,
              // A held author's signature proves the value as well.
              keys: {...pendingKeys, ...roles.editingKeys},
              retiredKeys: roles.retiredKeys,
            );
            if (state.deleted) {
              // A tombstone keeps the document's fields, so an undelete
              // wins the site back intact; only fields that prove
              // themselves.
              final proven = await dropUnverified(
                remote,
                local: doc,
                libraryId: libraryId,
                approvedKeys: roles.editingKeys,
                retiredKeys: roles.retiredKeys,
              );
              doc = mergeSiteDocuments(local: doc, remote: proven).merged;
            }
            // An edit waiting for an owner's approval is never erased.
            final before = doc.clocks;
            doc = await carryHeld(
              doc,
              remote,
              libraryId: libraryId,
              pendingKeys: pendingKeys,
            );
            carried = {
              for (final e in doc.clocks.entries)
                if (before[e.key]?.hlc != e.value.hlc) e.key: before[e.key],
            };
          } catch (e) {
            // Nothing readable to keep.
            if (!SharedLibraryTransport.isUnreadable(e)) rethrow;
          }
        }
        doc = _claimUnattributed(doc, membership.memberId);
        for (final e in localKeys.entries) {
          doc = await signOwnFields(
            doc,
            libraryId: libraryId,
            memberId: e.key,
            key: e.value,
          );
        }
        try {
          uploadAttempted = true;
          final modified = await t.writeSite(doc);
          await _recordUpload(state, modified, uploaded: doc, carried: carried);
          pushed++;
        } catch (e) {
          if (!SharedLibraryTransport.isPermissionError(e)) rethrow;
          _log.warning('Library $libraryId refused an upload: read-only');
          readOnly = true;
        }
      }

      // 5. Suggestions. Read-only credentials refuse them as they refuse
      // sites: the suggestions wait, and the library reads as read-only.
      if (!holdWrites) {
        await _retrySuggestionDeletes(t, libraryId);
        if (await _uploadSuggestions(t, libraryId)) {
          uploadAttempted = true;
          readOnly = true;
        }
      }
      if (roles.roleOf(membership.memberId) == SharedLibraryRole.owner) {
        await _pullSuggestions(t, libraryId, roles: roles);
      }

      // Files read in the wrong form (a member wrote plain after the
      // library was encrypted, or the reverse): an owner rewrites them.
      if (!holdWrites &&
          roles.roleOf(membership.memberId) == SharedLibraryRole.owner) {
        for (final e in {...t.mismatched}.entries) {
          try {
            await t.rewrite(e.key, e.value);
          } catch (err) {
            if (!SharedLibraryTransport.isPermissionError(err)) rethrow;
          }
        }
      }

      // A rewrite into a new form (encryption on, off, a new key) cut short:
      // an owner finishes it, so no file is left sealed under a key that
      // is about to be dropped, or plain in an encrypted library.
      if (rewriting &&
          !holdWrites &&
          roles.roleOf(membership.memberId) == SharedLibraryRole.owner &&
          await _finishRewrite(t, libraryId) &&
          !encrypted) {
        await _dropLibraryKeys(libraryId);
      }

      // 6. Status.
      // The read-only flag records the last upload's verdict; a sync that
      // uploaded nothing leaves it as it was.
      await _store.setLibraryStatus(
        libraryId,
        lastSyncAt: _now(),
        clearError: true,
        readOnlyDetected: uploadAttempted ? readOnly : null,
      );
      final effectiveReadOnly =
          holdWrites || (uploadAttempted ? readOnly : library.readOnlyDetected);
      return SharedLibrarySyncResult(
        status: effectiveReadOnly
            ? SharedLibrarySyncStatus.readOnly
            : SharedLibrarySyncStatus.success,
        pulled: pulled,
        pushed: pushed,
      );
    } catch (e, st) {
      _log.error('Library $libraryId sync failed', error: e, stackTrace: st);
      return _fail(
        libraryId,
        SharedLibrarySyncStatus.failed,
        e is CloudStorageException ? e.displayMessage : e.toString(),
      );
    }
  }

  /// The roles this device goes by after reading [incoming] (issue
  /// #2567): the newer file when an owner (or the recovery key) of the
  /// trusted roles signed it, else the trusted roles, with a warning, or a
  /// reset held for the member to answer. Before any roles are trusted
  /// (just joined), a self-consistent file is taken as found.
  Future<SharedLibraryRoles> _trustRoles(
    SharedLibrary library,
    SharedLibraryRoles incoming,
  ) async {
    final trusted = library.roles;
    if (incoming == trusted) {
      if (library.rolesRejected || library.pendingRoles != null) {
        await _store.setLibraryStatus(
          library.id,
          rolesRejected: false,
          clearPendingRoles: true,
        );
      }
      return trusted;
    }
    final verdict = await judgeRoles(
      trusted: trusted,
      incoming: incoming,
      libraryId: library.id,
    );
    switch (verdict) {
      case RolesVerdict.trusted:
        await _store.setLibraryStatus(
          library.id,
          roles: incoming,
          rolesRejected: false,
          clearPendingRoles: true,
        );
        // An approval (held edits now count) or a rejection (held edits
        // now repair): documents this device already read are read again.
        if (!incoming.judgesFieldsAs(trusted)) {
          await _store.clearRemoteStamps(library.id);
        }
        return incoming;
      case RolesVerdict.resetPending:
        await _store.setLibraryStatus(library.id, pendingRoles: incoming);
        return trusted;
      case RolesVerdict.rejected:
        _log.warning('Ignoring roles of ${library.id} not signed by an owner');
        await _store.setLibraryStatus(library.id, rolesRejected: true);
        return trusted;
    }
  }

  /// Records [state] and keys [t] for it: the key it names, when a local
  /// profile holds it or another device of the profile sent it. A failed
  /// result when the library is encrypted and no such key is here.
  Future<SharedLibrarySyncResult?> _useKey(
    SharedLibraryTransport t,
    String libraryId,
    String diverId,
    LibraryEncryptionState state,
  ) async {
    final keyId = state.keyId;
    await _store.setLibraryStatus(
      libraryId,
      encrypted: state.encrypted,
      keyId: keyId,
      clearKeyId: keyId == null,
    );
    // The key the state names, when a local profile holds it or another
    // device of the profile sent it before this one saw the change that
    // made it: the transport may have been keyed before this sync saw the
    // new key id.
    final named = keyId == null
        ? null
        : state.encrypted
        ? await _store.cipherNamed(libraryId, keyId: keyId, diverId: diverId)
        : await _store.libraryCipherFor(libraryId, keyId: keyId);
    if (named != null) {
      t.cipher = named;
    } else {
      t.cipher ??= await _store.libraryCipherFor(libraryId);
    }
    if (!state.encrypted) {
      t.encrypting = false;
      return null;
    }
    final held = t.cipher;
    if (held == null || held.keyId != keyId) {
      return _fail(
        libraryId,
        SharedLibrarySyncStatus.locked,
        held == null
            ? 'Enter the passphrase for this library'
            : "This library's passphrase changed",
      );
    }
    t.encrypting = true;
    return null;
  }

  Future<SharedLibrarySyncResult> _fail(
    String libraryId,
    SharedLibrarySyncStatus status,
    String error,
  ) async {
    await _store.setLibraryStatus(libraryId, lastError: error);
    return SharedLibrarySyncResult(status: status, error: error);
  }

  /// Forgets [libraryId]'s key on every local profile, and any kept aside.
  Future<void> _dropLibraryKeys(String libraryId) async {
    for (final m in await _store.membershipsForLibrary(libraryId)) {
      if (m.libraryKey != null) {
        await _store.setLibraryKey(diverId: m.diverId, libraryId: libraryId);
      }
    }
    await _store.clearSpareKey(libraryId);
  }

  /// Rewrites every file not yet in the library's current form, then
  /// clears the rewriting flag. False when one could not be rewritten here
  /// (under a key this device lacks, or without the rights): the flag
  /// stays for another owner.
  Future<bool> _finishRewrite(
    SharedLibraryTransport t,
    String libraryId,
  ) async {
    final index = await t.backupIndexFile();
    final files = {
      ...await t.sealableFiles(),
      if (index != null) index.key: index.value,
    };
    // Every file this device can open is rewritten; one under a key it
    // lacks leaves the flag for an owner who holds it.
    var incomplete = false;
    try {
      for (final e in files.entries) {
        try {
          await t.settle(e.key, e.value);
        } on LibraryLockedException catch (err) {
          _log.warning('Rewrite of $libraryId not finished here: $err');
          incomplete = true;
        }
      }
    } catch (e) {
      if (!SharedLibraryTransport.isPermissionError(e)) rethrow;
      _log.warning('No rights to finish the rewrite of $libraryId');
      return false;
    }
    if (incomplete) return false;
    await t.clearRewritingFlag();
    return true;
  }

  /// Pulls in at most this many documents at a time.
  static const _pullBatch = 200;

  /// The local side of a merge: the row as a document, or just its clocks
  /// when the row is gone or a tombstone.
  Future<SiteDocument> _localDocument(
    String siteId,
    SharedSiteState? state, {
    required bool hasRow,
  }) async => state == null
      ? SiteDocument(id: siteId)
      : hasRow && !state.deleted
      ? await _bridge.build(siteId, state)
      : SiteDocument(id: siteId, deleted: state.deleted, clocks: state.clocks);

  /// Folds [remote] (only the fields that proved themselves) into the
  /// local site. Returns true when the local row changed.
  Future<bool> _mergeRemote(
    SharedLibrary library,
    _Pulled pulled,
    SiteDocument remote, {
    required String diverId,
  }) async {
    final siteId = remote.id;
    final hasRow = pulled.hasRow;
    final state = pulled.state;
    final stamp = pulled.stamp;
    final local = pulled.local;
    final outcome = mergeSiteDocuments(local: local, remote: remote);
    final merged = outcome.merged;
    final newest = newestClockOf(merged.clocks.values);
    final base =
        state ?? SharedSiteState(siteId: siteId, libraryId: library.id);

    final bool changedLocal;
    if (merged.deleted) {
      if (hasRow) {
        await _remover(siteId: siteId, ownerDiverId: diverId);
      }
      changedLocal = hasRow;
    } else {
      final fields = hasRow && !(state?.deleted ?? false)
          ? outcome.remoteWon
          : merged.fields.keys.toSet();
      if (fields.isNotEmpty) {
        await _bridge.apply(
          merged,
          libraryId: library.id,
          vocabularyDiverId: diverId,
          fields: fields,
        );
      }
      changedLocal = fields.isNotEmpty;
    }
    await _store.putSiteState(
      base.copyWith(
        clocks: merged.clocks,
        deleted: merged.deleted,
        dirty: (state?.dirty ?? false) || outcome.needsUpload,
        remoteModifiedTime: stamp,
        lastEditorMemberId: newest?.memberId,
        lastEditedAtMs: newest?.hlc.physicalTime,
      ),
    );
    return changedLocal;
  }

  /// Marks [sent] uploaded at [modified], keeping the signed clocks of
  /// [uploaded]. An edit saved while the upload was on the wire changed
  /// the clocks: it keeps them and stays dirty for the next sync. A null
  /// [modified] clears the stamp so the next pull re-reads the document.
  /// A field in [carried] went up for a member awaiting approval: its
  /// value never reached the row, so the clock this device held for it is
  /// kept (none when it held none), and the held edit still reads as newer
  /// once it counts.
  Future<void> _recordUpload(
    SharedSiteState sent,
    DateTime? modified, {
    required SiteDocument uploaded,
    Map<String, FieldClock?> carried = const {},
  }) async {
    final current = await _store.getSiteState(sent.siteId) ?? sent;
    final editedMeanwhile =
        current.deleted != sent.deleted ||
        !const MapEquality<String, FieldClock>().equals(
          current.clocks,
          sent.clocks,
        );
    final recorded = {
      for (final e in uploaded.clocks.entries)
        if (!carried.containsKey(e.key))
          e.key: e.value
        else
          e.key: ?carried[e.key],
    };
    await _store.putSiteState(
      current.copyWith(
        clocks: editedMeanwhile ? null : recorded,
        dirty: editedMeanwhile,
        remoteModifiedTime: modified?.toUtc().toIso8601String(),
        clearRemoteModifiedTime: modified == null,
      ),
    );
  }

  Future<SiteDocument> _documentFor(SharedSiteState state) async {
    if (state.deleted) {
      return SiteDocument(
        id: state.siteId,
        deleted: true,
        clocks: state.clocks,
      );
    }
    return _bridge.build(state.siteId, state);
  }
}
