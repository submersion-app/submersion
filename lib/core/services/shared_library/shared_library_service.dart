import 'dart:async';

import 'package:collection/collection.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/shared_library/crypto/roles_trust.dart';
import 'package:submersion/core/services/shared_library/crypto/field_signatures.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/crypto/suggestion_signatures.dart';
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/core/services/shared_library/member_clock.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/shared_library/site_document_bridge.dart';
import 'package:submersion/core/services/shared_library/site_document_merge.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';

enum SharedLibrarySyncStatus {
  success,
  readOnly,
  notALibrary,
  needsNewerApp,

  /// Made by a test build before format 2: it can only be created again.
  retired,
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

      // 2. Roles and members. Only roles this device can trust count: a
      // file rewritten by someone who is no owner changes nothing here.
      final roles = await _trustRoles(library, await t.readRoles());
      final members = await t.listMembers();
      await _store.setLibraryStatus(
        libraryId,
        name: await _nameOf(t) ?? manifest['name'] as String?,
      );
      await _store.replaceMembers(libraryId, members);
      // Probed afresh every sync: a refused upload sets it, so upgraded
      // credentials clear the banner on the next run. An ownership reset
      // waiting for this member's answer holds every write back.
      final holdWrites =
          (await _store.getLibrary(libraryId))?.pendingRoles != null;
      var readOnly = holdWrites;
      SharedLibraryMember? mine;
      for (final m in members) {
        if (m.memberId == membership.memberId) mine = m;
      }
      // The card is rewritten, signed, whenever it lacks this profile's
      // key, its name changed, or its signature does not hold.
      final myKey = await _store.ensureSigningKey(diverId);
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
      // Members with a genuine card whose key no owner approved yet: their
      // edits are held, neither applied nor overwritten.
      final pendingKeys = {
        for (final m in members)
          if (m.cardVerified &&
              m.publicKey != null &&
              roles.approvedKeys[m.memberId] != m.publicKey)
            m.memberId: m.publicKey!,
      };

      // 3. Pull, in batches: each batch's documents are read, their
      // signatures checked together (in parallel), then merged in order.
      final states = await _store.siteStates(libraryId);
      final clock = MemberClock(membership.memberId);
      var pulled = 0;
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
          } on FormatException catch (e) {
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
          approvedKeys: roles.approvedKeys,
          pendingKeys: pendingKeys,
        );
        for (var k = 0; k < batch.length; k++) {
          if (await _mergeRemote(
            library,
            batch[k],
            checked[k],
            diverId: diverId,
            clock: clock,
          )) {
            pulled++;
          }
        }
      }

      // 4. Push.
      var pushed = 0;
      var uploadAttempted = false;
      final remoteFiles = {
        for (final f in siteFiles) SharedLibraryTransport.siteIdOf(f): f.id,
      };
      for (final state in await _store.dirtySites(libraryId)) {
        if (readOnly) break;
        SiteDocument doc;
        try {
          doc = await _documentFor(state);
        } on StateError {
          // The row is gone and no tombstone was recorded: nothing to send.
          await _store.deleteSiteState(state.siteId);
          continue;
        }
        final remoteId = remoteFiles[state.siteId];
        if (remoteId != null && (state.deleted || pendingKeys.isNotEmpty)) {
          try {
            final remote = await t.readSite(remoteId);
            if (state.deleted) {
              // A tombstone keeps the document's fields, so an undelete
              // wins the site back intact; only fields that prove
              // themselves.
              final proven = await dropUnverified(
                remote,
                local: doc,
                libraryId: libraryId,
                approvedKeys: roles.approvedKeys,
              );
              doc = mergeSiteDocuments(local: doc, remote: proven).merged;
            }
            // An edit waiting for an owner's approval is never erased.
            doc = await carryHeld(
              doc,
              remote,
              libraryId: libraryId,
              pendingKeys: pendingKeys,
            );
          } on FormatException {
            // Nothing readable to keep.
          }
        }
        doc = await signOwnFields(
          _claimUnattributed(doc, membership.memberId, clock),
          libraryId: libraryId,
          memberId: membership.memberId,
          key: myKey,
        );
        try {
          uploadAttempted = true;
          final modified = await t.writeSite(doc);
          await _recordUpload(state, modified, uploaded: doc);
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
        if (await _uploadSuggestions(t, libraryId, key: myKey)) {
          uploadAttempted = true;
          readOnly = true;
        }
      }
      if (roles.roleOf(membership.memberId) == SharedLibraryRole.owner) {
        await _pullSuggestions(t, libraryId, roles: roles);
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
    final RolesVerdict verdict;
    if (trusted.version == 0) {
      verdict = await isSelfConsistent(incoming)
          ? RolesVerdict.trusted
          : RolesVerdict.rejected;
    } else {
      verdict = await judgeRoles(trusted: trusted, incoming: incoming);
    }
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
        await _store.clearRemoteStamps(library.id);
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

  /// The library's name from `info.json`, or null when it cannot be read.
  Future<String?> _nameOf(SharedLibraryTransport t) async {
    try {
      return (await t.readInfo())?['name'] as String?;
    } on FormatException {
      return null;
    }
  }

  Future<SharedLibrarySyncResult> _fail(
    String libraryId,
    SharedLibrarySyncStatus status,
    String error,
  ) async {
    await _store.setLibraryStatus(libraryId, lastError: error);
    return SharedLibrarySyncResult(status: status, error: error);
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

  /// Fields going up with no clock, or stamped without a known member (a
  /// device with two member profiles and no acting one), go up as this
  /// profile's edits: a field nobody signed is dropped by every other
  /// member.
  static SiteDocument _claimUnattributed(
    SiteDocument doc,
    String memberId,
    MemberClock clock,
  ) {
    final clocks = <String, FieldClock>{
      for (final e in doc.clocks.entries)
        e.key: e.value.memberId == LibraryEditStamper.unknownMember
            ? e.value.copyWith(memberId: memberId, clearSig: true)
            : e.value,
    };
    for (final field in [...doc.fields.keys, SiteDocument.deletedField]) {
      clocks[field] ??= FieldClock(hlc: clock.next(), memberId: memberId);
    }
    return doc.copyWith(clocks: clocks);
  }

  /// Folds [remote] (only the fields that proved themselves) into the
  /// local site. Returns true when the local row changed.
  Future<bool> _mergeRemote(
    SharedLibrary library,
    _Pulled pulled,
    SiteDocument remote, {
    required String diverId,
    required MemberClock clock,
  }) async {
    final siteId = remote.id;
    final hasRow = pulled.hasRow;
    final state = pulled.state;
    final stamp = pulled.stamp;
    final local = pulled.local;
    final outcome = mergeSiteDocuments(local: local, remote: remote);
    for (final c in remote.clocks.values) {
      clock.receive(c.hlc);
    }
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
  Future<void> _recordUpload(
    SharedSiteState sent,
    DateTime? modified, {
    required SiteDocument uploaded,
  }) async {
    final current = await _store.getSiteState(sent.siteId) ?? sent;
    final editedMeanwhile =
        current.deleted != sent.deleted ||
        !const MapEquality<String, FieldClock>().equals(
          current.clocks,
          sent.clocks,
        );
    await _store.putSiteState(
      current.copyWith(
        clocks: editedMeanwhile ? null : uploaded.clocks,
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

  /// Finishes the folder deletes that failed when a suggestion was handled
  /// offline: an owner's accepted or dismissed one, a reader's withdrawn
  /// one. Without rights to delete, the row waits for an owner to do it.
  Future<void> _retrySuggestionDeletes(
    SharedLibraryTransport t,
    String libraryId,
  ) async {
    for (final status in const [
      SharedSiteSuggestion.resolved,
      SharedSiteSuggestion.withdrawn,
    ]) {
      for (final s in await _store.suggestions(libraryId, status: status)) {
        try {
          await t.deleteSuggestion(s.id);
          await _store.deleteSuggestion(s.id);
        } catch (e) {
          if (!SharedLibraryTransport.isPermissionError(e)) rethrow;
          _log.warning('No rights to delete suggestion ${s.id}');
        }
      }
    }
  }

  /// Uploads the pending outgoing suggestions. True when the storage
  /// refused one for lack of rights: it and the rest stay pending.
  Future<bool> _uploadSuggestions(
    SharedLibraryTransport t,
    String libraryId, {
    required LibrarySigningKey key,
  }) async {
    final pending = await _store.suggestions(
      libraryId,
      direction: SharedSiteSuggestion.outgoing,
      status: SharedSiteSuggestion.pending,
    );
    for (final s in pending) {
      try {
        await t.writeSuggestion(s.id, await signSuggestion(s.toJson(), key));
      } catch (e) {
        if (!SharedLibraryTransport.isPermissionError(e)) rethrow;
        _log.warning('Library $libraryId refused a suggestion: read-only');
        return true;
      }
      await _store.putSuggestion(
        s.copyWith(status: SharedSiteSuggestion.uploaded),
      );
    }
    return false;
  }

  /// Takes in the suggestions their authors provably wrote, with a key an
  /// owner approved. Others stay in the folder and are read again next
  /// time (an approval may come).
  Future<void> _pullSuggestions(
    SharedLibraryTransport t,
    String libraryId, {
    required SharedLibraryRoles roles,
  }) async {
    final files = await t.listSuggestions();
    final remoteIds = {
      for (final f in files) SharedLibraryTransport.suggestionIdOf(f),
    };
    final held = await _store.suggestions(
      libraryId,
      direction: SharedSiteSuggestion.incoming,
    );
    final heldIds = {for (final s in held) s.id};
    for (final s in held) {
      if (!remoteIds.contains(s.id)) await _store.deleteSuggestion(s.id);
    }
    for (final f in files) {
      final id = SharedLibraryTransport.suggestionIdOf(f);
      if (heldIds.contains(id)) continue;
      try {
        final json = await t.readSuggestion(f.id);
        final author = json['memberId'];
        if (author is! String ||
            !await verifySuggestion(json, roles.approvedKeys[author])) {
          continue;
        }
        await _store.putSuggestion(
          SharedSiteSuggestion.fromJson(
            json,
            libraryId: libraryId,
            direction: SharedSiteSuggestion.incoming,
            remoteModifiedTime: f.modifiedTime.toUtc().toIso8601String(),
          ),
        );
      } on FormatException catch (e) {
        _log.warning('Skipping unreadable suggestion ${f.name}: $e');
      }
    }
  }
}

/// A pulled document with what its merge needs, read before the batch's
/// signatures are checked.
class _Pulled {
  const _Pulled({
    required this.remote,
    required this.stamp,
    required this.state,
    required this.hasRow,
    required this.local,
  });

  final SiteDocument remote;
  final String stamp;
  final SharedSiteState? state;
  final bool hasRow;
  final SiteDocument local;
}
