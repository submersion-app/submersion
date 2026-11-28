import 'package:drift/drift.dart' show Variable;
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/library_document_stamper.dart';
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
/// leaves. A site that any dive or plan links to, or that holds a private
/// document of a profile here (issue #4713), survives as a personal site
/// under a new id, with dives, plans, media, documents, features, species,
/// types and tags re-pointed, so an undelete in the library can never
/// collide with it; its shared documents stay as private copies. A site
/// nothing links to is removed with its shared documents, with no personal
/// tombstone.
class SiteDetacher {
  SiteDetacher({
    SharedLibraryStore? store,
    SiteRepository? sites,
    LibraryDocumentStamper? documents,
  }) : _store = store ?? SharedLibraryStore(),
       _sites = sites ?? SiteRepository(),
       _documents = documents ?? LibraryDocumentStamper(store: store);

  final SharedLibraryStore _store;
  final SiteRepository _sites;
  final LibraryDocumentStamper _documents;
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
    if (!await _sites.hasLinks(siteId) &&
        !await _holdsPrivateDocuments(siteId)) {
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
      // Shared documents stay as the diver's own, filed on the site until
      // the relink below moves them with the rest.
      for (final documentId in await _sharedDocumentsOf(siteId)) {
        await _documents.keepAsPrivate(documentId, ownerDiverId);
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

  /// Whether a profile here has a private document filed on [siteId]:
  /// removing the site would delete it on every device of that profile.
  Future<bool> _holdsPrivateDocuments(String siteId) async =>
      (await _db
              .customSelect(
                'SELECT 1 FROM documents WHERE site_id = ? '
                'AND shared_library_id IS NULL LIMIT 1',
                variables: [Variable.withString(siteId)],
              )
              .get())
          .isNotEmpty;

  Future<List<String>> _sharedDocumentsOf(String siteId) async => [
    for (final r
        in await _db
            .customSelect(
              'SELECT id FROM documents WHERE site_id = ? '
              'AND shared_library_id IS NOT NULL',
              variables: [Variable.withString(siteId)],
            )
            .get())
      r.read<String>('id'),
  ];
}
