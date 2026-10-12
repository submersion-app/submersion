import 'dart:async';

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
      var readOnly = library.readOnlyDetected;
      if (membership != null) {
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
      }

      // 3. Pull.
      final states = await _store.siteStates(libraryId);
      final clock = MemberClock(
        membership?.memberId ?? LibraryEditStamperMember.unknown,
      );
      var pulled = 0;
      for (final f in await t.listSites()) {
        final siteId = SharedLibraryTransport.siteIdOf(f);
        final state = states[siteId];
        final stamp = f.modifiedTime.toUtc().toIso8601String();
        if (state != null && state.remoteModifiedTime == stamp) continue;
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
      final remoteFiles = {
        for (final f in await t.listSites())
          SharedLibraryTransport.siteIdOf(f): f.id,
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
          final modified = await t.writeSite(doc);
          await _store.putSiteState(
            state.copyWith(
              dirty: false,
              remoteModifiedTime: modified.toUtc().toIso8601String(),
            ),
          );
          pushed++;
        } catch (e) {
          if (!SharedLibraryTransport.isPermissionError(e)) rethrow;
          _log.warning('Library $libraryId refused an upload: read-only');
          readOnly = true;
        }
      }

      // 5. Suggestions.
      await _uploadSuggestions(t, libraryId);
      if (membership != null &&
          roles.roleOf(membership.memberId) == SharedLibraryRole.owner) {
        await _pullSuggestions(t, libraryId);
      }

      // 6. Status.
      await _store.setLibraryStatus(
        libraryId,
        lastSyncAt: _now(),
        clearError: true,
        readOnlyDetected: readOnly,
      );
      return SharedLibrarySyncResult(
        status: readOnly
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
    final newest = _newestClock(merged.clocks);
    final base =
        state ?? SharedSiteState(siteId: siteId, libraryId: library.id);

    if (merged.deleted) {
      if (hasRow) {
        await _remover(siteId: siteId, ownerDiverId: diverId);
      }
      await _store.putSiteState(
        base.copyWith(
          clocks: merged.clocks,
          deleted: true,
          dirty: (state?.dirty ?? false) || outcome.needsUpload,
          remoteModifiedTime: stamp,
          lastEditorMemberId: newest?.memberId,
          lastEditedAtMs: newest?.hlc.physicalTime,
        ),
      );
      return hasRow;
    }

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
    await _store.putSiteState(
      base.copyWith(
        clocks: merged.clocks,
        deleted: false,
        dirty: (state?.dirty ?? false) || outcome.needsUpload,
        remoteModifiedTime: stamp,
        lastEditorMemberId: newest?.memberId,
        lastEditedAtMs: newest?.hlc.physicalTime,
      ),
    );
    return fields.isNotEmpty;
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

  static FieldClock? _newestClock(Map<String, FieldClock> clocks) {
    FieldClock? newest;
    for (final c in clocks.values) {
      if (newest == null || c.hlc.compareTo(newest.hlc) > 0) newest = c;
    }
    return newest;
  }

  Future<void> _uploadSuggestions(
    SharedLibraryTransport t,
    String libraryId,
  ) async {
    final pending = await _store.suggestions(
      libraryId,
      direction: SharedSiteSuggestion.outgoing,
      status: SharedSiteSuggestion.pending,
    );
    for (final s in pending) {
      await t.writeSuggestion(s.id, s.toJson());
      await _store.putSuggestion(
        s.copyWith(status: SharedSiteSuggestion.uploaded),
      );
    }
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

/// The member id recorded when a sync runs without a membership.
abstract final class LibraryEditStamperMember {
  static const unknown = 'unknown';
}
