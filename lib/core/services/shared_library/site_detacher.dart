import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';

/// A library site leaving this device (issue #2567): when the library's
/// tombstone arrives, when a referent deletes it here, or when the member
/// leaves. A site that any dive or plan links to survives as a personal
/// site under a new id, with dives, plans, media, features, species, types
/// and tags re-pointed, so an undelete in the library can never collide
/// with it. A site nothing links to is removed, with no personal tombstone.
class SiteDetacher {
  SiteDetacher({SharedLibraryStore? store, SiteRepository? sites})
    : _store = store ?? SharedLibraryStore(),
      _sites = sites ?? SiteRepository();

  final SharedLibraryStore _store;
  final SiteRepository _sites;
  final _uuid = const Uuid();
  AppDatabase get _db => DatabaseService.instance.database;

  /// Returns the id of the personal copy, or null when the site was removed
  /// or already gone. [keepState] leaves the library state row in place
  /// (a local delete still has its tombstone to upload).
  Future<String?> detachOrRemove({
    required String siteId,
    required String ownerDiverId,
    bool keepState = false,
  }) async {
    final site = await _sites.getSiteById(siteId);
    if (site == null) {
      if (!keepState) await _store.deleteSiteState(siteId);
      return null;
    }
    if (!await _sites.hasLinks(siteId)) {
      await _sites.deleteSite(siteId, logTombstones: false);
      if (!keepState) await _store.deleteSiteState(siteId);
      return null;
    }
    final newId = _uuid.v4();
    await _db.transaction(() async {
      await _sites.createSite(
        // Shared with every local profile, as the club site was visible to
        // all of them; the owner may unshare it later.
        site.copyWith(
          id: newId,
          diverId: ownerDiverId,
          isShared: true,
          clearSharedLibraryId: true,
        ),
      );
      await _sites.relinkSiteReferences(from: siteId, to: newId);
      await _sites.deleteSite(
        siteId,
        logTombstones: false,
        cascadeMedia: false,
      );
      if (!keepState) await _store.deleteSiteState(siteId);
    });
    SyncEventBus.notifyLocalChange();
    return newId;
  }
}
