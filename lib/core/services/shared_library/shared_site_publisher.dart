import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/member_clock.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/site_detacher.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';

/// Moves sites into and out of a club library (issue #2567): push converts
/// a personal site in place, delete stamps the tombstone and detaches the
/// local row, undelete wins the site back with a newer clock.
class SharedSitePublisher {
  SharedSitePublisher({
    SharedLibraryStore? store,
    SiteDetacher? detacher,
    SyncRepository? syncRepository,
  }) : _store = store ?? SharedLibraryStore(),
       _detacher = detacher ?? SiteDetacher(),
       _sync = syncRepository ?? SyncRepository();

  final SharedLibraryStore _store;
  final SiteDetacher _detacher;
  final SyncRepository _sync;
  AppDatabase get _db => DatabaseService.instance.database;

  Future<String> _memberId(String diverId, String libraryId) async {
    final membership = await _store.membership(
      diverId: diverId,
      libraryId: libraryId,
    );
    if (membership == null) {
      throw StateError('profile $diverId is not a member of $libraryId');
    }
    return membership.memberId;
  }

  /// A personal site becomes the library site, same id: `sharedLibraryId`
  /// set, owner and profile sharing cleared, every field clocked under
  /// the member, state dirty. Dives, plans, features, media and hides are
  /// untouched. A site already in a library is left alone.
  Future<void> push({
    required String siteId,
    required String libraryId,
    required String diverId,
  }) async {
    final memberId = await _memberId(diverId, libraryId);
    final row = await (_db.select(
      _db.diveSites,
    )..where((t) => t.id.equals(siteId))).getSingleOrNull();
    if (row == null) throw StateError('site $siteId does not exist');
    if (row.sharedLibraryId != null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final clock = MemberClock(memberId);
    final clocks = {
      for (final f in SiteDocument.fieldNames)
        f: FieldClock(hlc: clock.next(), memberId: memberId),
    };
    await _db.transaction(() async {
      await (_db.update(
        _db.diveSites,
      )..where((t) => t.id.equals(siteId))).write(
        DiveSitesCompanion(
          sharedLibraryId: Value(libraryId),
          diverId: const Value(null),
          isShared: const Value(false),
          updatedAt: Value(now),
        ),
      );
      await _store.putSiteState(
        SharedSiteState(
          siteId: siteId,
          libraryId: libraryId,
          clocks: clocks,
          dirty: true,
          lastEditorMemberId: memberId,
          lastEditedAtMs: now,
        ),
      );
      // The personal library drops its copy of the row: peers that already
      // hold the library row ignore the tombstone, peers that still carry
      // the old personal copy delete it.
      await _sync.logDeletions(entityType: 'diveSites', recordIds: [siteId]);
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Editors and owners: the site leaves the library for everyone. The
  /// tombstone is clocked under the member and uploaded by the next sync;
  /// locally the row is detached or removed right away.
  Future<void> deleteFromLibrary({
    required String siteId,
    required String diverId,
  }) async {
    final row = await (_db.select(
      _db.diveSites,
    )..where((t) => t.id.equals(siteId))).getSingleOrNull();
    final libraryId = row?.sharedLibraryId;
    if (libraryId == null) throw StateError('site $siteId is not in a library');
    final memberId = await _memberId(diverId, libraryId);
    final existing =
        await _store.getSiteState(siteId) ??
        SharedSiteState(siteId: siteId, libraryId: libraryId);
    final stamp = _stamp(existing, memberId);
    await _store.putSiteState(
      existing.copyWith(
        clocks: {...existing.clocks, SiteDocument.deletedField: stamp},
        deleted: true,
        dirty: true,
        lastEditorMemberId: memberId,
        lastEditedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _detacher.detachOrRemove(
      siteId: siteId,
      ownerDiverId: diverId,
      keepState: true,
    );
  }

  /// Wins a deleted site back: `deleted` is clocked false under the member
  /// and the next sync re-pulls the document (its fields still live in the
  /// library) and uploads the merged result.
  Future<void> undelete({
    required String siteId,
    required String diverId,
  }) async {
    final existing = await _store.getSiteState(siteId);
    if (existing == null) {
      throw StateError('site $siteId has no library state to undelete');
    }
    final memberId = await _memberId(diverId, existing.libraryId);
    final stamp = _stamp(existing, memberId);
    await _store.putSiteState(
      existing.copyWith(
        clocks: {...existing.clocks, SiteDocument.deletedField: stamp},
        deleted: false,
        dirty: true,
        clearRemoteModifiedTime: true,
        lastEditorMemberId: memberId,
        lastEditedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    SyncEventBus.notifyLocalChange();
  }

  static FieldClock _stamp(SharedSiteState state, String memberId) {
    final clock = MemberClock(memberId);
    for (final c in state.clocks.values) {
      clock.receive(c.hlc);
    }
    return FieldClock(hlc: clock.next(), memberId: memberId);
  }
}
