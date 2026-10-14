part of 'shared_library_service.dart';

// What the push of a library sync builds and checks (issue #2567), and the
// suggestion side of a sync.

/// Whether [now] (the site's state as it is) differs from [before] (as a
/// pull read it): an edit was saved in between.
bool _editedSince(SharedSiteState? before, SharedSiteState? now) {
  if (before == null || now == null) return before != now;
  return before.deleted != now.deleted ||
      !const MapEquality<String, FieldClock>().equals(
        before.clocks,
        now.clocks,
      );
}

/// [doc] with each field another member signed under the clock the
/// folder's copy [remote] holds taking that copy's value: the value as
/// its author signed it, where this device keeps its own spelling or
/// order (its tag "wreck" for their "Wreck"). [local] are the members
/// whose fields this device signs itself. Only a value its author's key
/// in [keys] proves is taken: one changed in the folder under their clock
/// would go up again from every device.
Future<SiteDocument> _authorsValues(
  SiteDocument doc,
  SiteDocument remote,
  Set<String> local, {
  required String libraryId,
  required Map<String, String> keys,
  required Map<String, List<(String, int)>> retiredKeys,
}) async {
  final differing = <String>{
    for (final e in doc.clocks.entries)
      if (e.key != SiteDocument.deletedField &&
          !local.contains(e.value.memberId) &&
          remote.clocks[e.key] == e.value &&
          remote.fields.containsKey(e.key) &&
          !const DeepCollectionEquality().equals(
            remote.fields[e.key],
            doc.fields[e.key],
          ))
        e.key,
  };
  if (differing.isEmpty) return doc;
  final proven = await dropUnverified(
    SiteDocument(
      id: remote.id,
      fields: {for (final f in differing) f: remote.fields[f]},
      clocks: {for (final f in differing) f: remote.clocks[f]!},
    ),
    local: SiteDocument(id: remote.id),
    libraryId: libraryId,
    approvedKeys: keys,
    retiredKeys: retiredKeys,
  );
  return doc.copyWith(fields: {...doc.fields, ...proven.fields});
}

/// Fields going up with no clock, or stamped without a known member (a
/// device with two member profiles and no acting one), go up as this
/// profile's edits: a field nobody signed is dropped by every other
/// member.
SiteDocument _claimUnattributed(SiteDocument doc, String memberId) {
  final clocks = <String, FieldClock>{
    for (final e in doc.clocks.entries)
      e.key: e.value.memberId == LibraryEditStamper.unknownMember
          ? e.value.copyWith(memberId: memberId, clearSig: true)
          : e.value,
  };
  // A claim: signed, so it counts, yet any real edit of the field wins
  // over it. A field this member could not verify (and so holds empty)
  // never overwrites the value others hold.
  for (final field in [...doc.fields.keys, SiteDocument.deletedField]) {
    clocks[field] ??= FieldClock.claim(
      memberId,
      field == SiteDocument.deletedField ? doc.deleted : doc.fields[field],
    );
  }
  return doc.copyWith(clocks: clocks);
}

/// Suggestions in a library sync: retried deletes, uploads, and an owner's
/// pull of what members suggested.
extension _SuggestionSync on SharedLibraryService {
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
          await t.deleteSuggestion(s.fileId);
          await _store.deleteSuggestion(s.id);
        } catch (e) {
          if (!SharedLibraryTransport.isPermissionError(e)) rethrow;
          _log.warning('No rights to delete suggestion ${s.id}');
        }
      }
    }
  }

  /// Uploads the device's pending suggestions, each signed by the local
  /// profile that wrote it: another profile on this device may have
  /// written one, and a signature by the syncing profile would never
  /// verify as its author's. True when the storage refused one for lack of
  /// rights: it and the rest stay pending.
  Future<bool> _uploadSuggestions(
    SharedLibraryTransport t,
    String libraryId,
  ) async {
    final pending = await _store.suggestions(
      libraryId,
      direction: SharedSiteSuggestion.outgoing,
      status: SharedSiteSuggestion.pending,
    );
    if (pending.isEmpty) return false;
    final keys = <String, LibrarySigningKey>{
      for (final m in await _store.membershipsForLibrary(libraryId))
        m.memberId: m.signingKey ?? await _store.ensureSigningKey(m.diverId),
    };
    for (final s in pending) {
      final key = keys[s.memberId];
      // Its author no longer belongs here: nothing can sign it.
      if (key == null) continue;
      try {
        await t.writeSuggestion(
          s.id,
          await signSuggestion(s.toJson(), key, libraryId: libraryId),
        );
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
    // Taken in already, unless held for an approval that may since have
    // come.
    final known = {
      for (final s in held)
        if (s.status != SharedSiteSuggestion.held) s.fileId,
    };
    for (final s in held) {
      if (!remoteIds.contains(s.fileId)) await _store.deleteSuggestion(s.id);
    }
    // The keys on members' own signed cards: a suggestion signed by one
    // whose owner has not approved it yet is held, not dropped, so the
    // owner learns it is waiting.
    final cardKeys = {
      for (final m in await _store.getMembers(libraryId))
        if (m.cardVerified && m.publicKey != null) m.memberId: m.publicKey!,
    };
    for (final f in files) {
      final id = SharedLibraryTransport.suggestionIdOf(f);
      if (known.contains(id)) continue;
      try {
        final json = await t.readSuggestion(f.id);
        // A suggestion is the file of its own id: a copy under another name
        // (anyone who may write suggestions can make one) would come back
        // once its original was accepted or dismissed.
        if (json['id'] != id) {
          _log.warning('Suggestion ${f.name} names another id; skipped');
          continue;
        }
        final author = json['memberId'];
        if (author is! String) continue;
        final approved = roles.approvedKeys[author];
        final String status;
        if (approved != null) {
          if (!await verifySuggestion(json, approved, libraryId: libraryId)) {
            continue;
          }
          status = SharedSiteSuggestion.pending;
        } else if (await verifySuggestion(
          json,
          cardKeys[author],
          libraryId: libraryId,
        )) {
          status = SharedSiteSuggestion.held;
        } else {
          // Its author was rejected or left: nothing is waiting any more.
          await _store.deleteSuggestion(
            '${SharedSiteSuggestion.incomingPrefix}$id',
          );
          continue;
        }
        await _store.putSuggestion(
          SharedSiteSuggestion.fromJson(
            json,
            libraryId: libraryId,
            direction: SharedSiteSuggestion.incoming,
            remoteModifiedTime: f.modifiedTime.toUtc().toIso8601String(),
          ).copyWith(status: status),
        );
      } catch (e) {
        if (!SharedLibraryTransport.isUnreadable(e)) rethrow;
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
