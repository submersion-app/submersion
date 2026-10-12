import 'dart:async';

import 'package:collection/collection.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/logger_service.dart';
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

/// One sync of one club library (issue #2567): manifest, roles and members,
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
      if (version > SharedLibraryLayout.formatVersion) {
        return await _fail(
          libraryId,
          SharedLibrarySyncStatus.needsNewerApp,
          'Library format $version needs a newer app',
        );
      }

      // 2. Roles and members.
      final roles = await t.readRoles();
      final members = await t.listMembers();
      await _store.setLibraryStatus(
        libraryId,
        roles: roles,
        name: manifest['name'] as String?,
      );
      await _store.replaceMembers(libraryId, members);
      // Probed afresh every sync: a refused upload sets it, so upgraded
      // credentials clear the banner on the next run.
      var readOnly = false;
      SharedLibraryMember? mine;
      for (final m in members) {
        if (m.memberId == membership.memberId) mine = m;
      }
      if (mine == null || mine.displayName != membership.displayName) {
        try {
          await t.writeMember(
            SharedLibraryMember(
              memberId: membership.memberId,
              displayName: membership.displayName,
              joinedAt: mine?.joinedAt ?? _now().toUtc(),
            ),
            appVersion: _appVersion,
          );
          if (mine == null) {
            await _store.replaceMembers(libraryId, [
              ...members,
              SharedLibraryMember(
                memberId: membership.memberId,
                displayName: membership.displayName,
                joinedAt: _now().toUtc(),
              ),
            ]);
          }
        } catch (e) {
          // A member card is a courtesy: a refused write is not a
          // read-only library (readers may write cards by policy).
          _log.warning('Could not write member card for $libraryId: $e');
        }
      }
      // 3. Pull.
      final states = await _store.siteStates(libraryId);
      final clock = MemberClock(membership.memberId);
      var pulled = 0;
      final siteFiles = await t.listSites();
      for (final f in siteFiles) {
        final siteId = SharedLibraryTransport.siteIdOf(f);
        final stamp = f.modifiedTime.toUtc().toIso8601String();
        if (states[siteId]?.remoteModifiedTime == stamp) continue;
        // Read afresh: an edit saved since the sync began has new clocks.
        final state = await _store.getSiteState(siteId);
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
        if (await _mergeRemote(
          library,
          remote,
          stamp,
          state,
          diverId: diverId,
          clock: clock,
        )) {
          pulled++;
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
        if (state.deleted && remoteFiles.containsKey(state.siteId)) {
          // A tombstone keeps the document's fields, so an undelete wins
          // the site back intact.
          try {
            final remote = await t.readSite(remoteFiles[state.siteId]!);
            doc = mergeSiteDocuments(local: doc, remote: remote).merged;
          } on FormatException {
            // Nothing readable to keep; the bare tombstone goes up.
          }
        }
        try {
          uploadAttempted = true;
          final modified = await t.writeSite(doc);
          await _recordUpload(state, modified);
          pushed++;
        } catch (e) {
          if (!SharedLibraryTransport.isPermissionError(e)) rethrow;
          _log.warning('Library $libraryId refused an upload: read-only');
          readOnly = true;
        }
      }

      // 5. Suggestions. Read-only credentials refuse them as they refuse
      // sites: the suggestions wait, and the library reads as read-only.
      await _retrySuggestionDeletes(t, libraryId);
      if (await _uploadSuggestions(t, libraryId)) {
        uploadAttempted = true;
        readOnly = true;
      }
      if (roles.roleOf(membership.memberId) == SharedLibraryRole.owner) {
        await _pullSuggestions(t, libraryId);
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
      final effectiveReadOnly = uploadAttempted
          ? readOnly
          : library.readOnlyDetected;
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

  Future<SharedLibrarySyncResult> _fail(
    String libraryId,
    SharedLibrarySyncStatus status,
    String error,
  ) async {
    await _store.setLibraryStatus(libraryId, lastError: error);
    return SharedLibrarySyncResult(status: status, error: error);
  }

  /// Folds [remote] into the local site. Returns true when the local row
  /// changed.
  Future<bool> _mergeRemote(
    SharedLibrary library,
    SiteDocument remote,
    String stamp,
    SharedSiteState? state, {
    required String diverId,
    required MemberClock clock,
  }) async {
    final siteId = remote.id;
    final hasRow = await SiteRepository().getSiteById(siteId) != null;
    final local = state == null
        ? SiteDocument(id: siteId)
        : hasRow && !state.deleted
        ? await _bridge.build(siteId, state)
        : SiteDocument(
            id: siteId,
            deleted: state.deleted,
            clocks: state.clocks,
          );
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

  /// Marks [sent] uploaded at [modified]. An edit saved while the upload
  /// was on the wire changed the clocks: it keeps them and stays dirty for
  /// the next sync. A null [modified] clears the stamp so the next pull
  /// re-reads the document.
  Future<void> _recordUpload(SharedSiteState sent, DateTime? modified) async {
    final current = await _store.getSiteState(sent.siteId) ?? sent;
    final editedMeanwhile =
        current.deleted != sent.deleted ||
        !const MapEquality<String, FieldClock>().equals(
          current.clocks,
          sent.clocks,
        );
    await _store.putSiteState(
      current.copyWith(
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
    String libraryId,
  ) async {
    final pending = await _store.suggestions(
      libraryId,
      direction: SharedSiteSuggestion.outgoing,
      status: SharedSiteSuggestion.pending,
    );
    for (final s in pending) {
      try {
        await t.writeSuggestion(s.id, s.toJson());
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

  Future<void> _pullSuggestions(
    SharedLibraryTransport t,
    String libraryId,
  ) async {
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
