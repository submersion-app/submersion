import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const String _libraryFieldsKey = 'site.libraryFields';

/// The held changes of a site's rows that are not columns of the site.
const String siteTypesKey = 'site.types';
const String siteTagsKey = 'site.tags';
const String siteSpeciesKey = 'site.species';
const String siteFeaturesKey = 'site.features';

/// The library fields each held list changes when it is written. A list's
/// write sees the record, not the sitting, so it cannot note its field
/// itself ([noteSiteLibraryFields]): a held list is a write of its field.
const Map<String, Set<String>> _heldLibraryFields = {
  siteTypesKey: {'siteTypes'},
  siteTagsKey: {'tags'},
  siteSpeciesKey: {'species'},
  siteFeaturesKey: {'features'},
};

/// What a sitting on a site needs as it starts, before any card is open
/// (issue #4527, phase 2): the site's own rows that are not columns of the
/// site, read now, so each card's read layout can show the sitting's rows
/// once they change.
void startSiteSitting(EditSession<DiveSite> session, ProviderRead read) {
  siteTypesList.load(session);
  siteTagsList.load(session);
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
    for (final key in session.heldKeys) ...?_heldLibraryFields[key],
    ...?session.recall<Set<String>>(_libraryFieldsKey),
  };
}

/// Forgets the fields noted by an earlier attempt, before a save: one that
/// did not commit stamped nothing.
void clearSiteLibraryFields(EditSession<DiveSite> session) {
  if (session.isDisposed) return;
  session.remember(_libraryFieldsKey, null);
}
