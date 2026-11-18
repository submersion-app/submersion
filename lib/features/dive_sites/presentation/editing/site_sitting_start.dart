import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_features_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sharing_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_species_sitting.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// One of the site's rows that are not columns of the site, held as a
/// list: how a sitting loads it, and the library fields its write changes.
typedef SiteHeldList = ({
  String key,
  Future<void> Function(EditSession<DiveSite> session) load,
  bool? Function(EditSession<DiveSite> session) wroteChange,
  Set<String> libraryFields,
});

/// The site's held lists, in one table: each is loaded as a sitting starts
/// and, once held, is a write of its library fields. A list's write sees
/// the record, not the sitting, so it cannot note its fields itself
/// ([wroteChange] says whether it changed anything); kept together, a list cannot be loaded here
/// without naming them.
final List<SiteHeldList> siteHeldLists = [
  (
    key: siteTypesList.key,
    load: siteTypesList.load,
    wroteChange: siteTypesList.wroteChange,
    libraryFields: {'siteTypes'},
  ),
  (
    key: siteTagsList.key,
    load: siteTagsList.load,
    wroteChange: siteTagsList.wroteChange,
    libraryFields: {'tags'},
  ),
  (
    key: siteSpeciesList.key,
    load: siteSpeciesList.load,
    wroteChange: siteSpeciesList.wroteChange,
    libraryFields: {'species'},
  ),
  (
    key: siteFeaturesList.key,
    load: siteFeaturesList.load,
    wroteChange: siteFeaturesList.wroteChange,
    libraryFields: {'features'},
  ),
];

/// What a sitting on a site needs as it starts, before any card is open
/// (issue #4527, phase 2): the site's own rows that are not columns of the
/// site, read now, so each card's read layout can show the sitting's rows
/// once they change.
void startSiteSitting(EditSession<DiveSite> session, ProviderRead read) {
  for (final list in siteHeldLists) {
    list.load(session);
  }
  loadSiteSharing(session, read);
  holdSittingMedia(
    session,
    SittingMediaWriters.forSite(read),
    cardId: SiteDetailSectionId.media.name,
  );
  holdDocumentLinks(
    session,
    read,
    owner: DocumentOwner(DocumentOwnerKind.site, session.stored.id),
    cardId: SiteDetailSectionId.documents.name,
  );
}

/// The library fields the sitting's held writes changed, for the stamp made
/// once the sitting has committed: held writes write without stamping, since
/// a rollback would not undo a stamp.
Set<String> siteLibraryFields(EditSession<DiveSite> session) {
  if (session.isDisposed) return const {};
  return {
    for (final list in siteHeldLists)
      // A list whose write changed no stored row gets no fresh clock.
      if (session.isHeld(list.key) && list.wroteChange(session) != false)
        ...list.libraryFields,
  };
}
