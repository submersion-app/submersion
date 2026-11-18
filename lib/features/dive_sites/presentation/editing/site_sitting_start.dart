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

const String _libraryFieldsKey = 'site.libraryFields';

/// One of the site's rows that are not columns of the site, held as a
/// list: how a sitting loads it, and the library fields its write changes.
typedef SiteHeldList = ({
  String key,
  Future<void> Function(EditSession<DiveSite> session) load,
  Set<String> libraryFields,
});

/// The site's held lists, in one table: each is loaded as a sitting starts
/// and, once held, is a write of its library fields. A list's write sees
/// the record, not the sitting, so it cannot note its fields itself
/// ([noteSiteLibraryFields]); kept together, a list cannot be loaded here
/// without naming them.
final List<SiteHeldList> siteHeldLists = [
  (
    key: siteTypesList.key,
    load: siteTypesList.load,
    libraryFields: {'siteTypes'},
  ),
  (key: siteTagsList.key, load: siteTagsList.load, libraryFields: {'tags'}),
  (
    key: siteSpeciesList.key,
    load: siteSpeciesList.load,
    libraryFields: {'species'},
  ),
  (
    key: siteFeaturesList.key,
    load: siteFeaturesList.load,
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

/// Records that a held write touched [fields] of a library site, for the
/// stamp made once the sitting has committed: held writes write without
/// stamping, since a rollback would not undo a stamp.
void noteSiteLibraryFields(EditSession<DiveSite> session, Set<String> fields) {
  if (fields.isEmpty || session.isDisposed) return;
  session.remember(_libraryFieldsKey, {
    ...siteLibraryFields(session),
    ...fields,
  });
}

/// The library fields the sitting's held writes touch: those of the held
/// lists, and those a held write noted in this save.
Set<String> siteLibraryFields(EditSession<DiveSite> session) {
  if (session.isDisposed) return const {};
  return {
    for (final list in siteHeldLists)
      if (session.isHeld(list.key)) ...list.libraryFields,
    ...?session.recall<Set<String>>(_libraryFieldsKey),
  };
}

/// Forgets the fields noted by an earlier attempt, before a save: one that
/// did not commit stamped nothing.
void clearSiteLibraryFields(EditSession<DiveSite> session) {
  if (session.isDisposed) return;
  session.remember(_libraryFieldsKey, null);
}
