import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';

/// The id of the personal copy a detached library site [siteId] survives as.
///
/// Deterministic, so every device of a diver that detaches the same site
/// makes the same row and personal sync merges one copy instead of two. It
/// never equals [siteId], so an undelete in the library cannot collide with
/// it. The name string is frozen: changing it would fork every copy.
String detachedSiteId(String siteId) => const Uuid().v5(
  Namespace.url.value,
  'submersion:detached-library-site:$siteId',
);

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
    final newId = detachedSiteId(siteId);
    // Another device of this diver may have detached first and its copy
    // already arrived by personal sync: relink to it rather than insert.
    final arrived = await _sites.getSiteById(newId) != null;
    await _db.transaction(() async {
      if (!arrived) {
        await _sites.createSite(
          // Shared with every local profile, as the library site was visible to
          // all of them; the owner may unshare it later.
          site.copyWith(
            id: newId,
            diverId: ownerDiverId,
            isShared: true,
            clearSharedLibraryId: true,
          ),
        );
      }
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
